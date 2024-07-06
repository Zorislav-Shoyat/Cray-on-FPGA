`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
// 
// Create Date:    15:52:33 02/15/2015 
// Design Name: 
// Module Name:    Dual_Port_RAM 
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

//////////////////////////////
//
// From: http://danstrother.com/2010/09/11/inferring-rams-in-fpgas/
//
//////////////////////////////

// A parameterized, inferable, true dual-port, dual-clock block RAM in Verilog.
//
// ZS 15/2/15 16:00 Changed parameters to fit Vector Registers
//
 
module Dual_Port_RAM #(
    parameter DATA = 64,
    parameter ADDR = 6			// Bits
) (
    // Port A
    input   wire                a_clk,
    input   wire                a_wr,
    input   wire    [ADDR-1:0]  a_addr,
    input   wire    [DATA-1:0]  a_din,
    output  reg     [DATA-1:0]  a_dout,
     
    // Port B
    input   wire                b_clk,
    input   wire                b_wr,
    input   wire    [ADDR-1:0]  b_addr,
    input   wire    [DATA-1:0]  b_din,
    output  reg     [DATA-1:0]  b_dout
);
 
// Shared memory
reg [DATA-1:0] mem [(2**ADDR)-1:0];
 
// Port A
always @(posedge a_clk) begin
    a_dout      <= mem[a_addr];
    if(a_wr) begin
        a_dout      <= a_din;
        mem[a_addr] <= a_din;
    end
end
 
// Port B
always @(posedge b_clk) begin
    b_dout      <= mem[b_addr];
    if(b_wr) begin
        b_dout      <= b_din;
        mem[b_addr] <= b_din;
    end
end
 
endmodule

