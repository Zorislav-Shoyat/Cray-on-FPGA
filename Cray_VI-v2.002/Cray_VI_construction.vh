///////////////////////////////////////////
//
// Zorislav Shoyat, 17/2/2015, 0:53
//		Atelier, Tintilin
//
// 19/2/2015, 15:10, Atelier, Delphinus
//
///////////////////////////////////////////
//
// DEFINITION OF TIMING PARAMETERS:
//		
//
///////////////////////////////////////////

/*
	Cycle counting: from the posedge of clk ending a command to the posedge of clk when data is in the next unit

	Memory read/write:
	
	From falling edge of start memory read through MFU:
		2 cycles for read
		1 cycle for write
	
	Vector register read/write:
		From falling edge of start vector register to o_rd_data / from i_data to saved in memory
			1 cycle write
			2 cycle read
	
	Vector register chain to FU, after falling edge of start:
		1 cycle
	
*/

`define	BYTE		[ 7:0]
`define	PARCEL	[15:0]
`define	HALFWORD	[31:0]
`define	WORD		[63:0]
// in other words:
`define	char		BYTE
`define	short 	PARCEL
`define	integ		HALFWORD
`define	long		WORD

`define MEMADDRBITS	24
`define	ADDRBITS	24
`define	DATABITS	64

`define	I_CHANNELS	16
`define	O_CHANNELS	16

//
//	Functional Unit Timings
//
// The actual timing is one more than indicated here!
//

`define	V_REG_WRITE_TIME	4'd0
`define	V_REG_READ_TIME	4'd1

`define	BREG_WRITE_TIME	4'b0
`define	BREG_READ_TIME		4'd1

`define	TREG_WRITE_TIME	4'b0
`define	TREG_READ_TIME		4'd1

`define	MEM_FU_WRITE_TIME	4'd1
`define	MEM_FU_READ_TIME	4'd2


`define	FPADD_TIME			4'd6
`define 	FPMUL_TIME			4'd7
`define	FPRECIP_TIME		4'd14

`define	VADD_TIME			4'd2
`define	VLOG_TIME			4'd2
`define	VPOP_TIME			4'd5
`define	VSHIFT_TIME			4'd4

`define	SLOG_TIME			4'd1
`define	SIMM_TIME			4'd1
`define	SIMM_C_TIME			4'd1
`define	SSHIFT_E_TIME		4'd2
`define	SCONST_TIME			4'd2
`define	SINTERCPU_TIME		4'd2
`define	SADD_TIME			4'd3
`define	SSHIFT_A_TIME		4'd3
`define	SVM_TIME				4'd1
`define	SBUS_T_TIME			4'd1
`define	SMEM_READ_TIME		`MEM_FU_READ_TIME + 4'd1
`define	SMEM_WRITE_TIME	`MEM_FU_WRITE_TIME + 4'd1

`define	ANONE_TIME			4'd0
`define	AIMM_TIME			4'd1
`define	AIMM_C_TIME			4'd1
`define	ASIMM_TIME			4'd1
`define	ABUS_S_TIME			4'd1
`define	ABUS_B_TIME			4'd1
`define	AINTERCPU_TIME		4'd2
`define	AADD_TIME			4'd2
`define	A_SLZC_TIME			4'd3
`define	A_SPOP_TIME			4'd4
`define	ACHAN_TIME			4'd4
`define	AMUL_TIME			4'd2
`define	AMEM_READ_TIME		`MEM_FU_READ_TIME + 4'd1
`define	AMEM_WRITE_TIME	`MEM_FU_WRITE_TIME + 4'd1



`ifdef PARAMETERS
//
// Bus distinguishers
//

localparam SBUS_IMM      = 5'b00000,     //immediate
           SBUS_COMP_IMM = 5'b00001,	   //complement of immediate
	        SBUS_S_LOG    = 5'b00010,     //scalar logical
	        SBUS_S_SHIFT  = 5'b00011,     //scalar shift 
	        SBUS_S_ADD    = 5'b00100,     //scalar add
	        SBUS_FP_ADD   = 5'b00101,     //floating point add
	        SBUS_FP_MULT  = 5'b00110,     //floating point multiply
	        SBUS_FP_RA    = 5'b00111,     //floating point reciprocal approximation
	        SBUS_CONST_GEN= 5'b01000,     //transmit (Ak) or constant to Si
	        SBUS_RTC      = 5'b01001,     //real time clock
	        SBUS_V_MASK   = 5'b01010,     //vector mask
	        SBUS_T_BUS    = 5'b01011,     //transmit (Tjk) to Si
	        SBUS_V0       = 5'b01100,     //transmit (Vj) to Si
			  SBUS_V1       = 5'b01101,
			  SBUS_V2       = 5'b01110,
			  SBUS_V3       = 5'b01111,
			  SBUS_V4       = 5'b10000,
			  SBUS_V5       = 5'b10001,
			  SBUS_V6       = 5'b10010,
			  SBUS_V7       = 5'b10011,
	        SBUS_MEM      = 5'b10100,
   	     SBUS_NONE     = 5'b10101,
			  SBUS_INTERCPU = 5'b10110,     //InterCPU Communication Block
			  SBUS_HI_SR    = 5'b10111;     //073i01 - some status bits to Si
			  
localparam ABUS_IMM      = 4'b0000,     //immediate
           ABUS_COMP_IMM = 4'b0001,	   //complement of immediate
	        ABUS_SIMM     = 4'b0010,     //short immediate
	        ABUS_S_BUS    = 4'b0011,     //transmit (Sj) to Ai
	        ABUS_B_BUS    = 4'b0100,     //transmit (Bjk) to Ai
	        ABUS_S_POP    = 4'b0101,     //scalar population count
	        ABUS_A_ADD    = 4'b0110,     //address add
	        ABUS_A_MULT   = 4'b0111,     //address multiply
	        ABUS_A_BUS    = 4'b1000,     //transmit (Ak) to Si
	        ABUS_CHANNEL  = 4'b1001,     //DMA Engine
	        ABUS_MEM      = 4'b1010,     //memory
   	     ABUS_NONE     = 4'b1011,
			  ABUS_INTERCPU = 4'b1100;     //InterCPU COmmunication block

`endif

`ifdef NOTDEF

// VADD
localparam SCAL_VEC_ADD = 7'b1101100,
           VEC_VEC_ADD  = 7'b1101101,
           SCAL_VEC_SUB = 7'b1101110,
           VEC_VEC_SUB  = 7'b1101111;

`endif
