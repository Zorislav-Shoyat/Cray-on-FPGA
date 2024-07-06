`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: VITLER systeemonwikkeling
// Engineer: Zorislav Shoyat
// 
// Create Date:    20:56:00 05/06/2014 (5/6/14), Atelier, Tintilin
// Design Name: Virtue on Cray - VIM-CR1
// Module Name:    IO_SECTION 
// Project Name: Scientific Tablet
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

// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"

module IO_SECTION
	(
		// INTERNAL SYSTEM COMMUNICATION
		input wire clk,
		input wire rst,
			// THE MEMORY MAPPED ADDRESS INSIDE THE I/O SECTION
		input wire[3:0] io_rd_addr,
		input wire io_rd_req,
		output reg[63:0] io_rd_data,
		output reg io_rd_ack,
		input wire[3:0] io_wr_addr,
		input wire io_wr_req,
		input wire[63:0] io_wr_data,
		output reg io_wr_ack,
			// DMA & IOP REQUESTS TO THE I/O
		output wire	`PARCEL [`I_CHANNELS-1:0] o_ch_data ,
		output wire	`PARCEL [`I_CHANNELS-1:0] o_ch_vld,
		input wire	`PARCEL [`I_CHANNELS-1:0] i_ch_rdy,

		input wire	`PARCEL [`O_CHANNELS-1:0] i_ch_data,
		input wire	`PARCEL [`O_CHANNELS-1:0] i_ch_vld,
		output wire	`PARCEL [`O_CHANNELS-1:0] o_ch_rdy,
		// EXTERNAL SYSTEM COMMUNICATION
		output wire[7:0] LEDS,
		input wire UART_RX,
		output wire UART_TX,
				// beware: negative logic
		input wire UART_CTS,
			// beware: negative logic
		output wire UART_RTS,
		input wire[4:0] BUTTONS_N,
		input wire[7:0] SWITCH
		
`ifndef CRAY_1
`ifndef NO_IOP
		,
		// IOP INTERFACE
		output wire  [21:0] IOP_mem_rd_addr,
		output wire         IOP_mem_rd_req,
		input wire  [63:0]  iop_mem_rd_data,
		input  wire         iop_mem_rd_ack,
		output wire         IOP_mem_wr_req,
		output wire  [21:0] IOP_mem_wr_addr,
		output wire  [63:0] IOP_mem_wr_data,
		input  wire         iop_mem_wr_ack
`endif
		,

		//////////////////////////////////////////////
		//       High-speed 1250MB/s channel pair   //
		//Incoming channel data (from outside world)//
		//////////////////////////////////////////////
		input  wire [15:0] i_ch06_data,
		input  wire        i_ch06_vld,
		output wire        o_ch06_rdy,
		//Outgoing channel data
		output wire [15:0] o_ch07_data,
		output wire        o_ch07_vld,
		input  wire        i_ch07_rdy,
		////////////////////////////////
		//        6 MB/s channels     //
		////////////////////////////////
		//incoming data
		input wire [15:0] i_ch10_data,
		input wire        i_ch10_vld,
		output wire       o_ch10_rdy,

		input wire [15:0] i_ch12_data,
		input wire        i_ch12_vld,
		output wire       o_ch12_rdy,
				  
		input wire [15:0] i_ch14_data,
		input wire        i_ch14_vld,
		output wire       o_ch14_rdy,
				  
		input wire [15:0] i_ch16_data,
		input wire        i_ch16_vld,
		output wire       o_ch16_rdy,
		//outgoing data
		output wire [15:0] o_ch11_data,
		output wire        o_ch11_vld,
		input  wire        i_ch11_rdy,

		output wire [15:0] o_ch13_data,
		output wire        o_ch13_vld,
		input  wire        i_ch13_rdy,

		output wire [15:0] o_ch15_data,
		output wire        o_ch15_vld,
		input  wire        i_ch15_rdy,

		output wire [15:0] o_ch17_data,
		output wire        o_ch17_vld,
		input  wire        i_ch17_rdy
`endif // not CRAY_1
	);


///////////////////////////////////
//   Memory-Mapped Peripherals   //
///////////////////////////////////


/////////////////////////////////////////////
//
// DECODE ALL READ REQUESTS
//
/////////////////////////////////////////////

/*
// {pipe:)
reg rd_req;
reg rd_addr;

always@ (posedge clk)
	begin
		rd_req <= io_rd_req;
		rd_addr <= io_rd_addr;
		if (io_rd_req | rd_req)	begin
			case(io_rd_addr | rd_addr)
				// SERIAL PORT
				4'b0000:io_rd_data <= {63'b0,tx_busy};			// 0x100000 // O'4000000	// SERIAL PORT TEST DATA TRANSMITION IN PROGRESS
				4'b0001:io_rd_data <= {63'b0,rx_data_rdy};	// 0x100001 // O'4000001	// SERIAL PORT TEST DATA RECEPTION FINISHED
				4'b0010:io_rd_data <= rx_data;	            // 0x100002 // O'4000002	// SERIAL PORT RECEIVED DATA
				4'b0011:io_rd_data <= 64'b0;                 // 0x100003 // O'4000003	// SERIAL PORT TRANSMIT DATA -- no read
				4'b0100:io_rd_data <= 64'b0;                 // 0x100004 // O'4000004	// SERIAL PORT CHARACTER VECTOR LENGTH -- no read
				// STATUS LED
				4'b1000:io_rd_data <= {56'b0,LEDS};         	// 0x100008 // O'4000010 	// STATUS LEDS SET OR READ
				// SWITCHES
				4'b1001:io_rd_data <= {56'b0,SWITCH};			// 0x100009 // O'4000011	//	MAINTENANCE SWITCHES
				// BUTTONS
				4'b1010:io_rd_data <= {59'b0,~BUTTONS_N};		// 0x10000A // O'4000012	// CONTROL BUTTONS
			
				default: io_rd_data <= 64'b0;
			endcase			
		end
	end
*/
	
always@(posedge clk)
	begin
		if (io_rd_req)	begin
			case(io_rd_addr)
				// SERIAL PORT
				4'b0000:io_rd_data <= {63'b0,tx_busy};			// 0x100000 // O'4000000	// SERIAL PORT TEST DATA TRANSMITION IN PROGRESS
				4'b0001:io_rd_data <= {63'b0,rx_data_rdy};	// 0x100001 // O'4000001	// SERIAL PORT TEST DATA RECEPTION FINISHED
				4'b0010:io_rd_data <= rx_data;	            // 0x100002 // O'4000002	// SERIAL PORT RECEIVED DATA
				4'b0011:io_rd_data <= 64'b0;                 // 0x100003 // O'4000003	// SERIAL PORT TRANSMIT DATA -- no read
				4'b0100:io_rd_data <= 64'b0;                 // 0x100004 // O'4000006	// SERIAL PORT TX CHARACTER VECTOR LENGTH -- no read
				4'b0101:io_rd_data <= 64'b0;                 // 0x100005 // O'4000005	// SERIAL PORT RX CHARACTER VECTOR LENGTH -- no read
				// STATUS LED
				4'b1000:io_rd_data <= {56'b0,LEDS};         	// 0x100008 // O'4000010 	// STATUS LEDS SET OR READ
				// SWITCHES
				4'b1001:io_rd_data <= {56'b0,SWITCH};			// 0x100009 // O'4000011	//	MAINTENANCE SWITCHES
				// BUTTONS
				4'b1010:io_rd_data <= {59'b0,~BUTTONS_N};		// 0x10000A // O'4000012	// CONTROL BUTTONS
			
				default: io_rd_data <= 64'b0;
			endcase			
		end
	end


/////////////////////////////////////////////
//
// SYSTEM MAINTENANCE SERIAL PORT
//
/////////////////////////////////////////////

wire        rx_data_rdy; 
wire [63:0] rx_data;
wire        uart_rd_req; 
wire        tx_start;
wire        tx_busy;

wire [3:0] CVL;
wire CVL_wr_en;

// READ
assign uart_rd_req = io_rd_req && (io_rd_addr[3:0] == 4'b0010) && rx_data_rdy;  	//located @ 0x100002

// WRITE
assign CVL = io_wr_data[3:0];
assign tx_start = io_wr_req && (io_wr_addr[3:0] == 4'b0011) && !tx_busy;  			//located @ 0x100003
assign CVL_tx_wr_en = io_wr_req && (io_wr_addr[3:0] == 4'b0100);							//located @ 0x100004
assign CVL_rx_wr_en = io_wr_req && (io_wr_addr[3:0] == 4'b0101);							//located @ 0x100005

uart64 Maintenance_console
	(
		.clk(clk),
      .rst(rst),
      .enable_read(uart_rd_req),          
      .enable_write(tx_start),  
      .data_in(io_wr_data),             
      .data_out(rx_data),              
		.i_rx(UART_RX),
      .i_cts(UART_CTS),
		.o_rts(UART_RTS),             
		.o_tx(UART_TX),           
		.busy_write(tx_busy),            
		.data_avail(rx_data_rdy),
		.command (CVL),
		.write_rxc (CVL_rx_wr_en),
		.write_txc (CVL_tx_wr_en)
	);          

////////////////////////////////////////////////
//
// SYSTEM STATUS LED OUTPUT
//
////////////////////////////////////////////////

wire[7:0] led_it_be = io_wr_data[7:0];

wire led_out = io_wr_req && (io_wr_addr[3:0] == 4'b1000);  //located @ 0x10008 // LED_OUT = LED_IN

E2LP_Led_output Board_led_output
	(
		.system_clock(clk),
		.i_Leds(led_it_be),
		.LEDS(LEDS),
		.Set(led_out)
	);


`ifndef CRAY_1
`ifndef NO_IOP
/////////////////////////////////////////////////
//
//        (Fake) IOP                             
//
/////////////////////////////////////////////////
//This just does some memory pokes after reset
//to emulate what the IOP is currently doing

wire [23:0] iop_mem_addr;
wire iop_mem_en;
wire iop_mem_wr;
wire iop_mem_ack;

assign IOP_mem_rd_addr = iop_mem_addr;
assign IOP_mem_wr_addr = iop_mem_addr;
assign IOP_mem_rd_req = iop_mem_en & !iop_mem_wr;
assign IOP_mem_wr_req = iop_mem_en & iop_mem_wr;

fake_iop iop(.clk(clk),
             .rst(rst),
				 .o_mem_addr(iop_mem_addr),
				 .o_mem_data(IOP_mem_wr_data),
			 /* .i_mem_data(iop_mem_rd_data), */
				 .o_mem_req(iop_mem_en),
				 .o_mem_wr(iop_mem_wr),
				 .i_mem_ack(iop_mem_ack));
`endif // not NO_IOP
`endif // not CRAY_1


// IO FINISHED:
//
// For Led out and Serial port a short cycle is enough
// for iop, waite on iop ack

always @(posedge clk)
	io_rd_ack <= io_rd_req
`ifndef CRAY_1
`ifndef NO_IOP
									& iop_mem_ack
`endif
`endif
														;

always @(posedge clk)
	io_wr_ack <= io_wr_req
`ifndef CRAY_1
`ifndef NO_IOP
									& iop_mem_ack
`endif
`endif
														;


endmodule
