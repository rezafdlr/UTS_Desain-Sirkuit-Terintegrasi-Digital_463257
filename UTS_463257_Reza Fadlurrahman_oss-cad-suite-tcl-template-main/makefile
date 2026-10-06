DIR_BUILD = build
DIR_CONS = constraints
DIR_RTL = rtl
DIR_SIM = sim
DIR_TB = tb
DIR_TCL = tcl
 
TOP_LEVEL = top_tm1638_demo
VERILOGS = $(DIR_RTL)/$(TOP_LEVEL).v $(DIR_RTL)/tm1638.v
CELLS_SIM = $(DIR_SIM)/cells_sim.v

.PHONY: compile vvp gtk sim syn pnr bit flash all clean

compile:
	if not exist $(DIR_BUILD) mkdir $(DIR_BUILD)
	iverilog -g2012 \
	-o $(DIR_BUILD)/$(TOP_LEVEL)_sim \
	$(VERILOGS) \
	$(CELLS_SIM) \
	$(DIR_TB)/$(TOP_LEVEL)_tb.v

vvp:
	vvp $(DIR_BUILD)/$(TOP_LEVEL)_sim

gtk:
	gtkwave $(DIR_BUILD)/$(TOP_LEVEL)_tb.vcd

sim:
	if not exist $(DIR_BUILD) mkdir $(DIR_BUILD)
	iverilog -g2012 -o $(DIR_BUILD)/$(TOP_LEVEL)_sim $(VERILOGS) $(CELLS_SIM) $(DIR_TB)/$(TOP_LEVEL)_tb.v
	vvp $(DIR_BUILD)/$(TOP_LEVEL)_sim
	gtkwave $(DIR_BUILD)/$(TOP_LEVEL)_tb.vcd

#syn:
# 	yosys -c $(DIR_RTL)/$(TOP_LEVEL).tcl

syn:
	if not exist $(DIR_BUILD) mkdir $(DIR_BUILD)
	yosys -p "synth_ice40 -top $(TOP_LEVEL) -json $(DIR_BUILD)/$(TOP_LEVEL)_netlist.json" $(VERILOGS)

pnr:
	nextpnr-ice40 \
		--up5k \
		--package sg48 \
		--json $(DIR_BUILD)/$(TOP_LEVEL)_netlist.json \
		--pcf $(DIR_CONS)/$(TOP_LEVEL).pcf \
		--asc $(DIR_BUILD)/$(TOP_LEVEL).asc

bit:
	icepack $(DIR_BUILD)/$(TOP_LEVEL).asc $(DIR_BUILD)/$(TOP_LEVEL).bin

flash:
	icesprog $(DIR_BUILD)/$(TOP_LEVEL).bin

all:
	if not exist $(DIR_BUILD) mkdir $(DIR_BUILD)
	yosys -p "synth_ice40 -top $(TOP_LEVEL) -json $(DIR_BUILD)/$(TOP_LEVEL)_netlist.json" $(VERILOGS)
	nextpnr-ice40 \
		--up5k \
		--package sg48 \
		--json $(DIR_BUILD)/$(TOP_LEVEL)_netlist.json \
		--pcf $(DIR_CONS)/$(TOP_LEVEL).pcf \
		--asc $(DIR_BUILD)/$(TOP_LEVEL).asc
	icepack $(DIR_BUILD)/$(TOP_LEVEL).asc $(DIR_BUILD)/$(TOP_LEVEL).bin

clean:
	if exist $(DIR_BUILD) rmdir $(DIR_BUILD) /S /Q