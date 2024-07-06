This code was partially supported by the E2LP FP7-ICT EU Project at the Ruđer Bošković Institute Centre for Informatics and Computing, Zagreb, Croatia.

This implementation was inspired by, and heavily using, the Homebrew Cray 1a code by Christofer Fenton: https://www.chrisfenton.com/homebrew-cray-1a/

A "promotional" video about this implementation, "Reincarnation of Cray-1 on E2LP Platform" can be viewed at: http://gu.irb.hr/MIPRO2020/Reincarnation%20CRAY-1%20on%20E2LP%20Platform-720p.mp4

E2LP Laboratory Exercise Documentation: http://grgur.irb.hr/Cray-E2LP/DSD_23_Cray-1_on_E2LP.pdf0.pdf

The used FPGA on E2LP board is Xilinx xc6sxl45-2fgg676. The Xilinx ise project file is in Cray_VI-2.002/Cray-VI/Cray-VI.xise

IMPORTANT: All sources are written with tabstop 3 (vi/vim ':se ts=3')!

Remark: As the FPGA used on E2LP board does not have enough space to implement external DRAM access (allthough the DRAM is present on the board), this implementation uses only 24 KiW (per 64 bit) words of memory. An implementation on a larger FPGA would allow to use external memory, but the implementation may be tricky, due to parallel read/write capabilities of the Cray processor and strictly timed memory random access approach of this implementation. Memory banking, as done on the original Cray processor(s) shall be implemented and used.

PS: The VI in Cray-VI is not the number 6, but the acronym for Virtue Infrastructure.
