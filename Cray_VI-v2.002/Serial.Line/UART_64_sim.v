/////////////////////////////////////
//       64-bit UART               //
/////////////////////////////////////
// Uart that sends/receives data only
// in 8-byte chunks

/////////////////////////////////////////////////////////
//
// Zorislav Shoyat, 11/3/2014, 3:02
//
// Added a command channel to switch
// between modes (octal):
//
// command[4:0] CharacterVectorLength -- CVL
//
// command = 00 -- ignore input, set RTS to off
//              -- wait for CTS /* TBD */, ignore data
// command = 1..10 -- receive the amount of bytes
//                 -- transmit the amount of bytes
// e.g.:
//     command = 01 -- receive/transmit byte by byte
//     command = 02 -- receive/transmit parcel by parcel
//     command = 10 -- receive/transmit word by word
//
// use write_command to enter command
//
//////////////////////////////////////////////////////////

//
// ZS 11/2/15 19:13 (Delphinus)
//
// uart_tx_data load on @negedge clk (was @*)
//
// ZS 15/2/15 15:15
//
// All outputs are registered, all on posedge
//

//
//  ZS 18/2/15 18:54 (Delphinus)
//
// Special flag for simulation:
// The file 'UART_64.v' has the SIMULATION flag disabled
// The file 'UART_64_sim.v' has the SIMULATION flag enabled
//
`define SIMULATION


// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"


module uart64(clk,
              rst,
				  enable_read,
				  enable_write,
				  data_in,
				  data_out,
				  i_rx,
				  o_tx,
				  i_cts,
				  o_rts,
				  busy_write,
				  data_avail,
				  command, write_rxc, write_txc);

input  wire clk;
input  wire rst;
input  wire enable_read;
input  wire enable_write;
input  wire [63:0] data_in;
output reg [63:0] data_out;
input  wire i_rx;
input  wire i_cts;
output wire o_rts;
output wire o_tx;
output reg busy_write;
output reg data_avail;
input wire[3:0] command;  // CVL (rx/tx)
input wire write_txc; // enable transmitter CVL
input wire write_rxc; // enable receiver CVL		// Sets also the RequestToSend

reg [1:0] tx_state;
reg [3:0] tx_count;
reg [1:0] rx_state;
reg [3:0] rx_count;

wire       tx_busy;
wire       uart_tx_enable;
reg [63:0] temp_tx_data;
reg [7:0]  uart_tx_data;
`ifdef SIMULATION
reg [7:0] uart_rx_data;
reg       rx_empty;
`else
wire [7:0] uart_rx_data;
wire       rx_empty;
`endif
wire       uart_read_en;
wire       sio_ce;
wire       sio_ce_x4;
wire [7:0] div0;
wire [7:0] div1;


////////////
// CVLs
////////////

reg[3:0] tx_command;  // CVLtx - Character Vector Length for Transmission
reg[3:0] rx_command;  // CVLrx - Character Vector Length for Reception

always@(posedge clk)
	if(rst)
		tx_command <= 4'o0;
	else if (write_txc)
		tx_command <= command;

always@(posedge clk)
	if(rst)
		rx_command <= 4'o0;
	else if (write_rxc)
		rx_command <= command;

//////////////////
// Transmit data
//////////////////

always@(posedge clk)
   if (enable_write)
      temp_tx_data <= data_in;

always@(posedge clk)
	busy_write <= (tx_state != TX_IDLE);

/////////////////
// Receive data
/////////////////

`ifdef SIMULATION
always @*
	if(~rx_empty)
	   begin
			case(rx_count)
				3'b111:data_out[7:0]   = uart_rx_data;
				3'b110:data_out[15:8]  = uart_rx_data;
				3'b101:data_out[23:16] = uart_rx_data;
				3'b100:data_out[31:24] = uart_rx_data;
				3'b011:data_out[39:32] = uart_rx_data;
				3'b010:data_out[47:40] = uart_rx_data;
				3'b001:data_out[55:48] = uart_rx_data;
				3'b000:data_out[63:56] = uart_rx_data;	// The characters in a Word are left oriented
			endcase
		end
`else
always@(posedge clk)
   if(rst)
	   data_out <= 64'b0;
	else if(rx_state==RX_RECEIVE)
	   begin
			case(rx_count)
				3'b111:data_out[7:0]   <= uart_rx_data;
				3'b110:data_out[15:8]  <= uart_rx_data;
				3'b101:data_out[23:16] <= uart_rx_data;
				3'b100:data_out[31:24] <= uart_rx_data;
				3'b011:data_out[39:32] <= uart_rx_data;
				3'b010:data_out[47:40] <= uart_rx_data;
				3'b001:data_out[55:48] <= uart_rx_data;
				3'b000:data_out[63:56] <= uart_rx_data;	// The characters in a Word are left oriented
			endcase
		end
`endif
		
always@(posedge clk)
	data_avail <= (rx_state==RX_DONE);
		
	
///////////////////////////////////
//     Uart Transmit Controller  //
///////////////////////////////////
//This block is in charge of taking in
//a 64-bit word, choppint it into 8-bit
//chunks, and then sending all 8 chunks
//out the UART

localparam TX_IDLE = 2'b00,
           TX_SEND = 2'b01,
			  TX_WAIT = 2'b10,
			  TX_DONE = 2'b11;
			  
always@(posedge clk)
   if(rst)
	   tx_state <= TX_IDLE;
	else case(tx_state)
	   TX_IDLE:if(enable_write) tx_state <= TX_WAIT;
		TX_WAIT:
					if (!i_cts) // (i_cts == 0 if clear to send)
						begin
							if (tx_command == 0)
								tx_state <= TX_DONE;
							else 
								if (!tx_busy)
									tx_state <= TX_SEND;
						end						
		TX_SEND:if(tx_count == (tx_command - 1))
		           tx_state <= TX_DONE;
				  else
				     tx_state <= TX_WAIT;
		TX_DONE:tx_state <= TX_IDLE;
	endcase
		
always@(posedge clk)
   if(rst)
	   tx_count <= 3'b0;
	else if(tx_state==TX_SEND)
	   tx_count <= tx_count + 1;
	else if(tx_state==TX_DONE)
	   tx_count <= 3'b0;

always@(posedge clk)
   case(tx_count)
	   3'b111:uart_tx_data <= temp_tx_data[7:0];
		3'b110:uart_tx_data <= temp_tx_data[15:8];
		3'b101:uart_tx_data <= temp_tx_data[23:16];
		3'b100:uart_tx_data <= temp_tx_data[31:24];
		3'b011:uart_tx_data <= temp_tx_data[39:32];
		3'b010:uart_tx_data <= temp_tx_data[47:40];
		3'b001:uart_tx_data <= temp_tx_data[55:48];
		3'b000:uart_tx_data <= temp_tx_data[63:56];	// The characters in a Word are left oriented
	endcase
	
assign uart_tx_enable = (tx_state == TX_SEND);
	
	
////////////////////////////////////
//      UART Receive Controller   //
////////////////////////////////////
//This block is responsible for 
//combining 8 8-bit chunks of data
//into one 64-bit chunk of data

localparam RX_IDLE    = 2'b00,
           RX_RECEIVE = 2'b01,
           RX_WAIT    = 2'b10,
			  RX_DONE    = 2'b11;

`ifdef SIMULATION
reg rts;

always@ (posedge clk)
	if (rst)
		begin
			rx_state <= RX_IDLE;
			rx_count <= 0;
			rts <= 0;
		end
	else
		case (rx_state)
			RX_IDLE:		begin
								rx_count <= 0;
								rts <= 0;
								if (rx_command != 0)
									rx_state <= RX_RECEIVE;
							end
			RX_RECEIVE:	begin
								rts <= 1;
								if (~rx_empty)
									rx_state <= RX_WAIT;
								else
									if (rx_command < rx_count + 2) // rx_count + 1 >= rx_command
										rx_state <= RX_DONE;
									else
											rx_count <= rx_count + 1;
							end
			RX_WAIT:		begin
								rts <= 0;
								if (rx_empty)
									rx_state <= RX_RECEIVE;
							end
			RX_DONE:		begin
								rts <= 0;
								rx_count <= 0;
								if (enable_read)
									rx_state <= RX_IDLE;
							end
		endcase





assign uart_read_en = (rx_state==RX_RECEIVE);

assign o_rts = uart_rts | rts;
							
`else
always@(posedge clk)
   if(rst)
		rx_state <= RX_IDLE;
	else case(rx_state)
		RX_IDLE: if(!rx_empty) rx_state <= RX_RECEIVE;
		RX_RECEIVE:if(rx_count == (rx_command))
		              rx_state <= RX_DONE;
					  else
					     rx_state <= RX_WAIT;
		RX_WAIT: if (rx_count == (rx_command))
						rx_state <= RX_DONE;
					else
						if(!rx_empty)
							rx_state <= RX_RECEIVE;
		RX_DONE:if(enable_read)
		           rx_state <= RX_IDLE;
	endcase

wire uart_rts;	

always@(posedge clk)
   if(rst)
	   rx_count <= 3'b0;
	else if(rx_state==RX_RECEIVE)
	   rx_count <= rx_count + 1;
	else if(rx_state==RX_IDLE)
	   rx_count <= 3'b0;


assign uart_read_en = (rx_state==RX_RECEIVE);

assign o_rts = uart_rts & (rx_command != 5'b00000) & (rx_state != RX_WAIT) & (rx_state != RX_DONE);
`endif


///////////////////////////
// The serial controller
//////////////////////////

`ifdef SIMULATION

assign i_cts = 0;
reg uart_rts;

always @(posedge clk)
	if (uart_tx_enable)
		$write ("%c", uart_tx_data);

assign tx_busy = 0;

reg [8:0] c;

integer inputfile;

initial
	begin
		inputfile = $fopen ("TEST.ROM", "r");
	end
		
always @(posedge clk)	
	if (rst)
		begin
			c <= 0;
			uart_rts <= 1;
			rx_empty <= 1;
		end
	else
		if (rx_state == RX_IDLE)
			rx_empty <= 1;
		else
			if (rx_state == RX_DONE)
				rx_empty <= 0;
			else
				if (uart_read_en)
					begin
						c <= $fgetc (inputfile);
						if (~c[8])
							begin
								uart_rx_data <= c[7:0];
								rx_empty <= 0;
							end
						else
							rx_empty <= 1;
					end

`else
sasc_top serport(.clk(clk),
                 .rst(!rst),	
                 // SIO
                 .rxd_i(i_rx),
                 .txd_o(o_tx),
                 .cts_i(i_cts),
                 .rts_o(uart_rts), 
                 // External Baud Rate Generator
                 .sio_ce(sio_ce),
                 .sio_ce_x4(sio_ce_x4),
                 // Internal Interface
                 .din_i(uart_tx_data),
                 .dout_o(uart_rx_data),
					  .re_i(uart_read_en),
					  .we_i(uart_tx_enable),
					  .full_o(tx_busy),
					  .empty_o(rx_empty));

////////////////////////////
// The Baud rate generator
////////////////////////////


/*
	Example:
	If your system clock is 50MHz and you want to generate a 9.6 Kbps baud rate:
	9600*4 = 38400KHz
	50MHz/38400KHz=1302 or 6*217
	set div0=4 (6-2) and set div1=217

9600*4 = 38400
27MHz/38400=703 = 6*117

115200*4 = 460800
27MHz/460800 = 59 = 6*10
set div0=4, set div1=10

115200*4 = 460800
80MHz/460800 = 173.6 ~= 174 = 6*29
set div0=4, set div1=29

// Zorislav Shoyat, 10/3/2014, 20:44

57600*4 = 230400
50Mhz/230400 = 217.014 -= 217 = 7*31

1843200 baud: 7 -> XX * 7 (-0.22 err = 3.14%)
921600 baud: 14 -> 0 * 7 (-0.44 err = 3.38%)
460800 baud: 27 -> 1 * 9 (0.13 err = 0.48%)
230400 baud: 54 -> 4 * 9 (0.25 err = 0.46%)
115200 baud: 108 -> 10 * 9 (0.51 err = 0.47%)
57600 baud: 217 -> 5 * 31
38400 baud: 325 -> 11 * 25
28800 baud: 434 -> 12 * 31
19200 baud: 651 -> 19 * 31
14400 baud: 868 -> 26 * 31
9600 baud: 1302 -> 40 * 31
7200 baud: 1736 -> 54 * 31
4800 baud: 2604 -> 82 * 31
3600 baud: 3472 -> 110 * 31
2400 baud: 5208 -> 166 * 31
1800 baud: 6944 -> 222 * 31
1200 baud: 10417 -> 166 * 62
600 baud: 20833 -> 166 * 124
300 baud: 41667 -> 166 * 248
200 baud: 62500 -> 166 * 372
150 baud: 83333 -> 
134 baud: 93284 ->
110 baud: 113636 ->
75 baud: 166667 ->
50 baud: 250000 ->

// Zorislav Shoyat, 16/4/2014, 8:00

57600*4 = 230400
70Mhz/230400 = 303.82 -= 304 = 10*30

115200 baud: 152 -> 7 * 17
57600 baud: 304 -> 7 * 34

// ZS, 11/5/2014, 20:59

20MHz:

115200 baud: 43.4 -> (4-2) 2 * 11

// Zorislav Shoyat, 15/2/15 15:30

105MHz:

115200 baud: 227.86 -> (12-2) 10 * 19

60MHz:

115200 baud: 130.2 -> (13-2) 11 * 10

*/

`ifdef NOTDEF
assign div0 = 0;
assign div1 = 2;
`else
`ifdef MHz105
assign div0 = 8'd10; // 115200 baud
assign div1 = 8'd19;
`elsif  MHz80
assign div0 = 8'd4; // 115200 baud
assign div1 = 8'd29;
`elsif  MHz70
assign div0 = 8'd7; // 115200 baud
assign div1 = 8'd17;
`elsif  MHz60
assign div0 = 8'd11; // 115200 baud
assign div1 = 8'd10;
`elsif MHz50
assign div0 = 8'd10; // 115200 baud
assign div1 = 8'd9;
`elsif MHz20
assign div0 = 8'd2; // 115200 baud
assign div1 = 8'd11;
`else
	ERROR
`endif
`endif


sasc_brg bridge(.clk(clk),
                .rst(!rst),
					 .div0(div0),
					 .div1(div1),
					 .sio_ce(sio_ce),
					 .sio_ce_x4(sio_ce_x4));
`endif


endmodule
