`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:36:33 05/06/2014 
// Design Name: 
// Module Name:    RESET 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////
//
// SYSTEM RESET:
//
//    @start of clock	&
//    @ ! SYSTEM_RESET_N   :
//           #2-#6 SYSTEM_RESET
//           #4-#8 CPU_RESET (all)
//
/////////////////////////////////////////////////////


// Define the CRAY computer type in "Cray_type.vh"
`include "Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "Cray_VI_construction.vh"


module RESET
	(
		input wire SYSTEM_CLOCK,
		input wire SYSTEM_RESET_N,
		output reg SYSTEM_RESET,
		output reg CPU_RESET 
	);

reg [2:0] rstcnt;
reg inreset;

initial 
	begin
		inreset = 1;
		rstcnt = 7;
	end
	
always @(posedge SYSTEM_CLOCK)
	if (! SYSTEM_RESET_N)
		begin
			rstcnt <= 0;
			inreset <= 1;
		end
	else
		if (inreset)
			begin
				rstcnt <= rstcnt - 3'b1;
				case (rstcnt)
					6: SYSTEM_RESET <= 1;
					4: CPU_RESET <= 1;
					2: SYSTEM_RESET <= 0;
					0: begin
							CPU_RESET <= 0;
							inreset <= 0;
						end
				endcase
			end
		else
			rstcnt <= 0;

endmodule
