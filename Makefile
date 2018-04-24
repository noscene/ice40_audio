PROJ = audiotest
#PIN_DEF = audiotest.pcf
PIN_DEF = audiotest_up5k.pcf
#DEVICE = hx8k
DEVICE = up5k

all: $(PROJ).rpt $(PROJ).bin header

%.blif: %.v

	php hexgen.php > sine_table.hex
	php sin_pi2.php > sin_pi2.hex
	yosys -v 2 -p 'synth_ice40 -top top -blif $@' $<

%.asc: $(PIN_DEF) %.blif
	#arachne-pnr -d 8k  -o $@ -p $^ -P tq144:4k
	arachne-pnr -d 5k  -o $@ -p $^ -P sg48

header: $(PROJ).bin
	xxd -i $(PROJ).bin  > $(PROJ).h
	sed -i -r 's/unsigned/const unsigned/g' $(PROJ).h

%.bin: %.asc
	icepack $< $@

%.rpt: %.asc
	icetime -d $(DEVICE) -mtr $@ $<

prog: $(PROJ).bin
	#iCEburn.py  -e -v -w  $<
	curl -F file=@audiotest.bin http://10.0.1.40/fupload 

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	iCEburn.py  -e -v -w  $<

clean:
	rm -f $(PROJ).blif $(PROJ).asc $(PROJ).rpt $(PROJ).bin $(PROJ).h

.PHONY: all prog clean
