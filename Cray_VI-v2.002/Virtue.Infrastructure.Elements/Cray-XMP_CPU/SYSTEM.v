
//////////////////////////////////////////////////////////////////
//        Cray System Top-level                                 //
//        Author: Christopher Fenton                            //
//        Date:  8/8/23                                         //
//////////////////////////////////////////////////////////////////
//
//This is the top-level file that actually gets instantiated 
//into the FPGA. It contains the actual CRAY_1 CPU block, 
//4 kilowords of RAM, a UART, and the system clock-divider.
//
//////////////////////////////////////////////////////////////////
//
// Adapted by Zorislav Shoyat, 14/3/2014, 20:47
//
//////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////
//
// A complete rehaul started 6/5/2014, 18:58, Atelier, Tintilin
//
//
//////////////////////////////////////////////////////////////////
//
// Zorislav Shoyat, 15/2/15, 21:42, Atelier, Delphinus
//
// New memory interface with address acknowledgements.
//
//


// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"


module Cray_VI
	(
		input wire CLOCK_P,
		input wire CLOCK_N,
		input wire SYSTEM_RESET_N,
		output wire[7:0] LEDS,
		input wire UART_RX,
		output wire UART_TX,
		input wire UART_CTS,		// beware: negative logic
		output wire UART_RTS,	// beware: negative logic
		input wire[4:0] BUTTONS_N,
		input wire[7:0] SWITCH
	);

`ifdef CRAY_XMP
	`ifdef CRAY_XMP_1
		parameter NUM_CPUS=1;
	`elsif CRAY_XMP_2
		parameter NUM_CPUS=2;
	`elsif CRAY_XMP_3
		parameter NUM_CPUS=3;
	`elsif CRAY_XMP_4
		parameter NUM_CPUS=3;
	`endif
`else // CRAY_XMP
`ifdef CRAY_1
	parameter NUM_CPUS=1;
`endif // CRAY_1
`endif // CRAY_XMP


wire[4:0] BUTTON;
assign BUTTON = ~ BUTTONS_N;

//////////////////////////////////////////



//////////////////////////////////////////
//
// SYSTEM CLOCK
//
//////////////////////////////////////////

wire SYSTEM_CLOCK_100, SYSTEM_CLOCK_80, SYSTEM_CLOCK_70, SYSTEM_CLOCK_60, SYSTEM_CLOCK_50, SYSTEM_CLOCK_20;

System_clock_input CLOCK (CLOCK_P, CLOCK_N, SYSTEM_CLOCK_105, SYSTEM_CLOCK_80, SYSTEM_CLOCK_70, SYSTEM_CLOCK_60, SYSTEM_CLOCK_50, SYSTEM_CLOCK_20);

`ifdef MHz100
wire SYSTEM_CLOCK = SYSTEM_CLOCK_100;
`elsif MHz80
wire SYSTEM_CLOCK = SYSTEM_CLOCK_80;
`elsif MHz70
wire SYSTEM_CLOCK = SYSTEM_CLOCK_70;
`elsif MHz60
wire SYSTEM_CLOCK = SYSTEM_CLOCK_60;
`elsif MHz50
wire SYSTEM_CLOCK = SYSTEM_CLOCK_50;
`elsif MHz20
wire SYSTEM_CLOCK = SYSTEM_CLOCK_20;
`else
	ERROR
`endif


wire        clk;
assign clk = SYSTEM_CLOCK;


//////////////////////////////////////////
//
// RESET
//
//////////////////////////////////////////

wire CPU_RESET;

RESET POWER_ON_RESET
	(
		.SYSTEM_CLOCK (SYSTEM_CLOCK),
//		.SYSTEM_RESET_N (BUTTONS_N[3]),
		.SYSTEM_RESET_N (SYSTEM_RESET_N),
		.SYSTEM_RESET (SYSTEM_RESET),
		.CPU_RESET (CPU_RESET)
	);
				
reg        rst;
reg [3:0]  cpu_rst;

always@(posedge clk)
   begin
      rst <= SYSTEM_RESET;
      cpu_rst[NUM_CPUS-1:0] <= {CPU_RESET,CPU_RESET,CPU_RESET,CPU_RESET};
	end
	

//////////////////////////////////
//
//   n-COMPUTATION SECTIONS           
//
//////////////////////////////////

wire [21:0] mem_rd_addr;
wire [63:0] mem_rd_data;
wire [21:0] mem_wr_addr;
wire [63:0] mem_wr_data;
wire        mem_rd_req;
wire        mem_wr_req;
wire        mem_rd_ack;
wire        mem_wr_ack;
wire			mem_rd_addr_ack;
wire			mem_wr_addr_ack;

wire [21:0] mem_rdB_addr;
wire [63:0] mem_rdB_data;
wire [21:0] mem_wrB_addr;
wire [63:0] mem_wrB_data;
wire        mem_rdB_req;
wire        mem_wrB_req;
wire        mem_rdB_ack;
wire        mem_wrB_ack;
wire			mem_rdB_addr_ack;
wire			mem_wrB_addr_ack;

COMPUTATION_SECTION COMPUTER
	(
		.clk(clk),
		.rst(rst),
		.cpu_rst(cpu_rst[0]),
		.o_mem_rd_req(mem_rd_req),
		.o_mem_rd_addr(mem_rd_addr),
		.i_mem_rd_addr_ack(mem_rd_addr_ack),
		.i_mem_rd_data(mem_rd_data),
		.i_mem_rd_ack(mem_rd_ack),
		.o_mem_wr_req(mem_wr_req),
		.o_mem_wr_addr(mem_wr_addr),
		.i_mem_wr_addr_ack(mem_wr_addr_ack),
		.i_mem_wr_ack(mem_wr_ack),
		.o_mem_wr_data(mem_wr_data),

		.o_mem_rdB_req(mem_rdB_req),
		.o_mem_rdB_addr(mem_rdB_addr),
		.i_mem_rdB_addr_ack(mem_rdB_addr_ack),
		.i_mem_rdB_data(mem_rdB_data),
		.i_mem_rdB_ack(mem_rdB_ack),
		.o_mem_wrB_req(mem_wrB_req),
		.o_mem_wrB_addr(mem_wrB_addr),
		.i_mem_wrB_addr_ack(mem_wrB_addr_ack),
		.i_mem_wrB_ack(mem_wrB_ack),
		.o_mem_wrB_data(mem_wrB_data)
		
`ifndef CRAY_1
		,
		//Incoming data
		.i_ch06_data(i_ch06_data),
		.i_ch06_vld(i_ch06_vld),
		.o_ch06_rdy(o_ch06_rdy),
		//Outgoing data
		.o_ch07_data(o_ch07_data),
		.o_ch07_vld(o_ch07_vld),
		.i_ch07_rdy(i_ch07_rdy),			  
		////////////////////////////////
		//        6 MB/s channels     //
		////////////////////////////////
		//incoming data
		.i_ch10_data(16'hcafe),
		.i_ch10_vld(1'b1),
		.o_ch10_rdy(),

		.i_ch12_data(16'hbeef),
		.i_ch12_vld(1'b1),
		.o_ch12_rdy(),

		.i_ch14_data(16'hcafe),
		.i_ch14_vld(1'b1),
		.o_ch14_rdy(),

		.i_ch16_data(16'ha5a5),
		.i_ch16_vld(1'b1),
		.o_ch16_rdy(),
		//outgoing data
		.o_ch11_data(),
		.o_ch11_vld(),
		.i_ch11_rdy(1'b1),

		.o_ch13_data(),
		.o_ch13_vld(),
		.i_ch13_rdy(1'b1),

		.o_ch15_data(),
		.o_ch15_vld(),
		.i_ch15_rdy(1'b1),

		.o_ch17_data(),
		.o_ch17_vld(),
		.i_ch17_rdy(1'b1)
`endif // not CRAY_1
	);


//////////////////////////////////////////
//
// MEMORY
//
//////////////////////////////////////////

// Single port memory traffic from the
// computation section in this moment
wire mem_A_rd_req;
wire [23:0] mem_A_rd_addr; 
wire mem_A_rd_addr_ack;
wire [63:0] Mem_A_rd_data;
wire Mem_A_rd_ack; 
wire mem_A_wr_req; 
wire [23:0] mem_A_wr_addr; 
wire mem_A_wr_addr_ack;
wire [63:0] mem_A_wr_data; 
wire Mem_A_wr_ack;

wire mem_B_rd_req;
wire [23:0] mem_B_rd_addr; 
wire mem_B_rd_addr_ack;
wire [63:0] Mem_B_rd_data;
wire Mem_B_rd_ack; 
wire mem_B_wr_req; 
wire [23:0] mem_B_wr_addr; 
wire mem_B_wr_addr_ack;
wire [63:0] mem_B_wr_data; 
wire Mem_B_wr_ack;

wire mem_C_rd_req;
wire [23:0] mem_C_rd_addr; 
wire mem_C_rd_addr_ack;
wire [63:0] Mem_C_rd_data;
wire Mem_C_rd_ack; 
wire mem_C_wr_req; 
wire [23:0] mem_C_wr_addr; 
wire mem_C_wr_addr_ack;
wire [63:0] mem_C_wr_data; 
wire Mem_C_wr_ack;

wire mem_D_rd_req;
wire [23:0] mem_D_rd_addr; 
wire mem_D_rd_addr_ack;
wire [63:0] Mem_D_rd_data;
wire Mem_D_rd_ack; 
wire mem_D_wr_req; 
wire [23:0] mem_D_wr_addr; 
wire mem_D_wr_addr_ack;
wire [63:0] mem_D_wr_data; 
wire Mem_D_wr_ack;


// CHANNEL A

assign mem_A_rd_req = mem_rd_req;
assign mem_A_rd_addr = mem_rd_addr;
assign mem_rd_addr_ack = Mem_A_rd_addr_ack;
assign mem_rd_data = Mem_A_rd_data;
assign mem_rd_ack = Mem_A_rd_ack;
assign mem_A_wr_req = mem_wr_req;
assign mem_A_wr_addr = mem_wr_addr;
assign mem_wr_addr_ack = Mem_A_wr_addr_ack;
assign mem_wr_ack = Mem_A_wr_ack;
assign mem_A_wr_data = mem_wr_data;

// CHANNEL B

assign mem_B_rd_req = mem_rdB_req;
assign mem_B_rd_addr = mem_rdB_addr;
assign mem_rdB_addr_ack = Mem_B_rd_addr_ack;
assign mem_rdB_data = Mem_B_rd_data;
assign mem_rdB_ack = Mem_B_rd_ack;
assign mem_B_wr_req = mem_wrB_req;
assign mem_B_wr_addr = mem_wrB_addr;
assign mem_wrB_addr_ack = Mem_B_wr_addr_ack;
assign mem_wrB_ack = Mem_B_wr_ack;
assign mem_B_wr_data = mem_wrB_data;


// CHANNEL C

assign mem_C_rd_addr = 0;
assign mem_C_rd_req = 0;
assign mem_C_wr_req = 0;
assign mem_C_wr_addr = 0;
assign mem_C_wr_data = 0;

// CHANNEL D

assign mem_D_rd_addr = 0;
assign mem_D_rd_req = 0;
assign mem_D_wr_req = 0;
assign mem_D_wr_addr = 0;
assign mem_D_wr_data = 0;


// MEMORY MAPPED IO (DECODER/MUX)
wire[23:0] IO_rd_addr;
wire IO_rd_req;
wire[63:0] io_rd_data;
wire io_rd_ack;
wire[23:0] IO_wr_addr;
wire IO_wr_req;
wire[63:0] IO_wr_data;
wire io_wr_ack;


MEMORY_SECTION MEMORY
	(
    .clk(clk), 
    .rst(rst),
	 
    .mem_A_rd_req(mem_A_rd_req), 
    .mem_A_rd_addr(mem_A_rd_addr), 
    .A_rd_addr_ack(Mem_A_rd_addr_ack), 
    .A_rd_data(Mem_A_rd_data), 
    .A_rd_ack(Mem_A_rd_ack), 
    .mem_A_wr_req(mem_A_wr_req), 
    .mem_A_wr_addr(mem_A_wr_addr), 
    .A_wr_addr_ack(Mem_A_wr_addr_ack), 
    .mem_A_wr_data(mem_A_wr_data), 
    .A_wr_ack(Mem_A_wr_ack),
	 
    .mem_B_rd_req(mem_B_rd_req), 
    .mem_B_rd_addr(mem_B_rd_addr), 
    .B_rd_addr_ack(Mem_B_rd_addr_ack), 
    .B_rd_data(Mem_B_rd_data), 
    .B_rd_ack(Mem_B_rd_ack), 
    .mem_B_wr_req(mem_B_wr_req), 
    .mem_B_wr_addr(mem_B_wr_addr), 
    .B_wr_addr_ack(Mem_B_wr_addr_ack), 
    .mem_B_wr_data(mem_B_wr_data), 
    .B_wr_ack(Mem_B_wr_ack),
	 
    .mem_C_rd_req(mem_C_rd_req), 
    .mem_C_rd_addr(mem_C_rd_addr), 
    .C_rd_addr_ack(Mem_C_rd_addr_ack), 
    .C_rd_data(Mem_C_rd_data), 
    .C_rd_ack(Mem_C_rd_ack), 
    .mem_C_wr_req(mem_C_wr_req), 
    .mem_C_wr_addr(mem_C_wr_addr), 
    .C_wr_addr_ack(Mem_C_wr_addr_ack), 
    .mem_C_wr_data(mem_C_wr_data), 
    .C_wr_ack(Mem_C_wr_ack),
	 
    .mem_D_rd_req(mem_D_rd_req), 
    .mem_D_rd_addr(mem_D_rd_addr), 
    .D_rd_addr_ack(Mem_D_rd_addr_ack), 
    .D_rd_data(Mem_D_rd_data), 
    .D_rd_ack(Mem_D_rd_ack), 
    .mem_D_wr_req(mem_D_wr_req), 
    .mem_D_wr_addr(mem_D_wr_addr), 
    .D_wr_addr_ack(Mem_D_wr_addr_ack), 
    .mem_D_wr_data(mem_D_wr_data), 
    .D_wr_ack(Mem_D_wr_ack),
	 
    .IO_rd_addr(IO_rd_addr), 
    .IO_rd_req(IO_rd_req), 
    .io_rd_data(io_rd_data), 
    .io_rd_ack(io_rd_ack), 
    .IO_wr_addr(IO_wr_addr), 
    .IO_wr_req(IO_wr_req), 
    .IO_wr_data(IO_wr_data), 
    .io_wr_ack(io_wr_ack)
	);


//////////////////////////////////////////
//
// INPUT/OUTPUT
//
//////////////////////////////////////////


IO_SECTION IN_OUT
	(
		.clk (clk),
		.rst (rst), 
		.io_rd_addr (IO_rd_addr),
		.io_rd_req (IO_rd_req),
		.io_rd_data (io_rd_data),
		.io_rd_ack (io_rd_ack),
		.io_wr_addr (IO_wr_addr),
		.io_wr_req (IO_wr_req),
		.io_wr_data (IO_wr_data),
		.io_wr_ack (io_wr_ack),
		
		// EXTERNAL SYSTEM COMMUNICATION
		.LEDS(LEDS),
		.UART_RX (UART_RX),
		.UART_TX (UART_TX),
			// beware: negative logic
		.UART_CTS (UART_CTS),
			// beware: negative logic
		.UART_RTS (UART_RTS),
		.BUTTONS_N (BUTTONS_N),
		.SWITCH (SWITCH)
		
`ifndef CRAY_1
		,
		//////////////////////////////////////////////
		//       High-speed 1250MB/s channel pair   //
		//Incoming channel data (from outside world)//
		//////////////////////////////////////////////
		i_ch06_data,
		i_ch06_vld,
		o_ch06_rdy,
		//Outgoing channel data
		o_ch07_data,
		o_ch07_vld,
		i_ch07_rdy,
		////////////////////////////////
		//        6 MB/s channels     //
		////////////////////////////////
		//incoming data
		i_ch10_data,
		i_ch10_vld,
		o_ch10_rdy,

		i_ch12_data,
		i_ch12_vld,
		o_ch12_rdy,
				  
		i_ch14_data,
		i_ch14_vld,
		o_ch14_rdy,
				  
		i_ch16_data,
		i_ch16_vld,
		o_ch16_rdy,
		//outgoing data
		o_ch11_data,
		o_ch11_vld,
		i_ch11_rdy,

		o_ch13_data,
		o_ch13_vld,
		i_ch13_rdy,

		o_ch15_data,
		o_ch15_vld,
		i_ch15_rdy,

		o_ch17_data,
		o_ch17_vld,
		i_ch17_rdy
`endif // not CRAY_1
    );


	
endmodule
