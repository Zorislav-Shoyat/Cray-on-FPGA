//////////////////////////////////////////////////////////////////
//        Cray Instruction Buffer                               //
//        Author: Christopher Fenton                            //
//        Date:  8/8/23                                         //
//////////////////////////////////////////////////////////////////
//
//This is the block of instruction buffers. Each of the four 
//buffers can hold 64 16-bit parcels. Instruction buffers load
//64-bit words from memory

//
// no changes: r257 by christopher.h.fenton on Jan 7, 2015
//  (tmp_addr not used)
//

//
// ZS 15/2/15 17:52
//
// mem_addr_ack !!!
//
///////////////////////////
//
// Zorislav Shoyat, 9/3/2015, 14:57
//
// Added "Cray-2" type 8 32 word buffers
//



// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"


module i_buf(clk, rst, i_clear_ibuf, i_p_addr, o_nip_nxt, o_word_nxt, o_nip_vld, o_mem_read, o_mem_addr, i_mem_addr_ack, i_mem_data, i_mem_rd_ack);

input  wire clk;
input  wire rst;
input  wire i_clear_ibuf;
input  wire [23:0] i_p_addr;
output reg [15:0]  o_nip_nxt;
output reg [63:0]  o_word_nxt;
output wire        o_nip_vld;
//64-bit wide memory interface
output wire        o_mem_read;
output wire [21:0] o_mem_addr;
input  wire			 i_mem_addr_ack;
input  wire [63:0] i_mem_data;
input  wire        i_mem_rd_ack;


reg [17:0] buf_delay;
reg [17:0] cur_buf;
//instruction buffers
reg [63:0] buf0 [15:0];
reg [63:0] buf1 [15:0];
reg [63:0] buf2 [15:0];
reg [63:0] buf3 [15:0];
reg [63:0] buf4 [15:0];
reg [63:0] buf5 [15:0];
reg [63:0] buf6 [15:0];
reg [63:0] buf7 [15:0];

wire [63:0] cur_buf0_word, cur_buf1_word, cur_buf2_word, cur_buf3_word;
wire [63:0] cur_buf4_word, cur_buf5_word, cur_buf6_word, cur_buf7_word;

//beginning address registers
reg [17:0] beg_addr0, beg_addr1, beg_addr2, beg_addr3;
reg [17:0] beg_addr4, beg_addr5, beg_addr6, beg_addr7;

//Buffers get replaced with an LRU policy based on the 2-bit buffer counter
reg [2:0] buf_cnt;
reg [4:0] mem_cnt;
reg [4:0] addr_cnt;

reg buf_state;      //state register

reg clear_ibuf;

wire buf0_match, buf1_match, buf2_match, buf3_match;
wire buf4_match, buf5_match, buf6_match, buf7_match;
wire no_match;
wire load_complete;

reg [5:0]  buffered_addr;

localparam IDLE = 1'b0,
           RX   = 1'b1;
localparam BUF_FULL = 4'b1111;

// ZS 9/3/2015, 5:17
// Buffer Access Counters
//reg buf0_act, buf1_act, buf2_act, buf3_act;


//This bit is kind of weird. There is a 2-cycle delay for some reason
//when the selected buffer changes. The incoming address is the address
//being sent out on the "nip_nxt" port, though, so I'm just implementing
//this by delaying the 'buffer address' lines by  2 cycles, and then
//ANDing (i_buf_addr==cur_buf_addr) with the o_nip_vld signal to get the 
//expected behavior
always@(posedge clk)
   begin
//	   buf_delay <= i_p_addr[23:6];
//		cur_buf   <= buf_delay;
		cur_buf   <= i_p_addr[23:6];
		buffered_addr <= i_p_addr[5:0];
	end
	
always @(posedge clk)
	begin
		if (clear_ibuf)
			clear_ibuf <= 0;
		else
			if (i_clear_ibuf)
				clear_ibuf <= 1;
	end

//Enable memory if we're trying to fill a buffer, and provide the correct address
assign o_mem_read = (buf_state == RX) ; //& !load_complete;

//tell the main block if the next instruction parcel is valid or not
//always@(posedge clk)
wire buffer_match = (buf0_match || buf1_match || buf2_match || buf3_match) | (buf4_match || buf5_match || buf6_match || buf7_match);
assign   o_nip_vld = buffer_match && (cur_buf==i_p_addr[23:6]);

//Let's check if the incoming address matches any beginning addresses
assign buf0_match = (cur_buf == beg_addr0);
assign buf1_match = (cur_buf == beg_addr1);
assign buf2_match = (cur_buf == beg_addr2);
assign buf3_match = (cur_buf == beg_addr3);
assign buf4_match = (cur_buf == beg_addr4);
assign buf5_match = (cur_buf == beg_addr5);
assign buf6_match = (cur_buf == beg_addr6);
assign buf7_match = (cur_buf == beg_addr7);

assign no_match = ~buffer_match;


//increment the memory counter whenever we're in RX state and the data is valid

//We want to pull in the 16-word cache-line associated with our address
`ifdef SINGLE_CYCLE_MEMORY
	wire [3:0] addr_cnt_plus_one = (addr_cnt[3:0] + 4'b1);	/* The +1 is there as the address has to be one in advance of the buffer addr */
	assign o_mem_addr = {i_p_addr[23:6],4'b0} + addr_cnt_plus_one;	
`else
	assign o_mem_addr = {i_p_addr[23:6],4'b0} + addr_cnt;	
`endif

// The address counter increments always when i_mem_rd_ack

always@(posedge clk)
   if(rst)
		`ifdef SINGLE_CYCLE_MEMORY
			addr_cnt <= 5'b11111; // That is: -1, for single cycle memory only
		`else
			addr_cnt <= 5'b0; // For multi cycle memory and memory which may not be ready...
		`endif
   else
		if (buf_state == RX)
			begin
				if (addr_cnt != BUF_FULL + 1)
					addr_cnt <= addr_cnt + i_mem_addr_ack;
			end
		else
			if (addr_cnt == BUF_FULL + 1)
				`ifdef SINGLE_CYCLE_MEMORY
					addr_cnt <= 5'b11111; // That is: -1, for single cycle memory only
				`else
					addr_cnt <= 5'b0; // For multi cycle memory and memory which may not be ready...
				`endif

// As we want to pipe the data as soon the memory latency is over, each time the memory request is done
// and the memory acknowledge is not given, we have to count the number of cycles, as to postpone
// the saving into the instruction buffer(s).
// The same algorithm has to be implemented also for MEMORY_FU
/*
wire mem_available;	// We may increment the counters


reg [7:0] mem_delay;	// Maximum alowable memory delay is 253 cycles. Shall be over than enough!

always @(posedge clk)
	if (~o_mem_read)
		mem_delay <= 8'b11111110;	// That is: - 2
	else
		if (~i_mem_rd_ack)
			mem_delay <= mem_delay + 8'd1;
		else
			if (mem_delay != 8'd0)
				mem_delay <= mem_delay - 8'd1;

assign mem_available = (mem_delay == 8'd0) & o_mem_read & i_mem_rd_ack;
*/

//assign mem_available = i_mem_rd_ack;

//	The version with -1 is valid if we have a single cycle memory, i.e. if the rd_ack comes in the same clock cycle.
//	Otherwise we have to start counting from 0, and the memory latency is one more, but it is easier to
//	manage memory not available delays.

	
always@(posedge clk)
   if(rst)
		`ifdef SINGLE_CYCLE_MEMORY
			mem_cnt <= 5'b11111; // That is: -1, for single cycle memory only
		`else
			mem_cnt <= 5'b0; // For multi cycle memory and memory which may not be ready...
		`endif
   else
		if(buf_state==RX)
			mem_cnt <= mem_cnt + i_mem_rd_ack;
		else
			if (mem_cnt == BUF_FULL + 1)
				`ifdef SINGLE_CYCLE_MEMORY
					mem_cnt <= 5'b11111; // That is: -1, for single cycle memory only
				`else
					mem_cnt <= 5'b0; // For multi cycle memory and memory which may not be ready...
				`endif


//Fill in the correct buffer as we're loading from memory
always@(posedge clk)
	if (~mem_cnt[4] && (buf_state == RX))
		case (buf_cnt)
			3'b000:	buf0[mem_cnt[3:0]] <= i_mem_data;
			3'b001:	buf1[mem_cnt[3:0]] <= i_mem_data;
			3'b010:	buf2[mem_cnt[3:0]] <= i_mem_data;
			3'b011:	buf3[mem_cnt[3:0]] <= i_mem_data;
			3'b100:	buf4[mem_cnt[3:0]] <= i_mem_data;
			3'b101:	buf5[mem_cnt[3:0]] <= i_mem_data;
			3'b110:	buf6[mem_cnt[3:0]] <= i_mem_data;
			3'b111:	buf7[mem_cnt[3:0]] <= i_mem_data;
		endcase

//detect when we're done loading
assign load_complete = i_mem_rd_ack & (mem_cnt==BUF_FULL);

//load the 'beginning address' registers of each buffer when we finish a load
always@(posedge clk)
   if(rst | (clear_ibuf)) // & buf0_match))
      beg_addr0 <= 18'b111111111111111111;
   else if((buf_cnt == 3'b000) && load_complete)
      beg_addr0 <= i_p_addr[23:6];

always@(posedge clk)
   if(rst | (clear_ibuf)) // & buf1_match))
      beg_addr1 <= 18'b111111111111111111;
   else if((buf_cnt == 3'b001) && load_complete)
      beg_addr1 <= i_p_addr[23:6];

always@(posedge clk)
   if(rst | (clear_ibuf)) // & buf2_match))
      beg_addr2 <= 18'b111111111111111111;
   else if((buf_cnt == 3'b010) && load_complete)
      beg_addr2 <= i_p_addr[23:6];

always@(posedge clk)
   if(rst | (clear_ibuf)) // & buf3_match))
      beg_addr3 <= 18'b111111111111111111;
   else if((buf_cnt == 3'b011) && load_complete)
      beg_addr3 <= i_p_addr[23:6];

always@(posedge clk)
   if(rst | (clear_ibuf)) // & buf4_match))
      beg_addr4 <= 18'b111111111111111111;
   else if((buf_cnt == 3'b100) && load_complete)
      beg_addr4 <= i_p_addr[23:6];

always@(posedge clk)
   if(rst | (clear_ibuf)) // & buf5_match))
      beg_addr5 <= 18'b111111111111111111;
   else if((buf_cnt == 3'b101) && load_complete)
      beg_addr5 <= i_p_addr[23:6];

always@(posedge clk)
   if(rst | (clear_ibuf)) // & buf6_match))
      beg_addr6 <= 18'b111111111111111111;
   else if((buf_cnt == 3'b110) && load_complete)
      beg_addr6 <= i_p_addr[23:6];

always@(posedge clk)
   if(rst | (clear_ibuf)) // & buf7_match))
      beg_addr7 <= 18'b111111111111111111;
   else if((buf_cnt == 3'b111) && load_complete)
      beg_addr7 <= i_p_addr[23:6];



//Now that the load is finished, increment the buffer counter every time we fill a buffer
always@(posedge clk)
   if(rst)
      buf_cnt <= 3'b000;
	else if (i_clear_ibuf | !load_complete)
	begin
		if (beg_addr0 == 18'b111111111111111111)
			buf_cnt <= 3'b000;
		else if (beg_addr1 == 18'b111111111111111111)
			buf_cnt <= 3'b001;
		else if (beg_addr2 == 18'b111111111111111111)
			buf_cnt <= 3'b010;
		else if (beg_addr3 == 18'b111111111111111111)
			buf_cnt <= 3'b011;
		else if (beg_addr4 == 18'b111111111111111111)
			buf_cnt <= 3'b100;
		else if (beg_addr5 == 18'b111111111111111111)
			buf_cnt <= 3'b101;
		else if (beg_addr6 == 18'b111111111111111111)
			buf_cnt <= 3'b110;
		else if (beg_addr7 == 18'b111111111111111111)
			buf_cnt <= 3'b111;
	end
   else if (load_complete)
		buf_cnt <= buf_cnt + 3'b1;

		
		
//now lets select some data
assign cur_buf0_word = buf0[i_p_addr[5:2]];
assign cur_buf1_word = buf1[i_p_addr[5:2]];
assign cur_buf2_word = buf2[i_p_addr[5:2]];
assign cur_buf3_word = buf3[i_p_addr[5:2]];
assign cur_buf4_word = buf4[i_p_addr[5:2]];
assign cur_buf5_word = buf5[i_p_addr[5:2]];
assign cur_buf6_word = buf6[i_p_addr[5:2]];
assign cur_buf7_word = buf7[i_p_addr[5:2]];


//select the correct 16-bit parcel out of the current 64-bit word
always@*
begin
   case({buf0_match, buf1_match, buf2_match, buf3_match, buf4_match, buf5_match, buf6_match, buf7_match})
      8'b10000000:case(i_p_addr[1:0])
                 2'b11:o_nip_nxt=cur_buf0_word[15:0];
                 2'b10:o_nip_nxt=cur_buf0_word[31:16];
                 2'b01:o_nip_nxt=cur_buf0_word[47:32];
                 2'b00:o_nip_nxt=cur_buf0_word[63:48];
              endcase

      8'b01000000:case(i_p_addr[1:0])
                 2'b11:o_nip_nxt=cur_buf1_word[15:0];
                 2'b10:o_nip_nxt=cur_buf1_word[31:16];
                 2'b01:o_nip_nxt=cur_buf1_word[47:32];
                 2'b00:o_nip_nxt=cur_buf1_word[63:48];
              endcase

      8'b00100000:case(i_p_addr[1:0])
                 2'b11:o_nip_nxt=cur_buf2_word[15:0];
                 2'b10:o_nip_nxt=cur_buf2_word[31:16];
                 2'b01:o_nip_nxt=cur_buf2_word[47:32];
                 2'b00:o_nip_nxt=cur_buf2_word[63:48];
              endcase

      8'b00010000:case(i_p_addr[1:0])
                 2'b11:o_nip_nxt=cur_buf3_word[15:0];
                 2'b10:o_nip_nxt=cur_buf3_word[31:16];
                 2'b01:o_nip_nxt=cur_buf3_word[47:32];
                 2'b00:o_nip_nxt=cur_buf3_word[63:48];
               endcase

      8'b00001000:case(i_p_addr[1:0])
                 2'b11:o_nip_nxt=cur_buf4_word[15:0];
                 2'b10:o_nip_nxt=cur_buf4_word[31:16];
                 2'b01:o_nip_nxt=cur_buf4_word[47:32];
                 2'b00:o_nip_nxt=cur_buf4_word[63:48];
              endcase

      8'b00000100:case(i_p_addr[1:0])
                 2'b11:o_nip_nxt=cur_buf5_word[15:0];
                 2'b10:o_nip_nxt=cur_buf5_word[31:16];
                 2'b01:o_nip_nxt=cur_buf5_word[47:32];
                 2'b00:o_nip_nxt=cur_buf5_word[63:48];
              endcase

      8'b00000010:case(i_p_addr[1:0])
                 2'b11:o_nip_nxt=cur_buf6_word[15:0];
                 2'b10:o_nip_nxt=cur_buf6_word[31:16];
                 2'b01:o_nip_nxt=cur_buf6_word[47:32];
                 2'b00:o_nip_nxt=cur_buf6_word[63:48];
              endcase

      8'b00000001:case(i_p_addr[1:0])
                 2'b11:o_nip_nxt=cur_buf7_word[15:0];
                 2'b10:o_nip_nxt=cur_buf7_word[31:16];
                 2'b01:o_nip_nxt=cur_buf7_word[47:32];
                 2'b00:o_nip_nxt=cur_buf7_word[63:48];
              endcase

      default: o_nip_nxt = 16'b0;
   endcase
end

//and we need to output the whole current 64-bit word (for exchange packages)
always@(posedge clk)
begin
   case({buf0_match, buf1_match, buf2_match, buf3_match, buf4_match, buf5_match, buf6_match, buf7_match})
      8'b10000000:o_word_nxt <= cur_buf0_word;
      8'b01000000:o_word_nxt <= cur_buf1_word;
      8'b00100000:o_word_nxt <= cur_buf2_word;         
      8'b00010000:o_word_nxt <= cur_buf3_word;
      8'b00001000:o_word_nxt <= cur_buf4_word;
      8'b00000100:o_word_nxt <= cur_buf5_word;
      8'b00000010:o_word_nxt <= cur_buf6_word;         
      8'b00000001:o_word_nxt <= cur_buf7_word;
      default:o_word_nxt <= 64'b0;
   endcase
end
//State machine to retrieve 128-byte chunks from memory
always@(posedge clk)
if(rst)
   buf_state <= IDLE;
else
   case(buf_state)
      IDLE: if(no_match && !load_complete) 
		         buf_state <= RX;
        RX: if (mem_cnt==BUF_FULL) 
		         buf_state <= IDLE;
   endcase


endmodule
