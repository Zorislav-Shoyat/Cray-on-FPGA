//This is a parameterizable register file


//////////////////////////////////////////////////////////////////
//        Secondary Address Register File                       //
//        Author: Christopher Fenton                            //
//        Date:  8/8/23                                         //
//////////////////////////////////////////////////////////////////
//
//This block contains one 64 entry, 24-bit register file used
//for the Cray-1A's 'secondary' address registers

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


module b_regfile (clk,
                  i_jk_addr,
                  o_jk_data,
                  i_wr_addr,
                  i_wr_data,
                  i_wr_en,
						i_cur_p,
						i_rtn_jump);

parameter WIDTH = 24;
parameter DEPTH = 64;
parameter LOGDEPTH = 6;


input  wire                clk;
input  wire [LOGDEPTH-1:0] i_jk_addr;
output reg  [WIDTH-1:0]   	o_jk_data;
input  wire [LOGDEPTH-1:0] i_wr_addr;
input  wire [WIDTH-1:0]    i_wr_data;
input  wire                i_wr_en;
input  wire [WIDTH-1:0]    i_cur_p;
input  wire                i_rtn_jump;

reg [WIDTH-1:0] data [DEPTH-1:0];     //the actual registers
reg [LOGDEPTH-1:0] jk_addr;
wire [WIDTH-1:0] wr_addr;
wire write_enable;
wire [23:0] data_to_be_written;


assign wr_addr = i_rtn_jump ? 6'b0 : i_wr_addr;
assign write_enable = i_wr_en || i_rtn_jump;
assign data_to_be_written = i_rtn_jump ? i_cur_p : i_wr_data;

`ifndef USE_CORES

//write a register
always@(posedge clk)
   if(write_enable)
      data[wr_addr] <= data_to_be_written;

always@(posedge clk)
	o_jk_data <= data[i_jk_addr];

//   jk_addr <= i_jk_addr;
//read registers
//assign o_jk_data = data[jk_addr];

`else

Block_Memory_64x24 bmem (
	.clka(clk),
	.wea(write_enable), 
	.addra(wr_addr), 
	.dina(data_to_be_written), 
	.clkb(clk),
	.rstb(rst),
	.addrb(i_jk_addr),
	.doutb(o_jk_data)); // Bus [63 : 0] 

`endif // USE_CORES
	
endmodule
