# MIPS32 Pipeline CPU (Verilog)

This project implements a **5-stage pipelined MIPS32 processor** in Verilog, including a testbench and waveform verification using **Icarus Verilog** and **GTKWave**.  

## 📌 Highlights
- 5 classic pipeline stages: **IF → ID → EX → MEM → WB**
- Supports **R-type, I-type, Load/Store, Branch, Halt**
- Written in **Verilog HDL** with proper testbench
- Simulation and waveform analysis using **GTKWave**
- Beginner-friendly CPU design project  

## 🛠️ How to Run
1. Compile with Icarus Verilog:
   ```bash
   iverilog -o pipe_mips32.vvp pipe_mips32.v testbench_mips32.v
   vvp pipe_mips32.vvp


