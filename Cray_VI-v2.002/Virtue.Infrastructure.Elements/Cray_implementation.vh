///////////////////////////////////////////
//
// Zorislav Shoyat, 15/3/2014, 19:10
//
///////////////////////////////////////////
//
// 12/5/14, 21:15
//
// Starting with vector timing
//
//
// 15/2/15, 18:18
//
// All implementation flags are now here, i.e. the processing units are
// not more (as mentioned above) in the "CPU.v", but here.
//
//
// 22/2/15 16:19
//
// The timing is working now, have to adapt/test the T and B regs
//
///////////////////////////////////////////


///////////////////////////////////////////
//
// DEFINE THE CRAY PHYSICAL IMPLEMENATION
// PARAMETERS
//
///////////////////////////////////////////

//
// USE DEVICE DEPENDANT CORES

//
// XILINX

//`define XILINX

//
// USE CORES


// Define the basic ROM name
`define MONITOR_ROM	"BOOT.ROM"

//`define USE_CORES

// SPEED
`define MHz60

// CRAY_1 (etc.) IMPLEMENTATION BY FUNCTIONAL UNITS
// The minimum scalar processor is default (without T registers)
// All other additional units, if FULL is not defined, shall
// be inserted into "CPU.v"
`define FULL

// For a Scalar (integer) processor define SCALAR (see below)
//
`ifndef FULL
`define SCALAR
`endif

// For a Full Scalar processor with Scalar Floating Point, define SCALAR and FLOATING_POINT
//
`ifdef FULL
`define SCALAR
`define FLOATING_POINT
`endif

// Minimum system:
// 	Simple Scalar processor:
//        SSCHED, ASCHED, S_RF, A_RF, B_RF, SLOG, SSHIFT, SCONST, SADD, IGEN, AADD, MFU, BRNCH
//
`define SSCHED
`define ASCHED
`define S_RF
`define A_RF
`define B_RF	// Necessary for the R instruction
`define SLOG
`define SSHIFT
`define SCONST
`define SADD
`define IGEN
`define AADD
`define MFU
`define BRNCH

// 	Full Scalar integer processor:
//        SSCHED, ASCHED, S_RF, A_RF, B_RF, T_RF, SLOG, SPOPLZ, SSHIFT, SCONST, SADD, IGEN, AADD, AMULT, MFU, BRNCH
//
`ifdef SCALAR
`define SPOPLZ
`define AMULT
`define T_RF
`endif

//		Floating point system (defined if FULL)
//
`ifdef FLOATING_POINT
`define FADD
`define FMULT
`define FRECIP
`endif

`ifdef FULL
// Full system:
//		Full Cray-1 processor:
//			Full Scalar Floating Point system + VSCHED, V_RF, VADD, VLOG, VPOPPAR, VSHIFT
//
`define VSCHED
`define V_RF
`define T_RF
`define VADD
`define VLOG
`define VPOPPAR
`define VSHIFT

`else
// Tailored system:
//		Put here defines to include above the minimum scalar processor:
//
//`define VSCHED
//`define V_RF
//`define VADD
//`define VLOG
//`define FADD
//`define FMULT
`endif

// Additionally there is the flag SINGLE_CYCLE_MEMORY, which
// makes the memory Single Cycle. Please use with caution the
// switch between the single-cycle and multi-cycle/many-cycle memory,
// as internal timings are very sensitive (specially vector timings)
//
// BEWARE: THE WHOLE TIMING WILL GET CONFUSED !!!

`undef SINGLE_CYCLE_MEMORY

//
// For compiling
//
`undef PARAMETERS
