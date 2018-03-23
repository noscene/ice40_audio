//------------------------------------------------------------------------------
//    Sample Verilog: using ice40hx (4k) iceZero board with an PCM5102 DAC via i2s
//------------------------------------------------------------------------------
module top (
//	input  clk,
	input  pa07,
	output LED1,
	output LED2,
	output LED3,
	output LRCK,		// GPIO 14 on iceZero  -> 42
	output DIN,			// GPIO 12 on iceZero  -> 44
	output BCK,			// GPIO 10 on iceZero  -> 47
	// output SCK			// GPIO 8  on iceZero  -> 55 can connect to GND
	input AD_FDATA,
	input AD_DB7,
	input AD_DB8,
	input AD_BUSY,
	output AD_CONV,
	output AD_RESET,
	output AD_RDCLK,
	output AD_CS
	); 
	
//	assign SCK = 1'b0;		// sclk connect to GND can handle pcm5102 by internal pll

	reg   [31:0] counter1 ;
	reg   [31:0] tmp = 0;
	wire  [15:0] sin;
	reg   [19:0] sin1;
	reg   [18:0] sin2;
	reg   [17:0] sin3;
	reg   [16:0] sin4;
	
	reg  [7:0] lutaddr = 0;	// lookup addr for 256 x 16bit sin values
	
	reg   [20:0] left_out = 0;		// left out
	reg   [15:0] right_out = 0;		// right out



	wire clk;
	SB_HFOSC inthosc (
	  .CLKHFPU(1'b1),
	  .CLKHFEN(1'b1),
	  //.CLKHF_DIV(2'b00),
	  .CLKHF(clk)
	);

	
	
	
	


	assign LED1 =  adc1[13];
	assign LED2 =  adc1[14]; 	// AD_CONV;
	assign LED3 =  adc1[15];	// AD_RDCLK; // pa07;
	
	
	wire [15:0] right_out_main;
	
	
	PCM5102 dac(.clk(clk),
				.left(left_out[19:4]),
				.right(right_out_main),
				.din(DIN),
				.bck(BCK),
				.lrck(LRCK) );

	reg [15:0]	adc1;		
	reg [15:0]	adc2;		
	reg [15:0]	adc3;		
	reg [15:0]	adc4;		
	reg [15:0]	adc5;		
	reg [15:0]	adc6;		
	reg [15:0]	adc7;		
	reg [15:0]	adc8;		
		
		
	AD7606 adc( .clk(clk),
				.audio1(adc1),
				.audio2(adc2),
				.audio3(adc3),
				.audio4(adc4),
				.audio5(adc5),
				.audio6(adc6),
				.audio7(adc7),
				.audio8(adc8),
				.fdata(AD_FDATA),
				.busy(AD_BUSY),
				.db7(AD_DB7),
				.db8(AD_DB8),
				.rdclk(AD_RDCLK),
				.conv(AD_CONV)
				);
				
	VCA vca1( 	.clk(clk),
				.vca_in_a(adc1),
				.vca_in_b(left_out[19:4]),
				.vca_out(right_out_main) );				



//	assign 	right_out_main = 	adc1;		
				
	assign AD_RESET  = 1'b0; 
	assign AD_CS	 = 1'b0; 
	


	mem_sin mylut( .addr(lutaddr), .sin_out(sin));

	reg   [15:0] saw=0;
	
	// oscillator fm sin wave + constant saw
	always @(posedge LRCK) begin
		saw 	 <= saw + 64;		// thea for saw
		right_out <= sin1; 
		left_out <=  sin1 + sin2 + sin3 + sin4;	// add all 4 bins
	end 
	
	reg  [7:0] addr1=0;
	reg  [7:0] addr2=0;
	reg  [7:0] addr3=0;
	reg  [7:0] addr4=0;

	// additive synth bin counter
	// Lookup the current sin values
	always @(posedge clk) begin
		counter1 <= counter1 + 1;	
		case (counter1[2:0])
			3'b000:	begin  lutaddr  <= addr1;   	end
			3'b001:	begin  sin1 	<= sin*6; 	end
			3'b010:	begin  lutaddr  <= addr2;   	end
			3'b011:	begin  sin2 	<= sin*3;	end
			3'b100:	begin  lutaddr  <= addr3;   	end
			3'b101:	begin  sin3 	<= sin*2;	end
			3'b110:	begin  lutaddr  <= addr4;   	end
			3'b111:	begin  sin4 	<= sin;		end
		endcase
	end
	
	always @(posedge counter1[24]) begin
		octave <= octave +1;
	end
	
	reg  [2:0] octave=0;
	
	// thea settings for 4 bins
	always @(posedge counter1[5 + octave]) begin
		addr1 <= addr1+1;
		addr2 <= addr2+2;
		addr3 <= addr3+3;
		addr4 <= addr4+4;
	end


endmodule


// I2S out by 3 wire PCM5102
//------------------------------------------------------------------------------
//          Copyright (c) 2018 Sven Braun, zMors, me@zmors.de
//------------------------------------------------------------------------------
// http://www.ti.com/product/PCM5101A-Q1/datasheet/specifications#slase121473
module PCM5102(clk,left,right,din,bck,lrck);
	input 			clk;			// sysclk 100MHz
	input [15:0]	left,right;		// left and right 16bit samples Uint16
	output 			din;			// pin on pcm5102 data
	output 			bck;			// pin on pcm5102 bit clock
	output 			lrck;			// pin on pcm5102 l/r clock can be used outside of this module to create new samples
	
	reg [2:0]	i2s_clk;			// 5 Bit Counter 100MHz -> 12.5 MHz dataclk = ca 384Khz SampleRate 4% tolerance ok by datasheet
	always @(posedge clk) begin
		i2s_clk 	<= i2s_clk + 1;
	end	

	reg [5:0]   i2sword = 0;		// 6 bit = 16 steps for left + right
	always @(negedge i2s_clk[2]) begin
		lrck	 	<= i2sword[5];
		din 		<= lrck ? right[15 - i2sword[4:1]] : left[15 - i2sword[4:1]];	// blit data bits
		bck			<= i2sword[0];
		i2sword		<= i2sword + 1;
	end	
endmodule


//------------------------------------------------------------------------------
//          Copyright (c) 2018 Sven Braun, zMors, me@zmors.de
//------------------------------------------------------------------------------
// http://www.....
module AD7606(clk,audio1,audio2,audio3,audio4,audio5,audio6,audio7,audio8,conv,rdclk,fdata,db7,db8,busy);
	input 				clk;		// sysclk 100MHz
	input 				db7;		// serial data 1-4 
	input 				db8;		// serial data 5-8 
	input				busy;		// ic is busy
	input				fdata;		// ic send first word
	output 				rdclk;		// data clk 
	output 				conv;		// start conversion a/b 

	output [15:0] 	audio1;			// 8 channel Data data
	output [15:0] 	audio2;			// 8 channel Data data
	output [15:0] 	audio3;			// 8 channel Data data
	output [15:0] 	audio4;			// 8 channel Data data
	output [15:0] 	audio5;			// 8 channel Data data
	output [15:0] 	audio6;			// 8 channel Data data
	output [15:0] 	audio7;			// 8 channel Data data
	output [15:0] 	audio8;			// 8 channel Data data


	parameter ADC_CLK_DIV = 1;	



	reg [ADC_CLK_DIV:0]	adc_clk;			// 4 Bit Counter 100MHz -> 12.5 MHz dataclk = ca 384Khz SampleRate 4% tolerance ok by datasheet
	reg [7:0]   adsword;			// 8 bit = 16 steps for 4 channels + carry
//	reg 		read_all_data;
		
		
		
	always @(posedge clk) begin
		adc_clk 	<= adc_clk + 1;
	end	

	

	always @(posedge adc_clk[ADC_CLK_DIV]) begin
		if(~adsword[7]) begin
			case (adsword[6:5])
				2'b00:	begin  audio1[15 - adsword[4:1] ]  <= db7;  audio5[15 - adsword[4:1] ]  <= db8;   	end
				2'b01:	begin  audio2[15 - adsword[4:1] ]  <= db7;  audio6[15 - adsword[4:1] ]  <= db8;   	end
				2'b10:	begin  audio3[15 - adsword[4:1] ]  <= db7;  audio7[15 - adsword[4:1] ]  <= db8;   	end
				2'b11:	begin  audio4[15 - adsword[4:1] ]  <= db7;  audio8[15 - adsword[4:1] ]  <= db8;   	end
			endcase
			rdclk		<= adsword[0];
		end else begin
			rdclk		<= 1'b1;
			if(adsword[6:0] == 7'b0000001)
				conv	 	<= 1'b0;
			else
				conv	 	<= 1'b1;
		end
		adsword		<= adsword + 1;
	end	



	

endmodule


// now try sysRam instead of cordic and save over 2000 luts on ice40!
// https://stackoverflow.com/questions/36852808/modify-ice40-bitstream-to-load-new-block-ram-content/36858486#36858486 -> for MakeFile
// https://www.wolframalpha.com/input/?i=graph+sin(+t)++%2B+sin+(+t+*2+)+*+0.5++%2B+sin+(+t+*3+)+*+0.333+%2B+sin+(+t+*4+)+*+0.25
// http://beausievers.com/synth/synthbasics/
// see makefile with php script to create sine_table.hex wavetable
module mem_sin( addr, sin_out);
	input [7:0] addr;
	output [15:0] sin_out;
	reg [15:0] my_memory [0:256];
	initial begin
 		$readmemh("sine_table.hex", my_memory);
	end
	assign	sin_out = my_memory[addr];
endmodule 

module VCA( vca_in_a, vca_in_b, vca_out,clk);
	input clk;
	input [15:0] vca_in_a;
	input [15:0] vca_in_b;
	output [15:0] vca_out;

	wire  [31:0] downsample;
	
	assign vca_out = downsample[31:16];

SB_MAC16 vca_mul (
    .A(vca_in_a[15:0]),
    .B(vca_in_b[15:0]),
    .C(16'b0),
    .D(16'b0),
    .CLK(clk),
    .CE(1'b1),
    .IRSTTOP(1'b0),	/* reset */
    .IRSTBOT(1'b0), /* reset */
    .ORSTTOP(1'b0), /* reset */
    .ORSTBOT(1'b0), /* reset */
    .AHOLD(1'b0),
    .BHOLD(1'b0),
    .CHOLD(1'b0),
    .DHOLD(1'b0),
    .OHOLDTOP(1'b0),
    .OHOLDBOT(1'b0),
    .OLOADTOP(1'b0),
    .OLOADBOT(1'b0),
    .ADDSUBTOP(1'b0),
    .ADDSUBBOT(1'b0),
    .CO(),
    .CI(1'b0),
    .O(downsample)
  );

//16x16 => 32 unsigned pipelined multiply
defparam vca_mul.B_SIGNED                  = 1'b0;
defparam vca_mul.A_SIGNED                  = 1'b0;
defparam vca_mul.MODE_8x8                  = 1'b0;

defparam vca_mul.BOTADDSUB_CARRYSELECT     = 2'b00;
defparam vca_mul.BOTADDSUB_UPPERINPUT      = 1'b0;
defparam vca_mul.BOTADDSUB_LOWERINPUT      = 2'b00;
defparam vca_mul.BOTOUTPUT_SELECT          = 2'b11;

defparam vca_mul.TOPADDSUB_CARRYSELECT     = 2'b00;
defparam vca_mul.TOPADDSUB_UPPERINPUT      = 1'b0;
defparam vca_mul.TOPADDSUB_LOWERINPUT      = 2'b00;
defparam vca_mul.TOPOUTPUT_SELECT          = 2'b11;

defparam vca_mul.PIPELINE_16x16_MULT_REG2  = 1'b1;
defparam vca_mul.PIPELINE_16x16_MULT_REG1  = 1'b1;
defparam vca_mul.BOT_8x8_MULT_REG          = 1'b1;
defparam vca_mul.TOP_8x8_MULT_REG          = 1'b1;
defparam vca_mul.D_REG                     = 1'b0;
defparam vca_mul.B_REG                     = 1'b1;
defparam vca_mul.A_REG                     = 1'b1;
defparam vca_mul.C_REG                     = 1'b0;

endmodule 

 //
/*
	SPI/Interface
	
	<><setWaveTable1>
	<><getWaveTable1>
	<><setRamp>
	<><getRamp>
	<><setDAC1>
	<><setDAC2>
	<><getDAC1>
	<><getDAC2>
	<><getDAC3>
	<><getDAC4>
	<><getDAC5>
	<><getDAC6>

*/
 