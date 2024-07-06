`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Christopher Fenton / Zorislav Shoyat
// 
// Create Date:    00:28:26 05/10/2014 
// Design Name: 
// Module Name:    Cray1_mem_arb 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: The original Fenton Cray-1 memory arbiter between the mfu and ibuf
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
//
// Zorislav Shoyat, 15/2/15, 17:03
//
// Read/Write addresses differentiated, as well as o_mem_wr_req_req and o_mem_rd_req (instead of _ce and _wr)
//
// 16/2/15 5:46
//
// _addr_ack-s added
//
// Zorislav Shoyat, 23/2/15, 17:09
//
// ibuf connected bo mem_B
//


// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"


module Memory_Arbiter
	(
		input  wire        clk,
		input  wire        rst,
		//Memory interface
		input  wire [63:0] i_mem_data,
		output wire [63:0] o_mem_data,
		output wire [21:0] o_mem_rd_addr,
		output wire [21:0] o_mem_wr_addr,
		input wire			 i_mem_rd_addr_ack,
		input wire			 i_mem_wr_addr_ack,
		output wire        o_mem_rd_req,
		output wire        o_mem_wr_req,
		input  wire        i_mem_rd_ack,
		input  wire        i_mem_wr_ack,

		input  wire [63:0] i_memB_data,
		output wire [63:0] o_memB_data,
		output wire [21:0] o_mem_rdB_addr,
		output wire [21:0] o_mem_wrB_addr,
		input wire			 i_mem_rdB_addr_ack,
		input wire			 i_mem_wrB_addr_ack,
		output wire        o_mem_rdB_req,
		output wire        o_mem_wrB_req,
		input  wire        i_mem_rdB_ack,
		input  wire        i_mem_wrB_ack,

		//Read data
		output wire  [63:0] o_read_instr0_data,
		output wire  [63:0] o_read_mfu0_data,

		//Instruction fetch interface
		input  wire [21:0] i_instr0_addr,
		output wire        o_instr0_addr_ack,
		input  wire        i_instr0_req,
		output reg         o_instr0_ack,
		//Memory Functional Unit interface
		input  wire [21:0] i_mfu0_rd_addr,
		input  wire [21:0] i_mfu0_wr_addr,
		input  wire [63:0] i_mfu0_wr_data,
		input  wire        i_mfu0_rd_req, 
		input  wire        i_mfu0_wr_req,
		output wire        o_mfu0_rd_ack,
		output wire        o_mfu0_wr_ack,
		output wire        o_mfu0_rd_addr_ack,
		output wire        o_mfu0_wr_addr_ack
	);

/*
assign o_mem_rd_addr    = i_mfu0_rd_addr;
assign o_mem_wr_addr = i_mfu0_wr_addr;
assign o_mem_data		= i_mfu0_wr_data;
assign o_mem_wr_req   	= i_mfu0_wr_req;
assign o_mem_rd_req      = i_mfu0_rd_req;
assign o_read_mfu0_data = i_mem_data ;

assign o_mfu0_rd_ack = i_mem_rd_ack; // & (last_mem_winner!=INSTR_BUF);
assign o_mfu0_rd_addr_ack = i_mem_rd_addr_ack; // & (last_mem_winner!=INSTR_BUF);
assign o_mfu0_wr_ack = i_mem_wr_ack; // & (last_mem_winner!=INSTR_BUF);
assign o_mfu0_wr_addr_ack = i_mem_wr_addr_ack; // & (last_mem_winner!=INSTR_BUF);


assign o_mem_rdB_addr = i_instr0_addr;
assign o_mem_rdB_req = i_instr0_req;

assign o_read_instr0_data = i_instr0_req ? i_mem_data : 0;
assign o_read_mfu0_data = i_mfu0_rd_req ? i_mem_data : 0;

//block instruction reads when a functional unit is accessing memory (I think this is implicit anyway)
always @(posedge clk)
	o_instr0_ack <= o_instr0_addr_ack; // & (last_mem_winner == INSTR_BUF) & i_mem_rd_ack;	// Postpone the i_buf rd_ack for one cycle after the address ack or longer (if !mem_rd_ack)
assign o_instr0_addr_ack = i_instr0_req && i_mem_rdB_addr_ack; // & (last_mem_winner==INSTR_BUF);
assign o_read_instr0_data = i_memB_data;
*/

assign o_mem_wrB_req = 0;
assign o_mem_rdB_req = 0;
assign o_mem_wrB_addr = 0;
assign o_memB_data	=  0;


//reg         last_mem_winner;
//reg instr_req;

//localparam INSTR_BUF = 1'b1,
//           FUNC = 1'b0;
			  
//assign the memory interface
assign o_mem_rd_addr    = i_mfu0_rd_req ? i_mfu0_rd_addr : i_instr0_addr;
assign o_mem_wr_addr = i_mfu0_wr_req ? i_mfu0_wr_addr : 0;
assign o_mem_data		= i_mfu0_wr_req ? i_mfu0_wr_data : 0;
assign o_mem_wr_req   	= i_mfu0_wr_req;
assign o_mem_rd_req      = i_mfu0_rd_req || i_instr0_req;

assign o_read_instr0_data = i_instr0_req ? i_mem_data : 0;
assign o_read_mfu0_data = i_mfu0_rd_req ? i_mem_data : 0;

//block instruction reads when a functional unit is accessing memory (I think this is implicit anyway)
always @(posedge clk)
	o_instr0_ack <= o_instr0_addr_ack; // & (last_mem_winner == INSTR_BUF) & i_mem_rd_ack;	// Postpone the i_buf rd_ack for one cycle after the address ack or longer (if !mem_rd_ack)
assign o_instr0_addr_ack = (!i_mfu0_rd_req && i_instr0_req && i_mem_rd_addr_ack); // & (last_mem_winner==INSTR_BUF);

assign o_mfu0_rd_ack = i_mfu0_rd_req && i_mem_rd_ack; // & (last_mem_winner!=INSTR_BUF);
assign o_mfu0_rd_addr_ack = i_mfu0_rd_req && i_mem_rd_addr_ack; // & (last_mem_winner!=INSTR_BUF);
assign o_mfu0_wr_ack = i_mfu0_wr_req && i_mem_wr_ack; // & (last_mem_winner!=INSTR_BUF);
assign o_mfu0_wr_addr_ack = i_mfu0_wr_req && i_mem_wr_addr_ack; // & (last_mem_winner!=INSTR_BUF);


//block instruction reads when a functional unit is accessing memory (I think this is implicit anyway)
//assign o_instr0_ack = (last_mem_winner==INSTR_BUF) && i_mem_rd_ack;
//assign o_mfu0_ack = (last_mem_winner!=INSTR_BUF) && i_mem_rd_ack;

//let's store the last winner for the memory interface
//always@ (posedge clk)
//	if (rst)
//		last_mem_winner <= INSTR_BUF;
//	else
//		last_mem_winner <= ~ (i_mfu0_rd_req | i_mfu0_wr_req);


endmodule
