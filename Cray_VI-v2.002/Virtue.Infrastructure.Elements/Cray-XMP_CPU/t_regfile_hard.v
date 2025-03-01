//This is a parameterizable register file


//////////////////////////////////////////////////////////////////
//        Secondary Scalar Register File                        //
//        Author: Christopher Fenton                            //
//        Date:  8/8/23                                         //
//////////////////////////////////////////////////////////////////
//
//This block contains one 64 entry, 64-bit register file used
//for the Cray-1A's 'secondary' scalar registers

///////////////////////////////////////////////
// Zorislav Shoyat, 15/3/2014, 19:51
//
// added choice for core memory or reg memory
///////////////////////////////////////////////


// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"


// As only XILINX core(s) are defined for now, use generic logic
// for all other
`ifdef USE_CORES
`ifndef XILINX
`undef USE_CORES
`endif // not XILINX
`endif // USE_CORES


module t_regfile_hard (clk,
                  i_jk_addr,
                  o_jk_data,
                  i_wr_addr,
                  i_wr_data,
                  i_wr_en);

parameter WIDTH = 64;
parameter DEPTH = 64;
parameter LOGDEPTH = 6;


input  wire                clk;
input  wire [LOGDEPTH-1:0] i_jk_addr;
`ifndef USE_CORES
output reg  [WIDTH-1:0]    o_jk_data;
`else
output wire [WIDTH-1:0]		o_jk_data;
`endif
input  wire [LOGDEPTH-1:0] i_wr_addr;
input  wire [WIDTH-1:0]    i_wr_data;
input  wire                i_wr_en;

wire [WIDTH-1:0] read_data;

`ifndef USE_CORES

reg [WIDTH-1:0] data [DEPTH-1:0];     //the actual registers

//write a register
always@(posedge clk)
   if(i_wr_en)
      data[i_wr_addr] <= i_wr_data;

//read registers
always@(posedge clk)
   o_jk_data <= data[i_jk_addr];

`else

hard_v_reg tmem (
	.clka(clk),
	.wea(i_wr_en), 
	.addra(i_wr_addr), 
	.dina(i_wr_data), 
	.clkb(clk),
//	.rstb(rst),
	.enb(1),
	.addrb(i_jk_addr),
	.doutb(o_jk_data)); // Bus [63 : 0] 

`endif // USE_CORES


endmodule
