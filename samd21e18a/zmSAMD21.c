#include <samd21.h>
#include <audiotest.h>


#define byte unsigned char
#define bool int

#define led  2

#define INPUT 0
#define INPUT_PULLUP 0 // https://github.com/gioblu/PJON/pull/30/files
#define OUTPUT 1
#define LOW 0
#define HIGH 1

void pinMode(int p, int mode) {
	if(mode==OUTPUT) {
		REG_PORT_DIR0 |= (1<<p);
	}else if(mode==INPUT){
		REG_PORT_DIR0 &= ~(1<<p);
	}
}

static inline void digitalWrite(int p, int b) {
    
    // REG_PORT_OUTTGL0
    
	if(b){
		REG_PORT_OUT0 |= (1<<p);
	}else{
		REG_PORT_OUT0 &= ~(1<<p);
	}
}

int digitalRead(int p) {
	if(REG_PORT_IN0 & (1<<p)) return 1;
	return 0;
}

void delay(int n) {
    for (;n >0; n--)    {
        for (int i=0;i<100;i++)
            __asm("nop");
    }
}

#define CPU_FREQUENCY 48000000
#define NVM_SW_CALIB_DFLL48M_COARSE_VAL   58
#define CRYSTALLESS 1

#define SYSCTRL_FUSES_OSC32K_CAL_ADDR   (NVMCTRL_OTP4 + 4)
#define SYSCTRL_FUSES_OSC32K_CAL_Pos   6
#define 	SYSCTRL_FUSES_OSC32K_ADDR   SYSCTRL_FUSES_OSC32K_CAL_ADDR
#define 	SYSCTRL_FUSES_OSC32K_Pos   SYSCTRL_FUSES_OSC32K_CAL_Pos
#define 	SYSCTRL_FUSES_OSC32K_Msk   (0x7Fu << SYSCTRL_FUSES_OSC32K_Pos)
//volatile bool g_interrupt_enabled = true;

static void gclk_sync(void) {
    while (GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY)
        ;
}

static void dfll_sync(void) {
    while ((SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY) == 0)
        ;
}

#define FLASH_WAIT_STATES                 1
#define NVM_SW_CALIB_DFLL48M_COARSE_VAL   58
#define NVM_SW_CALIB_DFLL48M_FINE_VAL     64

void clock_init(void) {
    
    PORT->Group[1].DIRSET.reg = (1<<3);
	PORT->Group[1].OUTSET.reg = (1<<3);
	PORT->Group[0].DIRSET.reg = (1<<27);
	PORT->Group[0].OUTSET.reg = (1<<27);
	/* Configure flash wait states */
	NVMCTRL->CTRLB.bit.RWS = FLASH_WAIT_STATES;

	/* Set OSC8M prescalar to divide by 1 */
	SYSCTRL->OSC8M.bit.PRESC = 0;

	/* Configure OSC8M as source for GCLK_GEN0 */
	GCLK_GENCTRL_Type genctrl={0};
	uint32_t temp_genctrl;
	GCLK->GENCTRL.bit.ID = 0; /* GENERATOR_ID - GCLK_GEN_0 */
	while(GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY);
	temp_genctrl = GCLK->GENCTRL.reg;
	genctrl.bit.SRC = GCLK_GENCTRL_SRC_OSC8M_Val;
	genctrl.bit.GENEN = 1;
	genctrl.bit.RUNSTDBY = 0;
	GCLK->GENCTRL.reg = (genctrl.reg | temp_genctrl);
	while(GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY);  
	
	
	
	SYSCTRL_DFLLCTRL_Type dfllctrl_conf = {0};
	SYSCTRL_DFLLVAL_Type dfllval_conf = {0};
	uint32_t coarse =( *((uint32_t *)(NVMCTRL_OTP4)
                    + (NVM_SW_CALIB_DFLL48M_COARSE_VAL / 32))
                    >> (NVM_SW_CALIB_DFLL48M_COARSE_VAL % 32))
                    & ((1 << 6) - 1);
	if (coarse == 0x3f) {
		coarse = 0x1f;
	}
	uint32_t fine =( *((uint32_t *)(NVMCTRL_OTP4)
                  + (NVM_SW_CALIB_DFLL48M_FINE_VAL / 32))
                  >> (NVM_SW_CALIB_DFLL48M_FINE_VAL % 32))
                  & ((1 << 10) - 1);
	if (fine == 0x3ff) {
		fine = 0x1ff;
	}
	dfllval_conf.bit.COARSE  = coarse;
	dfllval_conf.bit.FINE    = fine;
	dfllctrl_conf.bit.USBCRM = 1;
	dfllctrl_conf.bit.BPLCKC = 0;
	dfllctrl_conf.bit.QLDIS  = 0;
	dfllctrl_conf.bit.CCDIS  = 1;
	dfllctrl_conf.bit.ENABLE = 1;

	SYSCTRL->DFLLCTRL.bit.ONDEMAND = 0;
	while (!(SYSCTRL->PCLKSR.reg & SYSCTRL_PCLKSR_DFLLRDY));
	SYSCTRL->DFLLMUL.reg = 48000;
	SYSCTRL->DFLLVAL.reg = dfllval_conf.reg;
	SYSCTRL->DFLLCTRL.reg = dfllctrl_conf.reg;

	GCLK_CLKCTRL_Type clkctrl={0};
	uint16_t temp;
	GCLK->CLKCTRL.bit.ID = 0; // GCLK_ID - DFLL48M Reference 
	temp = GCLK->CLKCTRL.reg;
	clkctrl.bit.CLKEN = 1;
	clkctrl.bit.WRTLOCK = 0;
	clkctrl.bit.GEN = GCLK_CLKCTRL_GEN_GCLK0_Val;
	GCLK->CLKCTRL.reg = (clkctrl.reg | temp);

	/* Configure DFLL48M as source for GCLK_GEN1 */
	GCLK->GENCTRL.bit.ID = 1; /* GENERATOR_ID - GCLK_GEN_1 */
	while(GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY);
	temp_genctrl = GCLK->GENCTRL.reg;
	genctrl.bit.SRC = GCLK_GENCTRL_SRC_DFLL48M_Val;
	genctrl.bit.GENEN = 1;
	genctrl.bit.RUNSTDBY = 0;
	GCLK->GENCTRL.reg = (genctrl.reg | temp_genctrl);
	while(GCLK->STATUS.reg & GCLK_STATUS_SYNCBUSY);
	
	
	
}








/*

https://community.atmel.com/forum/sam-d21-spi-interface-bare-code

Kein gültiges MuxSetting! :-(((
// http://asf.atmel.no/docs/3.15.0/thirdparty.wireless.avr2025_mac.apps.mac.no_beacon.coord.ncp.samd20_reb233_xpro/html/asfdoc_sam0_sercom_spi_mux_settings.html

CLK
Svens-Mac-Pro:pio svenbraun$ grep MUX_PA19 samd21e18a.h |grep SERCOM
#define MUX_PA19C_SERCOM1_PAD3             2L
#define PINMUX_PA19C_SERCOM1_PAD3  ((PIN_PA19C_SERCOM1_PAD3 << 16) | MUX_PA19C_SERCOM1_PAD3)


#define MUX_PA19D_SERCOM3_PAD3             3L
#define PINMUX_PA19D_SERCOM3_PAD3  ((PIN_PA19D_SERCOM3_PAD3 << 16) | MUX_PA19D_SERCOM3_PAD3)


MOSI!!!!
#define MUX_PA23C_SERCOM3_PAD1             2L
#define PINMUX_PA23C_SERCOM3_PAD1  ((PIN_PA23C_SERCOM3_PAD1 << 16) | MUX_PA23C_SERCOM3_PAD1)

// Kann man wohl knicken, da falsche pins im PCB Layout!

void spiInit(void) {
    PM->APBCMASK.bit.SERCOM3_ = 1;
    GCLK->CLKCTRL.reg = GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_ID_SERCOM3_CORE;
    while(GCLK->STATUS.bit.SYNCBUSY);
    const SERCOM_SPI_CTRLA_Type ctrla = {
      .bit.DORD = 0, // MSB first
      .bit.CPHA = 0, // Mode 0
      .bit.CPOL = 0,
      .bit.FORM = 0, // SPI frame
      .bit.DIPO = 3, // MISO on PAD[3]
      .bit.DOPO = 0, // MOSI on PAD[0], SCK on PAD[1], SS_ on PAD[2]
      .bit.MODE = 3  // Master
    };
    SERCOM1->SPI.CTRLA.reg = ctrla.reg;
    const SERCOM_SPI_CTRLB_Type ctrlb = {
      .bit.RXEN = 1,   // RX enabled
      .bit.MSSEN = 1,  // HW SS
      .bit.CHSIZE = 0  // 8-bit
    };
    SERCOM1->SPI.CTRLB.reg = ctrlb.reg;	

    SERCOM1->SPI.BAUD.reg = 0; // Rate is clock / 2 

    // Mux for SERCOM1 PA16,PA17,PA18,PA19
    const PORT_WRCONFIG_Type wrconfig = {
      .bit.WRPINCFG = 1,
      .bit.WRPMUX = 1,
      .bit.PMUX = MUX_PA16C_SERCOM1_PAD0,
      .bit.PMUXEN = 1,
      .bit.HWSEL = 1,
      .bit.PINMASK = (uint16_t)((PORT_PA16 | PORT_PA17 | PORT_PA18 | PORT_PA19) >> 16)
    };
    PORT->Group[0].WRCONFIG.reg = wrconfig.reg;

    SERCOM1->SPI.CTRLA.bit.ENABLE = 1;
    while(SERCOM1->SPI.SYNCBUSY.bit.ENABLE);
}

uint8_t spiSend(uint8_t data) {
    while(SERCOM1->SPI.INTFLAG.bit.DRE == 0);
    SERCOM1->SPI.DATA.reg = data;
    while(SERCOM1->SPI.INTFLAG.bit.RXC == 0);
    return SERCOM1->SPI.DATA.reg;
}
*/

#  define RPI_ICE_CLK     19 // on RaspHeader GPIO 16
#  define RPI_ICE_CDONE   16 // on RaspHeader GPIO  5
#  define RPI_ICE_MOSI    23 // on RaspHeader GPIO  6  
#  define RPI_ICE_MISO    22 // ignore this Pin
#  define LOAD_FROM_FLASH  5 // ignore this Pin
#  define RPI_ICE_CRESET  17 // on RaspHeader GPIO  26
#  define RPI_ICE_CS      18 // on RaspHeader GPIO  12
#  define RPI_ICE_SELECT   5 // ignore this Pin

void reset_inout() {
    pinMode(RPI_ICE_CLK,     INPUT_PULLUP);
    pinMode(RPI_ICE_CDONE,   INPUT_PULLUP);
    pinMode(RPI_ICE_MOSI,    INPUT_PULLUP);
    pinMode(RPI_ICE_MISO,    INPUT_PULLUP);
    pinMode(LOAD_FROM_FLASH, INPUT_PULLUP);
    pinMode(RPI_ICE_CRESET,  OUTPUT);
    pinMode(RPI_ICE_CS,      OUTPUT);
    pinMode(RPI_ICE_SELECT,  INPUT_PULLUP);
}

void digitalSync(int usec_delay) {
    for (int n = 0 ;n < usec_delay ; n++)   {
            __asm("nop");
    }
}

// https://forum.arduino.cc/index.php?topic=334073.30
static inline void iceClock() {
    const unsigned int clkPin = (1<<RPI_ICE_CLK);

    REG_PORT_OUTCLR0 = clkPin;
    REG_PORT_OUTSET0 = clkPin;

	// REG_PORT_OUT0 &= ~clkPin;
	// REG_PORT_OUT0 |= clkPin;
    //  digitalWrite(RPI_ICE_CLK, LOW);
    //  digitalWrite(RPI_ICE_CLK, HIGH);
}

int k = 0;


int prog_bitstream() {
//  assert(enable_prog_port);

  pinMode(RPI_ICE_CLK,     OUTPUT);
  pinMode(RPI_ICE_MOSI,    OUTPUT);
  pinMode(LOAD_FROM_FLASH, OUTPUT);
  pinMode(RPI_ICE_CRESET,  OUTPUT);
  pinMode(RPI_ICE_CS,      OUTPUT);
  pinMode(RPI_ICE_SELECT,  OUTPUT);

  //fprintf(stderr, "reset..\n");

  // enable reset
  digitalWrite(RPI_ICE_CRESET, LOW);

  // start clock high
  digitalWrite(RPI_ICE_CLK, HIGH);

  // select SRAM programming mode
  digitalWrite(LOAD_FROM_FLASH, LOW);
  digitalWrite(RPI_ICE_SELECT, LOW);
  digitalWrite(RPI_ICE_CS, LOW);
  digitalSync(100);

  // release reset
  digitalWrite(RPI_ICE_CRESET, HIGH);
  digitalSync(2000);

  for (int i = 0; i < 8; i++) {
    iceClock();
  }



  const unsigned int mosiPin = (1<<RPI_ICE_MOSI);
  const unsigned int size = sizeof(ice40);
  for ( k = 0; k < size; k++) {
    byte d = ice40[k];

    if(d==0){
        REG_PORT_OUTCLR0 = mosiPin;  
        iceClock();
        iceClock();
        iceClock();
        iceClock();
        iceClock();
        iceClock();
        iceClock();
        iceClock();
        continue;
    }



    if(d & 0x80) REG_PORT_OUTSET0 = mosiPin; else  REG_PORT_OUTCLR0 = mosiPin;  iceClock();
    if(d & 0x40) REG_PORT_OUTSET0 = mosiPin; else  REG_PORT_OUTCLR0 = mosiPin;  iceClock();
    if(d & 0x20) REG_PORT_OUTSET0 = mosiPin; else  REG_PORT_OUTCLR0 = mosiPin;  iceClock();
    if(d & 0x10) REG_PORT_OUTSET0 = mosiPin; else  REG_PORT_OUTCLR0 = mosiPin;  iceClock();
    if(d & 0x8) REG_PORT_OUTSET0 = mosiPin; else  REG_PORT_OUTCLR0 = mosiPin;  iceClock();
    if(d & 0x4) REG_PORT_OUTSET0 = mosiPin; else  REG_PORT_OUTCLR0 = mosiPin;  iceClock();
    if(d & 0x2) REG_PORT_OUTSET0 = mosiPin; else  REG_PORT_OUTCLR0 = mosiPin;  iceClock();
    if(d & 0x1) REG_PORT_OUTSET0 = mosiPin; else  REG_PORT_OUTCLR0 = mosiPin;  iceClock();
    
    

//    for (int i = 7; i >= 0; i--) {
//        if(((d >> i) & 1) ) {
//            REG_PORT_OUTSET0 = mosiPin;
//        }else{
//    	    REG_PORT_OUTCLR0 = mosiPin;
//      	}
//      iceClock();
//    }

  }








  for (int i = 0; i < 49; i++) {
      iceClock();
  }

  bool cdone_high = digitalRead(RPI_ICE_CDONE) == HIGH;
  reset_inout();
  if (!cdone_high) return 0;

  return 1;
}




void setup(){
    clock_init();
	pinMode(led,OUTPUT);
	prog_bitstream();
}

void loop(){
        digitalWrite(led,0);
        delay(10);
        digitalWrite(led,1);
        delay(500);
}





int main()
{
	setup();
	while(1) {
        	loop();
	}
}





