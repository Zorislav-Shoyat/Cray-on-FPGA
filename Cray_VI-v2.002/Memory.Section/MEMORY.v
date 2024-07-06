`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:17:05 05/06/2014 
// Design Name: 
// Module Name:    MEMORY_SECTION 
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

////////////////////////////////////////////////////////
//
// Zorislav Shoyat, 15/2/15, 21:09 Zagreb, Delphinus
//
// Each memory channel has:
//		Two Requests:
//			Request read:					mem_X_rd_req
//			Request write:					mem_X_wr_req
//		Two Addresses:
//			Read address:					mem_X_rd_addr
//			Write address:					mem_X_wr_addr
//		Four return Acknowledgments:
//			Two Address Accepted:
//				Read address accepted:	Mem_X_rd_addr_ack
//				Write address accepted:	Mem_X_wr_addr_ack
//			Two Data Accepted (for Write) or Available (for Read):
//				Data Available:			Mem_X_rd_ack
//				Write Accepted:			Mem_X_wr_ack
//
//	With these signals several kinds of memories can be implemented.
//
// The _addr_ack-s are used primarily for a pipelined (vector, stream) memory, where many addresses
// may follow one after the other, and the _rd/wr_ack is given after an initial latency.
// However, if the memory pipeline is full, the _addr_ack for the given channel and direction
// will be false, therefore stopping the addresses comming from the processing elements.
// For a single transaction memory, the _addr_ack will be given for just one cycle before the
// appropriate _ack becomes active (i.e. the _addr_ack will be off for the address to new-address latency time.
//
// In summary: (memory requester = REQ, memory accepter = ACK; the ACK time is depending on memory parameters)
//		The REQs set up the _xx_addr (and, for write cycles, the _xx_data), and raise the _xx_req
//    The ACK accepts the address and raises _xx_addr_ack; ACK writes data and raises the _wr_ack
//		If _xx_addr_ack the REQs set up a new _xx_addr (e.g. increment the pointer); ACK reads data, sets _rd_ack
//		If _xx_ack is received by the REQs, they store the data and increment (if necessary) the internal data pointers
//
// As opposed to the Read cycle, when the Memory Requester can not proceed until the _rd_ack is received,
// for Write cycles all the data necessary for the Memory operation is already provided by the Memory Requester,
// consequently the Memory Write Latency is irrelevant for the Requester. Only the acceptance of the Address,
// indicated by the _wr_addr_ack is relevant. However, the _wr_ack is propagated if necessary for any reason
//
////////////////////////////////////////////////////////
//
// Zorislav Shoyat, 23/2/2015, 17:03, Atelier, Delphinus
//
// Introducing Dual R/W Port Memory
//
////////////////////////////////////////////////////////


// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"


module MEMORY
	(
		input wire clk,
		input wire rst,
		
		// Four memory channels
		//
		// A channel
		input mem_A_rd_req,
		input [23:0] mem_A_rd_addr,
		output reg Mem_A_rd_addr_ack,
		output reg[63:0] Mem_A_rd_data,
		output reg Mem_A_rd_ack,
		input mem_A_wr_req,
		input [23:0] mem_A_wr_addr,
		output reg Mem_A_wr_addr_ack,
		input [63:0] mem_A_wr_data,
		output reg Mem_A_wr_ack,
		// B channel
		input mem_B_rd_req,
		input [23:0] mem_B_rd_addr,
		output reg Mem_B_rd_addr_ack,
		output reg [63:0] Mem_B_rd_data,
		output reg Mem_B_rd_ack,
		input mem_B_wr_req,
		input [23:0] mem_B_wr_addr,
		output reg Mem_B_wr_addr_ack,
		input [63:0] mem_B_wr_data,
		output reg Mem_B_wr_ack,
		// C channel
		input mem_C_rd_req,
		input [23:0] mem_C_rd_addr,
		output reg Mem_C_rd_addr_ack,
		output reg [63:0] Mem_C_rd_data,
		output reg Mem_C_rd_ack,
		input mem_C_wr_req,
		input [23:0] mem_C_wr_addr,
		output reg Mem_C_wr_addr_ack,
		input [63:0] mem_C_wr_data,
		output reg Mem_C_wr_ack,
		// D channel
		input mem_D_rd_req,
		input [23:0] mem_D_rd_addr,
		output reg Mem_D_rd_addr_ack,
		output reg [63:0] Mem_D_rd_data,
		output reg Mem_D_rd_ack,
		input mem_D_wr_req,
		input [23:0] mem_D_wr_addr,
		output reg Mem_D_wr_addr_ack,
		input [63:0] mem_D_wr_data,
		output reg Mem_D_wr_ack, 
		
		output reg Memory_Error
	);


///////////////////////////////
//      System RAM           //
///////////////////////////////
//The system has `INTERNAL_MEMORY_WORDS 
//(times 8 in bytes) of RAM that
//gets pre-initialized with the 
//contents of monitor.rom (a text file
//in hexadecimal format).

`define CLOG2(x) \
   (x <= 2) ? 1 : \
   (x <= 4) ? 2 : \
   (x <= 8) ? 3 : \
   (x <= 16) ? 4 : \
   (x <= 32) ? 5 : \
   (x <= 64) ? 6 : \
	(x <= 128) ? 7 : \
	(x <= 256) ? 8 : \
	(x <= 512) ? 9 : \
	(x <= 1024) ? 10 : \
	(x <= 2048) ? 11 : \
	(x <= 4096) ? 12 : \
	(x <= 8192) ? 13 : \
	(x <= 16384) ? 14 : \
	(x <= 32768) ? 15 : \
	(x <= 65536) ? 16 : \
	(x <= 131072) ? 17 : \
	(x <= 262144) ? 18 : \
	(x <= 524288) ? 19 : \
	(x <= 1048576) ? 20 : \
	(x <= 2097152) ? 21 : \
	(x <= 4194304) ? 22 : \
   -1
	
localparam MEM_WIDTH = `INTERNAL_MEMORY_WORDS;
localparam LOG_MEM_WIDTH = `CLOG2(MEM_WIDTH);


////////////////////
// INTERNAL MEMORY
////////////////////

reg  [63:0] ram [MEM_WIDTH-1:0];

//////////////////////
// INITIAL BOOTSTRAP
//////////////////////
initial $readmemh (`MONITOR_ROM, ram);
//initial $readmemh ("TEST.ROM", ram);

always @(posedge clk)
	if (rst)
		Memory_Error <= 0;
	else
		if ((mem_A_rd_addr > MEM_WIDTH) || (mem_A_wr_addr > MEM_WIDTH))
			Memory_Error <= 1;
		else
			Memory_Error <= 0;
		

//
// Define SLOW_MEMORY to simulate longer memory latency
//
//
// BEWARE: Shall possibly be adjusted for SINGLE_CYCLE_MEMORY
//

// The MEMORY:
//
//
//

////////////////////////////////////////////////////////
//
// Channel A
//
////////////////////////////////////////////////////////

`undef SLOW_MEMORY

`ifdef SLOW_MEMORY
	`define SLOW_MEMORY_READ
	`define SLOW_MEMORY_WRITE
`else
	`undef SLOW_MEMORY_READ
	`undef SLOW_MEMORY_WRITE
`endif

//////////////////////////
// Internal memory READ */
//////////////////////////

always @*
	Mem_A_rd_addr_ack = mem_A_rd_req;


`ifdef SLOW_MEMORY_READ
	reg [63:0] mrdata;
`endif

always@ (posedge clk)
	if (mem_A_rd_req)
		`ifdef SLOW_MEMORY_READ
			begin
				mrdata <= ram[mem_A_rd_addr[LOG_MEM_WIDTH-1:0]];
				Mem_A_rd_data <= mrdata;
			end
		`else
			Mem_A_rd_data <= ram[mem_A_rd_addr[LOG_MEM_WIDTH-1:0]];
		`endif


`ifndef SINGLE_CYCLE_MEMORY
	`ifdef SLOW_MEMORY_READ
		reg mrack;
	`endif
	
	always@(posedge clk)
		begin
			`ifdef SLOW_MEMORY_READ
				mrack <= mem_A_rd_req;
				Mem_A_rd_ack <= mrack;
			`else
				Mem_A_rd_ack <= mem_A_rd_req;
			`endif
		end
`else
//	always@(posedge clk)
//		Mem_A_rd_ack <= mem_A_rd_req;
	always@*
		Mem_A_rd_ack = mem_A_rd_req;
`endif
		


///////////////////////////
/* Internal memory WRITE */
///////////////////////////

	
//`define SINGLE_CYCLE_MEMORY

`ifdef SLOW_MEMORY_WRITE
	reg [63:0] mwdata;
	reg [LOG_MEM_WIDTH-1:0] mwaddr;
`endif


always@ (posedge clk)
	if (mem_A_wr_req)
		`ifdef SLOW_MEMORY_WRITE
			begin
				mwdata <= mem_A_wr_data;
				mwaddr <= mem_A_wr_addr[LOG_MEM_WIDTH-1:0];
				ram[mwaddr] <= mwdata;
			end
		`else
			ram[mem_A_wr_addr[LOG_MEM_WIDTH-1:0]] <= mem_A_wr_data;
		`endif


`ifndef SINGLE_CYCLE_MEMORY
//	`ifdef SLOW_MEMORY_WRITE
//		reg mwack;
//	`endif
	`ifdef SLOW_MEMORY_WRITE
		always@(posedge clk)
			begin
				Mem_A_wr_ack <= mem_A_wr_req;
				Mem_A_wr_addr_ack <= mem_A_wr_req;
			end
	`else
		always @(posedge clk)
				Mem_A_wr_ack <= mem_A_wr_req;
		always @*
				Mem_A_wr_addr_ack = mem_A_wr_req;
	`endif
`else
	always@*
		Mem_A_wr_ack = mem_A_wr_req;
	always @*
		Mem_A_wr_addr_ack = mem_A_wr_req;
`endif

`undef SLOW_MEMORY

`ifdef SLOW_MEMORY
	`define SLOW_MEMORY_READ
	`define SLOW_MEMORY_WRITE
`else
	`undef SLOW_MEMORY_READ
	`undef SLOW_MEMORY_WRITE
`endif


////////////////////////////////////////////////////////
//
// Channel B
//
////////////////////////////////////////////////////////

/*
//////////////////////////
// Internal memory READ //
//////////////////////////

always @*
	Mem_B_rd_addr_ack = mem_B_rd_req;


`ifdef SLOW_MEMORY_REBD
	reg [63:0] mrdata;
`endif

always@ (negedge clk)
	if (mem_B_rd_req)
		`ifdef SLOW_MEMORY_READ
			begin
				mrdata <= ram[mem_B_rd_addr[LOG_MEM_WIDTH-1:0]];
				Mem_B_rd_data <= mrdata;
			end
		`else
			Mem_B_rd_data <= ram[mem_B_rd_addr[LOG_MEM_WIDTH-1:0]];
		`endif


`ifndef SINGLE_CYCLE_MEMORY
	`ifdef SLOW_MEMORY_READ
		reg mrack;
	`endif
	
	always@(negedge clk)
		begin
			`ifdef SLOW_MEMORY_READ
				mrack <= mem_B_rd_req;
				Mem_B_rd_ack <= mrack;
			`else
				Mem_B_rd_ack <= mem_B_rd_req;
			`endif
		end
`else
//	always@(posedge clk)
//		Mem_B_rd_ack <= mem_B_rd_req;
	always@*
		Mem_B_rd_ack = mem_B_rd_req;
`endif
		

///////////////////////////
// Internal memory WRITE //
///////////////////////////

	
//`define SINGLE_CYCLE_MEMORY

`ifdef SLOW_MEMORY_WRITE
	reg [63:0] mwdata;
	reg [LOG_MEM_WIDTH-1:0] mwaddr;
`endif


always@ (negedge clk)
	if (mem_B_wr_req)
		`ifdef SLOW_MEMORY_WRITE
			begin
				mwdata <= mem_B_wr_data;
				mwaddr <= mem_B_wr_addr[LOG_MEM_WIDTH-1:0];
				ram[mwaddr] <= mwdata;
			end
		`else
			ram[mem_B_wr_addr[LOG_MEM_WIDTH-1:0]] <= mem_B_wr_data;
		`endif


`ifndef SINGLE_CYCLE_MEMORY
//	`ifdef SLOW_MEMORY_WRITE
//		reg mwack;
//	`endif
	`ifdef SLOW_MEMORY_WRITE
		always@(negedge clk)
			begin
				Mem_B_wr_ack <= mem_B_wr_req;
				Mem_B_wr_addr_ack <= mem_B_wr_req;
			end
	`else
		always @*
				Mem_B_wr_ack = mem_B_wr_req;
		always @*
				Mem_B_wr_addr_ack = mem_B_wr_req;
	`endif
`else
	always@*
		Mem_B_wr_ack = mem_B_wr_req;
	always @*
		Mem_B_wr_addr_ack = mem_B_wr_req;
`endif
*/
		
endmodule

/*
`ifndef SINGLE_CYCLE_MEMORY
		reg mrack;
	`ifdef SLOW_MEMORY_READ
		reg mrack1;
	`endif
	
	always@(posedge clk)
			begin
				mrack <= mem_A_rd_req;
				`ifdef SLOW_MEMORY_READ
					mrack1 <= mrack;
					Mem_A_rd_ack <= mrack1;
				`else
					Mem_A_rd_ack <= mrack;
				`endif
			end
			
*/