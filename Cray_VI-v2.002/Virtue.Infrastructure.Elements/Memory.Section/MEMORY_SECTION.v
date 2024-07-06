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
// Zorislav Shoyat, 15/2/15, 22:44 Zagreb, Delphinus
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
//				Read address accepted:	X_rd_addr_ack
//				Write address accepted:	X_wr_addr_ack
//			Two Data Accepted (for Write) or Available (for Read):
//				Data Available:			X_rd_ack
//				Write Accepted:			X_wr_ack
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
// (i.e. hard sychronisation with a Memory Write...).
//
// (Comment also in "MEMORY.v")
////////////////////////////////////////////////////////
//
// Zorislav Shoyat, 23/2/2015, 17:00
//
// Introducing dual R/W port RAM
//
////////////////////////////////////////////////////////


// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"


module MEMORY_SECTION
	(
		input wire clk,
		input wire rst,
		
		// Four memory channels
		//
		// A channel
		input mem_A_rd_req,
		input [23:0] mem_A_rd_addr,
		output reg A_rd_addr_ack,
		output reg[63:0] A_rd_data,
		output reg A_rd_ack,
		input mem_A_wr_req,
		input [23:0] mem_A_wr_addr,
		output reg A_wr_addr_ack,
		input [63:0] mem_A_wr_data,
		output reg A_wr_ack,
		// B channel
		input mem_B_rd_req,
		input [23:0] mem_B_rd_addr,
		output reg B_rd_addr_ack,
		output reg [63:0] B_rd_data,
		output reg B_rd_ack,
		input mem_B_wr_req,
		input [23:0] mem_B_wr_addr,
		output reg B_wr_addr_ack,
		input [63:0] mem_B_wr_data,
		output reg B_wr_ack,
		// C channel
		input mem_C_rd_req,
		input [23:0] mem_C_rd_addr,
		output reg C_rd_addr_ack,
		output reg [63:0] C_rd_data,
		output reg C_rd_ack,
		input mem_C_wr_req,
		input [23:0] mem_C_wr_addr,
		output reg C_wr_addr_ack,
		input [63:0] mem_C_wr_data,
		output reg C_wr_ack,
		// D channel
		input mem_D_rd_req,
		input [23:0] mem_D_rd_addr,
		output reg D_rd_addr_ack,
		output reg [63:0] D_rd_data,
		output reg D_rd_ack,
		input mem_D_wr_req,
		input [23:0] mem_D_wr_addr,
		output reg D_wr_addr_ack,
		input [63:0] mem_D_wr_data,
		output reg D_wr_ack,
		
		output wire o_Memory_Error,
		
		// COMMAND OUTPUT TO:
		// Memory mapped IO
		output wire [7:0] IO_rd_addr,
		output wire IO_rd_req,
		input wire [63:0] io_rd_data,
		input wire io_rd_ack,
		output wire [7:0] IO_wr_addr,
		output wire IO_wr_req,
		output wire [63:0] IO_wr_data,
		input wire io_wr_ack
    );

/*
///////////////////////////////////////
	ONLY ONE CHANNEL (A) IMPLEMENTED
	(7/5/2014, 0:36)
///////////////////////////////////////
//
///////////////////////////////////////
	ONLY TWO CHANNELS (A, B) IMPLEMENTED
	(23/2/2015, 17:02)
///////////////////////////////////////
*/


/////////////////////////////////////////////
//
// MEMORY DECODER - MEMORY MAPPED I/O
// OR MEMORY
//
/////////////////////////////////////////////

/////////////////////////
//    Memory Map       //
/////////////////////////
//
// System RAM:  0x000000-0x000FFF 
// UART Tx Busy:0x100000   (READ ONLY)
// UART Rx Rdy: 0x100001   (READ ONLY)
// UART Rx Data:0x100002   (If you read this address)
// UART Rx Clr: 0x100002   (If you write this address)
// UART Tx Data:0x100003   (WRITE ONLY)
// UART CVL:    0x100004	(Character vector length: 0..8)
// LED output:  0x100008   (READ or WRITE, it is a reg)
// SWITCHES:	 0x100009	(READ 8-bit)
// BUTTONS		 0x10000A   (READ 5-bit)


wire Internal_RAM_A = (mem_A_rd_req & (mem_A_rd_addr[23:20] != 4'b0001)) | (mem_A_wr_req & (mem_A_wr_addr[21:20] != 4'b0001));
wire Internal_RAM_B = (mem_B_rd_req & (mem_B_rd_addr[23:20] != 4'b0001)) | (mem_B_wr_req & (mem_B_wr_addr[21:20] != 4'b0001));
wire Internal_RAM_C = (mem_C_rd_req & (mem_C_rd_addr[23:20] != 4'b0001)) | (mem_C_wr_req & (mem_C_wr_addr[21:20] != 4'b0001));
wire Internal_RAM_D = (mem_D_rd_req & (mem_D_rd_addr[23:20] != 4'b0001)) | (mem_D_wr_req & (mem_D_wr_addr[21:20] != 4'b0001));

/////////////////////
// Memory mapped IO
/////////////////////

IO_Decoder IO_DECODER (
    .mem_A_rd_req(mem_A_rd_req), 
    .mem_A_rd_addr(mem_A_rd_addr), 
    .mem_A_wr_req(mem_A_wr_req), 
    .mem_A_wr_addr(mem_A_wr_addr), 
    .mem_A_wr_data(mem_A_wr_data), 

    .mem_B_rd_req(mem_B_rd_req), 
    .mem_B_rd_addr(mem_B_rd_addr), 
    .mem_B_wr_req(mem_B_wr_req), 
    .mem_B_wr_addr(mem_B_wr_addr), 
    .mem_B_wr_data(mem_B_wr_data), 

    .mem_C_rd_req(mem_C_rd_req), 
    .mem_C_rd_addr(mem_C_rd_addr), 
    .mem_C_wr_req(mem_C_wr_req), 
    .mem_C_wr_addr(mem_C_wr_addr), 
    .mem_C_wr_data(mem_C_wr_data), 

    .mem_D_rd_req(mem_D_rd_req), 
    .mem_D_rd_addr(mem_D_rd_addr), 
    .mem_D_wr_req(mem_D_wr_req), 
    .mem_D_wr_addr(mem_D_wr_addr), 
    .mem_D_wr_data(mem_D_wr_data), 

    .IO_rd_addr(IO_rd_addr), 
    .IO_rd_req(IO_rd_req), 
    .io_rd_data(io_rd_data), 
    .IO_wr_addr(IO_wr_addr), 
    .IO_wr_req(IO_wr_req), 
    .IO_wr_data(IO_wr_data), 
	 .Internal_IO(Internal_IO)
    );


///////////
// Memory
///////////

wire intermem_A_rd_req = mem_A_rd_req & Internal_RAM_A;
wire [23:0] intermem_A_rd_addr = mem_A_rd_addr;
wire Intermem_rd_addr_ack;
wire [63:0] Intermem_A_rd_data;
wire Intermem_A_rd_ack;
wire intermem_A_wr_req = mem_A_wr_req & Internal_RAM_A;
wire [23:0] intermem_A_wr_addr = mem_A_wr_addr;
wire Intermem_A_wr_addr_ack;
wire [63:0] intermem_A_wr_data = mem_A_wr_data;
wire Intermem_A_wr_ack;

wire intermem_B_rd_req = mem_B_rd_req & Internal_RAM_B;
wire [23:0] intermem_B_rd_addr = mem_B_rd_addr;
wire Intermem_B_rd_addr_ack;
wire [63:0] Intermem_B_rd_data;
wire Intermem_B_rd_ack;
wire intermem_B_wr_req = mem_B_wr_req & Internal_RAM_B;
wire [23:0] intermem_B_wr_addr = mem_B_wr_addr;
wire Intermem_B_wr_addr_ack;
wire [63:0] intermem_B_wr_data = mem_B_wr_data;
wire Intermem_B_wr_ack;

wire intermem_C_rd_req = mem_C_rd_req & Internal_RAM_C;
wire [23:0] intermem_C_rd_addr = mem_C_rd_addr;
wire Intermem_C_rd_addr_ack;
wire [63:0] Intermem_C_rd_data;
wire Intermem_C_rd_ack;
wire intermem_C_wr_req = mem_C_wr_req & Internal_RAM_C;
wire [23:0] intermem_C_wr_addr = mem_C_wr_addr;
wire Intermem_C_wr_addr_ack;
wire [63:0] intermem_C_wr_data = mem_C_wr_data;
wire Intermem_C_wr_ack;

wire intermem_D_rd_req = mem_D_rd_req & Internal_RAM_D;
wire [23:0] intermem_D_rd_addr = mem_D_rd_addr;
wire Intermem_D_rd_addr_ack;
wire [63:0] Intermem_D_rd_data;
wire Intermem_D_rd_ack;
wire intermem_D_wr_req = mem_D_wr_req & Internal_RAM_D;
wire [23:0] intermem_D_wr_addr = mem_D_wr_addr;
wire Intermem_D_wr_addr_ack;
wire [63:0] intermem_D_wr_data = mem_D_wr_data;
wire Intermem_D_wr_ack;

wire Memory_Error;


MEMORY INTERNAL_MEMORY (
    .clk(clk), 
    .rst(rst),
	 
    .mem_A_rd_req(intermem_A_rd_req), 
    .mem_A_rd_addr(intermem_A_rd_addr), 
    .Mem_A_rd_addr_ack(Intermem_A_rd_addr_ack), 
    .Mem_A_rd_data(Intermem_A_rd_data), 
    .Mem_A_rd_ack(Intermem_A_rd_ack), 
    .mem_A_wr_req(intermem_A_wr_req), 
    .mem_A_wr_addr(intermem_A_wr_addr), 
    .Mem_A_wr_addr_ack(Intermem_A_wr_addr_ack), 
    .mem_A_wr_data(intermem_A_wr_data), 
    .Mem_A_wr_ack(Intermem_A_wr_ack),
	 
    .mem_B_rd_req(intermem_B_rd_req), 
    .mem_B_rd_addr(intermem_B_rd_addr), 
    .Mem_B_rd_addr_ack(Intermem_B_rd_addr_ack), 
    .Mem_B_rd_data(Intermem_B_rd_data), 
    .Mem_B_rd_ack(Intermem_B_rd_ack), 
    .mem_B_wr_req(intermem_B_wr_req), 
    .mem_B_wr_addr(intermem_B_wr_addr), 
    .Mem_B_wr_addr_ack(Intermem_B_wr_addr_ack), 
    .mem_B_wr_data(intermem_B_wr_data), 
    .Mem_B_wr_ack(Intermem_B_wr_ack),
	 
    .mem_C_rd_req(intermem_C_rd_req), 
    .mem_C_rd_addr(intermem_C_rd_addr), 
    .Mem_C_rd_addr_ack(Intermem_C_rd_addr_ack), 
    .Mem_C_rd_data(Intermem_C_rd_data), 
    .Mem_C_rd_ack(Intermem_C_rd_ack), 
    .mem_C_wr_req(intermem_C_wr_req), 
    .mem_C_wr_addr(intermem_C_wr_addr), 
    .Mem_C_wr_addr_ack(Intermem_C_wr_addr_ack), 
    .mem_C_wr_data(intermem_C_wr_data), 
    .Mem_C_wr_ack(Intermem_C_wr_ack),
	 
    .mem_D_rd_req(intermem_D_rd_req), 
    .mem_D_rd_addr(intermem_D_rd_addr), 
    .Mem_D_rd_addr_ack(Intermem_D_rd_addr_ack), 
    .Mem_D_rd_data(Intermem_D_rd_data), 
    .Mem_D_rd_ack(Intermem_D_rd_ack), 
    .mem_D_wr_req(intermem_D_wr_req), 
    .mem_D_wr_addr(intermem_D_wr_addr), 
    .Mem_D_wr_addr_ack(Intermem_D_wr_addr_ack), 
    .mem_D_wr_data(intermem_D_wr_data), 
    .Mem_D_wr_ack(Intermem_D_wr_ack),
	 
	 .Memory_Error (Memory_Error)
    );


////////////////////
// MULTIPLEXER
////////////////////

//
// BEWARE: Internal IO does not yet produce _addr_ack !!!
//

always @*
	begin
		A_rd_data = /*(A_rd_ack)?*/ (Internal_RAM_A)? Intermem_A_rd_data : (Internal_IO)? io_rd_data : /*63'bXXXXX :*/ 63'b0;
		A_rd_ack = /*mem_A_rd_req &*/ ((io_rd_ack & Internal_IO) | (Intermem_A_rd_ack & Internal_RAM_A));
		A_rd_addr_ack = /*mem_A_rd_req &*/ ((io_rd_ack & Internal_IO) | (Intermem_A_rd_addr_ack & Internal_RAM_A));
		A_wr_ack = /*mem_A_wr_req &*/ ((io_wr_ack & Internal_IO) | (Intermem_A_wr_ack & Internal_RAM_A));
		A_wr_addr_ack = /*mem_A_rd_req &*/ ((io_wr_ack & Internal_IO) | (Intermem_A_wr_addr_ack & Internal_RAM_A));

		B_rd_data = (B_rd_ack)? (Internal_RAM_B)? Intermem_B_rd_data : (Internal_IO)? io_rd_data : 63'b0 : 63'b0;
		B_rd_ack = /*mem_A_rd_req &*/ ((io_rd_ack & Internal_IO) | (Intermem_B_rd_ack & Internal_RAM_A));
		B_rd_addr_ack = ((io_rd_ack & Internal_IO) | (Intermem_B_rd_addr_ack & Internal_RAM_B));
		B_wr_ack = ((io_rd_ack & Internal_IO) | (Intermem_B_wr_ack & Internal_RAM_B));
		B_wr_addr_ack = /*mem_A_rd_req &*/ ((io_wr_ack & Internal_IO) | (Intermem_B_wr_addr_ack & Internal_RAM_A));

//		C_rd_data = (C_rd_ack)? (Internal_RAM_C)? Intermem_C_rd_data : (Internal_IO)? io_rd_data : 63'b0 : 63'b0;
//		C_rd_ack = /*mem_A_rd_req &*/ ((io_rd_ack & Internal_IO) | (Intermem_C_rd_ack & Internal_RAM_A));
//		C_rd_addr_ack = ((io_rd_ack & Internal_IO) | (Intermem_C_rd_addr_ack & Internal_RAM_C));
//		C_wr_ack = ((io_rd_ack & Internal_IO) | (Intermem_C_wr_ack & Internal_RAM_C));
//		C_wr_addr_ack = /*mem_A_rd_req &*/ ((io_wr_ack & Internal_IO) | (Intermem_C_wr_addr_ack & Internal_RAM_A));

//		D_rd_data = (D_rd_ack)? (Internal_RAM_D)? Intermem_D_rd_data : (Internal_IO)? io_rd_data : 63'b0 : 63'b0;
//		D_rd_ack = /*mem_A_rd_req &*/ ((io_rd_ack & Internal_IO) | (Intermem_D_rd_ack & Internal_RAM_A));
//		D_rd_addr_ack = ((io_rd_ack & Internal_IO) | (Intermem_D_rd_addr_ack & Internal_RAM_D));
//		D_wr_ack = ((io_rd_ack & Internal_IO) | (Intermem_D_wr_ack & Internal_RAM_D));
//		D_wr_addr_ack = /*mem_A_rd_req &*/ ((io_wr_ack & Internal_IO) | (Intermem_D_wr_addr_ack & Internal_RAM_A));

	end


/////////////////
// MEMORY ERROR
////////////////

assign o_Memory_Error = Memory_Error & ~Internal_IO;


endmodule

