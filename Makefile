PROJ = audiotest
PIN_DEF = audiotest.pcf
DEVICE = hx8k
#DEVICE = up5k

all: $(PROJ).rpt $(PROJ).bin

%.blif: %.v

	php hexgen.php > sine_table.hex
	yosys -v 1 -p 'synth_ice40 -top top -blif $@' $<

%.asc: $(PIN_DEF) %.blif
	arachne-pnr -d 8k  -o $@ -p $^ -P tq144:4k
	#arachne-pnr -d 5k  -o $@ -p $^ -P sg48

%.bin: %.asc
	icepack $< $@

%.rpt: %.asc
	icetime -d $(DEVICE) -mtr $@ $<

prog: $(PROJ).bin
	iCEburn.py  -e -v -w  $<

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	iCEburn.py  -e -v -w  $<

clean:
	rm -f $(PROJ).blif $(PROJ).asc $(PROJ).rpt $(PROJ).bin

.PHONY: all prog clean
