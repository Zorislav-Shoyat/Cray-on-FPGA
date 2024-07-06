//////////////////////////////////////////////////////////////////
//        Cray Functional Unit Top-level                        //
//        Author: Christopher Fenton                            //
//        Date:  8/8/23                                         //
//////////////////////////////////////////////////////////////////
//
//This is the "functional unit" top-level block. It instantiates all
//of the register files (A, B, S, T and V), as well as all 13 functional
//units for computing (logical, math, etc.), and all of the logic to handle
//the program counter, branching, etc.
//

/////////////////////////////////////////////////////////////
// Zorislav Shoyat, 2/5/2014, 16:06, Zagreb, Atelier, Julia
//
// 10/5/2014, 20:17
//
// 11/5/2014, 23:37 Zagreb, Atelier, Tintilin (Julia)
//
//    Starting from a very small subset
//
// 14/2/2015. 2:41 Zaqreb. Atelier, Delphinus (Tintilin)
//
//    Cray_VI Version 0.3
//

//
// r257 by christopher.h.fenton on Jan 7, 2015
//

//
// 15/2/15, 18:22 Zagreb, Atelier, Delphinus
//
//    Moved functional unit selection to "Cray_implementation.vh"
//
// 20/2/2015. 18:20, Atelier, Delphinus
//
//		v_scheduler needs the vector length argument to postpone
//		the issue for one cycle if VL=1
//
//////////////////////////////////////////////////////////////////


// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"


`ifndef FULL
// Minimum system:
// 	Scalar processor:
//        SSCHED, ASCHED, S_RF, A_RF, SLOG, SSHIFT, SCONST, IGEN, AADD, MFU, BRNCH
//

// Tailored system:
//		Put defines into "Cray_implementation.vh" to include anything necessary above the minimum scalar processor:
//
`else
// Full system:
//		Full Cray-1 processor:
//			Minimal system + VSCHED, V_RF, T_RF, B_RF, VADD, VLOG, VPOPPAR, VSHIFT, FADD, FMULT, FRECIP, SADD, SPOPLZ, AMULT
//
`endif


module CPU(clk, 
                rst,
					 i_cpu_num,
                i_nip_nxt,
                i_word_nxt,
                i_nip_vld,
                o_p_addr,
					 o_clear_ibufs,
					 // Memory Interface
                o_mem_rd_req,
                o_mem_rd_addr,
					 i_mem_rd_ack,
					 i_mem_rd_addr_ack,
                i_data_from_mem,
                o_mem_wr_req,
                o_mem_wr_addr,
					 i_mem_wr_addr_ack,
					 i_mem_wr_ack,
                o_data_to_mem,
					 //DMA interface
					 o_dma_instr,
				    o_dma_mon_mode,
                o_dma_instr_vld,
                o_dma_ak,
                o_dma_aj,
				    i_dma_ai,
					 i_dma_int,
					 //Inter-cpu interface
					 o_cln,
					 o_intercpu_instr,
                o_intercpu_monmode,
                o_intercpu_instr_vld,
					 i_intercpu_issue,
                o_intercpu_sj,
					 o_intercpu_si,
                o_intercpu_ai,
                i_intercpu_si,
					 i_intercpu_ai
					 );			  


//system signals
input  wire clk;
input  wire rst;
input  wire [1:0]  i_cpu_num;
input  wire [15:0] i_nip_nxt;
input  wire [63:0] i_word_nxt;      
input  wire        i_nip_vld;
output wire [23:0] o_p_addr;
output wire        o_clear_ibufs;
//memory interface
output wire         o_mem_rd_req;
output wire [21:0]  o_mem_rd_addr;
input  wire         i_mem_rd_addr_ack;
input  wire [63:0]  i_data_from_mem;
input  wire         i_mem_rd_ack;
output wire         o_mem_wr_req;
output wire [21:0]  o_mem_wr_addr;
output reg  [63:0]  o_data_to_mem;
input  wire         i_mem_wr_ack;
input  wire         i_mem_wr_addr_ack;

//I/O interface
output wire [15:0] o_dma_instr;
output wire        o_dma_mon_mode;
output wire        o_dma_instr_vld;
output wire [23:0] o_dma_ak;
output wire [23:0] o_dma_aj;
input  wire [23:0] i_dma_ai;
input  wire        i_dma_int;

//inter-CPU communications
output wire [2:0]  o_cln;
output wire [15:0] o_intercpu_instr;
output wire        o_intercpu_monmode;
output wire        o_intercpu_instr_vld;
input  wire        i_intercpu_issue;
output wire [63:0] o_intercpu_sj;
output wire [63:0] o_intercpu_si;
output wire [23:0] o_intercpu_ai;
input  wire [63:0] i_intercpu_si;
input  wire [23:0] i_intercpu_ai;  

//Functional unit outputs
wire [23:0] a_poplz_out;       //24-bit output of scalar population/leading zero count
wire [23:0] a_mul_out;         //24-bit output of address multiply unit
wire [23:0] a_add_out;         //24-bit output of address adder
wire [23:0] a_imm_out;         //24-bit output of immediate values
wire [63:0] s_add_out;         //64-bit output of scalar adder output
wire [63:0] s_log_out;         //64-bit output of scalar logical unit
wire [63:0] s_shft_out;        //64-bit output of scalar shift unit
wire [63:0] s_const_out;       //64-bit output of Scalar constant generator / way to get data from A regs to scalar regs
wire [63:0] s_imm_out;         //64-bit output of immediate values
wire [63:0] f_add_out;         //64-bit output of floating point adder unit
wire [63:0] f_mul_out;         //64-bit output of floating point multiplier unit
wire [63:0] f_ra_out;          //64-bit output of floating point reciprocal approximation unit

wire vlog_busy;
wire vshift_busy;
wire vadd_busy;
wire fp_mul_busy;
wire fp_add_busy;
wire fp_ra_busy;
wire vpop_busy;
wire mem_busy;

wire [63:0] v_add_out;
wire [63:0] v_log_out;
wire [63:0] v_poppar_out;
wire [63:0] v_shft_out;

//vector control registers
reg [63:0]  vector_mask;
reg [6:0]   vector_length;

//scalar register file signals
wire [2:0]  s_j_addr;       //scalar read address
wire [2:0]  s_k_addr;
wire [2:0]  s_i_addr;
wire [2:0]  s_ex_addr;
wire [63:0] s_ex_data;
wire [63:0] s_j_data;       //scalar read data
wire [63:0] s_k_data;
wire [63:0] s_i_data;
reg  [63:0] s_wr_data;       //64-bit data input to scalar register file
wire s0_pos;
wire s0_neg;
wire s0_zero;
wire s0_nzero;
wire [7:0] s_res_mask;

wire [63:0] t_jk_data;
wire [5:0]  t_wr_addr;
wire [5:0]  t_rd_addr;
wire [63:0] t_wr_data;
wire        t_result_en;


//address register file signals
wire [2:0]  a_j_addr;       //address read address
wire [2:0]  a_k_addr;
wire [2:0]  a_i_addr;
wire [2:0]  a_h_addr;
wire [2:0]  a_ex_addr;
wire [23:0] a_ex_data;
wire [23:0] a_j_data;       //address read data
wire [23:0] a_k_data;
wire [23:0] a_i_data;
wire [23:0] a_h_data;
wire [23:0] a_a0_data;
reg  [23:0] a_wr_data;       //24-bit data input to address register file
wire a0_pos;
wire a0_neg;
wire a0_zero;
wire a0_nzero;
wire [7:0] a_res_mask;

wire [23:0] b_jk_data;
wire [23:0] b_wr_data;
wire [5:0]  b_wr_addr;
wire [5:0]  b_rd_addr;
wire        b_write_en;


//branch unit signals
wire [23:0] branch_dest;
wire branch_type;
wire branch_issue;
wire take_branch;
wire rtn_jump;

//memory unit signals

wire [5:0] mem_b_rd_addr;
wire [5:0] mem_b_wr_addr;
wire       mem_b_wr_en;
wire [5:0] mem_t_rd_addr;
wire [5:0] mem_t_wr_addr;
wire [63:0] data_from_mem_to_regs;
wire        mem_type;
wire        mem_issue;

wire        mem_rd_req;
wire [63:0] data_to_mem;
wire        mem_wr_req;
wire [21:0] mem_rd_addr;
wire [21:0] mem_wr_addr;
wire        mem_rd_ack;
wire        mem_wr_ack;

//InterCPU signals
wire        intercpu_type;

//Exchange Package logic
reg [3:0] execution_mode;
reg [3:0] ex_pkg_cnt;
reg [3:0] ex_pkg_cnt_delayed;

localparam EXECUTE      = 4'b0000,
           CLEAR_IBUF   = 4'b0001,
           FETCH_EX_PKG = 4'b0010,
           LOAD_WAIT    = 4'b0011,
           STORE_EX_PKG = 4'b0100,
           DELAY        = 4'b0111,
           LOAD_EX_PKG  = 4'b0101,
			  DONE         = 4'b0110;
			  

reg [7:0]  xa;
reg [2:0]  cln;
reg          program_state;
reg [7:0]  active_xa;
reg [23:0] instr_base_addr;
reg [23:0] instr_limit_addr;
reg [23:0] data_base_addr;
reg [23:0] data_limit_addr;

wire fpadd_err;
wire fp_error = fpadd_err;			// Floating Point Error
wire or_error = 0;					// Operand Range Error

///////////////////////////////////
//      Mode Register     //
///////////////////////////////////
reg mode_ws;     //Waiting for semaphore:           bit28 - w1
reg mode_fps;    //floating point error status:     bit27 - w1
reg mode_bdm;    //bidirectional memory mode:       bit26 - w1
reg mode_imm;    //interrupt monitor mode:          bit24 - w1                                         
reg mode_ior;    //operand range error mode:        bit28 - w2
reg mode_icm;    //correctable memory error mode:   bit27 - w2
reg mode_ifp;    //floating point error mode:       bit26 - w2
reg mode_ium;    //uncorrectable memory error mode: bit25 - w2
reg mode_mm;     //monitor mode:                    bit24 - w2
 
/////////////////////////////////
//      Flag Register    // 
///////////////////////////////// 
wire [10:0]  flags;		
//individual 1-bit flags
reg flag_icp; //Interrupt from Internal CPU
reg flag_dl;  //deadlock
reg flag_pci; //programmable clock interrupt
reg flag_mcu; //MCU - set when MIOP send signal
reg flag_fpe;  //floating point error
reg flag_ore; //operand range error - set when data ref is outside DBA/DLA bounds, & en_op_range_interrupt is set
reg flag_pre; //program range error - set when instr fetch is outside IBA/ILA bounds
reg flag_me; //memory error
reg flag_ioi;  //i/o interrupt flag
reg flag_eex; //set by error exit instr (000)
reg flag_nex; //set by normal exit instr (004)

wire signal_interrupt;

//Real Time Clock
reg [63:0]  real_time_clock;

//Programmable Clock
reg  prog_clock_en;
wire clear_prog_clk_int_req;
wire set_prog_clk_int_req;
wire programmable_clock_type;
reg [31:0] icd;    //interrupt countdown counter
reg [31:0] ii;      //Interrupt interval register

//******************************************
//*           Instruction Issue            *
//*                Logic                   *
//******************************************

reg  [23:0] p_addr;
reg  [15:0] nip, lip, cip;
reg         nip_vld, lip_vld, cip_vld;

wire [6:0]  cip_instr;
wire [2:0]  cip_i, cip_j, cip_k, cip_h;
wire        issue_vld;
reg  [15:0] last_instr;
wire        two_parcel_nip, two_parcel_cip; 

//break out the current instruction parcel into fields
assign cip_instr = cip[15:9];
assign cip_i     = cip[8:6];
assign cip_j     = cip[5:3];
assign cip_k     = cip[2:0];
assign cip_h     = cip[11:9];

//A-type scheduler signals
wire [3:0]  a_result_src;
wire [3:0]  a_result_delay;
wire        a_result_en;
wire        a_wr_en;
wire [2:0]  a_result_dest;  //the a-register we're targeting
wire [2:0]  a_wr_addr;
wire        a_issue;
wire        a_type;
wire        a0_busy;

//S-type scheduler signals
wire [4:0]  s_result_src;
wire [3:0]  s_result_delay;
wire        s_result_en;
wire        s_wr_en;
wire [2:0]  s_result_dest;  //the s-register we're targeting
wire [2:0]  s_wr_addr;
wire        s_issue;
wire        s_type;
wire [7:0]  vreg_swrite;
wire        s0_busy;

//V-type scheduler signals
wire [3:0]  v_fu_delay;
wire [2:0]  v_fu;
wire [7:0]  vwrite_start;
wire [7:0]  vread_start;
wire [7:0]  vfu_start;
wire [7:0]  vreg_busy;
wire [7:0]  vreg_chain_n;
wire [7:0]  vfu_busy; 
wire [(64*8-1):0] v_rd_data;
wire        v_issue;
wire        v_type;					
wire        v_mfu_ack;		// ZS 6/5/15 The v_mem_ack from mem_fu, shall be combined with outputs form chaining etc.

// B amd T scheduler signsls from mfu
wire			b_busy;			// ZS 23/2/15. 7:02 A/S regs may not read/write to B/T while B/T are active with MEM
wire			t_busy;

wire        exchange_type;

`ifndef CRAY_1
// DMA signals
		wire dma_type;
		wire dma_issue;
`else
		wire dma_type = 0;
		wire dma_issue = 0;
`endif

always @(posedge clk)
	if (rst)
		program_state <= 0;


//////////////////////////////////////////
//     Exchange Package Logic           //
//////////////////////////////////////////
//This block handles the operating "mode" of the CPU core. It's either running
//or context switching (exchanging 'exchange packages')

always@(posedge clk)
if(rst)
   execution_mode <= CLEAR_IBUF;
else
   case(execution_mode)
	   EXECUTE:    if((exchange_type || signal_interrupt) && issue_vld)  //execute normal instructions
                     execution_mode <= CLEAR_IBUF;
//						else
//							if (i_nip_vld & two_parcel_cip & ~lip_vld)
//								execution_mode <= DONE;
      CLEAR_IBUF: if (~mem_rd_req)
							execution_mode <= FETCH_EX_PKG;       //clear the instruction buffers
		FETCH_EX_PKG://if(i_nip_vld)                        //Wait while the XP is loaded into an instruction buffer
		               execution_mode <= LOAD_WAIT;
		LOAD_WAIT: if (~mem_wr_req)
							execution_mode <= STORE_EX_PKG;           //FIXME: Wait until all instructions are finished executing
		STORE_EX_PKG:if((ex_pkg_cnt==4'b1111) && i_mem_wr_addr_ack)
		             execution_mode <= DELAY;          //Write back the context of the current process
      DELAY:execution_mode <= LOAD_EX_PKG;
      LOAD_EX_PKG: if(ex_pkg_cnt_delayed==4'b1111)
		             execution_mode <= DONE;
		DONE: execution_mode <= EXECUTE;
 default:execution_mode <= EXECUTE;
	endcase


assign o_clear_ibufs = (execution_mode == CLEAR_IBUF); // || (execution_mode == DONE);

assign exchange_type = ((cip[15:9]==7'o000) || (cip[15:9]==7'o004)) && cip_vld;

//Increment the exchange package counter as we load in the package
always@(posedge clk)
   if(rst)
	   ex_pkg_cnt <= 4'b0;
   else if(execution_mode==STORE_EX_PKG)
		ex_pkg_cnt <= ex_pkg_cnt + i_mem_wr_ack;		//1 // ZS: Burst memory, so increment
	else if(execution_mode==LOAD_EX_PKG)
	   ex_pkg_cnt <= ex_pkg_cnt + 4'b1;
	else 
	   ex_pkg_cnt <= 4'b0;

always@(posedge clk)
   ex_pkg_cnt_delayed <= ex_pkg_cnt;
		
//look up the appropriate A and S reg values to store them during the exchange sequence
assign a_ex_addr = ex_pkg_cnt;	// ZS: Not Delayed
assign s_ex_addr = ex_pkg_cnt;


//We want to store the current exchange address if we start an exchange operation
always@(posedge clk)
   if(rst)
	   active_xa <= 0;
   else if(execution_mode==EXECUTE)
	   active_xa <= xa;

//If we're in execute mode, address is controlled by program counter. Otherwise controlled
//by the exchange package management logic
assign o_p_addr = (execution_mode==EXECUTE) ? (p_addr + {instr_base_addr[21:0],2'b0}) : {10'b0,active_xa,ex_pkg_cnt,2'b00};
                     
//The memory interface is controlled in a similar fashion:

//Exchange Package details on page 3-6 of CSM-0111000
/*
reg mode_ws;     //Waiting for semaphore:           bit28 - w1                                 
reg mode_fps;    //floating point error status:     bit27 - w1    
reg mode_bdm;    //bidirectional memory mode:       bit26 - w1  
reg mode_imm;    //interrupt monitor mode:          bit24 - w1                                         
reg mode_ior;    //operand range error mode:        bit28 - w2                                      
reg mode_icm;    //correctable memory error mode:   bit27 - w2 
reg mode_ifp;    //floating point error mode:       bit26 - w2                                       
reg mode_ium;    //uncorrectable memory error mode: bit25 - w2 
reg mode_mm;     //monitor mode:                    bit24 - w2
*/

// ZS 27/2/15, 12:59: p_addr - 2, as it is twice incremented before the EXIT is issued
// Check interrupt behaviour!
always@*
   begin
	   if(execution_mode != STORE_EX_PKG)
         o_data_to_mem = data_to_mem;
		else case(ex_pkg_cnt)
		        4'b0000: o_data_to_mem = {i_cpu_num[1:0],14'b0,p_addr - 2,a_ex_data};
				  4'b0001: o_data_to_mem = {16'b0,instr_base_addr[23:5],mode_ws,mode_fps,mode_bdm,1'b0,mode_imm,a_ex_data};
				  4'b0010: o_data_to_mem = {16'b0,instr_limit_addr[23:5],mode_ior,mode_icm,mode_ifp,mode_ium,mode_mm,a_ex_data};
				  4'b0011: o_data_to_mem = {14'b0,flags[10:9],active_xa,vector_length,flags[8:0],a_ex_data};
				  4'b0100: o_data_to_mem = {16'b0,data_base_addr[23:6],1'b0,program_state,1'b0,cln[2:0],a_ex_data};
				  4'b0101: o_data_to_mem = {16'b0,data_limit_addr[23:6],6'b0,a_ex_data};
				  4'b0110: o_data_to_mem = {40'b0,a_ex_data};
				  4'b0111: o_data_to_mem = {40'b0,a_ex_data};
				  default: o_data_to_mem = s_ex_data;
	   endcase
	end

//make sure to write the exchange package back before loading the new one
wire mfu_has_rd_mem = (execution_mode==EXECUTE) || (execution_mode == CLEAR_IBUF);
wire mfu_has_wr_mem = (execution_mode!=STORE_EX_PKG);

assign o_mem_wr_req = (mfu_has_wr_mem) ? mem_wr_req : (execution_mode==STORE_EX_PKG);
assign o_mem_rd_req    = mem_rd_req && (mfu_has_rd_mem);
assign o_mem_wr_addr  = (mfu_has_wr_mem) ? mem_wr_addr    : {10'b0,active_xa,ex_pkg_cnt};
assign o_mem_rd_addr  = (mfu_has_rd_mem) ? mem_rd_addr    : {10'b0,active_xa,ex_pkg_cnt};
assign mem_rd_ack     = i_mem_rd_ack && (mfu_has_rd_mem);
assign mem_wr_ack     = i_mem_wr_ack && (mfu_has_wr_mem);


//Set up the instr/data base and limit registers: bits 16-33, words 1,2 and 4,5
always@(posedge clk)
   if(rst)
      instr_base_addr <= 24'b0;
   else if((execution_mode==LOAD_EX_PKG) && (ex_pkg_cnt_delayed==4'b0001))
      instr_base_addr <= {i_word_nxt[47:29],5'b0};

always@(posedge clk)
   if(rst)
      instr_limit_addr <= 24'hFFFFFF;
   else if((execution_mode==LOAD_EX_PKG) && (ex_pkg_cnt_delayed==4'b0010))
      instr_limit_addr <= {i_word_nxt[47:29],5'b0};

always@(posedge clk)
   if(rst)
      data_base_addr <= 24'b0;
   else if((execution_mode==LOAD_EX_PKG) && (ex_pkg_cnt_delayed==4'b0100))
      data_base_addr <= {i_word_nxt[47:29],5'b0};

always@(posedge clk)
   if(rst)
      data_limit_addr <= 24'hFFFFFF;
   else if((execution_mode==LOAD_EX_PKG) && (ex_pkg_cnt_delayed==4'b0101))
      data_limit_addr <= {i_word_nxt[47:29],5'b0};


//and exchange address
always@(posedge clk)
   if(rst)
      xa <= 8'h0;
   else if((execution_mode==LOAD_EX_PKG) && (ex_pkg_cnt_delayed==4'b0011))
      xa <= i_word_nxt[47:40];
	else if(execution_mode==EXECUTE)
      xa <= ((cip[15:6]==10'o0013) && (cip[2:0]==3'b0) && cip_vld && issue_vld && mode_mm) ? ((cip[5:3]==3'b0) ? 8'b0 : a_j_data[11:4]) : xa;

//Set the mode bits - Pg 3-9 of CSM-0111000
always@(posedge clk)
	if(rst)
		begin
			mode_ws  <= 1'b0;
			mode_fps <= 1'b0;
			mode_bdm <= 1'b0;
			mode_imm <= 1'b0;
			mode_ior <= 1'b0;
			mode_icm <= 1'b0;
			mode_ifp <= 1'b0;
			mode_ium <= 1'b0;
			mode_mm  <= 1'b0;
		end
	else if((execution_mode==LOAD_EX_PKG) && (ex_pkg_cnt_delayed==4'b0001))
		begin
			mode_ws  <= i_word_nxt[28];      
			mode_fps <= i_word_nxt[27];
			mode_bdm <= i_word_nxt[26];
			mode_imm <= i_word_nxt[24];
		end
	else if((execution_mode==LOAD_EX_PKG) && (ex_pkg_cnt_delayed==4'b0010))
		begin
			mode_ior <= i_word_nxt[28];
			mode_icm <= i_word_nxt[27];
			mode_ifp <= i_word_nxt[26];
			mode_ium <= i_word_nxt[25];
			mode_mm  <= i_word_nxt[24];
		end
	else	// ZS 27/2/15, 15:07 Putting in statuses
		begin
			mode_fps <= fp_error;
			if ((cip[15:9] == 7'o002) & cip_vld & issue_vld)
				if (cip[8:6] == 3'o5)	// 0025
					mode_bdm <= 1;
				else if (cip[8:6] == 3'o6)	// 0026
					mode_bdm <= 0;
				else
					if (~|cip[5:0])
						case (cip_i)
							3'o1 : mode_ifp <= 1;
							3'o2 : mode_ifp <= 0;
							3'o3 : mode_ior <= 1;
							3'o4 : mode_ior <= 0;
						endcase
		end

//Now configure all of the flag bits
always@(posedge clk)
   if(rst)
	   begin
			flag_icp <= 1'b0; 
			flag_dl <= 1'b0;
			flag_pci <= 1'b0;
			flag_mcu <= 1'b0;
			flag_fpe <= 1'b0;  
			flag_ore <= 1'b0;
			flag_pre <= 1'b0; 
			flag_me <= 1'b0; 
			flag_ioi <= 1'b0;  
			flag_eex <= 1'b0; 
			flag_nex <= 1'b0; 
		end
	//Load initial values from the exchange package.
	else if((execution_mode==LOAD_EX_PKG) && (ex_pkg_cnt_delayed==4'b0011))
		begin
			flag_icp <= i_word_nxt[49]; //bit 14
			flag_dl <= i_word_nxt[48]; //bit 15
			flag_pci <= i_word_nxt[32]; //bit 31
			flag_mcu <= i_word_nxt[31]; //bit 32
			flag_fpe <= i_word_nxt[30]; //bit 33
			flag_ore <= i_word_nxt[29]; //bit 34
			flag_pre <= i_word_nxt[28]; //bit 35
			flag_me  <= i_word_nxt[27]; //bit 36
			flag_ioi   <= i_word_nxt[26]; //bit 37
			flag_eex <= i_word_nxt[25]; //bit 38
			flag_nex <= i_word_nxt[24]; //bit 39
		end
	//Now we need to take care of the conditions that actually set all of these flags
	else if(execution_mode==EXECUTE)
			begin
				//Interrupt from Internal CPU - Set when another CPU issues instr 001401
				flag_icp <= 1'b0; 
				//Deadlock - set when all CPUs in a cluster are holding issue on a test & set instr
				flag_dl <= 1'b0;
				//Programmable clock interrupt - set when the interrupt countdown counter in
				//the programmable clock equals 0.
				flag_pci <= mode_mm ? 1'b0 : ((flag_pci || set_prog_clk_int_req) && !clear_prog_clk_int_req);
				//MCU interrupt - set when the MIOP sends this signal
				flag_mcu <= 1'b0;
				//Floating Point Error - set when the floating point range error occurs in any of
				//the floating-point functional units and the enable floating-point interrupt flag is set. 
				flag_fpe <= mode_mm ? 1'b0 : mode_ifp & fp_error;
				//Operand Range Error - set when the data reference is made outside the boundaries of 
				//the data base address and data limit address registers, and the Enable Operand Range
				//Interrupt flag is set. 
				flag_ore <= mode_mm ? 1'b0 : mode_ior & or_error;
				//Program Range Error - set when an instruction fetch is made outside the boundaries of 
				//the Instruction Base Address and Instruction Limit Address registers.
				flag_pre <= 1'b0;
				//Memory Error - set when a correctable or uncorrectable memory error occurs and the
				//corresponding enable memory error mode bit is set in the M register
				flag_me  <= 1'b0;
				//I/O Interrupt flag - set when a 6 Mbyte channel or the 1250 Mbyte channel completes a transfer
				flag_ioi <= mode_mm ? 1'b0 : i_dma_int;
				//Error Exit - set by an error exit instruction (000)
				flag_eex <= /* mode_mm ? 1'b0 : */ (((cip[15:9]==7'o000) && cip_vld && issue_vld) || flag_eex);	// ZS Flag eex/nex in mm also
				//Normal Exit - set by a normal exit instruction (004)
				flag_nex <= /* mode_mm ? 1'b0 : */ (((cip[15:9]==7'o004) && cip_vld && issue_vld) || flag_nex);		
			end

//Monitor_mode (mode_mm) inhibits all interrupts except memory errors, error exit or normal exit
//Interrupt Monitor Mode (mode_imm) re-enables everything except PC, MCU, I/O and ICP errors
//Interrupt sources
//Deadlock: !mode_mm || mode_imm 
//PCI: !mode_mm 
//MCU: !mode_mm 
//FPE: !mode_mm || mode_imm 
//ORE: !mode_mm || mode_imm 
//PRE: !mode_mm || mode_imm 
//ME:  1'b1 
//IOI: !mode_mm 
//EEX: 1'b1 
//NEX: 1'b1 

//page 3-12 of Cray XMP-1 system programmer reference manual 
//Non ME flags can only be set if not in monitor mode 
//Except for the ME flag, if the program is in monitor mode 
//and the conditions for setting an F register are present, the 
//flag remains cleared and no exchange sequence is initiated. 


assign flags[10:0] = {flag_icp,flag_dl,flag_pci,flag_mcu,flag_fpe,flag_ore,flag_pre,flag_me,flag_ioi,flag_eex,flag_nex};

//Fire an interrupt when the current instruction executes, we're not in monitor mode, and a flag has been set
// ZS 1/3/15, 4:43 - however, the flag_eex and flag_nex shall not trigger the interrupt (specifically not NEX!)
assign signal_interrupt = (execution_mode==EXECUTE) && |flags[10:2] && !mode_mm;

//Cluster Number
always@(posedge clk)
   if(rst)
	   cln <= 3'b0;
	else if((execution_mode==LOAD_EX_PKG) && (ex_pkg_cnt_delayed==4'b0100))
		cln <= i_word_nxt[26:24];
	else if( (cip[15:6]==10'b0000001100) && (cip[2:0]==3'b011) && cip_vld)
	   cln <= cip[5:3];


//1) accept the incoming data from the instruction buffers

always@(posedge clk)
   if(rst || (execution_mode == DONE))
	   begin
		   nip     <= 16'b0;
			cip     <= 16'b0;
			lip     <= 16'b0;
			nip_vld <= 1'b0;
			cip_vld <= 1'b0;
			lip_vld <= 1'b0;
		end
   else	
		if (i_nip_vld & issue_vld)
			begin
				nip     <= i_nip_nxt;
				lip     <= i_nip_nxt;
				cip     <= nip;
				lip_vld <= take_branch ? 1'b0 : two_parcel_nip; //1'b1; //nip_vld;   //Only set it if you have a two_parcel_nip, and you haven't just branched
				nip_vld <= (two_parcel_nip || take_branch) ? 1'b0 : 1'b1;            //Set it if you didn't branch and the current cycle holds a one parcel nip
				cip_vld <= take_branch ? 1'b0 : (nip_vld && (execution_mode==EXECUTE));
			end
	/*
	else
		if (i_nip_vld & two_parcel_cip & ~lip_vld)
			begin
				nip     <= i_nip_nxt;
				lip     <= i_nip_nxt;
				lip_vld <= 1'b1;
				nip_vld <= 1'b0;
				cip_vld <= 1'b1;
			end
	*/
	//To catch the case where instruction issues during an I-cache miss.
	//Set cip_vld=0, preserve everything else.
	else if (issue_vld)
		begin
			nip     <= nip;
			lip     <= lip;
			cip     <= nip; //16'b0;
			lip_vld <= 1'b0; //lip_vld;
			nip_vld <= nip_vld; //take_branch ? 1'b0 : i_nip_vld; //nip_vld;
			cip_vld <= 0; //take_branch ? 1'b0 : (nip_vld && (execution_mode==EXECUTE)); //1'b0;
		end

//Two parcel instructions
assign two_parcel_nip = nip_vld && ((nip[15:10]==6'b000011)||   //006-007
                       (nip[15:12]==4'b0001)  ||   //010-017
 							  (nip[15:10]==6'b001000)||   //020-021
							  (nip[15:10]==6'b010000)||   //040-041
							  (nip[15:14]==2'b10)) ;       //100-137

assign two_parcel_cip = cip_vld && ((cip[15:10]==6'b000011)||   //006-007
                       (cip[15:12]==4'b0001)  ||   //010-017
 							  (cip[15:10]==6'b001000)||   //020-021
							  (cip[15:10]==6'b010000)||   //040-041
							  (cip[15:14]==2'b10)) ;       //100-137
always@(posedge clk)
   last_instr <= cip;

`ifdef SSCHED	
//Track S-type related reservations, destination data and if we can issue or not
s_scheduler ssched(.clk(clk),
            .rst(rst),
            .i_cip(cip),
				.i_cip_vld(cip_vld),
            .i_issue_vld(issue_vld),
            .o_s_issue(s_issue),
            .o_s_result_en(s_result_en),
            .o_s_result_src(s_result_src),
            .o_s_result_dest(s_result_dest),
            .o_s_type(s_type),
				.i_vreg_busy(vreg_busy),
				.o_vreg_write(vreg_swrite),
				.o_s0_busy(s0_busy),
				.o_s_res_mask(s_res_mask));
`else

s_scheduler ssched(.clk(0),
            .rst(0),
            .i_cip(0),
				.i_cip_vld(0),
            .i_issue_vld(0),
            .o_s_issue(s_issue),
            .o_s_result_en(s_result_en),
            .o_s_result_src(s_result_src),
            .o_s_result_dest(s_result_dest),
            .o_s_type(s_type),
				.i_vreg_busy(0),
				.o_vreg_write(vreg_swrite),
				.o_s0_busy(s0_busy),
				.o_s_res_mask(s_res_mask));
`endif

/*
Instruction 073i01 sets the low-order 32 bits to l's and returns the
following status to the high-order bits of Si:
Si Bit
2^63	Clustered, CLN#O (CL)
2^57	Program state (PS)
2^51	Floating-point error occurred (FPS)
2^50	Floating-point interrupt enabled (IFP)
2^49	Operand range interrupt enabled (lOR)
2^48	Bidirectional memory enabled (BDM)
2^40t	Processor number (PN) (This bit is always 0.)
2^33t	Cluster number bit 1 (CLN1)
2^32t	Cluster number bit 0 (CLNO)

t These bit positions return a value of 0 if not executed in monitor mode.

CSM-0111000-B-CRAY_XMP_1_System_Programmer_Reference_Manual-August_1986
*/

//Now let's get the correct data to write
always@*
begin
   if(execution_mode==EXECUTE)
        case(s_result_src[4:0])
                SBUS_IMM:     s_wr_data = s_imm_out;
                SBUS_COMP_IMM:s_wr_data = s_imm_out;
                SBUS_S_LOG:   s_wr_data = s_log_out;
                SBUS_S_SHIFT: s_wr_data = s_shft_out;
                SBUS_S_ADD:   s_wr_data = s_add_out;
                SBUS_FP_ADD:  s_wr_data = f_add_out;
                SBUS_FP_MULT: s_wr_data = f_mul_out;
                SBUS_FP_RA:   s_wr_data = f_ra_out;
                SBUS_CONST_GEN:s_wr_data= s_const_out;
                SBUS_RTC:     s_wr_data = real_time_clock;
                SBUS_V_MASK:  s_wr_data = vector_mask;
                SBUS_T_BUS:   s_wr_data = t_jk_data;
                SBUS_V0:      s_wr_data = v_rd_data[63:0];
					 SBUS_V1:      s_wr_data = v_rd_data[127:64];
					 SBUS_V2:      s_wr_data = v_rd_data[191:128];
					 SBUS_V3:      s_wr_data = v_rd_data[255:192];
		          SBUS_V4:      s_wr_data = v_rd_data[319:256];
		          SBUS_V5:      s_wr_data = v_rd_data[383:320];
		          SBUS_V6:      s_wr_data = v_rd_data[447:384];
		          SBUS_V7:      s_wr_data = v_rd_data[511:448];
                SBUS_MEM:    s_wr_data = data_from_mem_to_regs;
					 SBUS_INTERCPU:s_wr_data = i_intercpu_si;
					 SBUS_HI_SR:   s_wr_data = {|cln, 5'b0, program_state, 5'b0, mode_fps, mode_ifp, mode_ior, mode_bdm, 
														 6'b0, i_cpu_num[1:0],6'b0,cln[2:0],32'b1};
                default:      s_wr_data = 64'b0;
        endcase
	else
	   s_wr_data = i_word_nxt;
end

// Delay towards A/S regs, no delay from A/S regs
reg [3:0] s_ex_addr_delayed;
always @(posedge clk)
	s_ex_addr_delayed = s_ex_addr;
	
assign s_wr_en   = (execution_mode==EXECUTE) ? s_result_en   : ((execution_mode==LOAD_EX_PKG) && ex_pkg_cnt_delayed[3]);
assign s_wr_addr = (execution_mode==EXECUTE) ? s_result_dest : s_ex_addr_delayed;

wire s_conflict = (cip[15:9]==7'b0010011) && (cip[2:0]==3'b0) && s_res_mask[cip[5:3]]; // ZS 9/5/14


`ifdef ASCHED	
//Track A-type related reservations, destination data and if we can issue or not
a_scheduler asched(.clk(clk),
                   .rst(rst),
                   .i_cip(cip),
                   .i_cip_vld(cip_vld),
                   .i_lip_vld(lip_vld),
                   .i_issue_vld(issue_vld),
						 .i_s_conflict(s_conflict),				// ZS
                   .o_a_issue(a_issue),
                   .o_a_result_en(a_result_en),
                   .o_a_result_src(a_result_src),
                   .o_a_result_dest(a_result_dest),
                   .o_a_type(a_type),
			 .o_a0_busy(a0_busy),
			 .o_a_res_mask(a_res_mask));
`else
a_scheduler asched(.clk(0),
                   .rst(0),
                   .i_cip(0),
                   .i_cip_vld(0),
                   .i_lip_vld(0),
                   .i_issue_vld(0),
						 .i_s_conflict(0),
                   .o_a_issue(a_issue),
                   .o_a_result_en(a_result_en),
                   .o_a_result_src(a_result_src),
                   .o_a_result_dest(a_result_dest),
                   .o_a_type(a_type),
			 .o_a0_busy(a0_busy),
			 .o_a_res_mask(a_res_mask));
`endif

always@*
begin
   if(execution_mode == EXECUTE)
	   case(a_result_src[3:0])
		ABUS_IMM:     a_wr_data = a_imm_out;
		ABUS_COMP_IMM:a_wr_data = a_imm_out;
		ABUS_SIMM:    a_wr_data = {18'b0,last_instr[5:0]};
		ABUS_S_BUS:   a_wr_data = a_imm_out;
		ABUS_B_BUS:   a_wr_data = b_jk_data;
		ABUS_S_POP:   a_wr_data = a_poplz_out;
		ABUS_A_ADD:   a_wr_data = a_add_out;
		ABUS_A_MULT:  a_wr_data = a_mul_out;
		ABUS_CHANNEL: a_wr_data = i_dma_ai[23:0];
		ABUS_MEM:     a_wr_data = data_from_mem_to_regs[23:0];
		ABUS_INTERCPU:a_wr_data = i_intercpu_ai;
		default:      a_wr_data = 24'b0;
	   endcase
	else
	   a_wr_data = i_word_nxt[23:0];
end

// Delay towards A/S regs, no delay from A/S regs
reg [3:0] a_ex_addr_delayed;
always @(posedge clk)
	a_ex_addr_delayed = a_ex_addr;
	
assign a_wr_en = (execution_mode==EXECUTE) ? a_result_en : ((execution_mode==LOAD_EX_PKG) && !ex_pkg_cnt_delayed[3]);
assign a_wr_addr = (execution_mode==EXECUTE) ? a_result_dest : a_ex_addr_delayed;


`ifdef VSCHED	
//Track V-type instructions
v_scheduler vsched(
				.clk(clk),
				.i_cip(cip),
            .i_cip_vld(cip_vld), 
				.i_a_res_mask(a_res_mask),
				.o_fu_delay(v_fu_delay), 
				.o_fu(v_fu), 
				.o_vwrite_start(vwrite_start),
				.o_vread_start(vread_start), 
				.o_vfu_start(vfu_start),
				.o_v_issue(v_issue),
				.i_vreg_busy(vreg_busy),
				.i_vreg_chain_n(vreg_chain_n),
				.i_vfu_busy(vfu_busy) //,
				//.i_vl (vector_length)
				);
`else
assign v_fu_delay = 0;
assign v_fu = 0;
assign vwrite_start = 0;
assign vread_start = 0;
assign vfu_start = 0;
assign v_issue = 0;
`endif
/*
localparam VLOG      = 3'b000,   //vector logical
           VSHIFT    = 3'b001,	 //vector shift
			  VADD      = 3'b010,
	        FP_MUL    = 3'b011,   //FP multiply
	        FP_ADD    = 3'b100,   //FP adder 
	        FP_RA     = 3'b101,   //FP recip. approx.
	        VPOP      = 3'b110,   //vector pop count / parity
	         MEM      = 3'b111;
				
				vfu_start
*/
assign vfu_busy[0] = vlog_busy;
assign vfu_busy[1] = vshift_busy;
assign vfu_busy[2] = vadd_busy;
assign vfu_busy[3] = fp_mul_busy;
assign vfu_busy[4] = fp_add_busy;
assign vfu_busy[5] = fp_ra_busy;
assign vfu_busy[6] = vpop_busy;
assign vfu_busy[7] = mem_busy;
assign v_type = (cip[15:14] == 2'b11);


//check if it's free to issue
// ZS 22/2/15, 19:00
//
// When the buffers are empty there is a valid CIP in the processor, so we shall issue the instruction
// Therefore we issue whenever there is i_nip_vld or the cip_vld.
//
// ZS 27/2/15, 0:28
//
// We may issue all S and A instructions while T or B are busy, except B/T R/W instructions
//
// ZS 18/3/2015, 18:12 - wrong decoding of s_t_type, corrected
wire a_b_type = (cip[15:10] == 5'b001010);		// Bjk Ai, Ai Bjk, repeated in asched
wire s_t_type = (cip[15:10] == 5'b011110);		// Tjk Si, S1 Tjk, repeated in ssched
wire branch_b_type = (cip[15:11] == 5'b00001) & cip[9];
wire cmr_type = (cip == 16'o002700);
					
assign issue_vld = ((s_issue && s_type && mem_issue && mem_type) ||
                   (s_issue && s_type && !mem_type && !(t_busy & s_t_type)) ||
						 (a_issue && a_type && mem_issue && mem_type) ||
                   (a_issue && a_type && !mem_type &&!(b_busy & a_b_type)) ||	
						 (v_issue && v_type && mem_issue && mem_type) ||		// ZS 3/5/2014 2:01 v_issue/type has to behave the same as
						 (v_issue && v_type && !mem_type) ||						// a_ and s_
						 (branch_issue && branch_type & ~(b_busy & branch_b_type)) ||	// Cannot use R or J Bxx when B busy
						 (mem_issue && mem_type && !s_type && !a_type && !v_type) ||		// ZS 14/2/15 !v_type same as !s_ and !a_
						 (i_intercpu_issue && intercpu_type) ||
						 (dma_issue && dma_type) ||
						 exchange_type ||
						 !(s_type || a_type || v_type || branch_type || mem_type || exchange_type || intercpu_type || dma_type | s_t_type | a_b_type) ||
						 !cip_vld)
						 & (cip_vld | i_nip_vld)
						 & ~ (two_parcel_cip & ~lip_vld)
						 & ~ (cmr_type & (mem_rd_req | mem_wr_req));
						 


//////////////////////////////////////////////////
//           Register Files                     //
//////////////////////////////////////////////////

`ifdef V_RF
// ZS 6/2/15
// v_mem_ack shall be a combination of v_mfu_ack and readyness from different FUs.
// when v_mfu_ack is not active, i.e. the we are waiting for memory, we have to think about the behaviour of the whole CPU,
// as chaining could exhaust available data
// As now we have 1-cycle synchrounous memory, we just take it as granted that the memory (or other FUs) is (are) ready.
//
// The above changed! 16/2/15, 10:43

//wire v_mem_ack = (v_mfu_ack && mem_type) || !mem_type;
wire v_mem_ack = v_mfu_ack;
//wire v_mem_ack = 1;

//The eight vector register files
vec_regfile v0(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[63:0]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
					.i_mem_ack(v_mem_ack),
               .i_vread_start(vread_start[0]),
					.i_vwrite_start(vwrite_start[0]),
					.i_swrite_start(vreg_swrite[0]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[0]),
					.o_chain_n(vreg_chain_n[0]));

vec_regfile v1(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[127:64]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
					.i_mem_ack(v_mem_ack),
               .i_vread_start(vread_start[1]),
					.i_vwrite_start(vwrite_start[1]),
					.i_swrite_start(vreg_swrite[1]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[1]),
					.o_chain_n(vreg_chain_n[1]));

vec_regfile v2(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[191:128]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
					.i_mem_ack(v_mem_ack),
               .i_vread_start(vread_start[2]),
					.i_vwrite_start(vwrite_start[2]),
					.i_swrite_start(vreg_swrite[2]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[2]),
					.o_chain_n(vreg_chain_n[2]));

vec_regfile v3(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[255:192]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
					.i_mem_ack(v_mem_ack),
               .i_vread_start(vread_start[3]),
					.i_vwrite_start(vwrite_start[3]),
					.i_swrite_start(vreg_swrite[3]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[3]),
					.o_chain_n(vreg_chain_n[3]));

vec_regfile v4(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[319:256]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
					.i_mem_ack(v_mem_ack),
               .i_vread_start(vread_start[4]),
					.i_vwrite_start(vwrite_start[4]),
					.i_swrite_start(vreg_swrite[4]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[4]),
					.o_chain_n(vreg_chain_n[4]));

vec_regfile v5(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[383:320]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
					.i_mem_ack(v_mem_ack),
               .i_vread_start(vread_start[5]),
					.i_vwrite_start(vwrite_start[5]),
					.i_swrite_start(vreg_swrite[5]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[5]),
					.o_chain_n(vreg_chain_n[5]));

vec_regfile v6(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[447:384]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
					.i_mem_ack(v_mem_ack),
               .i_vread_start(vread_start[6]),
					.i_vwrite_start(vwrite_start[6]),
					.i_swrite_start(vreg_swrite[6]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[6]),
					.o_chain_n(vreg_chain_n[6]));

vec_regfile v7(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[511:448]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
					.i_mem_ack(v_mem_ack),
               .i_vread_start(vread_start[7]),
					.i_vwrite_start(vwrite_start[7]),
					.i_swrite_start(vreg_swrite[7]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[7]),
					.o_chain_n(vreg_chain_n[7]));
`else
assign v_rd_data[511:0] = 512'b0;
assign vreg_busy = 8'b0;
assign vreg_chain_n = 8'b0;
`endif

`ifdef S_RF
s_regfile #(.WIDTH(64),.DEPTH(8),.LOGDEPTH(3))
        s_rf(.clk(clk),
		 .rst(rst),
             .i_j_addr(cip_j),
             .i_k_addr(cip_k),
             .i_i_addr(cip_i),
             .i_ex_addr(s_ex_addr),
             .o_ex_data(s_ex_data),
             .o_j_data(s_j_data),
             .o_k_data(s_k_data),
             .o_i_data(s_i_data),
             .i_wr_addr(s_wr_addr),
             .i_wr_data(s_wr_data),
             .i_wr_en(s_wr_en),
             .o_s0_pos(s0_pos),
             .o_s0_neg(s0_neg),
             .o_s0_zero(s0_zero),
             .o_s0_nzero(s0_nzero));
`else
s_regfile #(.WIDTH(64),.DEPTH(8),.LOGDEPTH(3))
        s_rf(.clk(0),
		 .rst(0),
             .i_j_addr(0),
             .i_k_addr(0),
             .i_i_addr(0),
             .i_ex_addr(0),
             .o_ex_data(s_ex_data),
             .o_j_data(s_j_data),
             .o_k_data(s_k_data),
             .o_i_data(s_i_data),
             .i_wr_addr(0),
             .i_wr_data(0),
             .i_wr_en(0),
             .o_s0_pos(s0_pos),
             .o_s0_neg(s0_neg),
             .o_s0_zero(s0_zero),
             .o_s0_nzero(s0_nzero));
`endif

`ifdef T_RF
wire t_wr_en;

t_regfile_hard #(.WIDTH(64),.DEPTH(64),.LOGDEPTH(6))
        t_rf(.clk(clk),
        .i_jk_addr(t_rd_addr),
        .o_jk_data(t_jk_data),
        .i_wr_addr(t_wr_addr),
        .i_wr_data(t_wr_data),
        .i_wr_en(t_wr_en));
`else
assign t_jk_data = 0;
`endif

assign t_rd_addr = t_busy ? mem_t_rd_addr : {cip_j,cip_k};
assign t_wr_addr = t_busy ? mem_t_wr_addr : {cip_j,cip_k};

//We can accept data from the S reg-file or from memory
// ZS 18/3/2015, 17:57
// However, if the appropriate S register is not ready, we have to wait !

assign t_wr_data = t_busy ? data_from_mem_to_regs: s_i_data;
assign t_wr_en = t_result_en | ((cip_instr==7'o075) & cip_vld & issue_vld);

`ifdef A_RF
a_regfile #(.WIDTH(24),.DEPTH(8),.LOGDEPTH(3))
        A_rf(.clk(clk),
             .rst(rst),
             .i_j_addr(cip_j),
             .i_k_addr(cip_k),
             .i_i_addr(cip_i),
             .i_h_addr(cip_h),
             .i_ex_addr(a_ex_addr),
             .o_ex_data(a_ex_data),
             .o_j_data(a_j_data),
             .o_k_data(a_k_data),
             .o_i_data(a_i_data),
             .o_h_data(a_h_data),
             .o_a0_data(a_a0_data),
             .i_wr_addr(a_wr_addr),
             .i_wr_data(a_wr_data),
             .i_wr_en(a_wr_en),
             .o_a0_pos(a0_pos),
             .o_a0_neg(a0_neg),
             .o_a0_zero(a0_zero),
             .o_a0_nzero(a0_nzero));
`else
a_regfile #(.WIDTH(24),.DEPTH(8),.LOGDEPTH(3))
        A_rf(.clk(0),
             .rst(0),
             .i_j_addr(0),
             .i_k_addr(0),
             .i_i_addr(0),
             .i_h_addr(0),
             .i_ex_addr(0),
             .o_ex_data(a_ex_data),
             .o_j_data(a_j_data),
             .o_k_data(a_k_data),
             .o_i_data(a_i_data),
             .o_h_data(a_h_data),
             .o_a0_data(a_a0_data),
             .i_wr_addr(0),
             .i_wr_data(0),
             .i_wr_en(0),
             .o_a0_pos(a0_pos),
             .o_a0_neg(a0_neg),
             .o_a0_zero(a0_zero),
             .o_a0_nzero(a0_nzero));
`endif

`ifdef B_RF
b_regfile #(.WIDTH(24),.DEPTH(64),.LOGDEPTH(6))
        b_rf(.clk(clk),
        .i_jk_addr(b_rd_addr),
	     .o_jk_data(b_jk_data),
        .i_wr_addr(b_wr_addr),
        .i_wr_data(b_wr_data),
        .i_wr_en(b_write_en),
		  .i_cur_p(p_addr),
		  .i_rtn_jump(rtn_jump));
`else
b_regfile #(.WIDTH(24),.DEPTH(64),.LOGDEPTH(6))
        b_rf(.clk(0),
        .i_jk_addr(0),
	     .o_jk_data(b_jk_data),
        .i_wr_addr(0),
        .i_wr_data(0),
        .i_wr_en(0),
		  .i_cur_p(0),
		  .i_rtn_jump(0));
`endif

//Figure out when and what we should write into the B register file
assign b_wr_addr  = b_busy ? mem_b_wr_addr : {cip_j,cip_k};
assign b_wr_data  = b_busy ? data_from_mem_to_regs[23:0] : a_i_data;
assign b_write_en = mem_b_wr_en | ((cip_instr==7'o025) & cip_vld & issue_vld);
//and figure out what address to read from
//assign b_rd_addr = b_busy ? mem_b_rd_addr : {cip_j,cip_k}; 	// ZS 27/2/15, 3:19: This MUST be in MFU, as we have to release the b_addr
assign b_rd_addr = mem_b_rd_addr; 										// before releasing the b_busy !!! (for e.g. when branch waits on b_busy)


//////////////////////////////////////////////////
//           Vector Units                       //
//////////////////////////////////////////////////

`ifdef VADD
//Vector Addition unit
vector_add vadd(.clk(clk),           //system clock input
                .rst(rst),
                .i_start(vfu_start[2]),          //signal start of new vector operation
                .i_instr(cip_instr),          //7-bit instruction input
					 .i_vl(vector_length),
					 .i_j(cip_j),
					 .i_k(cip_k),
                .i_sj(s_j_data),  //64-bit sj input
                .i_v0(v_rd_data[63:0]),
                .i_v1(v_rd_data[127:64]),
                .i_v2(v_rd_data[191:128]),
                .i_v3(v_rd_data[255:192]),
                .i_v4(v_rd_data[319:256]),
                .i_v5(v_rd_data[383:320]),
                .i_v6(v_rd_data[447:384]),
                .i_v7(v_rd_data[511:448]),					 
                .o_result(v_add_out),        //64-bit output
					 .o_busy(vadd_busy));
`else
assign v_add_out = 64'b0;
assign vadd_busy = 0;
`endif

`ifdef VLOG
//Vector Logical unit
vector_logical vlog(.clk(clk),               //system clock input
                    .rst(rst),
                    .i_start(vfu_start[0]),  //signal start of new vector operation
                    .i_instr(cip_instr),     //7-bit instruction input
						  .i_vl(vector_length),    //7-bit vector length
                    .i_i(cip_i),             //3-bit i input
                    .i_j(cip_j),             //3-bit j input
                    .i_k(cip_k),             //3-bit k input
                    .i_sj(s_j_data),         //64-bit sj input
                    .i_v0(v_rd_data[63:0]),
                    .i_v1(v_rd_data[127:64]),
                    .i_v2(v_rd_data[191:128]),
                    .i_v3(v_rd_data[255:192]),
                    .i_v4(v_rd_data[319:256]),
                    .i_v5(v_rd_data[383:320]),
                    .i_v6(v_rd_data[447:384]),
                    .i_v7(v_rd_data[511:448]),		
                    .i_vm(vector_mask),      //64-bit vector mask input
                    .o_result(v_log_out),    //64-bit output
						  .o_busy(vlog_busy));     //FU reserved signal
`else
assign v_log_out = 64'b0;
assign vlog_busy = 0;
`endif

`ifdef VPOPPAR
//Vector Population Count and parity unit	    
vector_pop_parity vpoppar(.clk(clk),        //system clock input
                          .rst(rst),
                          .i_start(vfu_start[6]),       //signal to start a new vector operation
								  .i_vl(vector_length),
                          .i_k(cip_k),           //3-bit k field input
								  .i_j(cip_j),
                          .i_v0(v_rd_data[63:0]),
                          .i_v1(v_rd_data[127:64]),
                          .i_v2(v_rd_data[191:128]),
                          .i_v3(v_rd_data[255:192]),
                          .i_v4(v_rd_data[319:256]),
                          .i_v5(v_rd_data[383:320]),
                          .i_v6(v_rd_data[447:384]),
                          .i_v7(v_rd_data[511:448]),		  
								  .o_busy(vpop_busy),
                          .o_result(v_poppar_out));     //64-bit output
`else
assign v_poppar_out = 64'b0;
assign vpop_busy = 0;
`endif

//Vector Shift unit
wire [23:0] v_shft_ak_in = a_k_data;

`ifdef VSHIFT
vector_shift vshift(.clk(clk),                 //system clock input
                    .rst(rst),
                    .i_start(vfu_start[1]),    //signal start of new vector operation
                    .i_instr(cip_instr),       //7-bit instruction input
						  .i_vl(vector_length),      //7-bit vector length
                    .i_k(cip_k),               //3-bit k input
						  .i_j(cip_j),
                    .i_v0(v_rd_data[63:0]),
                    .i_v1(v_rd_data[127:64]),
                    .i_v2(v_rd_data[191:128]),
                    .i_v3(v_rd_data[255:192]),
                    .i_v4(v_rd_data[319:256]),
                    .i_v5(v_rd_data[383:320]),
                    .i_v6(v_rd_data[447:384]),
                    .i_v7(v_rd_data[511:448]),			
                    .i_ak(v_shft_ak_in),              //24-bit ak input
                    .o_result(v_shft_out),         //64-bit output
						  .o_busy(vshift_busy));
`else
assign v_shft_out = 64'b0;
assign vshift_busy = 0;
`endif


///////////////////////////////////////////////
//          Floating Point Units             //
///////////////////////////////////////////////


`ifdef FADD
//Floating Point Addition unit
float_add  fadd  (.clk(clk),       //system clock input
                  .rst(rst),
                  .i_cip(cip),      //7-bit instruction input
						.i_vstart(vfu_start[4]),
						.i_vector_length(vector_length),
                  .i_v0(v_rd_data[63:0]),
                  .i_v1(v_rd_data[127:64]),
                  .i_v2(v_rd_data[191:128]),
                  .i_v3(v_rd_data[255:192]),
                  .i_v4(v_rd_data[319:256]),
                  .i_v5(v_rd_data[383:320]),
                  .i_v6(v_rd_data[447:384]),
                  .i_v7(v_rd_data[511:448]),
                  .i_sj(s_j_data),         //64-bit sj register input
                  .i_sk(s_k_data),         //64-bit sk register input
                  .o_result(f_add_out),       //64-bit output
						.o_busy(fp_add_busy),
                  .err(fpadd_err));         //error output
`else
assign f_add_out = 64'b0;
assign fp_add_busy = 0;
`endif

`ifdef FMULT
//Floating Point Multiply unit
fast_float_mult fmult(.clk(clk),        //system clock input 
                 .rst(rst),
                 .i_cip(cip),       //current instruction parcel
					  .i_vstart(vfu_start[3]),
					  .i_vector_length(vector_length),
					  .i_v0(v_rd_data[63:0]),
                 .i_v1(v_rd_data[127:64]),
                 .i_v2(v_rd_data[191:128]),
                 .i_v3(v_rd_data[255:192]),
                 .i_v4(v_rd_data[319:256]),
                 .i_v5(v_rd_data[383:320]),
                 .i_v6(v_rd_data[447:384]),
                 .i_v7(v_rd_data[511:448]),
                 .i_sj(s_j_data),          //64-bit sj register input
                 .i_sk(s_k_data),          //64-bit sk register input
                 .o_result(f_mul_out),     //64-bit output
                 .o_busy(fp_mul_busy));
`else
assign f_mul_out = 64'b0;
assign fp_mul_busy = 0;
`endif

`ifdef FRECIP
//Floating Point Reciprocal Approximation unit
float_recip frecip(.clk(clk),      //system clock input
                   .rst(rst),
						 .i_vstart(vfu_start[5]),
						 .i_vector_length(vector_length),
						 .i_v0(v_rd_data[63:0]),
                   .i_v1(v_rd_data[127:64]),
                   .i_v2(v_rd_data[191:128]),
                   .i_v3(v_rd_data[255:192]),
                   .i_v4(v_rd_data[319:256]),
                   .i_v5(v_rd_data[383:320]),
                   .i_v6(v_rd_data[447:384]),
                   .i_v7(v_rd_data[511:448]),
                   .i_sj(s_j_data),            //64-bit sj register input
						 .i_j(cip_j),
                   .o_result(f_ra_out),        //64-bit output (14 cycles later)
						 .o_busy(fp_ra_busy));
`else
assign f_ra_out = 64'b0;
assign fp_ra_busy = 0;
`endif

//////////////////////////////////////////////////
//           Scalar Units                       //
//////////////////////////////////////////////////


`ifdef SADD
//Scalar Addition unit
scalar_add sadd(.clk(clk),                    //system clock input
                .i_instr(cip_instr),          //7-bit instruction input
                .i_sj(s_j_data),              //64-bit sj input
                .i_sk(s_k_data),              //64-bit sk input
                .o_result(s_add_out));        //64-bit output
`else
assign s_add_out = 64'b0;
`endif

`ifdef SLOG
//Scalar Logical unit
scalar_logical slog(.clk(clk),                //system clock input
							.i_s_type (s_type),
                    .i_instr(cip_instr),      //7-bit instruction input
                    .i_j(cip_j),              //3-bit j input
                    .i_k(cip_k),              //3-bit k input
                    .i_sj(s_j_data),          //64-bit sj input
                    .i_sk(s_k_data),          //64-bit sk input
						  .i_si(s_i_data),          //64-bit si input
                    .o_result(s_log_out));    //64-bit output
`else
assign s_log_out = 64'b0;
`endif

`ifdef SPOPLZ
//Scalar Population Count and Leading-Zero Count unit
scalar_pop_lz spoplz(.clk(clk),               //system clock input
                     .i_instr(cip_instr),     //7-bit instruction input
                     .i_sj(s_j_data),         //64-bit sj input
                     .o_result(a_poplz_out)); //24-bit output
`else
assign a_poplz_out = 64'b0;
`endif

`ifdef SSHIFT
//Scalar Shift unit
scalar_shift sshift(.clk(clk), 
							.i_s_type (s_type),
                    .i_instr(cip_instr),
                    .i_j(cip_j),
                    .i_k(cip_k),
                    .i_si(s_i_data), 
                    .i_sj(s_j_data), 
                    .i_ak(a_k_data), 
                    .o_result(s_shft_out));
`else
assign s_shft_out = 64'b0;
`endif

`ifdef SCONST
s_const_gen sconst(.clk(clk),
                   .i_j(cip_j),
						 .i_ak(a_k_data),
						 .o_result(s_const_out));
`else
assign s_const_out = 64'b0;
`endif

//////////////////////////////////////////////////
//          Address Units                       //
//////////////////////////////////////////////////

`ifdef IGEN
//This block actually generates immediate values for both
//address and scalar instructions
imm_gen  igen(.clk(clk),
              .i_instr(cip_instr),
				  .i_cip_j(cip_j),
				  .i_cip_k(cip_k),
				  .i_lip(lip),
				  .i_sj(s_j_data),
			     .o_a_result(a_imm_out),
				  .o_s_result(s_imm_out));
`else
assign a_imm_out = 64'b0;
assign s_imm_out = 64'b0;
`endif

`ifdef AADD
//Address Addition unit
addr_add  aadd(.clk(clk),          //system clock input
               .i_instr(cip_instr),         //7-bit instruction input
               .i_aj(a_j_data),            //24-bit aj input
               .i_ak(a_k_data),            //24-bit ak input
               .o_result(a_add_out));       //24-bit output
`else
assign a_add_out = 64'b0;
`endif

`ifdef AMULT
//Address Multiply unit
fast_addr_mult amult(.clk(clk),         //system clock input
                .i_aj(a_j_data),           //24-bit aj input
                .i_ak(a_k_data),           //24-bit ak input
                .o_result(a_mul_out));      //24-bit output
`else
assign a_mul_out = 64'b0;
`endif

`define MFU
`ifdef MFU
/////////////////////////////////////////////////////////
//         Memory Controller Functional Unit           //
/////////////////////////////////////////////////////////

/*
//
// Zorislav Shoyat, 5/2/15 19:11
//

reg mfu_reg_conflict;

always@*
   casez(cip[15:9])
	   7'b0011100:begin               //034 - Move (Ai) words from mem, starting at A0, to B RF, starting at JK
		              mfu_reg_conflict = a_res_mask[0] || a_res_mask[cip[8:6]];  //check for a conflict with Ai or A0
					   end 
		7'b0011101:begin               //035 - Move (Ai) words from B RF, starting at JK, to mem starting at A0
						  mfu_reg_conflict = a_res_mask[0] || a_res_mask[cip[8:6]];  //check for a conflict with Ai or A0
                 end						  
		7'b0011110:begin               //036 - Move (Ai) words from mem, starting at A0, to T RF, starting at JK
						  mfu_reg_conflict = a_res_mask[0] || a_res_mask[cip[8:6]];  //check for a conflict with Ai or A0
					   end 
		7'b0011111:begin               //037 - Move (Ai) words from T RF, starting at JK, to mem starting at A0
						  mfu_reg_conflict = a_res_mask[0] || a_res_mask[cip[8:6]];  //check for a conflict with Ai or A0
                 end						
		7'b1000???:begin
						  //We have an issue where we need to make sure we don't step on the toes of an in-flight write
						  //For now, be excessively cautious and don't issue if the registers are in-use
						  mfu_reg_conflict = |{a_res_mask};
						  //reg_conflict = i_a_res_mask[cip[8:6]] || i_a_res_mask[cip[11:9]];
                 end
		7'b1001???:begin
						  mfu_reg_conflict = a_res_mask[cip[8:6]] || a_res_mask[cip[11:9]];
                 end
		7'b1010???:begin
						  //We have an issue where we need to make sure we don't step on the toes of an in-flight write
						  //For now, be excessively cautious and don't issue if the registers are in-use
						  mfu_reg_conflict = |{a_res_mask,s_res_mask};
						  //reg_conflict = a_res_maskcip[11:9]] || s_res_mask[i_cip[8:6]];
                 end
		7'b1011???:begin
						  mfu_reg_conflict =  a_res_mask[cip[11:9]] || s_res_mask[cip[8:6]];
                 end
		7'b1111110:begin
						  mfu_reg_conflict = a_res_mask[0] || a_res_mask[cip[2:0]]; // We're waiting on A0 and Ak	// ZS k is 3 bit, not 4
					  end
		7'b1111111:begin
						  mfu_reg_conflict = a_res_mask[0] || a_res_mask[cip[2:0]]; // We're waiting on A0 and Ak
					  end
		default:begin
					  mfu_reg_conflict = 0;
				  end
	endcase
//
//
//
*/

MEM_FU mfu(.clk(clk),
              .rst(rst),
				  .i_mode_bdm (mode_bdm),
              .i_cip(cip),
				  .i_cip_vld(cip_vld),
				  .i_lip(lip),
				  .i_lip_vld(lip_vld),
				  .i_vector_length(vector_length),
				  .i_vstart(vfu_start[7]),
				  .i_data_base_addr(data_base_addr),
				  .i_data_limit_addr(data_limit_addr),
				  //interface to V regs
				  .i_v0_data(v_rd_data[63:0]),
				  .i_v1_data(v_rd_data[127:64]),
				  .i_v2_data(v_rd_data[191:128]),
				  .i_v3_data(v_rd_data[255:192]),
				  .i_v4_data(v_rd_data[319:256]),
				  .i_v5_data(v_rd_data[383:320]),
				  .i_v6_data(v_rd_data[447:384]),
				  .i_v7_data(v_rd_data[511:448]),
				  .o_v_ack(v_mfu_ack),
//				  // a or s conflict								// ZS 5/2/15
//				  .i_reg_conflict (mfu_reg_conflict),			// ibid.
				  //interface to A rf
				  .i_a0_data(a_a0_data),
				  .i_ai_data(a_i_data),
				  .i_ak_data(a_k_data),
				  .i_ah_data(a_h_data),
				  .i_a_res_mask(a_res_mask),
				  //interface to s rf
				  .i_si_data(s_i_data),
				  .i_s_res_mask(s_res_mask),
				  //interface to B rf
				  .o_b_rd_addr(mem_b_rd_addr),
				  .i_b_rd_data(b_jk_data),
				  .o_b_wr_addr(mem_b_wr_addr),
				  .o_b_wr_en(mem_b_wr_en),
				  //interface to T rf
				  .o_t_rd_addr(mem_t_rd_addr),
				  .i_t_rd_data(t_jk_data),
				  .o_t_wr_addr(mem_t_wr_addr),
				  .o_t_wr_en(t_result_en),
				  //memory interface
				  .o_mem_busy(mem_busy),
				  .o_mem_rd_req(mem_rd_req),
				  .o_mem_data(data_from_mem_to_regs),
				  .o_mem_rd_addr(mem_rd_addr),
				  .i_mem_rd_addr_ack (i_mem_rd_addr_ack),
				  .o_mem_wr_addr(mem_wr_addr),
				  .i_mem_wr_addr_ack (i_mem_wr_addr_ack),
				  .i_mem_rd_data(i_data_from_mem),
				  .o_mem_wr_data(data_to_mem),
				  .o_mem_wr_req(mem_wr_req),
				  .i_mem_rd_ack(mem_rd_ack),
				  .i_mem_wr_ack(mem_wr_ack),
				  .o_mem_type(mem_type),
				  .o_mem_issue(mem_issue),
				  .o_b_busy (b_busy),
				  .o_t_busy (t_busy));
`endif
				  

`ifndef CRAY_1
/////////////////////////////////////////////////////////
//          DMA "I/O" Controller Logic                 //
/////////////////////////////////////////////////////////

assign o_dma_instr = cip;
assign o_dma_mon_mode = mode_mm;
assign o_dma_instr_vld = cip_vld;
assign o_dma_ak = a_k_data;
assign o_dma_aj = a_j_data;
assign dma_type = ((cip[15:6]==10'o0010) ||
				(cip[15:6]==10'o0011) ||
				(cip[15:6]==10'o0012));
assign dma_issue = dma_type & !(|a_res_mask);
`else
assign dma_type = 0;
assign dma_issue = 0;
`endif

`ifdef CRAY_XMP
/////////////////////////////////////////////////////////
//        InterCPU Communication Logic                 //
/////////////////////////////////////////////////////////

//Figure out when it's an instruction targeting the interCPU communication block

assign intercpu_type = cip_vld &&
                      (((cip[15:6]==10'b0000001100) && (cip[2:0]==3'b0)) || //0014j0 RT Sj
                       ((cip[15:9]== 7'b0111010)    && (cip[5:0]==6'b0)) || //072i00 Si RT
							  ((cip[15:9]== 7'b0010110)    && (cip[2:0]==3'h7)) || //026ij7 Ai SBj
							  ((cip[15:9]== 7'b0010111)    && (cip[2:0]==3'h7)) || //027ij7 SBj Ai
							  ((cip[15:9]== 7'b0111010)    && (cip[2:0]==3'h3)) || //072ij3 Si STj
							  ((cip[15:9]== 7'b0111011)    && (cip[2:0]==3'h3)) || //073ij3 STj Si
							  ((cip[15:6]==10'b0000011100))                     || //0034jk SMjk 1,TS
							  ((cip[15:6]==10'b0000011110))                     || //0036jk SMjk 0
							  ((cip[15:6]==10'b0000011111))                     || //0037jk SMjk 1
							  ((cip[15:9]== 7'b0111010)    && (cip[5:0]==6'h02))|| //072i02 Si SM
							  ((cip[15:9]== 7'b0111011)    && (cip[5:0]==6'h02)));  //073i02 SM Si

//Make I/O assignments							 
assign o_cln[2:0] = cln[2:0];
assign o_intercpu_instr = cip[15:0];
//For now, we're going to gate sending instr_vld to the intercpu register block until there are no 
//outstanding writes to A/S registers. This will kill performance, but i don't *think* access to these 
//is terribly performance-critical. This really just underscores the need for a central scoreboard to 
//check for hazards in a straightforward/high-performance sort of way. The intercpu block can then be dumb, 
//and not worry about hazards. 
assign o_intercpu_instr_vld = cip_vld && !(|a_res_mask) && !(|s_res_mask) & intercpu_type; 	// ZS 3/3/15, 16:55 vld is only if type!
assign o_intercpu_monmode = mode_mm;
assign o_intercpu_sj = s_j_data;
assign o_intercpu_si = s_i_data;
assign o_intercpu_ai = a_i_data;

`elsif CRAY_1
assign intercpu_type = 0;
`endif // CRAY_XMP


/////////////////////////////////////////////////////////
//         Misc. Registers, instruction decoding, etc. //
/////////////////////////////////////////////////////////


//Let's increment the real-time clock every cycle
//Unless it's a 0014x0 instruction, then set the RTC to (Sj)
//FIXME: This should only work in monitor mode!

always@(posedge clk)
   real_time_clock <= rst ? 64'b0 : ((cip[15:6]==16'o0014) && (cip_k==3'o0) && cip_vld) ? s_j_data : (real_time_clock + 64'b1);


//Programmable Clock
// 0014j4     PCI Sj      Enter Interrupt Interval register with (Sj)
always@(posedge clk)
    ii[31:0] <= rst ? 32'b0 : 
	                ((cip[15:6]==10'o0014) && (cip[2:0]==3'h4) && cip_vld && issue_vld) ? s_j_data[31:0] : ii[31:0];

// 001405    CCI     Clear the programmable clock interrupt request
assign clear_prog_clk_int_req = (cip[15:0]==16'o001405) && cip_vld && issue_vld;

// 001406    ECI     Enable programmable clock interrupt request
// 001407    DCI     Disable programmable clock interrupt request
always@(posedge clk)
   prog_clock_en <= rst ? 1'b0 : 
	                               (cip[15:0]==16'o001406 && cip_vld && issue_vld) ? 1'b1 :
											 (cip[15:0]==16'o001407 && cip_vld && issue_vld) ? 1'b0 :
											 prog_clock_en;

//ICD - Interrupt Countdown counter:
//         -> set it when the PCI Sj instruction gets executed
//         -> If it's enabled, decrement every cycle until it reaches 0, then restore to ii[31:0]
//         -> Otherwise, just hold steady

// ZS 21/2/15 10:24
// added register before icd to improve timing
reg cip_icd;
reg [31:0] s_j_data_icd;

always@(posedge clk)
	begin
		cip_icd <= (cip[15:6]==10'o0014) && (cip[2:0]==3'h4) && cip_vld && issue_vld;
		s_j_data_icd = s_j_data[31:0];
	end
always@(posedge clk)
   icd[31:0] <= rst ? 32'b0 :
                     (cip_icd) ? s_j_data_icd :
							(prog_clock_en && icd[31:0]==32'b0) ? ii[31:0] :
							prog_clock_en ? (icd[31:0] - 32'b1) :
							icd[31:0];

assign set_prog_clk_int_req = prog_clock_en && (icd[31:0]==32'b0);

	
//Control the vector mask register
always@(posedge clk)
   vector_mask <= rst ? 64'hFFFFFFFFFFFFFFFF :
                     (cip_instr==7'o003) ?  ((cip_j != 3'b0) ? s_j_data : 64'b0) :   //for some reason this is supposed to take 3-6 cyles (??)
                        vector_mask;
								
//Control the vector length register
// ZS 9/3/2015, 3:05
//		Newer allow the vector_length (VL) register to become 0 !!!
//
always@(posedge clk)
   if(rst)
      vector_length <= 7'b1000000;
   else if(execution_mode==EXECUTE)
      begin
         vector_length <= (cip_instr==7'o002) ?
										((cip_k != 3'b0) ? 
											((a_k_data[5:0] == 7'b0)? 7'b1000000: a_k_data[5:0])
										: 7'b1000000)
									: vector_length;
      end
   else if((execution_mode==LOAD_EX_PKG) && (ex_pkg_cnt_delayed==4'b0011))
         vector_length <= (i_word_nxt[39:33] == 0) ? 7'b1000000 : i_word_nxt[39:33];


/*
   vector_length <= rst ? 7'b1000000 :
                     (execution_mode==EXECUTE) ? 
                     (cip_instr==7'o002) ?  ((cip_k != 3'b0) ? a_k_data[6:0] : 7'b1) :   //for some reason this is supposed to take 3-6 cyles (??)
                        vector_length;
*/


`ifdef BRNCH
brancher brnch(.clk(clk),
                .i_cip(cip),
					 .i_cip_vld(cip_vld),
					 .i_lip(lip),
					 .i_lip_vld(lip_vld),
					 .i_a0_neg(a0_neg),
					 .i_a0_pos(a0_pos),
					 .i_a0_zero(a0_zero),
					 .i_a0_nzero(a0_nzero),
					 .i_a0_busy(a0_busy),
					 .i_s0_neg(s0_neg),
					 .i_s0_pos(s0_pos),
					 .i_s0_zero(s0_zero),
					 .i_s0_nzero(s0_nzero),
					 .i_s0_busy(s0_busy),
					 .i_bjk(b_jk_data),
					 .o_branch_type(branch_type),
					 .o_branch_issue(branch_issue),
					 .o_take_branch(take_branch),
					 .o_rtn_jump(rtn_jump),
					 .o_nxt_p(branch_dest));
`else
brancher brnch(.clk(0),
                .i_cip(0),
					 .i_cip_vld(0),
					 .i_lip(0),
					 .i_lip_vld(0),
					 .i_a0_neg(0),
					 .i_a0_pos(0),
					 .i_a0_zero(0),
					 .i_a0_nzero(0),
					 .i_a0_busy(0),
					 .i_s0_neg(0),
					 .i_s0_pos(0),
					 .i_s0_zero(0),
					 .i_s0_nzero(0),
					 .i_s0_busy(0),
					 .i_bjk(0),
					 .o_branch_type(branch_type),
					 .o_branch_issue(branch_issue),
					 .o_take_branch(take_branch),
					 .o_rtn_jump(rtn_jump),
					 .o_nxt_p(branch_dest));
`endif
					 
					 
//Program Counter
//If it's not a branch, increment when we issue the current instruction parcel
//If it *is* a branch, jump to the appropriate destination
always@(posedge clk)
   if(rst)
      p_addr <= 24'b0;
   else if (execution_mode == EXECUTE)
	   p_addr <= 
			(issue_vld && (i_nip_vld ||  take_branch)) ?  											 //had been (issue_vld && i_nip_vld)
				(take_branch ?
					branch_dest : 
					//(i_nip_vld ) ? 
						(p_addr + 24'b1)) :
				//	p_addr) :
				p_addr;
	else if ((execution_mode == LOAD_EX_PKG) && (ex_pkg_cnt_delayed==4'b0000))
	   p_addr <= {i_word_nxt[47:24]};

//reg alert;
//always@(posedge clk)
//	alert <= rst ? 1'b0 : ( (p_addr[23:2]==22'h207B) || alert);


endmodule
