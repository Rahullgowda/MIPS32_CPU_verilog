module pipe_mips32(clk1,clk2);
input clk1,clk2; // Two phase clock
reg[31:0] PC,IF_ID_IR,IF_ID_NPC;
reg [31:0] ID_EX_IR,ID_EX_NPC,ID_EX_A,ID_EX_B,ID_EX_IMM;
reg [2:0] ID_EX_Type,EX_MEM_Type,MEM_WB_Type;
reg [31:0] EX_MEM_IR,EX_MEM_aluout,EX_MEM_B;
reg EX_MEM_cond;
reg [31:0] MEM_WB_IR,MEM_WB_aluout,MEM_WB_Lmd;
reg [31:0] regbank[31:0];
reg [31:0] mem[1023:0];

parameter ADD=6'b000000,
          SUB=6'b000001,
          AND=6'b000010,
          OR=6'b000011,
          SLT=6'b000100,
          MUL=6'b000101,
          HLT=6'b111111,
          LW=6'b001000,
          SW=6'b001001,
          ADDI=6'b001010,
          SUBI=6'b001011,
          SLTI=6'b001100,
          BNEQZ=6'b001101,
          BEQZ=6'b001110;

parameter RR_ALU=3'b000,
          RI_ALU=3'b001,
          LOAD=3'b010,
          STORE=3'b011,
          BRANCH=3'b100,
          HALT=3'b101;

reg HALTED;
reg TAKEN_BRANCH;

// INSTRUCTION FETCH STAGE:
always@(posedge clk1)
if(HALTED==0)
begin
    if (((EX_MEM_IR[31:26] == BEQZ) && (EX_MEM_cond == 1)) ||
        ((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_cond == 0)))
    begin
        IF_ID_IR   <= #2 mem[EX_MEM_aluout];
        TAKEN_BRANCH <= #2 1'b1;
        IF_ID_NPC  <= #2 EX_MEM_aluout + 1;
        PC         <= #2 EX_MEM_aluout + 1;
    end
    else
    begin
        IF_ID_IR   <= #2 mem[PC];
        IF_ID_NPC  <= #2 PC+1;
        PC         <= #2 PC+1;
    end
end

// Instruction Decode Stage : 
always @(posedge clk2)      
    if (HALTED == 0)
    begin
        if (IF_ID_IR[25:21] == 5'b00000) // r0 always zero
            ID_EX_A <= 0;
        else
            ID_EX_A <= #2 regbank[IF_ID_IR[25:21]];  // rs

        if (IF_ID_IR[20:16] == 5'b00000) // r0 always zero
            ID_EX_B <= 0;
        else
            ID_EX_B <= #2 regbank[IF_ID_IR[20:16]];  // rt

        ID_EX_NPC <= #2 IF_ID_NPC;
        ID_EX_IR  <= #2 IF_ID_IR;
        ID_EX_IMM <= #2 {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}};

        case(IF_ID_IR[31:26])
            ADD,SUB,AND,OR,SLT,MUL : ID_EX_Type <= #2 RR_ALU;
            ADDI,SUBI,SLTI         : ID_EX_Type <= #2 RI_ALU;
            LW                     : ID_EX_Type <= #2 LOAD;
            SW                     : ID_EX_Type <= #2 STORE;
            BNEQZ,BEQZ             : ID_EX_Type <= #2 BRANCH;
            HLT                    : ID_EX_Type <= #2 HALT;
            default                : ID_EX_Type <= #2 HALT;
        endcase
    end

// EXECUTION STAGE : 
always @(posedge clk1) begin
    if (HALTED == 0) begin
        EX_MEM_Type  <= #2 ID_EX_Type;   
        EX_MEM_IR    <= #2 ID_EX_IR;
        TAKEN_BRANCH <= #2 0;

        case (ID_EX_Type)

            // R-type ALU
            RR_ALU: begin
                case (ID_EX_IR[31:26])
                    ADD : EX_MEM_aluout <= #2 (ID_EX_A + ID_EX_B);
                    SUB : EX_MEM_aluout <= #2 (ID_EX_A - ID_EX_B);
                    AND : EX_MEM_aluout <= #2 (ID_EX_A & ID_EX_B);
                    OR  : EX_MEM_aluout <= #2 (ID_EX_A | ID_EX_B);
                    SLT : EX_MEM_aluout <= #2 (ID_EX_A < ID_EX_B);
                    MUL : EX_MEM_aluout <= #2 (ID_EX_A * ID_EX_B);
                    default: EX_MEM_aluout <= #2 32'hxxxxxxxx;
                endcase
            end

            // I-type ALU
            RI_ALU: begin
                case (ID_EX_IR[31:26])
                    ADDI:    EX_MEM_aluout <= #2 (ID_EX_A + ID_EX_IMM);
                    SUBI:    EX_MEM_aluout <= #2 (ID_EX_A - ID_EX_IMM);
                    SLTI:    EX_MEM_aluout <= #2 (ID_EX_A < ID_EX_IMM);
                    default: EX_MEM_aluout <= #2 32'hxxxxxxxx;
                endcase
            end

            // LOAD / STORE
            LOAD, STORE: begin
                EX_MEM_aluout <= #2 (ID_EX_A + ID_EX_IMM);
                EX_MEM_B      <= #2 ID_EX_B;
            end

            // BRANCH
            BRANCH: begin
                EX_MEM_aluout <= #2 (ID_EX_NPC + ID_EX_IMM);
                EX_MEM_cond   <= #2 (ID_EX_A == 0);
            end

            // Default
            default: begin
                EX_MEM_aluout <= #2 32'hxxxxxxxx;
            end

        endcase
    end
end

// MEM Stage
always @(posedge clk2)
    if (HALTED == 0)
    begin
        MEM_WB_Type <= #2 EX_MEM_Type;
        MEM_WB_IR   <= #2 EX_MEM_IR;

        case (EX_MEM_Type)
            RR_ALU, RI_ALU:
                MEM_WB_aluout <= #2 EX_MEM_aluout;

            LOAD:
                MEM_WB_Lmd <= #2 mem[EX_MEM_aluout];

            STORE: if (TAKEN_BRANCH == 0)   // Disable write
                       mem[EX_MEM_aluout] <= #2 EX_MEM_B;
        endcase
    end

// WB Stage
always @(posedge clk1)
begin
    if (TAKEN_BRANCH == 0)   // Disable write if branch taken
        case (MEM_WB_Type)
            RR_ALU:  regbank[MEM_WB_IR[15:11]] <= #2 MEM_WB_aluout;  // "rd"
            RI_ALU:  regbank[MEM_WB_IR[20:16]] <= #2 MEM_WB_aluout;  // "rt"
            LOAD:    regbank[MEM_WB_IR[20:16]] <= #2 MEM_WB_Lmd;     // "rt"
            HALT:    HALTED <= #2 1'b1;
        endcase
end

endmodule


// TEST BENCH MODULE: 


module testbench_mips32;
    reg clk1, clk2;
    integer k;

    pipe_mips32 mips(clk1, clk2);

    initial begin
        clk1 = 0; clk2 = 0;
        repeat (20) begin
            #5 clk1 = 1; #5 clk1 = 0;
            #5 clk2 = 1; #5 clk2 = 0;
        end
    end

    initial begin
        // Initialize registers
        for (k = 0; k < 31; k = k + 1)
            mips.regbank[k] = k;

        // Program in memory
        mips.mem[0] = 32'h2801000a;   // ADDI  R1, R0, 10
        mips.mem[1] = 32'h28020014;   // ADDI  R2, R0, 20
        mips.mem[2] = 32'h28030019;   // ADDI  R3, R0, 25
        mips.mem[3] = 32'h0ce77800;   // OR    R7, R7, R7  -- dummy instr.
        mips.mem[4] = 32'h0ce77800;   // OR    R7, R7, R7  -- dummy instr.
        mips.mem[5] = 32'h00222000;   // ADD   R4, R1, R2
        mips.mem[6] = 32'h0ce77800;   // OR    R7, R7, R7  -- dummy instr.
        mips.mem[7] = 32'h00832800;   // ADD   R5, R4, R3
        mips.mem[8] = 32'hfc000000;   // HLT

        // Reset signals
        mips.HALTED = 0;
        mips.PC = 0;
        mips.TAKEN_BRANCH = 0;

        // Wait and print register values
        #280
        for (k = 0; k < 6; k = k + 1)
            $display("R%1d = %2d", k, mips.regbank[k]);
    end

    initial begin
        $dumpfile("pipe_mips32.vcd");
        $dumpvars(0, testbench_mips32);  // dump only testbench + DUT
        #300 $finish;
    end
endmodule
