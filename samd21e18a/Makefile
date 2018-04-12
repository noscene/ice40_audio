LDSCRIPT = xdk-asf/samd21e18a_flash.ld
BOOTUP = xdk-asf/startup_samd21.o xdk-asf/system_samd21.o
MCUTYPE=__SAMD21E18A__

OBJS=$(BOOTUP) zmSAMD21.o

# Tools
CC=arm-none-eabi-gcc
LD=arm-none-eabi-gcc
AR=arm-none-eabi-ar
AS=arm-none-eabi-as
OC=arm-none-eabi-objcopy

ELF=zmSAMD21.elf

LDFLAGS+= -T$(LDSCRIPT) -mthumb -mcpu=cortex-m0 -Wl,--gc-sections
CFLAGS+= -mcpu=cortex-m0 -mthumb -g -Os  -fno-exceptions -std=c99
CFLAGS+= -I xdk-asf -I xdk-asf/include -I xdk-asf/cmsis -I .
CFLAGS+= -D$(MCUTYPE)

all: $(ELF) bin


$(ELF): $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS) $(LDLIBS)

# compile and generate dependency info
%.o:    %.c
	$(CC) -c $(CFLAGS) $< -o $@
	$(CC) -MM $(CFLAGS) $< > $*.d

%.o:    %.s
	$(AS) $< -o $@


bin:	$(ELF)
	$(OC) -O binary $(ELF) zmSAMD21.bin


clean:
	rm -f $(OBJS) $(OBJS:.o=.d) $(ELF) startup_stm32f* $(CLEANOTHER) zmSAMD21.bin

debug:  $(ELF)
	arm-none-eabi-gdb -iex "target extended-remote localhost:3333 " -ex "load" -ex "monitor reset" -ex "set confirm off" -ex "quit"  $(ELF)
#	arm-none-eabi-gdb -iex "target extended-remote localhost:3333 " -ex "load" -ex "monitor reset"  $(ELF)
#	arm-none-eabi-gdb -iex "target extended-remote 10.0.1.1:3333 " -ex "load" -ex "monitor reset"  $(ELF)

# pull in dependencies
-include        $(OBJS:.o=.d)

