////////////////////////////////////////////
//
// Zorislav Shoyat, 14/3/2014, 20:27
//
////////////////////////////////////////////
//
// DEFINE THE CRAY COMPUTER SYSTEM TYPE
//
////////////////////////////////////////////

// CRAY-1		- beware: CRAY-1 is modelled without I/O channels and DMA
// CRAY-XMP:   - the default CRAY-XMP is CRAY-XMP.4
// 	CRAY-XMP.1
// 	CRAY-XMP.2
// 	CRAY-XMP.3
// 	CRAY-XMP.4
//
//    NO_IOP   - do not include the IOP on board
//

//
// BEWARE: Present Cray-VI implementation does not support the
// XMP and other flags. See source for details
// STATE: 19/2/15, 14:59
//

`define CRAY_XMP
`define CRAY_XMP_1
//`define NO_IOP

`define CRAY_1

//`define MARB_XMP

`define INTERNAL_MEMORY_WORDS 24576

////////////////////////////////////////////
//
//	Zorislav Shoyat, 19/2/15, 14:57
//
////////////////////////////////////////////
//
// Include the Cray-VI construction details
// like data sizes, functional unit timings
// etc.
// Done in each file
////////////////////////////////////////////

/* `include "Cray_VI_construction.vh" */
