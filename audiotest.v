//------------------------------------------------------------------------------
//  Sample Verilog: using ice40up5k iceZero board with an PCM5102 DAC via i2s
//  				and a AD7606 8 channel ADC
//------------------------------------------------------------------------------
module top (
	input  pa07,
	output LED1,
	output LED2,
	output LED3,
	output LRCK,		// GPIO 14 on iceZero  -> 42
	output DIN,			// GPIO 12 on iceZero  -> 44
	output BCK,			// GPIO 10 on iceZero  -> 47
	input  AD_FDATA,
	input  AD_DB7,
	input  AD_DB8,
	input  AD_BUSY,
	output AD_CONV,
	output AD_RESET,
	output AD_RDCLK,
	output AD_CS
	); 
	
	assign AD_RESET  = 1'b0; 
	assign AD_CS	 = 1'b0; 	
	
	
	// assign SCK = 1'b0;		// sclk connect to GND can handle pcm5102 by internal pll
	// reg   [31:0] tmp = 0;
	// reg    [15:0] right_out = 0;		// right out


	// ice40up5k 48Mhz internal oscillator
	wire clk;
	SB_HFOSC inthosc (
	  .CLKHFPU(1'b1),
	  .CLKHFEN(1'b1),
	  //.CLKHF_DIV(2'b00),
	  .CLKHF(clk)
	);

	// monitor adc channel
	assign LED1 =  !adc1[13];		// assign leds
	assign LED2 =  !adc1[14]; 	
	assign LED3 =  !adc1[15]; 				
	

	wire  [15:0]	adc1,adc2,adc3,adc4,adc5,adc6,adc7,adc8;		
		
		
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
/*	
	wire [15:0] right_out_main;			
	VCA vca1( 	.clk(clk),
				.vca_in_a(adc1),
				.vca_in_b(left_out[19:4]),
				.vca_out(right_out_main) );				
	assign 	right_out_main = 	adc1;	// bypass the VCA for Testing	
*/


/*
	ALSYNTH add_lut_synth( 	.sample_clk(LRCK),
							.clk(clk),
							.pitch_mod(adc1),
							.audio_out(left_out) );	

*/

	



	wire  [15:0] left_out;		// left out
	wire  [15:0] right_out;		// left out
	wire  [15:0] noise_out;	
	wire  [15:0] decay_out;	
	wire  [15:0] from_vca;	
	wire mytrigger;
	
	PCM5102 dac(.clk(clk),
				.left(left_out),
				.right(right_out),
				.din(DIN),
				.bck(BCK),
				.lrck(LRCK) );


	G2T gate2trigger (	.clk(LRCK),
						.gate(adc1[15:15]),
						.trigger(mytrigger) );


	DECAY decay (	.clk(clk),
					.trigger(mytrigger),
					.decay_time(adc2),
					.decayout(decay_out) );

	VCA vca1( 	.clk(clk),
				.vca_in_a(decay_out),
				.vca_in_b(noise_out),
				.vca_out(from_vca) );	

	
	B2UNI16 bu1(	.clk(clk), .in(adc1), .out(left_out));

/*
	NOISE noise(	.clk(LRCK), 
					.audio_out(noise_out) );
*/
	SUPERSAW ssaw(	.clk(LRCK), 
					.pitch(adc5),
					.audio_out(noise_out) );


	SAW triOsc(		.clk(clk), 
					.pitch(adc5),
					.audio_out(right_out) );

	
/*	
	reg [9:0] thea_sin2;		
	always @(posedge LRCK)	begin
		thea_sin2<=thea_sin2+2; 
	end
		
	mem_2sin so2(	.clk(clk), 
					.addr(thea_sin2), 
					.sin_out(right_out));

*/

/*

	// Cordic stuff
	VCA square( 	.clk(clk),
					.vca_in_a(adc1),
					.vca_in_b(adc1),
					.vca_out(thea_inc) );
	wire [15:0] thea_inc;

	reg  signed [31:0] thea;
	wire [15:0] cordsin;
	wire signed [11:0] cordout;
	reg  signed [5:0] multest = 15;
	
	assign cordsin = cordout * multest;
	reg  signed  [11:0] Xin = 1000/1.647; 
	reg  signed  [11:0] Yin = 1;
	CORDIC cordic1 ( 	.clock(LRCK), 	
						 // .cosine, 
						.sine(cordout), 
						.x_start(Xin), 
						.y_start(Yin), 
					    .angle(thea)	
						);

	always @(posedge LRCK) begin
		thea = thea + ( thea_inc << 14 );
		//thea = thea + 22906; // 1Hz
		//thea = thea + 10078855; // 440Hz
	end

/* 


// Amplitude of Waveform Harmonics
// Harmonic       F     2F     3F     4F     5F     6F     7F     8F     9F 
// Triangle       1      -    -1/9     -     1/25    -    -1/49    -     1/81 
// Square         1      -     1/3     -     1/5     -     1/7     -     1/9 
// Saw            1     1/2    1/3    1/4    1/5    1/6    1/7    1/8    1/9 


// https://stackoverflow.com/questions/37909010/verilog-signed-multiplication-multiplying-numbers-of-different-sizes
// http://billauer.co.il/blog/2012/10/signed-arithmetics-verilog/
// https://stackoverflow.com/questions/24162329/verilog-signed-vs-unsigned-samples-and-first/24165896


  	// Generate table of bin values
//  	wire [31:0] morph [0:7];
  	//					 Saw	   Sqr     Tri     Sin
//	assign morph[7]	= {8'd128 , 8'd128, 8'd128, 8'd128 }; 
//	assign morph[6]	= {8'd64  , 8'd0,   8'd0,	8'd0   }; 
//	assign morph[5]	= {8'd43  , 8'd43,  8'd14,	8'd0   }; 
//	assign morph[4]	= {8'd32  , 8'd0,   8'd0,	8'd0   }; 
//	assign morph[3]	= {8'd26  , 8'd26,  8'd5,	8'd0   }; 
//	assign morph[2]	= {8'd21  , 8'd0,   8'd0,	8'd0   }; 
//	assign morph[1]	= {8'd18  , 8'd18,  8'd3,	8'd0   }; 
//	assign morph[0]	= {8'd16  , 8'd0,   8'd0,	8'd0   }; 
	
	
	wire  [11:0] morph [0:7];
  	//					 Saw	   Sqr     Tri     Sin
	assign morph[0]	= {11'd8 }; 
	assign morph[1]	= {11'd3   }; 
	assign morph[2]	= {11'd0   }; 
	assign morph[3]	= {11'd0   }; 
	assign morph[4]	= {11'd0  }; 
	assign morph[5]	= {11'd0   }; 
	assign morph[6]	= {11'd0   }; 
	assign morph[7]	= {11'd0   }; 
	
	

	reg [5:0] cordic_add_stages;
	wire [31:0]  thea_add; 

	wire [31:0] bin_factor32;
	wire [8:0]  bin_factor8;
	
	wire [2:0] harmonics;
	
	// sin gen
	reg  [15:0] cordsin;		// wire statt reg
	wire [15:0] cordout;
	// assign cordsin = cordout << 4;
	reg  signed  [11:0] Xin = 1000/1.647; 
	reg  signed  [11:0] Yin = 1;
	wire  [22:0] sum [0:7];
	wire  [31:0] bin_thea;
	// reg  [4:0]  harmonic_amp;		 
		
	wire cordic_clk;	
		
	wire  [15:0] cordTemp;

	// assi gn cordsin = cordTemp <<< 4;
		
	CORDIC cordic1 ( 	.clock(cordic_clk), 	
						 // .cosine, 
						.sine(cordout), 
						.x_start(Xin), 
						.y_start(Yin), 
					    .angle(bin_thea)	
						);
 

	parameter ramp = 65536 * 16;
	
	reg signed [22:0] produkt;
	reg [1:0] stages;

	assign harmonics = cordic_add_stages[5:3];
	assign stages = cordic_add_stages[2:1];
	
	// reg [22:0] allsum;
	
	// assign bin_thea = thea_add;
	
	wire  [31:0] cordsum;
	// assign cordsin = cordsum[31:16];
	
	always @(posedge clk) begin


		bin_factor8 		<= morph[harmonics];
	//	bin_factor8 		<= bin_factor32[31:24];

//		case (adc1[13:12])	// select Wave form
//			2'b00:	begin  bin_factor8 <= bin_factor32[31:24];  end
//			2'b01:	begin  bin_factor8 <= bin_factor32[23:16];  end
//			2'b10:	begin  bin_factor8 <= bin_factor32[15:8];   end
//			2'b11:	begin  bin_factor8 <= bin_factor32[7:0];    end 

//		endcase
		
		case (stages)	// select Wave form
			2'b00:	begin  bin_thea <= thea_add * 4   ; 	end
			2'b01:	begin  cordic_clk <= 1'b1;							end
			2'b10:	begin  sum[harmonics] <=  (cordout ) * bin_factor8  ;   end   // !!!!!!!!!!!!!!!!!! bin_factor8 macht das problem
			2'b11:	begin  cordic_clk <= 1'b0;	end
		endcase
		
		
		if(cordic_add_stages == 6'b111111) begin 
			 cordsin <= (sum[0]  );
			// cordsin <= cordum <<< 6;
			// cordsin <= sum[7] ;
			// sum = 32'd0; 
			thea_add <= thea_add + ramp; 
		end
		
		cordic_add_stages 	<= cordic_add_stages + 1;	
 
	end 
*/

endmodule

//------------------------------------------------------------------------------
//          B2UNI16 bipolar to unipolar
//------------------------------------------------------------------------------
module B2UNI16(clk,in,out);
	input 			clk;	
	input [15:0]	in;			// in 16bit 
	output [15:0]	out;		// out 16bit 

	always @(negedge clk)	begin
		if(in[15])
			out = {in[15], (~in[14:0] + 'b1)};
		else
			out = 16'h8000 - in;
	end 
endmodule



//------------------------------------------------------------------------------
//          PCM5102 2 Channel DAC
//------------------------------------------------------------------------------
// http://www.ti.com/product/PCM5101A-Q1/datasheet/specifications#slase121473
module PCM5102(clk,left,right,din,bck,lrck);
	input 			clk;			// sysclk 100MHz
	input [15:0]	left,right;		// left and right 16bit samples Uint16
	output 			din;			// pin on pcm5102 data
	output 			bck;			// pin on pcm5102 bit clock
	output 			lrck;			// pin on pcm5102 l/r clock can be used outside of this module to create new samples
	
	parameter DAC_CLK_DIV_BITS = 2;	// 1 = ca 384Khz, 2 = 192Khz, 3 = 96Khz, 4 = 48Khz 

	reg [DAC_CLK_DIV_BITS:0]	i2s_clk;			// 2 Bit Counter 48MHz -> 6,0 MHz bck = ca 187,5 Khz SampleRate 4% tolerance ok by datasheet
	always @(posedge clk) begin
		i2s_clk 	<= i2s_clk + 1;
	end	

	reg [15:0] l2c;
	reg [15:0] r2c;

	always @(negedge i2sword[5]) begin
		l2c <= left;
		r2c <= right; 
	end	

	reg [5:0]   i2sword = 0;		// 6 bit = 16 steps for left + right
	always @(negedge i2s_clk[DAC_CLK_DIV_BITS]) begin
		lrck	 	<= i2sword[5];
		din 		<= lrck ? r2c[16 - i2sword[4:1]] : l2c[16 - i2sword[4:1]];	// blit data bits
		bck			<= i2sword[0];
		i2sword		<= i2sword + 1;
	end	
endmodule


//------------------------------------------------------------------------------
//          AD7606 8 channel ADC
//------------------------------------------------------------------------------
// http://www.analog.com/media/en/technical-documentation/data-sheets/AD7606_7606-6_7606-4.pdf
module AD7606(clk,audio1,audio2,audio3,audio4,audio5,audio6,audio7,audio8,conv,rdclk,fdata,db7,db8,busy);
	input 				clk;		// sysclk 100MHz
	input 				db7;		// serial data 1-4 
	input 				db8;		// serial data 5-8 
	input				busy;		// ic is busy (we just ignore this and wait a time)
	input				fdata;		// ic send first word (we just ignore this)
	output 				rdclk;		// data clk 
	output 				conv;		// start conversion a/b 

	output [15:0] 	audio1,audio2,audio3,audio4,audio5,audio6,audio7,audio8;			// 1 channel audio data

	reg [15:0] raw_adc1,raw_adc2,raw_adc3,raw_adc4,raw_adc5,raw_adc6,raw_adc7,raw_adc8;

	parameter ADC_CLK_DIV = 1;		// clk div by 2

	reg [ADC_CLK_DIV:0]	adc_clk;		// clk divider counter
	reg [7:0]   		adsword;		// 8 bit = 16 steps for 4 channels + wait time
		
	always @(posedge clk) begin
		adc_clk 	<= adc_clk + 1;
	end	


	always @(posedge adc_clk[ADC_CLK_DIV]) begin
		if(~adsword[7]) begin
			case (adsword[6:5])
				2'b00:	begin  raw_adc1[15 - adsword[4:1] ]  <= db7;  raw_adc5[15 - adsword[4:1] ]  <= db8;   	end
				2'b01:	begin  raw_adc2[15 - adsword[4:1] ]  <= db7;  raw_adc6[15 - adsword[4:1] ]  <= db8;   	end
				2'b10:	begin  raw_adc3[15 - adsword[4:1] ]  <= db7;  raw_adc7[15 - adsword[4:1] ]  <= db8;   	end
				2'b11:	begin  raw_adc4[15 - adsword[4:1] ]  <= db7;  raw_adc8[15 - adsword[4:1] ]  <= db8;   	end
			endcase
			rdclk		<= adsword[0];
		end else begin
			audio1 <= raw_adc1 + 16'h8000;	// h8000 is normal scale but, offset for adc
			audio2 <= raw_adc2 + 16'h5000;	// h8000 is normal scale but, offset for adc
			audio3 <= raw_adc3 + 16'h5000;	// h8000 is normal scale but, offset for adc
			audio4 <= raw_adc4 + 16'h5000;	// h8000 is normal scale but, offset for adc
			audio5 <= raw_adc5 + 16'h5000;	// h8000 is normal scale but, offset for adc
			audio6 <= raw_adc6 + 16'h5000;	// h8000 is normal scale but, offset for adc
			audio7 <= raw_adc7 + 16'h5000;	// h8000 is normal scale but, offset for adc
			audio8 <= raw_adc8 + 16'h5000;	// h8000 is normal scale but, offset for adc

			rdclk		<= 1'b1;
			if(adsword[6:0] == 7'b0000001)
				conv	 	<= 1'b0;
			else
				conv	 	<= 1'b1;
		end
		adsword		<= adsword + 1;
	end	
endmodule

//------------------------------------------------------------------------------
//          BRAM LUT sineWave
//------------------------------------------------------------------------------
// https://stackoverflow.com/questions/36852808/modify-ice40-bitstream-to-load-new-block-ram-content/36858486#36858486 -> for MakeFile
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



//------------------------------------------------------------------------------
//          BRAM LUT sineWave 4 Quadrant 256x16 -> 1024x16
//------------------------------------------------------------------------------
// http://www.fpga4fun.com/DDS2.html
module mem_2sin(clk, addr, sin_out);
	input clk;
	input [9:0] addr;
	output [15:0] sin_out;	
	
	wire [8:0] ram_adr;
	assign ram_adr = addr[8] ? ~addr[7:0] : addr[7:0];
		
	reg [15:0] my_memory2 [0:256];
	initial begin
 		$readmemh("sin_pi2.hex", my_memory2);
	end
	
	wire [15:0] sine_1sym;  // sine with 1 symmetry

	always @(posedge clk) sine_1sym <=  my_memory2[ram_adr] >> 1;	
	
	wire [15:0] sine_2sym = addr[9] ? {1'b0,-sine_1sym} : {1'b1,sine_1sym};  // second symmetry
	
	always @(posedge clk) sin_out <= sine_2sym ;
endmodule 

//------------------------------------------------------------------------------
//          VCA , zMors
//------------------------------------------------------------------------------
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

//------------------------------------------------------------------------------
//          Gate2Trigger , zMors
//------------------------------------------------------------------------------
module G2T( gate,clk,trigger);
	input 	clk;
	input 	gate;
	output 	trigger;
	
	reg pre_gate;
	always @(posedge clk) begin
		if(!pre_gate && gate) begin
			trigger <= 1'b1;
			pre_gate <= 1'b1;
		end else begin
			trigger <= 1'b0;
		end
		
		if(!gate) begin
			pre_gate <= 1'b0;
		end;
	end 
	
endmodule
//------------------------------------------------------------------------------
//          Decay , zMors
//------------------------------------------------------------------------------
module DECAY( decay_time, decayout,clk,trigger);
	input clk;
	input trigger;
	input [15:0] decay_time;
	output [15:0] decayout;

	reg [15:0] ramp_down;
	reg [31:0] dcy_downsample;
	reg [15:0] dcycount;
	
//	assign decayout = dcy_downsample[31:16];
	assign decayout = ramp_down;

	reg dclk;
	always @(posedge clk) begin
		if(dcycount == 0) begin
			dcycount <= decay_time[15:4];
			dclk <= 1;
		end else begin
			dcycount <= dcycount - 1;
			dclk <= 0;
		end
	end

	always @(posedge dclk or posedge trigger) begin
		if(!trigger ) begin
			if(ramp_down > 1)
			ramp_down <= ramp_down - 1;
		end else begin
			ramp_down <= 16'h7ffc;
		end
	end	
	

	SB_MAC16 decay_mul (
	    .A(ramp_down),
	    .B(ramp_down),
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
	    // .SIGNEXTOUT(dcy_dsp_ready)
	    .O(dcy_downsample)
	  );

	//16x16 => 32 unsigned pipelined multiply
	defparam decay_mul.B_SIGNED                  = 1'b0;
	defparam decay_mul.A_SIGNED                  = 1'b0;
	defparam decay_mul.MODE_8x8                  = 1'b0;

	defparam decay_mul.BOTADDSUB_CARRYSELECT     = 2'b00;
	defparam decay_mul.BOTADDSUB_UPPERINPUT      = 1'b0;
	defparam decay_mul.BOTADDSUB_LOWERINPUT      = 2'b00;
	defparam decay_mul.BOTOUTPUT_SELECT          = 2'b11;

	defparam decay_mul.TOPADDSUB_CARRYSELECT     = 2'b00;
	defparam decay_mul.TOPADDSUB_UPPERINPUT      = 1'b0;
	defparam decay_mul.TOPADDSUB_LOWERINPUT      = 2'b00;
	defparam decay_mul.TOPOUTPUT_SELECT          = 2'b11;

	defparam decay_mul.PIPELINE_16x16_MULT_REG2  = 1'b1;
	defparam decay_mul.PIPELINE_16x16_MULT_REG1  = 1'b1;
	defparam decay_mul.BOT_8x8_MULT_REG          = 1'b1;
	defparam decay_mul.TOP_8x8_MULT_REG          = 1'b1;
	defparam decay_mul.D_REG                     = 1'b0;
	defparam decay_mul.B_REG                     = 1'b1;
	defparam decay_mul.A_REG                     = 1'b1;
	defparam decay_mul.C_REG                     = 1'b0;
	
endmodule 
//------------------------------------------------------------------------------
//          LFSR Noise
//------------------------------------------------------------------------------
module NOISE( clk, audio_out);
	input clk;
	output [15:0]	audio_out; 
	parameter SEED = 32'b10101011101010111010101110101011; // LFSR starting state
	parameter TAPS = 31'b0000000000000000000000001100010;  // LFSR feedback taps
	reg [31:0] shift_register;
	initial shift_register = SEED;
	always @(posedge clk)
	begin
		if(shift_register[31]) begin
			shift_register[31:1] <= shift_register[30:0]^TAPS;
		end else begin
			shift_register[31:1] <= shift_register[30:0];
		end
		shift_register[0] <= shift_register[31];
	end	
	assign audio_out = shift_register[31:16];
endmodule

//------------------------------------------------------------------------------
//          SUPERSAW Oscillator
//------------------------------------------------------------------------------
module SUPERSAW( clk,pitch, audio_out);
	input clk;
	input [15:0] pitch;
	wire [23:0]  pitch_int ;
	output [15:0]	audio_out; 
	reg [31:0] ramp1,ramp2,ramp3,ramp4,ramp5,ramp6,ramp7,ramp8;
	wire [12:0] s1,s2,s3,s4,s5,s6,s7,s8;
	assign s1 = ramp1[31:19]; 
	assign s2 = ramp2[31:19];
	assign s3 = ramp3[31:19];
	assign s4 = ramp4[31:19];
	assign s5 = ramp5[31:19];
	assign s6 = ramp6[31:19];
	assign s7 = ramp7[31:19];
	assign s8 = ramp8[31:19];
	
	assign pitch_int[23:7] = pitch[15:0] << 1;
	assign pitch_int[6:0] = 0 ;
	
	always @(posedge clk) 
	begin
		ramp1 <= ramp1 + pitch_int +  78855 ; 
		ramp2 <= ramp2 + pitch_int +  98851 ;
		ramp3 <= ramp3 + pitch_int + 118853 ;
		ramp4 <= ramp4 + pitch_int + 138857 ;
		ramp5 <= ramp5 + pitch_int + 148853 ;
		ramp6 <= ramp6 + pitch_int + 158855 ;
		ramp7 <= ramp7 + pitch_int + 168857 ;
		ramp8 <= ramp8 + pitch_int + 178851 ;
	end	
	assign audio_out = s1 + s2 + s3 + s4 + s5 + s6 + s7 + s8;
endmodule


//------------------------------------------------------------------------------
//          SAW Oscillator
//------------------------------------------------------------------------------
module SAW( clk,pitch, audio_out);
	input 				clk;
	input [15:0] 		pitch;
	output reg [15:0]	audio_out;
	reg [15:0] tmp;
		

	// Alles wieder grade biegen!
	always @(negedge clk)	begin
		if(tmp[15])
			audio_out = {tmp[15], (~tmp[14:0] + 'b1)};
		else
			audio_out = 16'h8000 - tmp;
	end 

		
	always @(posedge clk) begin
		tmp <= tmp - 2;
	end
endmodule	
//------------------------------------------------------------------------------
//          TRI Oscillator
//------------------------------------------------------------------------------
module TRI( clk,pitch, audio_out);
	input 				clk;
	input [15:0]    	pitch;
	output reg [15:0]	audio_out;
	reg count_down;
	reg [15:0] tmp;



	// Alles wieder grade biegen!
	always @(negedge clk)	begin
		if(tmp[15])
			audio_out = {tmp[15], (~tmp[14:0] + 'b1)};
		else
			audio_out = 16'h8000 - tmp;
	end 



		
	always @(negedge clk)	begin
		if (count_down == 1'b0)	begin
	  		if (tmp==16'hefff) begin
			    count_down <= 1'b1;
    			tmp<=tmp-1;
  			end	else begin
    			tmp<=tmp+1; 
    		end
		end else begin
		  	if(tmp == 16'h2000)  begin
		    	count_down <= 1'b0;
		    	tmp<=tmp+1;
	  		end else begin
	    		tmp<=tmp-1; 
			end
		end
	end 
endmodule	
/*
//------------------------------------------------------------------------------
//          Additive Synth
//------------------------------------------------------------------------------
// https://www.wolframalpha.com/input/?i=graph+sin(+t)++%2B+sin+(+t+*2+)+*+0.5++%2B+sin+(+t+*3+)+*+0.333+%2B+sin+(+t+*4+)+*+0.25
// http://beausievers.com/synth/synthbasics/
module ALSYNTH(sample_clk, clk, pitch_mod, audio_out);

	input 		 	sample_clk;
	input 		 	clk;
	input [15:0] 	pitch_mod;
	output [15:0]	audio_out;

	// Sin waves from wavetable for additive synths
	// reg   [15:0] saw=0;
	wire  [15:0] sin;
	reg   [19:0] sin1;
	reg   [18:0] sin2;
	reg   [17:0] sin3;
	reg   [16:0] sin4;
	reg   [7:0]  lutaddr = 0;	// lookup addr for 256 x 16bit sin values
	reg   [31:0] counter1;
	
	mem_sin mylut( .addr(lutaddr), .sin_out(sin));

	// oscillator fm sin wave + constant saw
	always @(posedge sample_clk) begin
		// saw 	  <= saw + 64;		// thea for saw
		// right_out <= sin1; 
		audio_out  <=  (sin1 + sin2 + sin3 + sin4) >>> 4; 	// add all 4 bins !!!shift!!!
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

	reg [15:0] pitch ; 
	always @(posedge clk) begin
		pitch <= pitch + 1;
		if(pitch == 15'h7fff) begin 
			pitch <= pitch_mod[14:0];	// reset countdown
			addr1 <= addr1+1;			// increment all 4 bins
			addr2 <= addr2+2;
			addr3 <= addr3+3;
			addr4 <= addr4+4;
		end else begin
		end
	end
endmodule

// https://github.com/Cognoscan/VerilogCogs/blob/master/oscillator.v
// Simple sinusoidal oscillator. Period depends on SHIFT and MULT
module oscillator #(
    parameter WIDTH = 12,
    parameter SHIFT = 6,
    //parameter MULT = 1, 	// Should usually be one unless only using in simulation
    parameter START = 2**(WIDTH-1) * 0.9
) (
    input clk,
    input rst,
    output reg signed [WIDTH-1:0] cos,
    output reg signed [WIDTH-1:0] sin
);

always @(posedge clk) begin 
    if (rst) begin
        cos <= START;
        sin <= 'd0;
    end else begin
        cos <= cos - ((sin + (cos >>> SHIFT)) >>> SHIFT);
        sin <= sin + (cos >>> SHIFT);
    end
end

endmodule
*/

//------------------------------------------------------------------------------
//          CORDIC
//------------------------------------------------------------------------------
module CORDIC(clock, cosine, sine, x_start, y_start, angle);

  parameter width = 12;

  // Inputs
  input clock;
  input signed [width-1:0] x_start,y_start; 
  input signed [31:0] angle;

  // Outputs
  output signed  [width-1:0] sine, cosine;

  // Generate table of atan values
  wire signed [31:0] atan_table [0:/* 30 */ 10];
                          
  assign atan_table[00] = 'b00100000000000000000000000000000; // 45.000 degrees -> atan(2^0)
  assign atan_table[01] = 'b00010010111001000000010100011101; // 26.565 degrees -> atan(2^-1)
  assign atan_table[02] = 'b00001001111110110011100001011011; // 14.036 degrees -> atan(2^-2)
  assign atan_table[03] = 'b00000101000100010001000111010100; // atan(2^-3)
  assign atan_table[04] = 'b00000010100010110000110101000011;
  assign atan_table[05] = 'b00000001010001011101011111100001;
  assign atan_table[06] = 'b00000000101000101111011000011110;
  assign atan_table[07] = 'b00000000010100010111110001010101;
  assign atan_table[08] = 'b00000000001010001011111001010011;
  assign atan_table[09] = 'b00000000000101000101111100101110;
  assign atan_table[10] = 'b00000000000010100010111110011000;
  /*
  assign atan_table[11] = 'b00000000000001010001011111001100;	// not need for 12bit
  assign atan_table[12] = 'b00000000000000101000101111100110;
  assign atan_table[13] = 'b00000000000000010100010111110011;
  assign atan_table[14] = 'b00000000000000001010001011111001;
  assign atan_table[15] = 'b00000000000000000101000101111100;
  assign atan_table[16] = 'b00000000000000000010100010111110;
  assign atan_table[17] = 'b00000000000000000001010001011111;
  assign atan_table[18] = 'b00000000000000000000101000101111;
  assign atan_table[19] = 'b00000000000000000000010100010111;
  assign atan_table[20] = 'b00000000000000000000001010001011;
  assign atan_table[21] = 'b00000000000000000000000101000101;
  assign atan_table[22] = 'b00000000000000000000000010100010;
  assign atan_table[23] = 'b00000000000000000000000001010001;
  assign atan_table[24] = 'b00000000000000000000000000101000;
  assign atan_table[25] = 'b00000000000000000000000000010100;
  assign atan_table[26] = 'b00000000000000000000000000001010;
  assign atan_table[27] = 'b00000000000000000000000000000101;
  assign atan_table[28] = 'b00000000000000000000000000000010;
  assign atan_table[29] = 'b00000000000000000000000000000001;
  assign atan_table[30] = 'b00000000000000000000000000000000;
*/
  reg signed [width:0] x [0:width-1];
  reg signed [width:0] y [0:width-1];
  reg signed    [31:0] z [0:width-1];


  // make sure rotation angle is in -pi/2 to pi/2 range
  wire [1:0] quadrant;
  assign quadrant = angle[31:30];

  always @(posedge clock)
  begin // make sure the rotation angle is in the -pi/2 to pi/2 range
    case(quadrant)
      2'b00,
      2'b11: // no changes needed for these quadrants
      begin
        x[0] <= x_start;
        y[0] <= y_start;
        z[0] <= angle;
      end

      2'b01:
      begin
        x[0] <= -y_start;
        y[0] <= x_start;
        z[0] <= {2'b00,angle[29:0]}; // subtract pi/2 for angle in this quadrant
      end

      2'b10:
      begin
        x[0] <= y_start;
        y[0] <= -x_start;
        z[0] <= {2'b11,angle[29:0]}; // add pi/2 to angles in this quadrant
      end
    endcase
  end


  // run through iterations
  genvar i;

  generate
  for (i=0; i < (width-1); i=i+1)
  begin: xyz
    wire z_sign;
    wire signed [width:0] x_shr, y_shr;

    assign x_shr = x[i] >>> i; // signed shift right
    assign y_shr = y[i] >>> i;

    //the sign of the current rotation angle
    assign z_sign = z[i][31];

    always @(posedge clock)
    begin
      // add/subtract shifted data
      x[i+1] <= z_sign ? x[i] + y_shr : x[i] - y_shr;
      y[i+1] <= z_sign ? y[i] - x_shr : y[i] + x_shr;
      z[i+1] <= z_sign ? z[i] + atan_table[i] : z[i] - atan_table[i];
    end
  end
  endgenerate

  // assign output
  assign cosine = x[width-1];
  assign sine = y[width-1];

endmodule



 //
/*
	some ideas for
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
 