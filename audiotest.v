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
	
	assign SCK = 1'b0;		// sclk connect to GND can handle pcm5102 by internal pll

	reg  [31:0] tmp = 0;
	reg  [31:0] counter1 ;

	wire  [15:0] sin;

	reg   [19:0] sin1;
	reg   [18:0] sin2;
	reg   [17:0] sin3;
	reg   [16:0] sin4;
	
	reg  [7:0] lutaddr = 0;	// lookup addr for 256 x 16bit sin values
	
	reg   [20:0] left_out = 0;		// left out
	reg   [15:0] right_out = 0;		// right out

	assign LED1 = left_out[15];
	assign LED2 = left_out[14];
	assign LED3 = left_out[13];
	
	PCM5102 dac(.clk(clk),
				.left(left_out[19:4]),
				.right(right_out),
				.din(DIN),
				.bck(BCK),
				.lrck(LRCK) );
	


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
		case (counter1[3:1])
			3'b000:	begin  lutaddr  <= addr1;   	end
			3'b001:	begin  sin1 	<= sin*4; 	end
			3'b010:	begin  lutaddr  <= addr2;   	end
			3'b011:	begin  sin2 	<= sin*3;	end
			3'b100:	begin  lutaddr  <= addr3;   	end
			3'b101:	begin  sin3 	<= sin*2;	end
			3'b110:	begin  lutaddr  <= addr4;   	end
			3'b111:	begin  sin4 	<= sin;		end
		endcase
	end
	
	// thea settings for 4 bins
	always @(posedge counter1[12]) begin
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
	
	reg [4:0]	i2s_clk;			// 5 Bit Counter 100MHz -> 6.25 MHz dataclk = ca 192Khz SampleRate 4% tolerance ok by datasheet
	always @(posedge clk) begin
		i2s_clk 	<= i2s_clk + 1;
	end	

	reg [5:0]   i2sword = 0;		// 6 bit = 16 steps for left + right
	always @(negedge i2s_clk[4]) begin
		lrck	 	<= i2sword[5];
		din 		<= lrck ? right[15 - i2sword[4:1]] : left[15 - i2sword[4:1]];	// blit data bits
		bck			<= i2sword[0];
		i2sword		<= i2sword + 1;
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

 
 