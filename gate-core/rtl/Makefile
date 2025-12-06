# OPEN GATE RTL simulation

SIM = iverilog
COCOTB = python3 -m cocotb

all: sim

sim: tb_open_gate
	$(COCOTB) run -v test_gate.py --sim=icarus

tb_open_gate: open_gate.sv tb_open_gate.sv
	$(SIM) -o tb_open_gate -g2012 open_gate.sv tb_open_gate.sv

wave: sim
	gtkwave tb_open_gate.vcd &

clean:
	rm -f tb_open_gate *.vcd *.vvp
	rm -rf pycache

.PHONY: all sim wave clean
