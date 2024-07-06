
// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"


// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"


module intercpu_sm_mux(i_cln, i_sm_1, i_sm_2, 
`ifndef CRAY_XMP_1 
								i_sm_3, 
`ifndef CRAY_XMP_2
								i_sm_4, 
`ifndef CRAY_XMP_3 
								i_sm_5, 
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
								o_si);

input wire [2:0] i_cln;
input wire [31:0] i_sm_1, i_sm_2;
`ifndef CRAY_XMP_1 
input wire [31:0] i_sm_3;
`ifndef CRAY_XMP_2 
input wire [31:0] i_sm_4;
`ifndef CRAY_XMP_3 
input wire [31:0] i_sm_5;
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
output reg [63:0] o_si;

always@*
   begin
	   case(i_cln)
			3'h0:o_si = 64'b0;
			3'h1:o_si = {i_sm_1[31:0],32'b0};
			3'h2:o_si = {i_sm_2[31:0],32'b0};
`ifndef CRAY_XMP_1 
			3'h3:o_si = {i_sm_3[31:0],32'b0};
`ifndef CRAY_XMP_2
			3'h4:o_si = {i_sm_4[31:0],32'b0};
`ifndef CRAY_XMP_3 
			3'h5:o_si = {i_sm_5[31:0],32'b0};
`endif // not CRAY_XMP_3
`endif // not CRAY_XMP_2
`endif // not CRAY_XMP_1
			default:o_si = 64'b0;
		endcase
	end

endmodule