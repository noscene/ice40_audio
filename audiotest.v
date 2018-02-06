//------------------------------------------------------------------------------
//    Sample Verilog: using ice40hx (4k) iceZero board with an PCM5102 DAC via i2s
//------------------------------------------------------------------------------
module top (
	input  clk,
	input   button,
	output LED1,
	output LED2,
	output LED3,
	output LRCK,		// GPIO 14 on iceZero  -> 42
	output DIN,			// GPIO 12 on iceZero  -> 44
	output BCK,			// GPIO 10 on iceZero  -> 47
	output SCK			// GPIO 8  on iceZero  -> 55 can connect to GND
	); 

	reg  [31:0] counter = 0;
	reg  signed [15:0] sin;
	reg  signed [15:0] cos;
	
	reg   [15:0] usin;	// remove later!

	reg  signed  [15:0] Xin = 16000/1.647; 
	reg  signed  [15:0] Yin = 1;

	// sub modules: sin gen + dac
	CORDIC s (clk,counter ,Xin,Yin,sin,cos); 
	PCM5102 dac(clk,usin,saw,DIN,BCK,LRCK);
	
	// sawtooth generator
	reg   [15:0] saw=0;
	
	// oscillator fm sin wave + constant saw
	always @(posedge LRCK) begin
		frq = frq + 1;
		saw = saw + 32;		// thea for saw
		usin = sin >> 1;	// remove later
	end 
	
	reg [18:0]  frq;
	reg [15:0]  saw=0;
	
	assign SCK = 1'b0;		// sclk connect to GND can handle pcm5102 by internal pll
	assign LED1 = frq[18];
	assign LED2 = frq[17];
	assign LED3 = frq[15];

	// FM Tester
	always @(posedge clk) begin
		counter <= counter + frq;	// thea for sinwave
	end

endmodule


// I2S out by 3 wire PCM5102
//------------------------------------------------------------------------------
//          Copyright (c) 2018 Sven Braun, zMors, me@zmors.de
//------------------------------------------------------------------------------
module PCM5102(clk,left,right,din,bck,lrck);
	input 			clk;			// sysclk 100MHz
	input [15:0]	left,right;		// left and right 16bit samples Uint16
	output 			din;			// pin on pcm5102 data
	output 			bck;			// pin on pcm5102 bit clock
	output 			lrck;			// pin on pcm5102 l/r clock can be used outside of this module to create new samples
	
	reg [4:0]	i2s_clk;			// 5 Bit Counter 100MHz -> 6.25 MHz dataclk = ca 192Khz SampleRate 4% tolerance ok by datasheet
	always @(posedge clk) begin
		i2s_clk 	<= i2s_clk + 1;
	end	

	reg [5:0]   i2sword = 0;		// 6 bit = 16 steps for left + right
	always @(negedge i2s_clk[4]) begin
		lrck	 	<= i2sword[5];
		din 		<= lrck ? left[15 - (i2sword >> 1 & 15)] : right[15 - (i2sword >> 1 & 15)];	// blit data bits
		bck			<= i2sword[0];
		i2sword		<= i2sword + 1;
	end	
endmodule



//------------------------------------------------------------------------------
//          Copyright (c) 2012 Kirk Weedman, KD7IRS, kirk@hdlexpress.com
//------------------------------------------------------------------------------

// NOTE: 1. Input angle is a modulo of 2*PI scaled to fit in a 32bit register. The user must translate
//          this angle to a value from 0 - (2^32-1).  0 deg = 32'h0, 359.9999... = 32'hFF_FF_FF_FF
//          To translate from degrees to a 32 bit value, multiply 2^32 by the angle (in degrees),
//          then divide by 360
//       2. Size of Xout, Yout is 1 bit larger due to a system gain of 1.647 (which is < 2)
module CORDIC (clock, angle, Xin, Yin, Xout, Yout);
   
   parameter XY_SZ = 16;   // width of input and output data
   
   localparam STG = XY_SZ; // same as bit width of X and Y

   input                      clock;
   // angle is a signed value in the range of -PI to +PI that must be represented as a 32 bit signed number
   input  signed       [31:0] angle;
   input  signed  [XY_SZ-1:0] Xin; 
   input  signed  [XY_SZ-1:0] Yin;
   output signed    [XY_SZ:0] Xout;
   output signed    [XY_SZ:0] Yout;
   
   //------------------------------------------------------------------------------
   //                             arctan table
   //------------------------------------------------------------------------------
   
   // Note: The atan_table was chosen to be 31 bits wide giving resolution up to atan(2^-30)
   wire signed [31:0] atan_table [0:30];
   
   // upper 2 bits = 2'b00 which represents 0 - PI/2 range
   // upper 2 bits = 2'b01 which represents PI/2 to PI range
   // upper 2 bits = 2'b10 which represents PI to 3*PI/2 range (i.e. -PI/2 to -PI)
   // upper 2 bits = 2'b11 which represents 3*PI/2 to 2*PI range (i.e. 0 to -PI/2)
   // The upper 2 bits therefore tell us which quadrant we are in.
   assign atan_table[00] = 32'b00100000000000000000000000000000; // 45.000 degrees -> atan(2^0)
   assign atan_table[01] = 32'b00010010111001000000010100011101; // 26.565 degrees -> atan(2^-1)
   assign atan_table[02] = 32'b00001001111110110011100001011011; // 14.036 degrees -> atan(2^-2)
   assign atan_table[03] = 32'b00000101000100010001000111010100; // atan(2^-3)
   assign atan_table[04] = 32'b00000010100010110000110101000011;
   assign atan_table[05] = 32'b00000001010001011101011111100001;
   assign atan_table[06] = 32'b00000000101000101111011000011110;
   assign atan_table[07] = 32'b00000000010100010111110001010101;
   assign atan_table[08] = 32'b00000000001010001011111001010011;
   assign atan_table[09] = 32'b00000000000101000101111100101110;
   assign atan_table[10] = 32'b00000000000010100010111110011000;
   assign atan_table[11] = 32'b00000000000001010001011111001100;
   assign atan_table[12] = 32'b00000000000000101000101111100110;
   assign atan_table[13] = 32'b00000000000000010100010111110011;
   assign atan_table[14] = 32'b00000000000000001010001011111001;
   assign atan_table[15] = 32'b00000000000000000101000101111101;
   assign atan_table[16] = 32'b00000000000000000010100010111110;
   assign atan_table[17] = 32'b00000000000000000001010001011111;
   assign atan_table[18] = 32'b00000000000000000000101000101111;
   assign atan_table[19] = 32'b00000000000000000000010100011000;
   assign atan_table[20] = 32'b00000000000000000000001010001100;
   assign atan_table[21] = 32'b00000000000000000000000101000110;
   assign atan_table[22] = 32'b00000000000000000000000010100011;
   assign atan_table[23] = 32'b00000000000000000000000001010001;
   assign atan_table[24] = 32'b00000000000000000000000000101000;
   assign atan_table[25] = 32'b00000000000000000000000000010100;
   assign atan_table[26] = 32'b00000000000000000000000000001010;
   assign atan_table[27] = 32'b00000000000000000000000000000101;
   assign atan_table[28] = 32'b00000000000000000000000000000010;
   assign atan_table[29] = 32'b00000000000000000000000000000001; // atan(2^-29)
   assign atan_table[30] = 32'b00000000000000000000000000000000;
   
   //------------------------------------------------------------------------------
   //                              registers
   //------------------------------------------------------------------------------
   
   //stage outputs
   reg signed [XY_SZ:0] X [0:STG-1];
   reg signed [XY_SZ:0] Y [0:STG-1];
   reg signed    [31:0] Z [0:STG-1]; // 32bit
   
   //------------------------------------------------------------------------------
   //                               stage 0
   //------------------------------------------------------------------------------
   wire                 [1:0] quadrant;
   assign   quadrant = angle[31:30];
   
   always @(posedge clock)
   begin // make sure the rotation angle is in the -pi/2 to pi/2 range.  If not then pre-rotate
      case (quadrant)
         2'b00,
         2'b11:   // no pre-rotation needed for these quadrants
         begin    // X[n], Y[n] is 1 bit larger than Xin, Yin, but Verilog handles the assignments properly
            X[0] <= Xin;
            Y[0] <= Yin;
            Z[0] <= angle;
         end
         
         2'b01:
         begin
            X[0] <= -Yin;
            Y[0] <= Xin;
            Z[0] <= {2'b00,angle[29:0]}; // subtract pi/2 from angle for this quadrant
         end
         
         2'b10:
         begin
            X[0] <= Yin;
            Y[0] <= -Xin;
            Z[0] <= {2'b11,angle[29:0]}; // add pi/2 to angle for this quadrant
         end
         
      endcase
   end
   
   //------------------------------------------------------------------------------
   //                           generate stages 1 to STG-1
   //------------------------------------------------------------------------------
   genvar i;

   generate
   for (i=0; i < (STG-1); i=i+1)
   begin: XYZ
      wire                   Z_sign;
      wire signed  [XY_SZ:0] X_shr, Y_shr; 
   
      assign X_shr = X[i] >>> i; // signed shift right
      assign Y_shr = Y[i] >>> i;
   
      //the sign of the current rotation angle
      assign Z_sign = Z[i][31]; // Z_sign = 1 if Z[i] < 0
   
      always @(posedge clock)
      begin
         // add/subtract shifted data
         X[i+1] <= Z_sign ? X[i] + Y_shr         : X[i] - Y_shr;
         Y[i+1] <= Z_sign ? Y[i] - X_shr         : Y[i] + X_shr;
         Z[i+1] <= Z_sign ? Z[i] + atan_table[i] : Z[i] - atan_table[i];
      end
   end
   endgenerate
   
   
   //------------------------------------------------------------------------------
   //                                 output
   //------------------------------------------------------------------------------
   assign Xout = X[STG-1];
   assign Yout = Y[STG-1];

endmodule



