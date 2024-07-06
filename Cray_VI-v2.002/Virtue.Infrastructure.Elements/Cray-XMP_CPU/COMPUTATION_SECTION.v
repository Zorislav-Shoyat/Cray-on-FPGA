//CRAY_1 top-level 



//////////////////////////////////////////////////////////////////
//        Cray CPU Top-level                                    //
//        Author: Christopher Fenton                            //
//        Date:  8/8/23                                         //
//////////////////////////////////////////////////////////////////
//
// Adapted by Zorislav Shoyat, 14/3/2014, 21:12
//
//////////////////////////////////////////////////////////////////
//
// Zorislav Shoyat, 15/2/15, 21:57, Atelier, Delphinus
//
// Adapted for _addr_ack and rd/wr independent addrs and acks
//

// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"

//
//This is the top-level for the CRAY_1A CPU block. It instantiates
//the primary "functional unit" block, as well as the 4 x 64-parcel
//instruction buffers.
//

module COMPUTATION_SECTION
					(clk,
                rst,
					 cpu_rst,
					 
					 o_mem_rd_req,
					 o_mem_rd_addr,
					 i_mem_rd_addr_ack,
					 i_mem_rd_data,
					 i_mem_rd_ack,
					 o_mem_wr_req,
					 o_mem_wr_addr,
					 i_mem_wr_addr_ack,
					 i_mem_wr_ack,
					 o_mem_wr_data,
					 
					 o_mem_rdB_req,
					 o_mem_rdB_addr,
					 i_mem_rdB_addr_ack,
					 i_mem_rdB_data,
					 i_mem_rdB_ack,
					 o_mem_wrB_req,
					 o_mem_wrB_addr,
					 i_mem_wrB_addr_ack,
					 i_mem_wrB_ack,
					 o_mem_wrB_data
`ifndef CRAY_1
					,
					 //I/O Channels
					 //High-speed channels
					 i_ch06_data,
					 i_ch06_vld,
					 o_ch06_rdy,
					 //Outgoing data
					 o_ch07_data,
					 o_ch07_vld,
					 i_ch07_rdy,			   
				    //Low-speed channels
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

`ifdef CRAY_XMP
	`ifdef CRAY_XMP_1
		parameter NUM_CPUS=1;
	`elsif CRAY_XMP_2
		parameter NUM_CPUS=2;
	`elsif CRAY_XMP_3
		parameter NUM_CPUS=3;
	`elsif CRAY_XMP_4
		parameter NUM_CPUS=4;
	`endif
`else
`ifdef CRAY_1
	parameter NUM_CPUS=1;
`endif
`endif

input  wire        clk;
input  wire        rst;
input  wire [NUM_CPUS-1:0]  cpu_rst;

output wire        o_mem_rd_req;
output wire [21:0] o_mem_rd_addr;
input  wire        i_mem_rd_addr_ack;
input  wire        i_mem_rd_ack;
input  wire [63:0] i_mem_rd_data;
output wire        o_mem_wr_req;
output wire [21:0] o_mem_wr_addr;
input  wire        i_mem_wr_addr_ack;
output wire [63:0] o_mem_wr_data;
input wire         i_mem_wr_ack;

output wire        o_mem_rdB_req;
output wire [21:0] o_mem_rdB_addr;
input  wire        i_mem_rdB_addr_ack;
input  wire        i_mem_rdB_ack;
input  wire [63:0] i_mem_rdB_data;
output wire        o_mem_wrB_req;
output wire [21:0] o_mem_wrB_addr;
input  wire        i_mem_wrB_addr_ack;
output wire [63:0] o_mem_wrB_data;
output wire        i_mem_wrB_ack;

// connection to modules, for now
//wire mem_ce;
//wire mem_wr_en;
//wire [21:0] mem_addr;

//assign o_mem_rd_req = mem_ce & !mem_wr_en;
//assign o_mem_rd_addr = mem_addr;
//assign o_mem_wr_req = mem_ce & mem_wr_en;
//assign o_mem_wr_addr = mem_addr;


`ifndef CRAY_1
//DMA interface
/*    High-speed 1250MB/s channel pair */
//Incoming data
input  wire [15:0] i_ch06_data;
input  wire        i_ch06_vld;
output wire        o_ch06_rdy;

//Outgoing data
output wire [15:0] o_ch07_data;
output wire        o_ch07_vld;
input  wire        i_ch07_rdy;			  
				  
////////////////////////////////
//        6 MB/s channels     //
////////////////////////////////
//incoming data
input wire [15:0] i_ch10_data;
input wire        i_ch10_vld;
output wire       o_ch10_rdy;

input wire [15:0] i_ch12_data;
input wire        i_ch12_vld;
output wire       o_ch12_rdy;
				  
input wire [15:0] i_ch14_data;
input wire        i_ch14_vld;
output wire       o_ch14_rdy;
				  
input wire [15:0] i_ch16_data;
input wire        i_ch16_vld;
output wire       o_ch16_rdy;
//outgoing data
output wire [15:0] o_ch11_data;
output wire        o_ch11_vld;
input  wire        i_ch11_rdy;

output wire [15:0] o_ch13_data;
output wire        o_ch13_vld;
input  wire        i_ch13_rdy;

output wire [15:0] o_ch15_data;
output wire        o_ch15_vld;
input  wire        i_ch15_rdy;

output wire [15:0] o_ch17_data;
output wire        o_ch17_vld;
input  wire        i_ch17_rdy;
`endif // not CRAY_1

//instruction buffer singals
wire [NUM_CPUS-1:0]		instr_buf_mem_rd_req;
wire [22*NUM_CPUS-1:0]	instr_buf_mem_addr;
wire [NUM_CPUS-1:0]		instr_buf_mem_addr_ack;
wire [64*NUM_CPUS-1:0]	instr_buf_mem_data;
wire [NUM_CPUS-1:0]		instr_buf_mem_vld;
wire [24*NUM_CPUS-1:0]	p_addr;  

//functional unit signals
wire [22*NUM_CPUS-1:0] fu_mem_rd_addr;
wire [22*NUM_CPUS-1:0] fu_mem_wr_addr;
wire [NUM_CPUS-1:0] fu_mem_rd_addr_ack;
wire [NUM_CPUS-1:0] fu_mem_wr_addr_ack;
wire [64*NUM_CPUS-1:0] fu_mem_rd_data;
wire [64*NUM_CPUS-1:0] fu_mem_wr_data;
wire [NUM_CPUS-1:0] fu_mem_rd_req;
wire [NUM_CPUS-1:0] fu_mem_wr_req;
wire [NUM_CPUS-1:0] fu_mem_rd_ack;
wire [NUM_CPUS-1:0] fu_mem_wr_ack;

wire [16*NUM_CPUS-1:0] nip_nxt;
wire [64*NUM_CPUS-1:0] word_nxt;
wire [NUM_CPUS-1:0]      nip_vld;
wire [NUM_CPUS-1:0]      clear_ibufs;
wire [63:0] mem_read_data;


//DMA signals
wire [63:0] dma_wr_data;
wire [21:0] dma_addr;
wire        dma_req;
wire        dma_wr;
wire        dma_ack;

wire [63:0] dma_instr;
wire [3:0]  dma_mon_mode;
wire [3:0]  dma_instr_vld;
wire [95:0] dma_ak;
wire [95:0] dma_aj;
wire [95:0] dma_ai;

//`ifndef CRAY_XMP_1
//Inter-cpu signals
wire [3*NUM_CPUS-1:0]  cln;
wire [16*NUM_CPUS-1:0] intercpu_instr;
wire [NUM_CPUS-1:0]      intercpu_mon_mode;
wire [NUM_CPUS-1:0]      intercpu_instr_vld;
wire [NUM_CPUS-1:0]      intercpu_issue;
wire [64*NUM_CPUS-1:0] intercpu_sj;
wire [64*NUM_CPUS-1:0] intercpu_si_i, intercpu_si_o;  //_i is cpu->intercpu, _o is intercpu->cpu
wire [24*NUM_CPUS-1:0] intercpu_ai_i, intercpu_ai_o;
//`endif // not CRAY_XMP_1


//IOP Signals
wire [21:0] iop_addr;
wire [63:0] iop_data;
wire        iop_req; 
wire        iop_wr;
wire        iop_ack;


/////////////////////////////////////////////////
//          10-Way Memory Arbiter              //
/////////////////////////////////////////////////
//This block arbitrates between the 4 instruction
//buffer interfaces, the 4 CPU's main memory interface,
//the I/O block and the IOP-Direct interfaces


wire [63:0] data_for_ibuf;
wire [63:0] data_for_fu;

`ifdef CRAY_1
`ifndef MARB_XMP
Memory_Arbiter marb
`else
mem_arb marb
`endif
	(
    .clk(clk), 
    .rst(rst), 
    .i_mem_data(i_mem_rd_data), 
    .o_mem_data(o_mem_wr_data), 
    .o_mem_rd_addr(o_mem_rd_addr), 
    .o_mem_wr_addr(o_mem_wr_addr), 
    .o_mem_rd_req(o_mem_rd_req), 
    .o_mem_wr_req(o_mem_wr_req), 
    .i_mem_rd_ack(i_mem_rd_ack), 
    .i_mem_wr_ack(i_mem_wr_ack), 
    .i_mem_rd_addr_ack(i_mem_rd_addr_ack), 
    .i_mem_wr_addr_ack(i_mem_wr_addr_ack),
	 
    .i_memB_data(i_mem_rdB_data), 
    .o_memB_data(o_mem_wrB_data),
    .o_mem_rdB_addr(o_mem_rdB_addr), 
    .o_mem_wrB_addr(o_mem_wrB_addr), 
    .o_mem_rdB_req(o_mem_rdB_req), 
    .o_mem_wrB_req(o_mem_wrB_req), 
    .i_mem_rdB_ack(i_mem_rdB_ack), 
    .i_mem_wrB_ack(i_mem_wrB_ack), 
    .i_mem_rdB_addr_ack(i_mem_rdB_addr_ack), 
    .i_mem_wrB_addr_ack(i_mem_wrB_addr_ack),
	 
	 .o_read_instr0_data (data_for_ibuf),
	 .o_read_mfu0_data (data_for_fu),
    .i_instr0_addr(instr_buf_mem_addr[21:0]), 
    .o_instr0_addr_ack(instr_buf_mem_addr_ack[0]), 
    .i_instr0_req(instr_buf_mem_rd_req[0]), 
    .o_instr0_ack(instr_buf_mem_vld[0]), 
    .i_mfu0_rd_addr(fu_mem_rd_addr[21:0]), 
    .i_mfu0_wr_addr(fu_mem_wr_addr[21:0]), 
    .i_mfu0_wr_data(fu_mem_wr_data[63:0]), 
    .i_mfu0_rd_req(fu_mem_rd_req[0]), 
    .i_mfu0_wr_req(fu_mem_wr_req[0]), 
    .o_mfu0_rd_ack(fu_mem_rd_ack[0]),
    .o_mfu0_wr_ack(fu_mem_wr_ack[0]),
    .o_mfu0_rd_addr_ack(fu_mem_rd_addr_ack[0]),
    .o_mfu0_wr_addr_ack(fu_mem_wr_addr_ack[0])
    );

`else
mem_arb marb(.clk(clk),
             .rst(rst),
             //Memory interface
				 .i_mem_rd_ack (i_mem_rd_ack),				//ZS 
             .i_mem_data(i_mem_rd_data),
             .o_mem_data(o_mem_wr_data),
             .o_mem_addr(mem_addr),
             .o_mem_ce(mem_ce),
             .o_mem_wr(mem_wr_en),
             //Read data
				 .o_read_instr0_data (data_for_ibuf),
				 .o_read_mfu0_data (data_for_fu),
//            .o_read_data(mem_read_data),
             //Instruction fetch interface
             .i_instr0_addr(instr_buf_mem_addr[21:0]),
             .i_instr0_req(instr_buf_mem_rd_req[0]),
             .o_instr0_ack(instr_buf_mem_vld[0]),
             //Memory Functional Unit interface
             .i_mfu0_addr(fu_mem_addr[21:0]),
             .i_mfu0_data(fu_mem_wr_data[63:0]),
             .i_mfu0_rd_req(fu_mem_rd_req[0]), 
             .i_mfu0_wr_req(fu_mem_wr_req[0]),
             .o_mfu0_ack(fu_mem_ack[0])
`ifndef CRAY_XMP_1
				,
             //Instruction fetch interface
             .i_instr1_addr(instr_buf_mem_addr[22*2-1:22]),
             .i_instr1_req(instr_buf_mem_rd_req[1]),
             .o_instr1_ack(instr_buf_mem_vld[1]),
             //Memory Functional Unit interface
             .i_mfu1_addr(fu_mem_addr[22*2-1:22]),
             .i_mfu1_data(fu_mem_wr_data[127:64]),
             .i_mfu1_req(fu_mem_rd_req[1]), 
             .i_mfu1_wr(fu_mem_wr_req[1]),
             .o_mfu1_ack(fu_mem_ack[1])
`ifndef CRAY_XMP_2				
				,
             //Instruction fetch interface
             .i_instr2_addr(instr_buf_mem_addr[22*3-1:22*2]),
             .i_instr2_req(instr_buf_mem_rd_req[2]),
             .o_instr2_ack(instr_buf_mem_vld[2]),
             //Memory Functional Unit interface
             .i_mfu2_addr(fu_mem_addr[22*3-1:22*2]),
             .i_mfu2_data(fu_mem_wr_data[191:128]),
             .i_mfu2_req(fu_mem_rd_req[2]), 
             .i_mfu2_wr(fu_mem_wr_req[2]),
             .o_mfu2_ack(fu_mem_ack[2])
`ifndef CRAY_XMP_3	// == `ifdef CRAY_XMP_4
				,
             //Instruction fetch interface
             .i_instr3_addr(instr_buf_mem_addr[22*4-1:22*3]),
             .i_instr3_req(instr_buf_mem_rd_req[3]),
             .o_instr3_ack(instr_buf_mem_vld[3]),
             //Memory Functional Unit interface
             .i_mfu3_addr(fu_mem_addr[22*4-1:22*3]),
             .i_mfu3_data(fu_mem_wr_data[255:192]),
             .i_mfu3_req(fu_mem_rd_req[3]), 
             .i_mfu3_wr(fu_mem_wr_req[3]),
             .o_mfu3_ack(fu_mem_ack[3])
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
				,
             //DMA interface
             .i_dma_addr(dma_addr[21:0]),
             .i_dma_data(dma_wr_data),
             .i_dma_req(dma_req), 
             .i_dma_wr(dma_wr),
             .o_dma_ack(dma_ack)
`ifndef NO_IOP
				,
             //IOP interface
             .i_iop_addr(iop_addr),
             .i_iop_data(iop_data),
             .i_iop_req(iop_req), 
             .i_iop_wr(iop_wr),
             .o_iop_ack(iop_ack)
`endif // not NO_IOP
				);
`endif // not CRAY_1

`ifdef CRAY_1
assign instr_buf_mem_data = {data_for_ibuf[63:0]};
assign fu_mem_rd_data     = {data_for_fu[63:0]};
`elsif CRAY_XMP_1
assign instr_buf_mem_data = {data_for_ibuf[63:0]};
assign fu_mem_rd_data     = {data_for_fu[63:0]};
`endif
`ifdef CRAY_XMP_2
assign instr_buf_mem_data = {data_for_ibuf[63:0],data_for_ibuf[63:0]};
assign fu_mem_rd_data     = {data_for_fu[63:0],data_for_fu[63:0]};
`endif
`ifdef CRAY_XMP_3
assign instr_buf_mem_data = {data_for_ibuf[63:0],data_for_ibuf[63:0],data_for_ibuf[63:0]};
assign fu_mem_rd_data     = {data_for_fu[63:0],data_for_fu[63:0],data_for_fu[63:0]};
`endif
`ifdef CRAY_XMP_4
assign instr_buf_mem_data = {data_for_ibuf[63:0],data_for_ibuf[63:0],data_for_ibuf[63:0],data_for_ibuf[63:0]};
assign fu_mem_rd_data     = {data_for_fu[63:0],data_for_fu[63:0],data_for_fu[63:0],data_for_fu[63:0]};
`endif


`ifndef CRAY_1
///////////////////////////////////////////////
//   Shared  DMA "I/O" Controller Logic      //
///////////////////////////////////////////////
dma_fu dma(.clk(clk),
           .rst(rst),
				//////////////////////////////////
				//         CPU Interfaces       //
				//////////////////////////////////
				//CPU0 Interface
            .i_cpu0_instr(dma_instr[15:0]),
				.i_cpu0_mon_mode(dma_mon_mode[0]),
            .i_cpu0_instr_vld(dma_instr_vld[0]),
            .i_cpu0_ak(dma_ak[23:0]),
            .i_cpu0_aj(dma_aj[23:0]),
				.o_cpu0_ai(dma_ai[23:0])
`ifndef CRAY_XMP_1
			,
				//CPU1 Interface
            .i_cpu1_instr(dma_instr[31:16]),
				.i_cpu1_mon_mode(dma_mon_mode[1]),
            .i_cpu1_instr_vld(dma_instr_vld[1]),
            .i_cpu1_ak(dma_ak[47:24]),
            .i_cpu1_aj(dma_aj[47:24]),
				.o_cpu1_ai(dma_ai[47:24])
`ifndef CRAY_XMP_2
			,
				//CPU2 Interface
            .i_cpu2_instr(dma_instr[47:32]),
				.i_cpu2_mon_mode(dma_mon_mode[2]),
            .i_cpu2_instr_vld(dma_instr_vld[2]),
            .i_cpu2_ak(dma_ak[71:48]),
            .i_cpu2_aj(dma_aj[71:48]),
				.o_cpu2_ai(dma_ai[71:48])
`ifndef CRAY_XMP_3	// == `ifdef CRAY_XMP_4
			,
				//CPU3 Interface
            .i_cpu3_instr(dma_instr[63:48]),
				.i_cpu3_mon_mode(dma_mon_mode[3]),
            .i_cpu3_instr_vld(dma_instr_vld[3]),
            .i_cpu3_ak(dma_ak[95:72]),
            .i_cpu3_aj(dma_aj[95:72]),
				.o_cpu3_ai(dma_ai[95:72])
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
			,
				  
            ////////////////////////////////
				//      1250 MB/s channels    //
				////////////////////////////////
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
            .i_ch10_data(i_ch10_data),
            .i_ch10_vld(i_ch10_vld),
            .o_ch10_rdy(o_ch10_rdy),

            .i_ch12_data(i_ch12_data),
            .i_ch12_vld(i_ch12_vld),
            .o_ch12_rdy(o_ch12_rdy),
				  
            .i_ch14_data(i_ch14_data),
            .i_ch14_vld(i_ch14_vld),
            .o_ch14_rdy(o_ch14_rdy),
				  
            .i_ch16_data(i_ch16_data),
            .i_ch16_vld(i_ch16_vld),
            .o_ch16_rdy(o_ch16_rdy),
				//outgoing data
            .o_ch11_data(o_ch11_data),
            .o_ch11_vld(o_ch11_vld),
            .i_ch11_rdy(i_ch11_rdy),

            .o_ch13_data(o_ch13_data),
            .o_ch13_vld(o_ch13_vld),
            .i_ch13_rdy(i_ch13_rdy),

            .o_ch15_data(o_ch15_data),
            .o_ch15_vld(o_ch15_vld),
            .i_ch15_rdy(i_ch15_rdy),

            .o_ch17_data(o_ch17_data),
            .o_ch17_vld(o_ch17_vld),
            .i_ch17_rdy(i_ch17_rdy),
            //////////////////////////////
				//      Memory Interface      //
				////////////////////////////////
            .o_mem_data(dma_wr_data),
				.i_mem_data(mem_read_data),
            .o_mem_addr(dma_addr),
            .o_mem_req(dma_req),
				.o_mem_wr(dma_wr),
            .i_mem_ack(dma_ack)
			);
`else // CRAY_1
assign dma_ai[95:0] = 96'b0;
`endif // CRAY_1

/////////////////////////////////////////////
//      Inter-CPU Communication Block      //
/////////////////////////////////////////////
					
`ifdef CRAY_XMP
intercpu_comms intercpu(.clk(clk),
                      .reset(rst),
                      //CPU0
                      .i_cln_0(               cln[2:0]),
                      .i_intercpu_instr_0(    intercpu_instr[15:0]),
							 .i_intercpu_mon_mode_0( intercpu_mon_mode[0]),
							 .i_intercpu_instr_vld_0(intercpu_instr_vld[0]),
							 .i_intercpu_sj_0(       intercpu_sj[63:0]),
							 .i_intercpu_si_0(       intercpu_si_i[63:0]),
							 .i_intercpu_ai_0(       intercpu_ai_i[23:0]),
							 .o_intercpu_si_0(       intercpu_si_o[63:0]),
							 .o_intercpu_ai_0(       intercpu_ai_o[23:0]),
							 .o_intercpu_issue_0(    intercpu_issue[0])
`ifndef CRAY_XMP_1
							,
							 //CPU1
							 .i_cln_1(               cln[5:3]),
                      .i_intercpu_instr_1(    intercpu_instr[31:16]),
							 .i_intercpu_mon_mode_1( intercpu_mon_mode[1]),
							 .i_intercpu_instr_vld_1(intercpu_instr_vld[1]),
							 .i_intercpu_sj_1(       intercpu_sj[127:64]),
							 .i_intercpu_si_1(       intercpu_si_i[127:64]),
							 .i_intercpu_ai_1(       intercpu_ai_i[47:24]),
							 .o_intercpu_si_1(       intercpu_si_o[127:64]),
							 .o_intercpu_ai_1(       intercpu_ai_o[47:24]),
							 .o_intercpu_issue_1(    intercpu_issue[1])
`ifndef CRAY_XMP_2
							,
							 //CPU2
							 .i_cln_2(               cln[8:6]),
                      .i_intercpu_instr_2(    intercpu_instr[47:32]),
							 .i_intercpu_mon_mode_2( intercpu_mon_mode[2]),
							 .i_intercpu_instr_vld_2(intercpu_instr_vld[2]),
							 .i_intercpu_sj_2(       intercpu_sj[191:128]),
							 .i_intercpu_si_2(       intercpu_si_i[191:128]),
							 .i_intercpu_ai_2(       intercpu_ai_i[71:48]),
							 .o_intercpu_si_2(       intercpu_si_o[191:128]),
							 .o_intercpu_ai_2(       intercpu_ai_o[71:48]),
							 .o_intercpu_issue_2(    intercpu_issue[2])
`ifndef CRAY_XMP_3
						,
							 //CPU3
							 .i_cln_3(               cln[11:9]),
                      .i_intercpu_instr_3(    intercpu_instr[63:48]),
							 .i_intercpu_mon_mode_3( intercpu_mon_mode[3]),
							 .i_intercpu_instr_vld_3(intercpu_instr_vld[3]),
							 .i_intercpu_sj_3(       intercpu_sj[255:192]),
							 .i_intercpu_si_3(       intercpu_si_i[255:192]),
							 .i_intercpu_ai_3(       intercpu_ai_i[95:72]),
							 .o_intercpu_si_3(       intercpu_si_o[255:192]),
							 .o_intercpu_ai_3(       intercpu_ai_o[95:72]),
							 .o_intercpu_issue_3(    intercpu_issue[3])
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
							);
`else // CRAY_1

assign intercpu_instr = 64'b0;
assign intercpu_mon_mode = 0;
assign intercpu_instr_vld = 0;
assign intercpu_sj = 256'b0;
assign intercpu_si_i = 256'b0;
assign intercpu_ai_i = 96'b0;

`endif // CRAY_1


genvar i;
generate
	for (i=0; i < NUM_CPUS; i=i+1) begin : CPU
	//Instruction Buffer
				i_buf instr_buf(
					 .clk(clk), 
                .rst(cpu_rst[i]),
					 .i_clear_ibuf (clear_ibufs[i]),
                .i_p_addr  (p_addr  [i*24+23:i*24]),
                .o_nip_nxt (nip_nxt [i*16+15:i*16]),
					 .o_word_nxt(word_nxt[i*64+63:i*64]),
                .o_nip_vld (nip_vld [i]),
                .o_mem_read  (instr_buf_mem_rd_req  [i]),
                .o_mem_addr(instr_buf_mem_addr[i*22+21:i*22]),
                .i_mem_addr_ack (instr_buf_mem_addr_ack [i]),
                .i_mem_data(instr_buf_mem_data[i*64+63:i*64]),
                .i_mem_rd_ack (instr_buf_mem_vld [i]));
					 
					 
	//CPU/Register section
				CPU cpu(
					//System signals
					.clk(clk),
					.rst(cpu_rst[i]),
					.i_cpu_num(i[1:0]),
					//Instruction buffer interface
					.i_nip_nxt      (nip_nxt [i*16+15:i*16]),
					.i_word_nxt     (word_nxt[i*64+63:i*64]),
					.i_nip_vld      (nip_vld [i]),
					.o_clear_ibufs  (clear_ibufs[i]),
					.o_p_addr       (p_addr  [i*24+23:i*24]),
					// I/O Interface
					.o_dma_instr(dma_instr[i*16+15:i*16]),
				   .o_dma_mon_mode(dma_mon_mode[i]),
               .o_dma_instr_vld(dma_instr_vld[i]),
               .o_dma_ak(dma_ak[i*24+23:i*24]),
               .o_dma_aj(dma_aj[i*24+23:i*24]),
`ifndef CRAY_1
				   .i_dma_ai(dma_ai[i*24+23:i*24]),
					.i_dma_int(0)							// TO BE ASSIGNED !!
`else
				   .i_dma_ai(0),
					.i_dma_int(0)
`endif // CRAY_1
				,
					//Memory Interface
					.o_mem_rd_req(fu_mem_rd_req[i]),
					.o_mem_rd_addr     (fu_mem_rd_addr[i*22+21:i*22]),
					.i_mem_rd_addr_ack(fu_mem_rd_addr_ack[i]),
					.i_data_from_mem(fu_mem_rd_data[i*64+63:i*64]),
					.i_mem_rd_ack(fu_mem_rd_ack[i]),
					.o_mem_wr_req(fu_mem_wr_req[i]),
					.o_mem_wr_addr     (fu_mem_wr_addr[i*22+21:i*22]),
					.i_mem_wr_addr_ack(fu_mem_wr_addr_ack[i]),
					.i_mem_wr_ack(fu_mem_wr_ack[i]),
					.o_data_to_mem(fu_mem_wr_data[i*64+63:i*64])
				,
					//Inter-CPU interface
					.o_cln(cln[i*3+2:i*3]),
					.o_intercpu_instr(intercpu_instr[i*16+15:i*16]),
               .o_intercpu_monmode(intercpu_mon_mode[i]),
               .o_intercpu_instr_vld(intercpu_instr_vld[i]),
               .o_intercpu_sj(intercpu_sj[i*64+63:i*64]),
					.o_intercpu_si(intercpu_si_i[i*64+63:i*64]),
               .o_intercpu_ai(intercpu_ai_i[i*24+23:i*24]),
`ifdef CRAY_XMP
					.i_intercpu_issue(intercpu_issue[i]),
               .i_intercpu_si(intercpu_si_o[i*64+63:i*64]),
					.i_intercpu_ai(intercpu_ai_o[i*24+23:i*24])
`else
					.i_intercpu_issue(1'b0),
               .i_intercpu_si(64'b0),
					.i_intercpu_ai(24'b0)
`endif // not CRAY_XMP
				);
	end
endgenerate

`ifdef CRAY_1
assign dma_instr = 0;
assign dma_mon_mode = 0;
assign dma_instr_vld = 0;
assign dma_ak = 0;
assign dma_aj = 0;
`endif

`ifndef CRAY_XMP
assign cln = 0;
assign intercpu_instr = 0;
assign intercpu_mon_mode = 0;
assign intercpu_sj = 0;
assign intercpu_si_i = 0;
assign intercpu_ai_i = 0;
`endif

endmodule
