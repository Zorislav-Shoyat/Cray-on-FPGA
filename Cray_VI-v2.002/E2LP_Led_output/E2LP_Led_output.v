///////////////////////////////////////////////////////////////////////////
//
// Zorislav Shoyat, 9/3/2014, 2:23
//
// VIRTUE INFRASTRUCTURE MACHINE,
// VIRTUE INFRASTRUCTURE ELEMENT 'E2LP BOARD LED DRIVER'
//
// NAME:
//       E2LP_Led_output
//
// FUNCTION:
//       Output to the 8 leds on the E2LP board
//
// CONNECTIONS:
//       system_clock (input wire)
//                     connect to system_clock
//       Leds (input wire 8 bit)
//             the bitmap to be written to the physical LEDS
//       Set (input wire)
//            connect as a chip enable
//
//	FEATURES:
//		Internal register locks the data on rising system clock
//
///////////////////////////////////////////////////////////////////////////
//
// v0.99 9/3/2014, 2:23, Atelier, Julia
//
///////////////////////////////////////////////////////////////////////////
//
// Signals are always positive logic
//
///////////////////////////////////////////////////////////////////////////


// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"


module E2LP_Led_output (system_clock, i_Leds, LEDS, Set);

input wire system_clock;
input wire[7:0] i_Leds;
output reg[7:0] LEDS;
input wire Set;


///////////////////////////////////////////////////////////////////////////
//
// Internal
//
// Working principle: on each negative edge of the system clock transfer
// the data into an internal register, whose outputs are directly connected
// to the E2LP board physical LEDs
//
///////////////////////////////////////////////////////////////////////////
reg [7:0] tmp_Leds;		// Disconnect the timing of actual output registers

always @(posedge system_clock)
	if (Set)
		tmp_Leds <= i_Leds;

always @(posedge system_clock)
	LEDS <= tmp_Leds;

endmodule


///////////////////////////////////////////////////////////////////////////
//
// A short direct test module
//
///////////////////////////////////////////////////////////////////////////
//
// v0.99 9/3/2014, 2:23, Atelier, Julia
//
///////////////////////////////////////////////////////////////////////////


/*
module _test_E2LP_Led_output (SYSTEM_CLOCK, SYSTEM_RESET, LEDS);

input wire SYSTEM_CLOCK;
input wire SYSTEM_RESET;
output wire[7:0] LEDS;

wire system_clock;
reg[7:0] Leds;
wire Set;

assign system_clock = SYSTEM_CLOCK;

assign Set = 1'b1;

E2LP_Led_output _test_boad_led_output(system_clock, Leds, LEDS, Set);

always @(posedge system_clock)
	Leds <= Leds + 1'b1;


endmodule
*/
