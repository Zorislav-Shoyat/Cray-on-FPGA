`timescale 1ns / 10ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    04:52:36 05/07/2014 
// Design Name: 
// Module Name:    IO_Decoder 
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
//
// Zorislav Shoyat, 16/2/15, 14:25, Atelier, Delphinus
//

/////////////////////
// Memory mapped IO
/////////////////////

// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"


module IO_Decoder
	(
				// Four memory channels
		//
		// A channel
		input mem_A_rd_req,
		input [23:0] mem_A_rd_addr,
		input mem_A_wr_req,
		input [23:0] mem_A_wr_addr,
		input [63:0] mem_A_wr_data,
		// B channel
		input mem_B_rd_req,
		input [23:0] mem_B_rd_addr,
		input mem_B_wr_req,
		input [23:0] mem_B_wr_addr,
		input [63:0] mem_B_wr_data,
		// C channel
		input mem_C_rd_req,
		input [23:0] mem_C_rd_addr,
		input mem_C_wr_req,
		input [23:0] mem_C_wr_addr,
		input [63:0] mem_C_wr_data,
		// D channel
		input mem_D_rd_req,
		input [23:0] mem_D_rd_addr,
		input mem_D_wr_req,
		input [23:0] mem_D_wr_addr,
		input [63:0] mem_D_wr_data,
		
		// COMMAND OUTPUT TO:
		// Memory mapped IO
		output reg [7:0] IO_rd_addr,
		output IO_rd_req,
		input [63:0] io_rd_data,
		output reg [7:0] IO_wr_addr,
		output IO_wr_req,
		output reg [63:0] IO_wr_data,
		output wire Internal_IO

	);

wire [3:0] Internal_IO_rd;
wire [3:0] Internal_IO_wr;
wire Internal_Read;
wire Internal_Write;



assign Internal_Read = (mem_A_rd_addr[21:20] == 2'b01);
assign Internal_Write = (mem_A_wr_addr[21:20] == 2'b01);
assign Internal_IO = Internal_Read | Internal_Write;
/*
assign Internal_Read = (mem_A_rd_addr[`ADDRBITS-1:10] == 14'b11111111111111);
assign Internal_Write = (mem_A_wr_addr[`ADDRBITS-1:10] == 14'b11111111111111);
assign Internal_IO = Internal_Read | Internal_Write;
*/

assign Internal_IO_rd[0] = Internal_Read & mem_A_rd_req;
assign Internal_IO_wr[0] = Internal_Write & mem_A_wr_req;
assign Internal_IO_rd[1] = Internal_Read & mem_B_rd_req;
assign Internal_IO_wr[1] = Internal_Write & mem_B_wr_req;
assign Internal_IO_rd[2] = Internal_Read & mem_C_rd_req;
assign Internal_IO_wr[2] = Internal_Write & mem_C_wr_req;
assign Internal_IO_rd[3] = Internal_Read & mem_D_rd_req;
assign Internal_IO_wr[3] = Internal_Write & mem_D_wr_req;

always @*
	casez (Internal_IO_rd)
		8'b???1:
			IO_rd_addr = mem_A_rd_addr[7:0];
		8'b??10:
			IO_rd_addr = mem_B_rd_addr[7:0];
		8'b?100:
			IO_rd_addr = mem_C_rd_addr[7:0];
		8'b1000:
			IO_rd_addr = mem_D_rd_addr[7:0];
		default:
			IO_rd_addr = 8'b0;
	endcase

assign IO_rd_req = (mem_A_rd_req | mem_B_rd_req | mem_C_rd_req | mem_D_rd_req) & Internal_IO;
	
always @*
	casez (Internal_IO_wr)
		8'b???1:
			begin
				IO_wr_addr = mem_A_wr_addr[7:0];
				IO_wr_data = mem_A_wr_data;
			end
		8'b??10:
			begin
				IO_wr_addr = mem_B_wr_addr[7:0];
				IO_wr_data = mem_B_wr_data;
			end
		8'b?100:
			begin
				IO_wr_addr = mem_C_wr_addr[7:0];
				IO_wr_data = mem_C_wr_data;
			end
		8'b1000:
			begin
				IO_wr_addr = mem_D_wr_addr[7:0];
				IO_wr_data = mem_D_wr_data;
			end
		default:
			begin
				IO_wr_addr = 8'b0;
				IO_wr_data = 64'b0;
			end
	endcase

assign IO_wr_req = (mem_A_wr_req | mem_B_wr_req | mem_C_wr_req | mem_D_wr_req) & Internal_IO;

endmodule
