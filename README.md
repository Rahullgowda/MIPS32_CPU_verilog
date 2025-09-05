# MIPS32_CPU_verilog
5-stage pipelined MIPS32 CPU written in Verilog with testbench and GTKWave simulation.

# MIPS-32 Pipelined CPU in Verilog
5-stage pipeline (IF, ID, EX, MEM, WB)  
Testbench included  
Simulated using Icarus Verilog + GTKWave  

### How to Run
```bash
iverilog -o pipe_mips32.vvp pipe_mips32.v testbench_mips32.v
vvp pipe_mips32.vvp
gtkwave pipe_mips32.vcd

