
// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"


// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"


module intercpu_st_mux(i_cln, i_j, i_st_1, i_st_2,
`ifndef CRAY_XMP_1 
								i_st_3, 
`ifndef CRAY_XMP_2
								i_st_4, 
`ifndef CRAY_XMP_3
								i_st_5,
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
								o_si);

input wire [2:0] i_cln;
input wire [2:0] i_j;
input wire [511:0] i_st_1, i_st_2;
`ifndef CRAY_XMP_1 
input wire [511:0] i_st_3;
`ifndef CRAY_XMP_2 
input wire [511:0] i_st_4;
`ifndef CRAY_XMP_3 
input wire [511:0] i_st_5;
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
output reg [63:0] o_si;

always@*
   begin
	   case(i_cln)
			3'h0:o_si = 64'b0;
			
			3'h1:case(i_j[2:0])
			        3'h0:o_si = i_st_1[63:0];
					  3'h1:o_si = i_st_1[127:64];
					  3'h2:o_si = i_st_1[191:128];
					  3'h3:o_si = i_st_1[255:192];
					  3'h4:o_si = i_st_1[319:256];
					  3'h5:o_si = i_st_1[383:320];
					  3'h6:o_si = i_st_1[447:384];
					  3'h7:o_si = i_st_1[511:448];
			     endcase 
				  
			3'h2:case(i_j[2:0])
			        3'h0:o_si = i_st_2[63:0];
					  3'h1:o_si = i_st_2[127:64];
					  3'h2:o_si = i_st_2[191:128];
					  3'h3:o_si = i_st_2[255:192];
					  3'h4:o_si = i_st_2[319:256];
					  3'h5:o_si = i_st_2[383:320];
					  3'h6:o_si = i_st_2[447:384];
					  3'h7:o_si = i_st_2[511:448];
			     endcase 
				  
`ifndef CRAY_XMP_1 
			3'h3:case(i_j[2:0])
			        3'h0:o_si = i_st_3[63:0];
					  3'h1:o_si = i_st_3[127:64];
					  3'h2:o_si = i_st_3[191:128];
					  3'h3:o_si = i_st_3[255:192];
					  3'h4:o_si = i_st_3[319:256];
					  3'h5:o_si = i_st_3[383:320];
					  3'h6:o_si = i_st_3[447:384];
					  3'h7:o_si = i_st_3[511:448];
			     endcase 
				  
`ifndef CRAY_XMP_2 
			3'h4:case(i_j[2:0])
			        3'h0:o_si = i_st_4[63:0];
					  3'h1:o_si = i_st_4[127:64];
					  3'h2:o_si = i_st_4[191:128];
					  3'h3:o_si = i_st_4[255:192];
					  3'h4:o_si = i_st_4[319:256];
					  3'h5:o_si = i_st_4[383:320];
					  3'h6:o_si = i_st_4[447:384];
					  3'h7:o_si = i_st_4[511:448];
			     endcase 
				  
`ifndef CRAY_XMP_3 
			3'h5:case(i_j[2:0])
			        3'h0:o_si = i_st_5[63:0];
					  3'h1:o_si = i_st_5[127:64];
					  3'h2:o_si = i_st_5[191:128];
					  3'h3:o_si = i_st_5[255:192];
					  3'h4:o_si = i_st_5[319:256];
					  3'h5:o_si = i_st_5[383:320];
					  3'h6:o_si = i_st_5[447:384];
					  3'h7:o_si = i_st_5[511:448];
			     endcase 
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
				  
			default:o_si = 64'b0;
		endcase
	end

endmodule
