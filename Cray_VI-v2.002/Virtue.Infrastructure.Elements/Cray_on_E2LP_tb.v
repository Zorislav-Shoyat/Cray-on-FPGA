//////////////////////////////////////////////////////////////////
//
// Adapted by Zorislav Shoyat, 14/3/2014, 20:47
//
//////////////////////////////////////////////////////////////////
//
// V0.001 WORKS! Just printing a greeting.
// 30/3/2014, 4:17 (4:08)
//
//////////////////////////////////////////////////////////////////

// 16/4/2014: It works with "Hello" monitor.rom
//
// 5/5/2014: Starting point
//
`define SIMULATION

//`timescale 1nS/10pS

// Define the CRAY computer type in "Cray_type.vh"
`include "Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "Cray_VI_construction.vh"

/////////////////////////
//    Memory Map       //
/////////////////////////
//
// System RAM:  0x000000-0x000FFF 
// UART Tx Busy:0x080000   (READ ONLY)
// UART Rx Rdy: 0x080001   (READ ONLY)
// UART Rx Data:0x080002   (If you read this address)
// UART Rx Clr: 0x080002   (If you write this address)
// UART Tx Data:0x080003   (WRITE ONLY)
//

// ZS 17/3/2014, 17:32
// E2LP

module Cray_VI_sim (CLOCK_P, CLOCK_N, SYSTEM_RESET_N,
								LEDS,
								UART_RX, UART_TX, UART_CTS, UART_RTS
							
							,
								BUTTONS_N, SWITCH
							
							);

input wire SYSTEM_RESET_N;
output wire[7:0] LEDS;
input wire UART_RX;
output wire UART_TX;
input wire UART_CTS;		// beware: negative logic
output wire UART_RTS;	// beware: negative logic

input wire[4:0] BUTTONS_N;
input wire[7:0] SWITCH;


///////////////////////////////////////////
// Differentially driven FPGA input clock
///////////////////////////////////////////
`ifdef SIMULATION

assign UART_CTS = 0;

output reg CLOCK_P;
output reg CLOCK_N;

always
	begin
		#10 CLOCK_P = ~CLOCK_P;
		#0 CLOCK_N = ~CLOCK_N;
	end
	
initial
	begin
		#0 CLOCK_P = 1;
		#0 CLOCK_N = 0;
	end
`else
input wire CLOCK_P;
input wire CLOCK_N;
`endif

//////////////////////////////////
//
// THE SYSTEM
//
//////////////////////////////////

Cray_VI SYSTEM (
    .CLOCK_P(CLOCK_P), 
    .CLOCK_N(CLOCK_N), 
    .SYSTEM_RESET_N(SYSTEM_RESET_N), 
    .LEDS(LEDS), 
    .UART_RX(UART_RX), 
    .UART_TX(UART_TX), 
    .UART_CTS(UART_CTS), 
    .UART_RTS(UART_RTS), 
    .BUTTONS_N(BUTTONS_N), 
    .SWITCH(SWITCH)
    );

endmodule
