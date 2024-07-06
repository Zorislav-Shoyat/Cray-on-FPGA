//******************************************
//       Memory Functional Unit
//******************************************
//

/////////////////
//
// Original design by Christofer Fenton
//
/////////////////

/////////////////
//
// Zorislav Shoyat, 16/2/15, 6:31, Atelier, Delphinus
//

/////////////////
//
// Zorislav Shoyat, 24/2/15, 1:07, Atelier, Delphinus
//
// The timing of Cray-VI finally works
//
// It is high time to clean up all old comments
//
// Decoupling the Read from the Write
//
// 24/2/15. 19:05, Atelier, Delphinus
//
// Independent READ and WRITE from/to memory
//


// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"


module MEM_FU(clk,
              rst,
				  i_mode_bdm,
              i_cip,
				  i_cip_vld,
				  i_lip,
				  i_lip_vld,
				  i_vector_length,
				  i_vstart,
				  i_data_base_addr,
				  i_data_limit_addr,
				  // input interface from A rf
				  i_a0_data,
				  i_ai_data,
				  i_ak_data,
				  i_ah_data,
				  i_a_res_mask,
				  // input interface from S rf
				  i_si_data,
				  i_s_res_mask,
				  // input interface from V regs
				  i_v0_data,
				  i_v1_data,
				  i_v2_data,
				  i_v3_data,
				  i_v4_data,
				  i_v5_data,
				  i_v6_data,
				  i_v7_data,
				  o_v_ack,
				  // input/output interface to B rf
				  o_b_rd_addr,
				  i_b_rd_data,
				  o_b_wr_addr,
				  o_b_wr_en,
				  // input/output interface to T rf
				  o_t_rd_addr,
				  i_t_rd_data,
				  o_t_wr_addr,
				  o_t_wr_en,
				  // output interface to A, S, V registers
				  o_mem_data,
				  // memory interface
				  //	read
				  o_mem_rd_req,
				  o_mem_rd_addr,
				  i_mem_rd_addr_ack,
				  i_mem_rd_data,
				  i_mem_rd_ack,
				  //	write
				  o_mem_wr_req,
				  o_mem_wr_addr,
				  i_mem_wr_addr_ack,
				  o_mem_wr_data,
				  i_mem_wr_ack,
				  // output interface to scheduling
				  o_mem_type,
				  o_mem_issue,
				  o_mem_busy,
				  o_b_busy,
				  o_t_busy);
				  
//system signals
input wire clk;                     //system clock
input wire rst;
input wire i_mode_bdm;					// Bidirectional Memory Mode
input wire [15:0] i_cip;            //current instruction parcel
input wire        i_cip_vld;
input wire [15:0] i_lip;            //lower instruction parcel
input wire        i_lip_vld;
input wire [6:0]  i_vector_length; 
input wire        i_vstart;
 
input wire [`ADDRBITS-1:0]       i_data_base_addr;
input wire [`ADDRBITS-1:0]       i_data_limit_addr;
 
//interface to registers
input wire [`ADDRBITS-1:0] i_a0_data;
input wire [`ADDRBITS-1:0] i_ai_data;
input wire [`ADDRBITS-1:0] i_ak_data;
input wire [`ADDRBITS-1:0] i_ah_data;
input wire [7:0]  i_a_res_mask;
 
input wire [`DATABITS-1:0] i_si_data;
input wire [7:0]  i_s_res_mask;

input wire [`DATABITS-1:0] i_v0_data;
input wire [`DATABITS-1:0] i_v1_data;
input wire [`DATABITS-1:0] i_v2_data;
input wire [`DATABITS-1:0] i_v3_data;
input wire [`DATABITS-1:0] i_v4_data;
input wire [`DATABITS-1:0] i_v5_data;
input wire [`DATABITS-1:0] i_v6_data;
input wire [`DATABITS-1:0] i_v7_data;
output wire o_v_ack;

output wire [5:0] o_b_rd_addr;
input wire  [`ADDRBITS-1:0] i_b_rd_data;
output reg  [5:0] o_b_wr_addr;
output reg  o_b_wr_en;
 
output reg  [5:0] o_t_rd_addr;
input  wire [`DATABITS-1:0]i_t_rd_data;
output reg  [5:0] o_t_wr_addr;
output reg  o_t_wr_en;

output reg  [`DATABITS-1:0] o_mem_data;        //data output to registers

//interface to memory
output wire o_mem_rd_req;
output wire [`ADDRBITS-3:0] o_mem_rd_addr;
input  wire i_mem_rd_addr_ack;
input  wire i_mem_rd_ack;
input  wire [`DATABITS-1:0] i_mem_rd_data;
output wire o_mem_wr_req;
output wire [`ADDRBITS-3:0] o_mem_wr_addr;
input  wire i_mem_wr_addr_ack;
output reg  [`DATABITS-1:0] o_mem_wr_data;
input  wire i_mem_wr_ack;
 
//instruction issue
output wire       o_mem_type;
output wire       o_mem_issue;
output wire       o_mem_busy;
output reg			o_b_busy;
output reg			o_t_busy;
wire  b_rd_en;
wire  t_rd_en;


wire [`ADDRBITS-3:0] ah_jkm;
wire v_type;
wire v_vld;
wire b_t_type;
wire b_t_vld;
wire a_s_type;
wire a_s_vld;
wire mem_vld;
reg  mem_ack_r;

reg  [1:0]  activity;
reg  [1:0]	b_activity;
reg  [1:0]	t_activity;

reg  [`ADDRBITS-3:0] mem_read_address;     //the memory address to read from
reg  [`ADDRBITS-3:0] mem_write_address;     //the memory address to write to
reg  [`ADDRBITS-3:0] start_write_addr;
reg  [`ADDRBITS-3:0] start_read_addr;
reg  [`ADDRBITS-3:0] read_stride;          //the amount to increment the address by
reg  [`ADDRBITS-3:0] write_stride;          //the amount to increment the address by
reg  [`ADDRBITS-3:0] start_read_stride;
reg  [`ADDRBITS-3:0] start_write_stride;
reg  [7:0]  count;           //the number of elements we should read/write
reg  [6:0]  start_count;
reg  [3:0]  source;
reg  [3:0]  start_source;
reg  [6:0]  remaining_write_count;
reg  [6:0]  remaining_read_count;
reg         reg_conflict;
wire        conflict;
reg mem_read;
reg mem_write;
 
reg  [3:0] write_delay;
reg  [3:0] start_write_delay;
 
wire read_complete;
wire write_complete;
 
reg [63:0] data_buf [63:0];
 
reg [`ADDRBITS-1:0] data_rd_base_addr;
reg [`ADDRBITS-1:0] data_rd_limit_addr;
 
reg [`ADDRBITS-1:0] data_wr_base_addr;
reg [`ADDRBITS-1:0] data_wr_limit_addr;
 
reg [`ADDRBITS-3:0] v_addr;
reg [`ADDRBITS-3:0] b_t_addr;
reg [5:0] b_rd_addr;

 
localparam V0   = 4'b0000,
           V1   = 4'b0001,
			  V2   = 4'b0010,
			  V3   = 4'b0011,
			  V4   = 4'b0100,
			  V5   = 4'b0101,
			  V6   = 4'b0110,
			  V7   = 4'b0111,
           B_RF = 4'b1000,
           T_RF = 4'b1001,
			  AI   = 4'b1010,
			  SI   = 4'b1011,
			  NONE = 4'b1100;
 
 
//Let's figure out what address we're supposed to read from
// - there are 3 possible sources - the b/t type (starting at A0, increment by 1)
//                                - the a/s type (read from Ah + jkm)
//                                - the v type   (start at A0, increment by Ak) 
 
always@(posedge clk)
   mem_ack_r <= i_mem_rd_ack;
 
assign o_mem_rd_addr = mem_read_address + data_rd_base_addr[`ADDRBITS-3:0];
assign o_mem_wr_addr = mem_write_address + data_wr_base_addr[`ADDRBITS-3:0];
 
always@(posedge clk)
//	if(&activity & o_mem_type)			// ZS 1/3/15, 6:32, Preserve the base and limit for the duration of the transfer
								// so that memory transfers can go in parallel with the exchanged programme
   	begin
			if (mem_read)
				begin
					data_rd_base_addr <= i_data_base_addr;
					data_rd_limit_addr <= i_data_limit_addr;
				end
			if (mem_write)
				begin
					data_wr_base_addr <= i_data_base_addr;
					data_wr_limit_addr <= i_data_limit_addr;
				end
		end

//
// From memory to functional units
//
always @(posedge clk)
	o_mem_data <= i_mem_rd_data;


// Conflict?
 // Bidirectional or unidirectional memory
 // Register conflict
assign conflict = reg_conflict | (i_mode_bdm ? (activity[WR] & mem_write) | (activity[RD] & mem_read) : |activity & (mem_read | mem_write));

//Figure out what type, if any, of memory access it is
assign b_t_type=(i_cip[15:11]==5'b00111);    //034-037 - 1 parcel
assign b_t_vld = b_t_type && i_cip_vld && !conflict;
 
assign a_s_type=(i_cip[15:14]==2'b10);       //100-137 - 2 parcels
assign a_s_vld = a_s_type && i_cip_vld && i_lip_vld && !conflict;
 
assign v_type  =(i_cip[15:10]==6'b111111); //176-177 - 1 parcel
assign v_vld   = v_type && (vstart || i_vstart) && !conflict;

// BEWARE, NEW:
// ZS 14/5/14 18:00, 19/5/15 3:17
reg vstart;
always @ (posedge clk)
	if (rst)
		vstart <= 0;
	else
		if (i_vstart)
			vstart <= 1;
		else
			if (vstart & ((activity[RD] & i_mem_rd_ack) | (activity[WR] & i_mem_wr_addr_ack))) // Wait for memory ack
				vstart <= 0;

assign o_v_ack = (i_mem_rd_ack | i_mem_wr_addr_ack);   // ???? !!!! ????

assign mem_vld = b_t_vld || a_s_vld || v_vld;
 
//OR them all so we know it's a mem access
assign o_mem_type = b_t_type || a_s_type || v_type;
 
//finally calculate the write delay

// ZS 16/2/15, 14:09
//		Optimising manually common subexpression
//
assign ah_jkm = i_ah_data[`ADDRBITS-3:0] + {i_cip[5:0],i_lip[15:0]};

//Let's do some decoding
always@*
   casez(i_cip[15:9])
	   7'b0011100:begin               	//034 - Move (Ai) words from mem, starting at A0, to B RF, starting at JK
						  mem_read = 1;
						  mem_write = 0;        
						  start_read_addr = i_a0_data[`ADDRBITS-3:0];
						  start_read_stride = 1;
                    start_write_addr = 0;
                    start_write_stride = 0;
						  start_count = i_ai_data[6:0];
						  start_source = NONE;
						  reg_conflict = i_a_res_mask[0] || i_a_res_mask[i_cip[8:6]];  //check for a conflict with Ai or A0
						  start_write_delay = 0; // To be calculated if necessary
					   end 
		7'b0011101:begin               	//035 - Move (Ai) words from B RF, starting at JK, to mem starting at A0
						  mem_read = 0;
						  mem_write = 1;        
                    start_write_addr = i_a0_data[`ADDRBITS-3:0];
                    start_write_stride = 1;
						  start_read_addr = 0;
					     start_read_stride = 0;
                    start_count = i_ai_data[6:0];
						  start_source = B_RF;
						  reg_conflict = i_a_res_mask[0] || i_a_res_mask[i_cip[8:6]];  //check for a conflict with Ai or A0
						  start_write_delay = `BREG_READ_TIME; //4'd3; // To be recalculated if necessary
                 end						  
		7'b0011110:begin               	//036 - Move (Ai) words from mem, starting at A0, to T RF, starting at JK
						  mem_read = 1;
						  mem_write = 0;        
						  start_read_addr = i_a0_data[`ADDRBITS-3:0];
						  start_read_stride = 1;
					     start_write_addr = 0;
					     start_write_stride = 0;
                    start_count = i_ai_data[6:0];
						  start_source = NONE;
						  reg_conflict = i_a_res_mask[0] || i_a_res_mask[i_cip[8:6]];  //check for a conflict with Ai or A0
						  start_write_delay = `BREG_WRITE_TIME; // To be calculated if necessary
					   end 
		7'b0011111:begin               	//037 - Move (Ai) words from T RF, starting at JK, to mem starting at A0
						  mem_read = 0;
						  mem_write = 1;        
                    start_write_addr = i_a0_data[`ADDRBITS-3:0];
                    start_write_stride = 1;
						  start_read_addr = 0;
					     start_read_stride = 0;
                    start_count = i_ai_data[6:0];
						  start_source = T_RF;
						  reg_conflict = i_a_res_mask[0] || i_a_res_mask[i_cip[8:6]];  //check for a conflict with Ai or A0
						  start_write_delay = `TREG_READ_TIME; // To be recalculated if necessary
                 end						
		7'b1000???:begin					 	//10hijkm - Read from (Ah + jkm) to Ai
						  mem_read = 1;
						  mem_write = 0;        
                    start_read_addr = ah_jkm;
						  start_read_stride = 0;
					     start_write_addr = 0;
					     start_write_stride = 0;
						  start_count = 1;
						  start_source = NONE;
						  //We have an issue where we need to make sure we don't step on the toes of an in-flight write
						  //For now, be excessively cautious and don't issue if the registers are in-use
						  reg_conflict = |{i_a_res_mask};
						  //reg_conflict = i_a_res_mask[i_cip[8:6]] || i_a_res_mask[i_cip[11:9]];
						  start_write_delay = `TREG_WRITE_TIME; // To be calculated if necessary
                 end
		7'b1001???:begin        			//11hijkm - Store (Ai) to (Ah + jkm)
						  mem_read = 0;
						  mem_write = 1;        
                    start_write_addr = ah_jkm;
						  start_write_stride = 0;
						  start_read_addr = 0;
					     start_read_stride = 0;
						  start_count = 1;
						  start_source = AI;
						  reg_conflict = i_a_res_mask[i_cip[8:6]] || i_a_res_mask[i_cip[11:9]];
						  start_write_delay = 0; // To be recalculated if necessary
                 end
		7'b1010???:begin        			//12hijkm - Read from (Ah + jkm) to Si
						  mem_read = 1;
						  mem_write = 0;        
                    start_read_addr = ah_jkm;
						  start_read_stride = 0;
					     start_write_addr = 0;
					     start_write_stride = 0;
						  start_count = 1;
						  start_source = NONE;
						  //We have an issue where we need to make sure we don't step on the toes of an in-flight write
						  //For now, be excessively cautious and don't issue if the registers are in-use
						  reg_conflict = |{i_a_res_mask,i_s_res_mask};
						  //reg_conflict = i_a_res_mask[i_cip[11:9]] || i_s_res_mask[i_cip[8:6]];
						  start_write_delay = 0; // To be calculated if necessary
                 end
		7'b1011???:begin        			//13hijkm - Store (Si) to (Ah + jkm)
						  mem_read = 0;
						  mem_write = 1;        
                    start_write_addr = ah_jkm;
						  start_write_stride = 0;
						  start_read_addr = 0;
					     start_read_stride = 0;
						  start_count = 1;
						  start_source = SI;
						  reg_conflict =  i_a_res_mask[i_cip[11:9]] || i_s_res_mask[i_cip[8:6]];
						  start_write_delay = 0; // To be recalculated if necessary
                 end
		7'b1111110:begin        			//176 - Read VL elements from memory to Vi, starting at A0, stride Ak
						  mem_read = 1;
						  mem_write = 0;        
						  start_read_addr = i_a0_data[`ADDRBITS-3:0];
						  start_read_stride = i_ak_data[`ADDRBITS-3:0];
					     start_write_addr = 0;
					     start_write_stride = 0;
						  start_count  = i_vector_length;
						  start_source = NONE;
						  reg_conflict = i_a_res_mask[0] || i_a_res_mask[i_cip[2:0]]; // We're waiting on A0 and Ak	// ZS k is 3 bit, not 4
						  start_write_delay = `V_REG_WRITE_TIME; // To be calculated if necessary
					  end
		7'b1111111:begin        			//177 - Write VL elements into memory from Vj, starting at A0, stride Ak
						  mem_read = 0;
						  mem_write = 1;        
						  start_write_addr = i_a0_data[`ADDRBITS-3:0];
						  start_write_stride = i_ak_data[`ADDRBITS-3:0];
						  start_read_addr = 0;
					     start_read_stride = 0;
						  start_count = i_vector_length;
						  start_source = {1'b0,i_cip[5:3]};  //encode the Vj register as the source
						  reg_conflict = i_a_res_mask[0] || i_a_res_mask[i_cip[2:0]]; // We're waiting on A0 and Ak
						  start_write_delay = `V_REG_READ_TIME;
					  end
		default:
					  begin
						  mem_read = 0;
						  mem_write = 0;        
						  reg_conflict = 0;
					     start_write_addr = 0;
					     start_write_stride = 0;
						  start_read_addr = 0;
					     start_read_stride = 0;
					     start_count = 0;
					     start_source = NONE;
					     start_write_delay = 0;
				  end
	endcase

 
////////////////////////
// The activity machine
////////////////////////

localparam IDLE = 2'b00,
           READ = 2'b01,
			  WRITE= 2'b10,
			  BOTH = 2'b11;
			  
localparam	RD	= 0,
				WR = 1;
//
// Beware of the bit logic used in the remainder of the text,
// using the abovementioned states as independent R and W
//
// ZS 23/2/15, 3:46
// We shall preserve the cip for the duration of B or T transfers

always@(posedge clk)
   if(rst)
		begin
			activity <= IDLE;
			b_activity <= IDLE;
			t_activity <= IDLE;
		end
	else
		begin
			if(mem_vld)
				begin
					if (mem_read)
						begin
							activity[RD] <= 1;
							b_activity[WR] <= b_t_type & ~i_cip[10];
							t_activity[WR] <= b_t_type & i_cip[10];
						end
					if (mem_write)
						begin
							activity[WR] <= 1;
							b_activity[RD] <= b_t_type & ~i_cip[10];
							t_activity[RD] <= b_t_type & i_cip[10];
						end
				end
			if(read_complete)
				begin
					activity[RD] <= 0;
					b_activity[WR] <= 0;
					t_activity[WR] <= 0;
				end
			if(write_complete)
				activity[WR] <= 0;
			if (remaining_write_count == 1)
				begin
					b_activity[RD] <= 0;
					t_activity[RD] <= 0;
				end
		end
		

////////////////////
//
// WRITE
//
////////////////////

//Let's wait the appropriate amount of time if it's a write from a vector register
always@(posedge clk)
   if(rst)
	   write_delay <= 4'b0;
	else if(~activity[WR] && mem_vld)
		write_delay <= start_write_delay;
	else if(write_delay != 4'b0)
	   write_delay <= write_delay - 1;	

//figure out how many elements we still need to write
always@(posedge clk)
   if(rst)
	   remaining_write_count <= 7'b0;
	else if(~activity[WR] & o_mem_type && mem_vld)
	   remaining_write_count <= start_count;
	else if(activity[WR] & (write_delay==3'b0))
	   remaining_write_count <= remaining_write_count - 1; // We have Burst (Vector) memory, so we just send the data there

always@(posedge clk)
   if(rst)
	   write_stride <= 0;
	else if(~activity[WR] & o_mem_type && mem_vld)
	   write_stride <= start_write_stride;


// Calculate the memory address we use, and stride through,
// but first wait on the write_delay (the amount of time the
// FU will need to give data for memory)

always@(posedge clk)
   if(rst)
			mem_write_address <= `ADDRBITS-2'b0;
	else 
		if(~activity[WR] & o_mem_type)
			mem_write_address <= start_write_addr;
		else
			if (activity[WR] && (write_delay == 0))
				mem_write_address <= mem_write_address + write_stride;
 
 
//and choose the source to write from
// First remember the source for the duration of the operation
reg [`ADDRBITS-1:0] ai_data;
reg [`DATABITS-1:0] si_data;

always@(posedge clk)
   if(rst)
	   source <= NONE;
 	else
		if (o_mem_issue & ~activity[WR])
			begin
				source <= start_source;
				ai_data <= i_ai_data;
				si_data <= i_si_data;
			end

// register the data
always@(posedge clk)
			case ((o_mem_issue & ~activity[WR]) ? start_source : source)
				V0:  o_mem_wr_data <= i_v0_data;   
				V1:  o_mem_wr_data <= i_v1_data;
				V2:  o_mem_wr_data <= i_v2_data;   
				V3:  o_mem_wr_data <= i_v3_data;   
				V4:  o_mem_wr_data <= i_v4_data;   
				V5:  o_mem_wr_data <= i_v5_data;   
				V6:  o_mem_wr_data <= i_v6_data;   
				V7:  o_mem_wr_data <= i_v7_data;   
				B_RF:o_mem_wr_data <= {`DATABITS'b0,i_b_rd_data};   
				T_RF:o_mem_wr_data <= i_t_rd_data;   
				AI:  o_mem_wr_data <= (o_mem_issue) ? {`DATABITS'b0, i_ai_data} : {`DATABITS'b0, ai_data};   
				SI:  o_mem_wr_data <= (o_mem_issue) ? i_si_data : si_data; 
				default: o_mem_wr_data <= `DATABITS'b0;
			endcase


//calculate the index into the B/T rf that we use
always@(posedge clk)
   if(rst)
	   begin
	      b_rd_addr <= 0;
		   o_t_rd_addr <= 0;
		end
	else 
		if (~i_mem_wr_addr_ack & o_mem_type & b_t_type & i_cip_vld & ~o_mem_issue)
			begin
				b_rd_addr <= i_cip[5:0];
				o_t_rd_addr <= i_cip[5:0];
			end
		else
			if (o_mem_issue | activity[WR])
				begin
					b_rd_addr <= b_rd_addr + 1;
					o_t_rd_addr <= o_t_rd_addr + 1;
				end

assign b_rd_en = b_activity[RD];
assign t_rd_en = t_activity[RD];
 
//Let's perform a memory write!
assign o_mem_wr_req = (activity[WR] && (remaining_write_count != 0));

assign write_complete = (activity[WR]) && (remaining_write_count == 0);


////////////////////
//
// READ
//
////////////////////

//figure out how many elements we still need to read
always@(posedge clk)
   if(rst)
	   remaining_read_count <= 7'b0;
	else if(~activity[RD] & o_mem_type && mem_vld)
	   remaining_read_count <= start_count;
	else if(activity[0])
	   remaining_read_count <= remaining_read_count - i_mem_rd_addr_ack;
 
always@(posedge clk)
   if(rst)
	   read_stride <= 0;
	else if(~activity[RD] & o_mem_type & mem_vld)
	   read_stride <= start_read_stride;

always@(posedge clk)
   if(rst)
		begin
			mem_read_address <= 22'b0;
		end
	else 
		if(~activity[RD] & o_mem_type)
			begin
				mem_read_address <= start_read_addr;
			end
		else
			begin
				if (activity[RD] & i_mem_rd_addr_ack)
					mem_read_address <= mem_read_address + read_stride;
			end

 
always@(posedge clk)
   if(rst)
	   begin
	      o_b_wr_addr <= 0;
         o_t_wr_addr <= 0;
		end
		//Grab the starting address when we begin the operation
	else if (~activity[RD] & o_mem_type & mem_vld)
      begin
	      o_b_wr_addr <= i_cip[5:0];
         o_t_wr_addr <= i_cip[5:0];
		end
		//Increment the address every time we write a value to a reg
	else if (activity[RD])
      begin
	      o_b_wr_addr <= o_b_wr_addr + mem_ack_r;
		   o_t_wr_addr <= o_t_wr_addr + mem_ack_r;
		end

 
//or write to some registers

// Wait for the cycle at the end of transfer, when read is already complete, but the B/T registers write is not yet.
always @(posedge clk)
	if (rst)
		begin
			o_b_wr_en <= 0;
			o_t_wr_en <= 0;
		end
	else
			begin
				o_b_wr_en <= b_activity[WR] & i_mem_rd_ack;
				o_t_wr_en <= t_activity[WR] & i_mem_rd_ack;
			end


assign o_b_rd_addr = (b_activity[RD] & ~(remaining_write_count == 1)) ? b_rd_addr : i_cip[5:0]; 

assign o_mem_rd_req = activity[RD];

assign read_complete = (activity[RD]) && (remaining_read_count == 7'b0) & i_mem_rd_ack; // Please check if necessary the rd_ack regarding memory cycling


//finally, 'issue' the instruction when we're done
// i_cip bit decoding (!)

wire same_dir = i_cip[9] ? activity[WR] : activity[RD];

wire a_s_busy = (i_cip[15:14] == 2'b10) & |activity; // To ensure sequential operation, all Memory ports must be free for A and S to MEM
wire v_busy = v_type & same_dir;
wire b_busy = b_t_type & ~i_cip[10] & same_dir;
wire t_busy = b_t_type & i_cip[10] & same_dir;

assign o_mem_busy = (i_mode_bdm ? &activity : |activity) | b_busy | t_busy | v_busy | a_s_busy;
assign o_mem_issue = ~o_mem_busy & ~conflict & o_mem_type;

always @(posedge clk)
	begin
		o_b_busy <= |b_activity;
		o_t_busy <= |t_activity;
	end


endmodule
