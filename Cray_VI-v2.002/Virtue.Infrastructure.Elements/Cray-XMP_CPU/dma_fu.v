/* This is the I/O controller block for the Cray X-MP.
This had a fairly complicated structure to try to maximize
bandwidth and provide priorities, etc. I'm going to ignore
that for now, and just focus on something that accomplishes
the same task. The XMP had a 'high-speed' channel pair (6,7)
that ran at 1250 MB/s (!!!) and was used to interface to the
giant 'SSD' ramdisk. It also had 4 'low-speed' channel pairs
(10/11, 12/13, 14/15, 16/17) that ran at 6 MB/s and were used
to talk to the IOPs. All four CPUs could access all five
channels. I'm going to ignore the 'groups' and priorities and
try to just make a block that provides round-robin access to
memory for all 5 channel pairs from all 4 CPUs.
*/


//Input channels (Write-only to memory)
// 6 - 1250 MB/s
// 10,12,14,16 - 6 MB/s
//Output channels (Read-only to memory)
// 7 - 1250 MB/s
// 11,13,15,17 - 6 MB/s

//////////////////////////////////////////////////////////////////
//
// Adapted by Zorislav Shoyat, 19/3/2014, 3:13
//
//////////////////////////////////////////////////////////////////

// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

`ifndef CRAY_1

module dma_fu(input  wire        clk,
              input  wire        rst,
				  //////////////////////////////////
				  //         CPU Interfaces       //
				  //////////////////////////////////
				  //CPU0 Interface
              input  wire [15:0] i_cpu0_instr,
				  input  wire        i_cpu0_mon_mode,
              input  wire        i_cpu0_instr_vld,
              input  wire [23:0] i_cpu0_ak,
              input  wire [23:0] i_cpu0_aj,
				  output reg  [23:0] o_cpu0_ai
`ifndef CRAY_XMP_1
				,
				  //CPU1 Interface
              input  wire [15:0] i_cpu1_instr,
				  input  wire        i_cpu1_mon_mode,
              input  wire        i_cpu1_instr_vld,
              input  wire [23:0] i_cpu1_ak,
              input  wire [23:0] i_cpu1_aj,
				  output reg  [23:0] o_cpu1_ai
`ifndef CRAY_XMP_2
				 ,
				  //CPU2 Interface
              input  wire [15:0] i_cpu2_instr,
				  input  wire        i_cpu2_mon_mode,
              input  wire        i_cpu2_instr_vld,
              input  wire [23:0] i_cpu2_ak,
              input  wire [23:0] i_cpu2_aj,
				  output reg  [23:0] o_cpu2_ai
`ifndef CRAY_XMP_3
				 ,
				  //CPU3 Interface
              input  wire [15:0] i_cpu3_instr,
				  input  wire        i_cpu3_mon_mode,
              input  wire        i_cpu3_instr_vld,
              input  wire [23:0] i_cpu3_ak,
              input  wire [23:0] i_cpu3_aj,
				  output reg  [23:0] o_cpu3_ai
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
				 ,
				  
              ////////////////////////////////
				  //      1250 MB/s channels    //
				  ////////////////////////////////
				  //Incoming data
              input  wire [15:0] i_ch06_data,
              input  wire         i_ch06_vld,
              output wire         o_ch06_rdy,
				  //Outgoing data
              output wire [15:0] o_ch07_data,
              output wire         o_ch07_vld,
              input  wire         i_ch07_rdy,			  
				  
				  ////////////////////////////////
				  //        6 MB/s channels     //
				  ////////////////////////////////
				  //incoming data
              input  wire [15:0] i_ch10_data,
              input  wire        i_ch10_vld,
              output wire        o_ch10_rdy,

              input  wire [15:0] i_ch12_data,
              input  wire        i_ch12_vld,
              output wire        o_ch12_rdy,
				  
              input  wire [15:0] i_ch14_data,
              input  wire        i_ch14_vld,
              output wire        o_ch14_rdy,
				  
              input  wire [15:0] i_ch16_data,
              input  wire        i_ch16_vld,
              output wire        o_ch16_rdy,
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
              input  wire        i_ch17_rdy,

              ////////////////////////////////
				  //      Memory Interface      //
				  ////////////////////////////////
              output wire [63:0] o_mem_data,
				  input  wire [63:0] i_mem_data,
              output wire [21:0] o_mem_addr,
              output wire        o_mem_req,
				  output wire        o_mem_wr,
              input  wire        i_mem_ack);



//Channel Address Registers
reg [21:0] ca_06, ca_07;
reg [21:0] ca_10, ca_11, ca_12, ca_13, ca_14, ca_15, ca_16, ca_17;

wire ca_06_inc, ca_07_inc;
wire ca_10_inc, ca_11_inc, ca_12_inc, ca_13_inc, ca_14_inc, ca_15_inc, ca_16_inc, ca_17_inc;

wire ca_06_ce, ca_07_ce;
wire ca_10_ce, ca_11_ce, ca_12_ce, ca_13_ce, ca_14_ce, ca_15_ce, ca_16_ce, ca_17_ce;

//Limit Address Registers
reg [21:0] cl_06, cl_07;
reg [21:0] cl_10, cl_11, cl_12, cl_13, cl_14, cl_15, cl_16, cl_17;

wire cl_06_inc, cl_07_inc;
wire cl_10_inc, cl_11_inc, cl_12_inc, cl_13_inc, cl_14_inc, cl_15_inc, cl_16_inc, cl_17_inc;


wire cl_06_ce, cl_07_ce;
wire cl_10_ce, cl_11_ce, cl_12_ce, cl_13_ce, cl_14_ce, cl_15_ce, cl_16_ce, cl_17_ce;

//"state" registers for each channel
reg ch_06, ch_07;
reg ch_10, ch_11, ch_12, ch_13, ch_14, ch_15, ch_16, ch_17;

wire ch_06_done, ch_7_done;
wire ch_10_done, ch_11_done, ch_12_done, ch_13_done, ch_14_done, ch_15_done, ch_16_done, ch_17_done;

wire ch06_full, ch07_full;
wire ch10_full, ch11_full, ch12_full, ch13_full, ch14_full, ch15_full, ch16_full, ch17_full;
wire [63:0] int_ch06_data;
wire [63:0] int_ch07_data;
wire [63:0] int_ch10_data;
wire [63:0] int_ch11_data;
wire [63:0] int_ch12_data;
wire [63:0] int_ch13_data;
wire [63:0] int_ch14_data;
wire [63:0] int_ch15_data;
wire [63:0] int_ch16_data;
wire [63:0] int_ch17_data;

wire ch11_wr, ch13_wr, ch15_wr, ch17_wr;
wire ch10_rd, ch12_rd, ch14_rd, ch16_rd;

//Memory Interfaces
localparam IDLE    = 2'h0;
localparam FETCH   = 2'h1;
localparam FORWARD = 2'h2; 

//Memory controller state info
reg [1:0]  mem_state;
reg [2:0]  cur_mem_sel;
wire       mem_req_vld;
wire       mem_waiting_data_valid;

//Let's flop the incoming CPU interfaces to improve timing
reg [15:0] cpu0_instr;
reg cpu0_mon_mode;
reg cpu0_instr_vld;
reg [23:0] cpu0_ak;
reg [23:0] cpu0_aj;

`ifndef CRAY_XMP_1
reg [15:0] cpu1_instr;
reg cpu1_mon_mode;
reg cpu1_instr_vld;
reg [23:0] cpu1_ak;
reg [23:0] cpu1_aj;

`ifndef CRAY_XMP_2
reg [15:0] cpu2_instr;
reg cpu2_mon_mode;
reg cpu2_instr_vld;
reg [23:0] cpu2_ak;
reg [23:0] cpu2_aj;

`ifndef CRAY_XMP_3
reg [15:0] cpu3_instr;
reg cpu3_mon_mode;
reg cpu3_instr_vld;
reg [23:0] cpu3_ak;
reg [23:0] cpu3_aj;
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
	 
wire channel_type_instr;
wire write_ca;
wire write_cl;
reg [1:0]  cpu_sel;
reg [23:0] int_aj;
reg [23:0] int_ak;

reg  [63:0] in_flight_data;
reg  [21:0] in_flight_addr;
reg  [3:0] unmasked_req;
reg  [3:0] masked_req;
wire       req_pending;
wire       masked_req_pending;
wire [9:0] incoming_reqs;
wire [9:0] masked_incoming_reqs;
reg  [9:0] req_mask;
reg  [9:0] nxt_mask;
reg  [3:0] nxt_grant;
reg  [3:0] grant;
wire       req_cpl;
wire       incoming_data_valid;
reg  [63:0] incoming_ch_data;

reg  [9:0]  interrupt_vector;
reg  [9:0]  int_clear;

wire cpu0_check_int;
`ifndef CRAY_XMP_1
wire cpu1_check_int;
`ifndef CRAY_XMP_3
wire cpu2_check_int;
`ifndef CRAY_XMP_3
wire cpu3_check_int;
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1

wire ch06_int, ch10_int, ch12_int, ch14_int, ch16_int;

////////////////////////////////////////////////
//            Channel control interfaces      //
////////////////////////////////////////////////
				  
// 'Fast' channels (should be 1250 MB/s, for now just use slow channels)


output wire [15:0] ch11_p_channel_data;
output wire ch11_p_channel_srdy;
output wire ch11_p_channel_disconnect;
output wire ch11_p_channel_data_valid;
input wire ch11_p_channel_drdy;


//Input channel			  
slow_ch_rx rx06(.rst(rst),
			  .clk(clk),
			  .i_data(i_ch06_data),
			  .i_valid(i_ch06_vld),
			  .o_ready(o_ch06_rdy),
			  .o_full(ch06_full),
			  .o_data(int_ch06_data),
			  .i_rd(ch06_rd),
			  .o_int(ch06_int));	

//Output channel
slow_ch_tx tx07(.rst(rst),
					 .clk(clk),
					 .o_data(o_ch07_data),
					 .o_valid(o_ch07_vld),
					 .i_ready(i_ch07_rdy),
					 .o_full(ch07_full),
					 .i_data(int_ch07_data),
					 .i_wr(ch07_wr),
					.i_last(ch_07_done));			  

			  				  
//  6MB/s Output Channels				  
slow_ch_tx tx11(.rst(rst),
					 .clk(clk),
					 .o_data(o_ch11_data),
					 .o_valid(o_ch11_vld),
					 .i_ready(i_ch11_rdy),
					 .o_full(ch11_full),
					 .i_data(int_ch11_data),
					 .i_wr(ch11_wr),
					.i_last(ch_11_done));
					 
slow_ch_tx tx13(.rst(rst),
					 .clk(clk),
					 .o_data(o_ch13_data),
					 .o_valid(o_ch13_vld),
					 .i_ready(i_ch13_rdy),
					 .o_full(ch13_full),
					 .i_data(int_ch13_data),
					 .i_wr(ch13_wr),
					.i_last(ch_13_done));
					 
slow_ch_tx tx15(.rst(rst),
					 .clk(clk),
					 .o_data(o_ch15_data),
					 .o_valid(o_ch15_vld),
					 .i_ready(i_ch15_rdy),
					 .o_full(ch15_full),
					 .i_data(int_ch15_data),
					 .i_wr(ch15_wr),
					.i_last(ch_15_done));
					 
slow_ch_tx tx17(.rst(rst),
					 .clk(clk),
					 .o_data(o_ch17_data),
					 .o_valid(o_ch17_vld),
					 .i_ready(i_ch17_rdy),
					 .o_full(ch17_full),
					 .i_data(int_ch17_data),
					 .i_wr(ch17_wr),
					.i_last(ch_17_done));			  

// 6MB/s Input Channels				  
slow_ch_rx rx10(.rst(rst),
			  .clk(clk),
			  .i_data(i_ch10_data),
			  .i_valid(i_ch10_vld),
			  .o_ready(o_ch10_rdy),
			  .o_full(ch10_full),
			  .o_data(int_ch10_data),
			  .i_rd(ch10_rd),
				.o_int(ch10_int));
			  
slow_ch_rx rx12(.rst(rst),
			  .clk(clk),
			  .i_data(i_ch12_data),
			  .i_valid(i_ch12_vld),
			  .o_ready(o_ch12_rdy),
			  .o_full(ch12_full),
			  .o_data(int_ch12_data),
			  .i_rd(ch12_rd),
				.o_int(ch12_int));
			  
slow_ch_rx rx14(.rst(rst),
			  .clk(clk),
			  .i_data(i_ch14_data),
			  .i_valid(i_ch14_vld),
			  .o_ready(o_ch14_rdy),
			  .o_full(ch14_full),
			  .o_data(int_ch14_data),
			  .i_rd(ch14_rd),
				.o_int(ch14_int));
			  		  
slow_ch_rx rx16(.rst(rst),
			  .clk(clk),
			  .i_data(i_ch16_data),
			  .i_valid(i_ch16_vld),
			  .o_ready(o_ch16_rdy),
			  .o_full(ch16_full),
			  .o_data(int_ch16_data),
			  .i_rd(ch16_rd),
				.o_int(ch16_int));


//This is a shared I/O controller that can be accessed independently by all four main CPUs.
//Collision-detect and all that fun stuff apparently needed to be handled in software,
//so it should be fine to resolve conflicts with a simple priority arbiter (CPU0 > CPU1, etc.).
//In the event of a simultaneous access, lower-priority CPUs will be ignored (which I think is
//close enough to the real behavior). As long as nothing deadlocks, we should be okay!

//Flop the incoming signals to improve timing
always@(posedge clk)
   begin
		cpu0_instr     <= i_cpu0_instr;
		cpu0_mon_mode  <= i_cpu0_mon_mode;
		cpu0_instr_vld <= i_cpu0_instr_vld;
		cpu0_ak        <= i_cpu0_ak;
		cpu0_aj        <= i_cpu0_aj;
`ifndef CRAY_XMP_1
		cpu1_instr     <= i_cpu1_instr;
		cpu1_mon_mode  <= i_cpu1_mon_mode;
		cpu1_instr_vld <= i_cpu1_instr_vld;
		cpu1_ak        <= i_cpu1_ak;
		cpu1_aj        <= i_cpu1_aj;
`ifndef CRAY_XMP_2
		cpu2_instr     <= i_cpu2_instr;
		cpu2_mon_mode  <= i_cpu2_mon_mode;
		cpu2_instr_vld <= i_cpu2_instr_vld;
		cpu2_ak        <= i_cpu2_ak;
		cpu2_aj        <= i_cpu2_aj;
`ifndef CRAY_XMP_3
		cpu3_instr     <= i_cpu3_instr;
		cpu3_mon_mode  <= i_cpu3_mon_mode;
		cpu3_instr_vld <= i_cpu3_instr_vld;
		cpu3_ak        <= i_cpu3_ak;
		cpu3_aj        <= i_cpu3_aj;
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
	end

//Read operations
always@(posedge clk)
	//Instr 033i00 - get highest priority interrupt (Lowest num)
	if(cpu0_instr_vld && cpu0_mon_mode && (cpu0_instr[15:9]==7'b0011011) && (cpu0_instr[5:0]==6'b0))
		casez(interrupt_vector[9:0])
		   10'b?????????1:o_cpu0_ai <= 24'h6;
			10'b????????10:o_cpu0_ai <= 24'h7;
			10'b???????100:o_cpu0_ai <= 24'h8;
			10'b??????1000:o_cpu0_ai <= 24'h9;
			10'b?????10000:o_cpu0_ai <= 24'hA;
			10'b????100000:o_cpu0_ai <= 24'hB;
			10'b???1000000:o_cpu0_ai <= 24'hC;
			10'b??10000000:o_cpu0_ai <= 24'hD;
			10'b?100000000:o_cpu0_ai <= 24'hE;
			10'b1000000000:o_cpu0_ai <= 24'hF;
			default: o_cpu0_ai <= 24'b0;
		endcase
	else if(cpu0_instr_vld && cpu0_mon_mode && (cpu0_instr[15:9]==7'b0011011))
		case(cpu0_aj[5:0])
			6'd06:o_cpu0_ai <= {2'b00,ca_06};
			6'd07:o_cpu0_ai <= {2'b00,ca_07}; 
			6'd08:o_cpu0_ai <= {2'b00,ca_10};
			6'd09:o_cpu0_ai <= {2'b00,ca_11};
			6'd10:o_cpu0_ai <= {2'b00,ca_12};
			6'd11:o_cpu0_ai <= {2'b00,ca_13};
			6'd12:o_cpu0_ai <= {2'b00,ca_14};
			6'd13:o_cpu0_ai <= {2'b00,ca_15};
			6'd14:o_cpu0_ai <= {2'b00,ca_16};
			6'd15:o_cpu0_ai <= {2'b00,ca_17};
		endcase

`ifndef CRAY_XMP_1
always@(posedge clk)
	//Instr 033i00 - get highest priority interrupt (Lowest num)
	if(cpu1_instr_vld && cpu1_mon_mode && (cpu1_instr[15:9]==7'b0011011) && (cpu1_instr[5:0]==6'b0))
		casez(interrupt_vector[9:0])
		   10'b?????????1:o_cpu1_ai <= 24'h6;
			10'b????????10:o_cpu1_ai <= 24'h7;
			10'b???????100:o_cpu1_ai <= 24'h8;
			10'b??????1000:o_cpu1_ai <= 24'h9;
			10'b?????10000:o_cpu1_ai <= 24'hA;
			10'b????100000:o_cpu1_ai <= 24'hB;
			10'b???1000000:o_cpu1_ai <= 24'hC;
			10'b??10000000:o_cpu1_ai <= 24'hD;
			10'b?100000000:o_cpu1_ai <= 24'hE;
			10'b1000000000:o_cpu1_ai <= 24'hF;
			default: o_cpu1_ai <= 24'b0;
		endcase
	else if(cpu1_instr_vld && cpu1_mon_mode && (cpu1_instr[15:9]==7'b0011011))
		case(cpu1_aj[5:0])
			6'd06:o_cpu1_ai <= {2'b00,ca_06};
			6'd07:o_cpu1_ai <= {2'b00,ca_07}; 
			6'd08:o_cpu1_ai <= {2'b00,ca_10};
			6'd09:o_cpu1_ai <= {2'b00,ca_11};
			6'd10:o_cpu1_ai <= {2'b00,ca_12};
			6'd11:o_cpu1_ai <= {2'b00,ca_13};
			6'd12:o_cpu1_ai <= {2'b00,ca_14};
			6'd13:o_cpu1_ai <= {2'b00,ca_15};
			6'd14:o_cpu1_ai <= {2'b00,ca_16};
			6'd15:o_cpu1_ai <= {2'b00,ca_17};
		endcase
		
`ifndef CRAY_XMP_2
always@(posedge clk)
	//Instr 033i00 - get highest priority interrupt (Lowest num)
	if(cpu2_instr_vld && cpu2_mon_mode && (cpu2_instr[15:9]==7'b0011011) && (cpu2_instr[5:0]==6'b0))
		casez(interrupt_vector[9:0])
		   10'b?????????1:o_cpu2_ai <= 24'h6;
			10'b????????10:o_cpu2_ai <= 24'h7;
			10'b???????100:o_cpu2_ai <= 24'h8;
			10'b??????1000:o_cpu2_ai <= 24'h9;
			10'b?????10000:o_cpu2_ai <= 24'hA;
			10'b????100000:o_cpu2_ai <= 24'hB;
			10'b???1000000:o_cpu2_ai <= 24'hC;
			10'b??10000000:o_cpu2_ai <= 24'hD;
			10'b?100000000:o_cpu2_ai <= 24'hE;
			10'b1000000000:o_cpu2_ai <= 24'hF;
			default: o_cpu2_ai <= 24'b0;
		endcase
	else if(cpu2_instr_vld && cpu2_mon_mode && (cpu2_instr[15:9]==7'b0011011))
		case(cpu2_aj[5:0])
			6'd06:o_cpu2_ai <= {2'b00,ca_06};
			6'd07:o_cpu2_ai <= {2'b00,ca_07}; 
			6'd08:o_cpu2_ai <= {2'b00,ca_10};
			6'd09:o_cpu2_ai <= {2'b00,ca_11};
			6'd10:o_cpu2_ai <= {2'b00,ca_12};
			6'd11:o_cpu2_ai <= {2'b00,ca_13};
			6'd12:o_cpu2_ai <= {2'b00,ca_14};
			6'd13:o_cpu2_ai <= {2'b00,ca_15};
			6'd14:o_cpu2_ai <= {2'b00,ca_16};
			6'd15:o_cpu2_ai <= {2'b00,ca_17};
		endcase
		
`ifndef CRAY_XMP_3
always@(posedge clk)
	//Instr 033i00 - get highest priority interrupt (Lowest num)
	if(cpu3_instr_vld && cpu3_mon_mode && (cpu3_instr[15:9]==7'b0011011) && (cpu3_instr[5:0]==6'b0))
		casez(interrupt_vector[9:0])
		   10'b?????????1:o_cpu3_ai <= 24'h6;
			10'b????????10:o_cpu3_ai <= 24'h7;
			10'b???????100:o_cpu3_ai <= 24'h8;
			10'b??????1000:o_cpu3_ai <= 24'h9;
			10'b?????10000:o_cpu3_ai <= 24'hA;
			10'b????100000:o_cpu3_ai <= 24'hB;
			10'b???1000000:o_cpu3_ai <= 24'hC;
			10'b??10000000:o_cpu3_ai <= 24'hD;
			10'b?100000000:o_cpu3_ai <= 24'hE;
			10'b1000000000:o_cpu3_ai <= 24'hF;
			default: o_cpu3_ai <= 24'b0;
		endcase
	else if(cpu3_instr_vld && cpu3_mon_mode && (cpu3_instr[15:9]==7'b0011011))
		case(cpu3_aj[5:0])
			6'd06:o_cpu3_ai <= {2'b00,ca_06};
			6'd07:o_cpu3_ai <= {2'b00,ca_07}; 
			6'd08:o_cpu3_ai <= {2'b00,ca_10};
			6'd09:o_cpu3_ai <= {2'b00,ca_11};
			6'd10:o_cpu3_ai <= {2'b00,ca_12};
			6'd11:o_cpu3_ai <= {2'b00,ca_13};
			6'd12:o_cpu3_ai <= {2'b00,ca_14};
			6'd13:o_cpu3_ai <= {2'b00,ca_15};
			6'd14:o_cpu3_ai <= {2'b00,ca_16};
			6'd15:o_cpu3_ai <= {2'b00,ca_17};
		endcase
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
		
//Determine if it's a channel-related instruction
assign cpu0_en = cpu0_instr_vld && cpu0_mon_mode && ((cpu0_instr[15:6]==10'b0000001000) || 
												                     (cpu0_instr[15:6]==10'b0000001001));
`ifndef CRAY_XMP_1
assign cpu1_en = cpu1_instr_vld && cpu1_mon_mode && ((cpu1_instr[15:6]==10'b0000001000) || 
												                     (cpu1_instr[15:6]==10'b0000001001));
`ifndef CRAY_XMP_2
assign cpu2_en = cpu2_instr_vld && cpu2_mon_mode && ((cpu2_instr[15:6]==10'b0000001000) || 
												                     (cpu2_instr[15:6]==10'b0000001001));
`ifndef CRAY_XMP_3
assign cpu3_en = cpu3_instr_vld && cpu3_mon_mode && ((cpu3_instr[15:6]==10'b0000001000) || 
												                     (cpu3_instr[15:6]==10'b0000001001));
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1

wire[3:0] cpu_en;

`ifdef CRAY_XMP_1
assign cpu_access = cpu0_en;
assign cpu_en = {cpu0_en, 3'b0};
`endif // CRAY_XMP_1
`ifdef CRAY_XMP_2
assign cpu_access = cpu0_en || cpu1_en;
assign cpu_en = {cpu0_en, cpu1_en, 2'b0};
`endif // CRAY_XMP_2
`ifdef CRAY_XMP_3
assign cpu_access = cpu0_en || cpu1_en || cpu2_en;
assign cpu_en = {cpu0_en, cpu1_en, cpu2_en, 1'b0};
`endif // CRAY_XMP_3
`ifdef CRAY_XMP_4
assign cpu_access = cpu0_en || cpu1_en || cpu2_en || cpu3_en;
assign cpu_en = {cpu0_en, cpu1_en, cpu2_en, cpu3_en};
`endif // CRAY_XMP_4


//And which CPU you should be servicing
always@*
   begin
		casez (cpu_en)
			4'b1???:begin
						cpu_sel = 2'b00;	//select CPU0
						int_aj  = cpu0_aj;
						int_ak  = cpu0_ak;
					  end
`ifndef CRAY_XMP_1
			4'b01??:begin
			         cpu_sel = 2'b01;	//select CPU1
						int_aj  = cpu1_aj;
						int_ak  = cpu1_ak;
					  end
`ifndef CRAY_XMP_2
			4'b001?:begin
			         cpu_sel = 2'b10;	//Select CPU2
						int_aj  = cpu2_aj;
						int_ak  = cpu2_ak;
					  end
`ifndef CRAY_XMP_3
			4'b0001:begin
			         cpu_sel = 2'b11;	//select CPU3
						int_aj  = cpu3_aj;
						int_ak  = cpu3_ak;
					  end
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
			endcase
	end

//Then figure out which instruction you are servicing
assign write_ca = cpu_access && ( ((cpu_sel==2'b00) && (cpu0_instr[15:6]==10'b0000001000))
`ifndef CRAY_XMP_1
											|| 
                                  ((cpu_sel==2'b01) && (cpu1_instr[15:6]==10'b0000001000))
`ifndef CRAY_XMP_2
											||
											 ((cpu_sel==2'b10) && (cpu2_instr[15:6]==10'b0000001000))
`ifndef CRAY_XMP_3
											||
											 ((cpu_sel==2'b11) && (cpu3_instr[15:6]==10'b0000001000))
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
										);

assign write_cl = cpu_access && ( ((cpu_sel==2'b00) && (cpu0_instr[15:6]==10'b0000001001))
`ifndef CRAY_XMP_1
											|| 
                                  ((cpu_sel==2'b01) && (cpu1_instr[15:6]==10'b0000001001))
`ifndef CRAY_XMP_2
											||
											 ((cpu_sel==2'b10) && (cpu2_instr[15:6]==10'b0000001001))
`ifndef CRAY_XMP_3
											||
											 ((cpu_sel==2'b11) && (cpu3_instr[15:6]==10'b0000001001))
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
										);
											 
						

//and Figure out which register to write
assign ca_06_ce = write_ca && (int_aj[5:0]==6'd6);
assign ca_07_ce = write_ca && (int_aj[5:0]==6'd7);
assign ca_10_ce = write_ca && (int_aj[5:0]==6'd8);
assign ca_11_ce = write_ca && (int_aj[5:0]==6'd9);
assign ca_12_ce = write_ca && (int_aj[5:0]==6'd10);
assign ca_13_ce = write_ca && (int_aj[5:0]==6'd11);
assign ca_14_ce = write_ca && (int_aj[5:0]==6'd12);
assign ca_15_ce = write_ca && (int_aj[5:0]==6'd13);
assign ca_16_ce = write_ca && (int_aj[5:0]==6'd14);
assign ca_17_ce = write_ca && (int_aj[5:0]==6'd15);

assign cl_06_ce = write_cl && (int_aj[5:0]==6'd6);
assign cl_07_ce = write_cl && (int_aj[5:0]==6'd7);
assign cl_10_ce = write_cl && (int_aj[5:0]==6'd8);
assign cl_11_ce = write_cl && (int_aj[5:0]==6'd9);
assign cl_12_ce = write_cl && (int_aj[5:0]==6'd10);
assign cl_13_ce = write_cl && (int_aj[5:0]==6'd11);
assign cl_14_ce = write_cl && (int_aj[5:0]==6'd12);
assign cl_15_ce = write_cl && (int_aj[5:0]==6'd13);
assign cl_16_ce = write_cl && (int_aj[5:0]==6'd14);
assign cl_17_ce = write_cl && (int_aj[5:0]==6'd15);

//Now we need to figure out when we're going to increment the CA registers
assign ca_06_inc = req_cpl && (grant==4'h0);
assign ca_07_inc = req_cpl && (grant==4'h1);
assign ca_10_inc = req_cpl && (grant==4'h2);
assign ca_11_inc = req_cpl && (grant==4'h3);
assign ca_12_inc = req_cpl && (grant==4'h4);
assign ca_13_inc = req_cpl && (grant==4'h5);
assign ca_14_inc = req_cpl && (grant==4'h6);
assign ca_15_inc = req_cpl && (grant==4'h7);
assign ca_16_inc = req_cpl && (grant==4'h8);
assign ca_17_inc = req_cpl && (grant==4'h9);


//Let's figure out when a channel operation is 'done'
// (i.e. when CA[n]==CL[n]-1)

assign ch_06_done = (ca_06 == (cl_06-22'b1));
assign ch_07_done = (ca_07 == (cl_07-22'b1));
assign ch_10_done = (ca_10 == (cl_10-22'b1));
assign ch_11_done = (ca_11 == (cl_11-22'b1));
assign ch_12_done = (ca_12 == (cl_12-22'b1));
assign ch_13_done = (ca_13 == (cl_13-22'b1));
assign ch_14_done = (ca_14 == (cl_14-22'b1));
assign ch_15_done = (ca_15 == (cl_15-22'b1));
assign ch_16_done = (ca_16 == (cl_16-22'b1));
assign ch_17_done = (ca_17 == (cl_17-22'b1));




always@(posedge clk)
	if(rst)
		interrupt_vector[9:0] <= 10'b0;
	else
		begin
			interrupt_vector[0] <= int_clear[0] ? 1'b0 : (ch06_int || interrupt_vector[0]);
			interrupt_vector[1] <= int_clear[1] ? 1'b0 : (ch_07_done || interrupt_vector[1]);
			interrupt_vector[2] <= int_clear[2] ? 1'b0 : (ch10_int || interrupt_vector[2]);
			interrupt_vector[3] <= int_clear[3] ? 1'b0 : (ch_11_done || interrupt_vector[3]);
			interrupt_vector[4] <= int_clear[4] ? 1'b0 : (ch12_int || interrupt_vector[4]);
			interrupt_vector[5] <= int_clear[5] ? 1'b0 : (ch_13_done || interrupt_vector[5]);
			interrupt_vector[6] <= int_clear[6] ? 1'b0 : (ch14_int || interrupt_vector[6]);
			interrupt_vector[7] <= int_clear[7] ? 1'b0 : (ch_15_done || interrupt_vector[7]);
			interrupt_vector[8] <= int_clear[8] ? 1'b0 : (ch16_int || interrupt_vector[8]);
			interrupt_vector[9] <= int_clear[9] ? 1'b0 : (ch_17_done || interrupt_vector[9]);
		end

assign cpu0_check_int = (cpu0_instr_vld && cpu0_mon_mode && (cpu0_instr[15:9]==7'b0011011) && (cpu0_instr[5:0]==6'b0));
`ifndef CRAY_XMP_1
assign cpu1_check_int = (cpu1_instr_vld && cpu1_mon_mode && (cpu1_instr[15:9]==7'b0011011) && (cpu1_instr[5:0]==6'b0));
`ifndef CRAY_XMP_2
assign cpu2_check_int = (cpu2_instr_vld && cpu2_mon_mode && (cpu2_instr[15:9]==7'b0011011) && (cpu2_instr[5:0]==6'b0));
`ifndef CRAY_XMP_3
assign cpu3_check_int = (cpu3_instr_vld && cpu3_mon_mode && (cpu3_instr[15:9]==7'b0011011) && (cpu3_instr[5:0]==6'b0));
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1

always@*
   begin
		int_clear[9:0] = 10'b0;
`ifdef CRAY_XMP_1
		if(cpu0_check_int)
`endif // RAY_XMP_1
`ifdef CRAY_XMP_2
		if(cpu0_check_int || cpu1_check_int)
`endif // CRAY_XMP_2
`ifdef CRAY_XMP_3
		if(cpu0_check_int || cpu1_check_int || cpu2_check_int)
`endif // CRAY_XMP_3
`ifdef CRAY_XMP_4
		if(cpu0_check_int || cpu1_check_int || cpu2_check_int || cpu3_check_int)
`endif // CRAY_XMP_4
		begin
			casez(interrupt_vector[9:0])
				10'b?????????1:int_clear[0] = 1'b1;
				10'b????????10:int_clear[1] = 1'b1;
				10'b???????100:int_clear[2] = 1'b1;
				10'b??????1000:int_clear[3] = 1'b1;
				10'b?????10000:int_clear[4] = 1'b1;
				10'b????100000:int_clear[5] = 1'b1;
				10'b???1000000:int_clear[6] = 1'b1;
				10'b??10000000:int_clear[7] = 1'b1;
				10'b?100000000:int_clear[8] = 1'b1;
				10'b1000000000:int_clear[9] = 1'b1;
			endcase
		end
		
	end

//Finally, let's implement all of the actual CA/CL/state registers
always@(posedge clk)
   begin
      //CA Registers - These can either get written or auto-incremented
      ca_06 <= rst ? 23'b0 : (ca_06_ce ? int_ak[22:0] : (ca_06_inc + ca_06));
      ca_07 <= rst ? 23'b0 : (ca_07_ce ? int_ak[22:0] : (ca_07_inc + ca_07));
      ca_10 <= rst ? 23'b0 : (ca_10_ce ? int_ak[22:0] : (ca_10_inc + ca_10));
      ca_11 <= rst ? 23'b0 : (ca_11_ce ? int_ak[22:0] : (ca_11_inc + ca_11));
      ca_12 <= rst ? 23'b0 : (ca_12_ce ? int_ak[22:0] : (ca_12_inc + ca_12));
      ca_13 <= rst ? 23'b0 : (ca_13_ce ? int_ak[22:0] : (ca_13_inc + ca_13));
      ca_14 <= rst ? 23'b0 : (ca_14_ce ? int_ak[22:0] : (ca_14_inc + ca_14));
      ca_15 <= rst ? 23'b0 : (ca_15_ce ? int_ak[22:0] : (ca_15_inc + ca_15));
      ca_16 <= rst ? 23'b0 : (ca_16_ce ? int_ak[22:0] : (ca_16_inc + ca_16));
      ca_17 <= rst ? 23'b0 : (ca_17_ce ? int_ak[22:0] : (ca_17_inc + ca_17));

      //CL Registers - these can only get written
      cl_06 <= rst ? 23'b0 : (cl_06_ce ? int_ak[22:0] : cl_06);
      cl_07 <= rst ? 23'b0 : (cl_07_ce ? int_ak[22:0] : cl_07);
      cl_10 <= rst ? 23'b0 : (cl_10_ce ? int_ak[22:0] : cl_10);
      cl_11 <= rst ? 23'b0 : (cl_11_ce ? int_ak[22:0] : cl_11);
      cl_12 <= rst ? 23'b0 : (cl_12_ce ? int_ak[22:0] : cl_12);
      cl_13 <= rst ? 23'b0 : (cl_13_ce ? int_ak[22:0] : cl_13);
      cl_14 <= rst ? 23'b0 : (cl_14_ce ? int_ak[22:0] : cl_14);
      cl_15 <= rst ? 23'b0 : (cl_15_ce ? int_ak[22:0] : cl_15);
      cl_16 <= rst ? 23'b0 : (cl_16_ce ? int_ak[22:0] : cl_16);
      cl_17 <= rst ? 23'b0 : (cl_17_ce ? int_ak[22:0] : cl_17);

      //Now take care of the 'state' registers - these get 'set' whenever
      //the corresponding 'CA' register gets written, and cleared whenever
      // the corresponding '_done' signal gets asserted
      ch_06 <= rst ? 1'b0 : (ch_06 ? (ch_06 && !ch_06_done) : ca_06_ce);
      ch_07 <= rst ? 1'b0 : (ch_07 ? (ch_07 && !ch_07_done) : ca_07_ce);
      ch_10 <= rst ? 1'b0 : (ch_10 ? (ch_10 && !ch_10_done) : ca_10_ce);
      ch_11 <= rst ? 1'b0 : (ch_11 ? (ch_11 && !ch_11_done) : ca_11_ce);
      ch_12 <= rst ? 1'b0 : (ch_12 ? (ch_12 && !ch_12_done) : ca_12_ce);
      ch_13 <= rst ? 1'b0 : (ch_13 ? (ch_13 && !ch_13_done) : ca_13_ce);
      ch_14 <= rst ? 1'b0 : (ch_14 ? (ch_14 && !ch_14_done) : ca_14_ce);
      ch_15 <= rst ? 1'b0 : (ch_15 ? (ch_15 && !ch_15_done) : ca_15_ce);
      ch_16 <= rst ? 1'b0 : (ch_16 ? (ch_16 && !ch_16_done) : ca_16_ce);
      ch_17 <= rst ? 1'b0 : (ch_17 ? (ch_17 && !ch_17_done) : ca_17_ce);
   end



//Now we need to implement the control state-machine for the channels.
//There is one global FSM that incorporates a 10-way round-robin arbiter
//and chooses which request to service.
//
//For channels 06,10,12,14,16: (Memory) -> Channel
//
//For channels 07,11,13,15,17: (Channel) -> Memory
//

/////////////////////////////////////
//      Memory Controller          //
/////////////////////////////////////
//Ch 06,07,10,11,12,13,14,15,16,17
//Memory controller state info



//Check if we have a request waiting (masked or unmasked)
assign incoming_reqs = {ch_06 && ch06_full,
								ch_07 && !ch07_full,
								ch_10 && ch10_full,
								ch_11 && !ch11_full,
								ch_12 && ch12_full,
								ch_13 && !ch13_full,
								ch_14 && ch14_full,
								ch_15 && !ch15_full, 
								ch_16 && ch16_full,	//Rx, full=data present
								ch_17 && !ch17_full};
								
assign req_pending = |incoming_reqs;
assign masked_incoming_reqs = incoming_reqs & req_mask;
assign masked_req_pending = |masked_incoming_reqs;

//Figure out which incoming request is highest priority
always@*
  begin
   if(req_pending)
      casez(incoming_reqs)
         10'b1?????????:unmasked_req = 4'b0000;
         10'b01????????:unmasked_req = 4'b0001;
         10'b001???????:unmasked_req = 4'b0010;
         10'b0001??????:unmasked_req = 4'b0011;
         10'b00001?????:unmasked_req = 4'b0100;
			10'b000001????:unmasked_req = 4'b0101;
			10'b0000001???:unmasked_req = 4'b0110;
			10'b00000001??:unmasked_req = 4'b0111;
			10'b000000001?:unmasked_req = 4'b1000;
			10'b0000000001:unmasked_req = 4'b1001;
      endcase
	end

always@*
  begin
   if(req_pending)
      casez(masked_incoming_reqs)
         10'b1?????????:masked_req = 4'b0000;
         10'b01????????:masked_req = 4'b0001;
         10'b001???????:masked_req = 4'b0010;
         10'b0001??????:masked_req = 4'b0011;
         10'b00001?????:masked_req = 4'b0100;
			10'b000001????:masked_req = 4'b0101;
			10'b0000001???:masked_req = 4'b0110;
			10'b00000001??:masked_req = 4'b0111;
			10'b000000001?:masked_req = 4'b1000;
			10'b0000000001:masked_req = 4'b1001;
      endcase
	end
//Figure out which one to choose, and what the new mask should be
always@*
	begin
		nxt_grant[3:0] = masked_req_pending ? masked_req[3:0] : unmasked_req[3:0];
		case(nxt_grant[3:0])
			4'b0000:nxt_mask[9:0] = 10'b0111111111;
			4'b0001:nxt_mask[9:0] = 10'b0011111111;
			4'b0010:nxt_mask[9:0] = 10'b0001111111;
			4'b0011:nxt_mask[9:0] = 10'b0000111111;
			4'b0100:nxt_mask[9:0] = 10'b0000011111;
			4'b0101:nxt_mask[9:0] = 10'b0000001111;
			4'b0110:nxt_mask[9:0] = 10'b0000000111;
			4'b0111:nxt_mask[9:0] = 10'b0000000011;
			4'b1000:nxt_mask[9:0] = 10'b0000000001;
			4'b1001:nxt_mask[9:0] = 10'b0000000000;
			default:nxt_mask[9:0] = 10'b0000000000;
		endcase
	end

always@(posedge clk)
	if(rst)
		begin
			grant[3:0]    <= 4'b0;
			req_mask[9:0] <= 10'b0111111111;
		end
	else if((mem_state==IDLE) && req_pending)
		begin
			grant[3:0] <= nxt_grant[3:0];
			req_mask[9:0] <= nxt_mask[9:0];
		end
		
			  		
always@(posedge clk)
   if(rst)
	   mem_state <= IDLE;
	else case(mem_state)
		//1. Let's wait till we have a request to service
		IDLE:if(req_pending)
				mem_state <= FETCH;
				
		//2. Let's grab the data from memory or channel, and put
		//it in the in_flight_data reg so we can forward it
		//grant[0]==0 -> Fetch data from mem, send to channel
		//grant[0]==1 -> Fetch data from channel, send to mem
		FETCH:if((grant[0]==1'b0) && i_mem_ack)
					mem_state <= FORWARD;
				else if((grant[0]==1'b1) && incoming_data_valid)
					mem_state <= FORWARD;
		//3. Move in_flight_data to its destination (either memory or channel)
		FORWARD:if(req_cpl)
					mem_state <= IDLE;
		//else go to IDLE
		default:mem_state <= IDLE;
	endcase


//We need to get data (from either a receiving channel or the mem controller)
// and store it in the in_flight_data reg so we can send it to its destination

//wait for valid data from the selected channel
assign incoming_data_valid = (ch06_full && grant==4'h0) ||
                             (ch10_full && grant==4'h2) ||
                             (ch12_full && grant==4'h4) || 
                             (ch14_full && grant==4'h6) ||
                             (ch16_full && grant==4'h8);

assign ch06_rd = (grant==4'h0) && (mem_state==FETCH);
assign ch10_rd = (grant==4'h2) && (mem_state==FETCH);
assign ch12_rd = (grant==4'h4) && (mem_state==FETCH);
assign ch14_rd = (grant==4'h6) && (mem_state==FETCH);
assign ch16_rd = (grant==4'h8) && (mem_state==FETCH);

always@*
   begin
	   case(grant)
			4'h0: incoming_ch_data = int_ch06_data;
			4'h2: incoming_ch_data = int_ch10_data;
			4'h4: incoming_ch_data = int_ch12_data;
			4'h6: incoming_ch_data = int_ch14_data;
			4'h8: incoming_ch_data = int_ch16_data;
		endcase
	end
	
	
always@(posedge clk)
	if((mem_state==FETCH) && grant[0] && i_mem_ack)
		in_flight_data <= i_mem_data;
	else if ((mem_state==FETCH) && !grant[0] && incoming_data_valid)
		in_flight_data <= incoming_ch_data;
		
//Figure out the address associated with this request (source or dest)
always@(posedge clk)
	if(mem_state==IDLE)
		case(nxt_grant)
			4'h0:in_flight_addr <= ca_06;
			4'h1:in_flight_addr <= ca_07;
			4'h2:in_flight_addr <= ca_10;
			4'h3:in_flight_addr <= ca_11;
			4'h4:in_flight_addr <= ca_12;
			4'h5:in_flight_addr <= ca_13;
			4'h6:in_flight_addr <= ca_14;
			4'h7:in_flight_addr <= ca_15;
			4'h8:in_flight_addr <= ca_16;
			4'h9:in_flight_addr <= ca_17;
			default:in_flight_addr <= 23'b0;
		endcase


//Drive the memory interface (to fetch or commit)
assign o_mem_data = in_flight_data;
assign o_mem_addr = in_flight_addr;
assign o_mem_req = ((mem_state==FETCH) && !grant[0]) || ((mem_state==FORWARD) && grant[0]);
assign o_mem_wr = ((mem_state==FORWARD) && grant[0]);


//Commit data to outgoing channels
assign ch07_wr = (grant==4'h1) && (mem_state==FORWARD);
assign ch11_wr = (grant==4'h3) && (mem_state==FORWARD);
assign ch13_wr = (grant==4'h5) && (mem_state==FORWARD);
assign ch15_wr = (grant==4'h7) && (mem_state==FORWARD);
assign ch17_wr = (grant==4'h9) && (mem_state==FORWARD);

//Check if transaction is complete
assign req_cpl = (mem_state==FORWARD) && (((grant[0]==1'b1) && i_mem_ack) || (grant[0]==1'b0));

endmodule

`endif