//////////////////////////////////////////////////////////////////
//        Vector Register File                                  //
//        Author: Christopher Fenton                            //
//        Date:  8/8/23                                         //
//////////////////////////////////////////////////////////////////
//
//This block contains one 64 entry, 64-bit register file used
//for each of the Cray-1A's 8 vector registers

// Adapted to:
// r239 by christopher.h.fenton on May 20, 2014
//

//////////////////////////////////////////////////////////////////
// Zorislav Shoyat, 11/3/2014, 6:45
// & 15/3/2014, 19:25
//
// Implemented the possibility to use memory cores or plain logic
//
//	ZS, 19/2/15 2:20
//
//	As an unespected memory not ready would have for the consequence a
// possible duplication of data through some of the vector related
// functional units, it would be necessary to make a special v_mem_ack[8]
// signal, and check the appropriate one in each V-related FU.
//
// Therefore, as we do not expect other than fast enough and vector
// specific memories (i.e. fast Random Access Memory, or reasonably
// fast Burst Access Memory - e.g. SDRAM, actually Vector Access Memory),
// we implement only the LATENCY wait, that is, any other missing
// v_mem_ack, i.e. memory not ready, must be related to some other
// vector register.
// To do this, we allow only the initial memory-not-ready
//
///////////////////////////////////////////////////////////////////


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


module vec_regfile(clk,
						  rst,
						o_rd_data,
						i_sbus,
						i_v_add,
						i_v_log,
						i_v_shift,
						i_v_poppar,
						i_fp_add,
						i_fp_mult,
						i_fp_ra,
						i_mem,
						i_mem_ack,
                  i_vread_start,
						i_vwrite_start,
						i_swrite_start,
						i_vector_length,
						i_vector_mask,
						i_ak,
						i_fu_time,
						i_fu,
						o_busy,
						o_chain_n);

parameter WIDTH = 64;
parameter DEPTH = 64;
parameter LOGDEPTH = 6;


input  wire                clk;
input  wire                rst;
`ifndef USE_CORES
output reg  [WIDTH-1:0]    o_rd_data;
`else
output wire  [WIDTH-1:0]    o_rd_data;
`endif
input  wire [WIDTH-1:0]    i_sbus;
input  wire [WIDTH-1:0]    i_v_add;
input  wire [WIDTH-1:0]    i_v_log;
input  wire [WIDTH-1:0]    i_v_shift;
input  wire [WIDTH-1:0]    i_v_poppar;
input  wire [WIDTH-1:0]    i_fp_add;
input  wire [WIDTH-1:0]    i_fp_mult;
input  wire [WIDTH-1:0]    i_fp_ra;
input  wire [WIDTH-1:0]    i_mem;
input  wire						i_mem_ack;
input  wire                i_vread_start;
input  wire                i_vwrite_start;
input  wire                i_swrite_start;
input  wire [LOGDEPTH:0]   i_vector_length;
input  wire [WIDTH-1:0]    i_vector_mask;
input  wire [23:0]         i_ak;
input  wire [3:0]          i_fu_time;
input  wire [2:0]          i_fu;
output wire                o_busy;
output wire                o_chain_n;


wire chain_n;

reg  [WIDTH-1:0]   selected_data;
reg  [WIDTH-1:0]   chain_data;
wire [WIDTH-1:0]   data_to_be_written;
wire  [WIDTH-1:0]  data_to_be_read;

wire                mem_wr_en;
wire                mem_rd_en;
wire  [5:0]         mem_wr_addr;
`ifndef USE_CORES
reg  [WIDTH-1:0]   data [DEPTH-1:0];     //the actual registers
`endif
reg  [WIDTH-1:0]   delay0, delay1, delay2;
reg  [2:0]         vec_state;

//
// Due to timing problems presently there is no possibility for memory LATENCY
// controlled by the _mem_ack signals.
// The processor is hard-wired to work with 1 cycle latency,
//	i.e. address->data->register and register/data/address->mem_wr_data
//reg					 mem_already_acked;
//reg					 mem_wr_en;
//
wire	v_mem_ack = 1;	// Always ack for now, ignore memory acks
// ////

reg [LOGDEPTH:0] read_ptr;
reg [LOGDEPTH:0] write_ptr;
reg [LOGDEPTH:0]   cur_vector_length;
reg [LOGDEPTH:0]   cur_vector_length_minus_one;
reg [WIDTH-1:0]    cur_vector_mask;
reg [4:0]          write_delay;

reg [2:0]          cur_source;
reg [WIDTH-1:0]    sbus;
reg [WIDTH-1:0]    v_add;
reg [WIDTH-1:0]    v_log;
reg [WIDTH-1:0]    v_shift;
reg [WIDTH-1:0]    v_poppar;
reg [WIDTH-1:0]    fp_add;
reg [WIDTH-1:0]    fp_mult;
reg [WIDTH-1:0]    fp_ra;
reg [WIDTH-1:0]    mem;

wire               write_enable;
wire               final_write_enable;
wire [5:0]         final_write_address;
reg                swrite_start;

localparam IDLE = 3'b000,	// Bit 0 indicates WRITE, Bit 1 indicates reads
			 WRITE = 3'b001,	// Bit 1 is used in read_ptr 'always' to indicate not-WRITE and not-IDLE
           READ = 3'b010,
		    CHAIN = 3'b011,
			 DUMMY = 3'b100,
		READWRITE = 3'b110,
		WRITEREAD = 3'b111;	// Not used

			
//Sources			   
localparam VLOG   = 3'b000,   //vector logical
           VSHIFT = 3'b001,	 //vector shift
			  VADD   = 3'b010,
	        FP_MUL = 3'b011,   //FP multiply
	        FP_ADD = 3'b100,   //FP adder 
	        FP_RA  = 3'b101,   //FP recip. approx.
	        VPOP   = 3'b110,   //vector pop count / parity
	        MEMORY = 3'b111;

reg [4:0] fu_time;

reg vwrite_start;


/*
// Memory LATENCY... allow only one memory-not-ready
// BEWARE: Specific for vector memories, provide memory to have
// bursts long enough!! In memory design beware of inter-bank
// vector accesses!
//
// Does not work presently, 19/2/15, 19:36
//

always @*
	if (i_mem_ack)
		mem_already_acked = 1;
	else
		if (~o_busy)
			mem_already_acked = 0;
		else
			mem_already_acked = mem_already_acked;


//assign v_mem_ack = ((cur_source == MEM) & mem_already_acked) ? 1 : i_mem_ack;

always @(posedge clk)
	if (cur_source == MEM)
		if (~mem_already_acked)
			v_mem_ack <= i_mem_ack;
		else
			v_mem_ack <= 1;
	else
		v_mem_ack <= 1;
*/


// calculate the write delay
always@(posedge clk)
   if(rst)
	   fu_time <= 5'b0;
   else
		if (i_vread_start | (i_vwrite_start && (i_vector_length == 1)))
				fu_time <= i_fu_time + 5'd1;
		else
			if (fu_time != 5'b0)
				fu_time <= fu_time - v_mem_ack;
			else if (i_vwrite_start)
				fu_time <= i_fu_time;

//reg busy;
//always @(posedge clk)
//	busy <= ((vec_state != IDLE) && !((vec_state==WRITE) && (write_ptr == cur_vector_length_minus_one)));
//assign o_busy = busy;

//wire writing = (({1'b0,write_ptr}!=(cur_vector_length_minus_one)));// || (cur_vector_length == 1));
wire writing = ~({1'b0,write_ptr}==(cur_vector_length_minus_one + (cur_vector_length == 1)));

assign o_busy = (vec_state != IDLE);
//assign o_busy = (vec_state != IDLE) && !((vec_state==WRITE) && (write_ptr == (cur_vector_length_minus_one)));




//

assign chain_n = write_ptr != 1;   //chain slot time

reg chain_slot_n;
always @(posedge clk)
	if (rst)
		chain_slot_n <= 0;
	else
		if (~chain_n & (vec_state != READWRITE))
			chain_slot_n <= 0;
		else
			if (vec_state != WRITE)
				chain_slot_n <= 1;

assign o_chain_n = chain_slot_n & chain_n;

//just grab the current vector length and mask
always@(posedge clk)
//	if (rst)
//		begin
//			cur_vector_length <= 0;
//			cur_vector_length_minus_one <= 7'b0;
//		end
//	else 
	if(i_vread_start || i_vwrite_start)
	begin
	   cur_vector_length <= i_vector_length;
		cur_vector_length_minus_one <= i_vector_length - 7'b1;
		cur_vector_mask   <= i_vector_mask;
	end

//Grab the source
always@(posedge clk)
   if(i_vwrite_start)
	   cur_source <= i_fu;


//Figure out which source we actually want to write from	
/*
always@ (posedge clk)
	if (mem_wr_en)		// i.e. writing to the V register, therefore we need selected_data
	begin
		case(cur_source)
			VLOG: 	selected_data <= i_v_log;   	//vector logical
         VSHIFT: 	selected_data <= i_v_shift; 	//vector shift
			VADD: 	selected_data <= i_v_add;   	//vector add
	      FP_MUL: 	selected_data <= i_fp_mult; 	//FP multiply
	      FP_ADD: 	selected_data <= i_fp_add;  	//FP adder 
	      FP_RA: 	selected_data <= i_fp_ra;   	//FP recip. approx.
	      VPOP: 	selected_data <= i_v_poppar;	//vector pop count / parity
	      MEM: 	selected_data <= i_mem;     		//memory
		endcase
		sbus    <= i_sbus;
		// as well as the write signal coming in from the s-bus
	   swrite_start <= i_swrite_start;
		// Delay chain data to be compatible with read data
		chain_data <= selected_data;
	end
*/
/*
always@(posedge clk)
   begin
   //Let's flop all of the data to get better timing
      v_log   <= i_v_log;
		v_shift <= i_v_shift;
		v_add   <= i_v_add;
		fp_mult <= i_fp_mult;
		fp_add  <= i_fp_add;
		fp_ra   <= i_fp_ra;
		v_poppar<= i_v_poppar;
		mem     <= i_mem;
		sbus    <= i_sbus;
	//as well as the write signal coming in from the s-bus
	   swrite_start <= i_swrite_start;
   end	
*/

always @*
//	if (mem_wr_en)		// i.e. writing to the V register, therefore we need selected_data
		begin
			case(cur_source)
				VLOG: 	selected_data = i_v_log;   	//vector logical
				VSHIFT: 	selected_data = i_v_shift; 	//vector shift
				VADD: 	selected_data = i_v_add;   	//vector add
				FP_MUL: 	selected_data = i_fp_mult; 	//FP multiply
				FP_ADD: 	selected_data = i_fp_add;  	//FP adder 
				FP_RA: 	selected_data = i_fp_ra;   	//FP recip. approx.
				VPOP: 	selected_data = i_v_poppar;	//vector pop count / parity
				MEMORY: 	selected_data = i_mem;     	//memory
			endcase
		end
		
always @*
		sbus = i_sbus;

always @(posedge clk)
	begin
		// as well as the write signal coming in from the s-bus
	   swrite_start <= i_swrite_start;
		// Delay chain data to be compatible with read data
		chain_data <= selected_data;
	end

assign data_to_be_written = swrite_start ? sbus : selected_data;

//Let's calculate the read pointer


/*	
always@*
	if(rst)
		read_ptr = 6'b0;
	else if ((vec_state == CHAIN) && chain_slot)
		read_ptr = write_ptr - 1;
   else if(vec_state == WRITE)
	   read_ptr = 6'b0;          //if it's a vector, start at -1, as the read/write ram needs 2 cycles, 
	else if ((vec_state!=IDLE) && (vec_state != WRITE))
	   read_ptr = read_ptr + 1;	// There is no WRITE LATENCY, as we work with Vector (Burst) memories or full RAM
	else
      read_ptr = i_ak[5:0];     //if it's scalar, start at Ak
*/

always @(posedge clk)
	if(rst)
		read_ptr <= 6'b0;
	else
		if (((chain_n & (vec_state == WRITE))	&& !(vec_state == READWRITE)
						|| (vec_state == IDLE))
					&& ~i_vread_start
					&& !(i_vread_start & i_vwrite_start))
			read_ptr <= 6'b0;
		else
			if ((vec_state[1] | i_vread_start))		// neither IDLE nor WRITE
				read_ptr <= read_ptr + 1;
			else
				read_ptr <= i_ak[5:0];

/*
always@(negedge clk)
	if(rst)
		read_ptr <= 6'b111111;
   else if(i_vread_start)
	   read_ptr <= 6'b111111;          //if it's a vector, start at -2, as the read/write ram needs 3 cycles, 
	else if ((vec_state!=IDLE) && (vec_state != WRITE))
	   read_ptr <= read_ptr + v_mem_ack;
	else
      read_ptr <= i_ak[5:0];     //if it's scalar, start at Ak
*/

//and the write pointer
always@(posedge clk)
   if(rst)
	   write_ptr <= 6'b0;
   else
		if(i_vwrite_start | (vec_state == IDLE) | (vec_state == READ))
			write_ptr <= 6'b0;
		else
			if ((write_delay == 5'b0) & ~write_ptr[6])		// Over the top!
				write_ptr <= write_ptr + v_mem_ack;

//always@*
//   begin

//assign write_enable = ((vec_state!=IDLE) && (vec_state!=READ));// && (write_delay==5'b0);// && ({1'b0,write_ptr} < cur_vector_length));
assign write_enable = (((vec_state!=IDLE) && (vec_state!=READ)) && (write_delay==5'b0) && ({1'b0,write_ptr} < cur_vector_length));
assign mem_wr_en   = (write_enable && cur_vector_mask[write_ptr]) || i_swrite_start;
assign mem_wr_addr = i_swrite_start ? i_ak[5:0] : write_ptr;

//   end

assign mem_rd_en = (vec_state != IDLE) | i_vread_start; //(vec_state == READ) || (vec_state == READWRITE);

`ifndef USE_CORES

// ZS 15/2/15 16:12
// Write
always @(posedge clk)
	if (mem_wr_en)
		data[mem_wr_addr] <= data_to_be_written;

// Read
// Write before read in case of address collision implemented here
//
always @(posedge clk)
	if (mem_rd_en)
		o_rd_data <= ((mem_wr_addr == read_ptr) & mem_wr_en)? data_to_be_written : data[read_ptr];
		
//	begin
//		if (vec_state == CHAIN)
//			o_rd_data <= selected_data;
//		else
//			o_rd_data <= data[read_ptr];
//		o_rd_data <= rd_data0;
//	end


/*
reg [LOGDEPTH-1:0] read_ram;
wire [5:0] preread = read_ptr; // + 6'b1;
always@(posedge clk)
	begin
		if(mem_wr_en)
			data[mem_wr_addr] <= data_to_be_written;
		read_ram <= preread;
	end

//always@*
//	if ((vec_state == READ) || (vec_state == READWRITE) || (vec_state == CHAIN))
		assign data_to_be_read = data[read_ram];		
*/

/***
	EXAMPLE:
		Following is the Verilog code for a dual-port RAM with synchronous read (read through). 
	
reg    [4:0] read_dpra; 
 
  always @(posedge clk) begin   
    if (we)   
      ram[a] <= di;   
    read_a <= a;   
    read_dpra <= dpra;   
  end   
  assign spo = ram[read_a];   
  assign dpo = ram[read_dpra];   
***/


`else // USE_CORES

assign o_rd_data = (mem_wr_addr == read_ptr) ? data_to_be_written : data_to_be_read;

hard_v_reg vmem (
	.clka(clk),
	.wea(mem_wr_en), 
	.addra(mem_wr_addr), 
	.dina(data_to_be_written), 
	.clkb(clk),
//	.rstb(rst),
	.enb(mem_rd_en),
	.addrb(read_ptr),
	.doutb(data_to_be_read)); // Bus [63 : 0] 

// read a register
//always @*
//	o_rd_data = data_to_be_read;

//always@ (posedge clk)
//   begin
//	   delay0 <= data_to_be_read;
//		delay1 <= delay0;
//		o_rd_data <= (vec_state==CHAIN) ? selected_data : delay1;      //this properly re-directs the input during chain-slot time
//	end


`endif // USE_CORES


//finally calculate the write delay

always@(posedge clk)
   if(rst)
	   write_delay <= 5'b0;
   else 
		if (i_vwrite_start)
			if (i_vread_start)		//					if ((vec_state == WRITE) || i_vread_start)
				write_delay <= i_fu_time; // + 5'd1;
			else
				write_delay <= i_fu_time; // + 5'd1;
		else
			if (write_delay != 5'b0)
				write_delay <= write_delay - v_mem_ack;


/////////////////////
//   FSM           //
/////////////////////
//This is the finite state machine that controls
//the vector register
always@(posedge clk)
if(rst) vec_state <= IDLE;
else
   case(vec_state)
	   IDLE: begin
		         if (i_vread_start & i_vwrite_start)
						vec_state <= READWRITE;
					else if(i_vread_start)
					   vec_state <= READ;
					else if(i_vwrite_start)
					   vec_state <= WRITE;
		      end
		READ: begin
		         if(({1'b0,read_ptr}==(cur_vector_length_minus_one) | (cur_vector_length == 1)) /* && (fu_time == 0) */)
					   vec_state <= IDLE;
		      end
		WRITE:begin
		         if (i_vread_start & i_vwrite_start)
						vec_state <= READWRITE;
					else if(i_vread_start && writing)
					   vec_state <= CHAIN;
					else if (i_vread_start && ~(writing))
					   vec_state <= READ;
					else if ((i_vwrite_start))// && (writing))
					   vec_state <= WRITE;
					else if ({1'b0,write_ptr}==(cur_vector_length_minus_one + (cur_vector_length == 1))) // && (fu_time == 0))
					   vec_state <= IDLE;
		      end
		CHAIN:begin
		         if (({1'b0,read_ptr}==(cur_vector_length_minus_one)) | (cur_vector_length == 1))
					   vec_state <= IDLE;
		      end
		READWRITE:
				begin
					if({1'b0,read_ptr}==(cur_vector_length_minus_one))
						if ({1'b0,write_ptr}==(cur_vector_length_minus_one + (cur_vector_length == 1))) // && (fu_time == 0) )
							vec_state <= IDLE;
						else
							vec_state <= WRITE;
					else
						if ({1'b0,write_ptr}==(cur_vector_length_minus_one + (cur_vector_length == 1))) // && (fu_time == 0))
							vec_state <= READ;
						else
							vec_state <= READWRITE;
				end
		default:
				vec_state <= IDLE;
	endcase
/*
always@(posedge clk)
if(rst) vec_state <= IDLE;
else
   case(vec_state)
	   IDLE: begin
		         if (i_vread_start & i_vwrite_start)
						vec_state <= READWRITE;
					else if(i_vread_start)
					   vec_state <= READ;
					else if(i_vwrite_start)
					   vec_state <= WRITE;
		      end
		READ: begin
		         if({1'b0,read_ptr}==(cur_vector_length_minus_one & ~i_vwrite_start))
					   vec_state <= IDLE;
					else if (i_vwrite_start && (write_ptr != 0))
						vec_state <= CHAIN; // Kind of reverse chain, reading and rewriting...
					else if (!v_mem_ack)
						vec_state <= READWRITE;
		      end
		WRITE:begin
		         if (i_vread_start & i_vwrite_start)
						vec_state <= READWRITE;
					else if(i_vread_start && ~({1'b0,write_ptr}==(cur_vector_length_minus_one)))
					   vec_state <= CHAIN;
					else if (i_vread_start && ({1'b0,write_ptr}==(cur_vector_length_minus_one)))
					   vec_state <= READ;
					else if ((i_vwrite_start) && ({1'b0,write_ptr}==(cur_vector_length_minus_one)))
					   vec_state <= WRITE;
					else if ({1'b0,write_ptr}==(cur_vector_length_minus_one))
					   vec_state <= IDLE;
		      end
		CHAIN:begin
		         if({1'b0,read_ptr}==(cur_vector_length - 7'b1))
					   vec_state <= IDLE;
		      end
		READWRITE:
				begin
					if({1'b0,read_ptr}==(cur_vector_length_minus_one))
						if ({1'b0,write_ptr}==(cur_vector_length_minus_one))
							vec_state <= IDLE;
						else
							vec_state <= WRITE;
					else
						if ({1'b0,write_ptr}==(cur_vector_length_minus_one))
							vec_state <= READ;
						else
							vec_state <= READWRITE;
				end
	endcase
*/

endmodule
