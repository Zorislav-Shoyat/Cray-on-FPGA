//scalar population/leading zero count unit
//
//This is the 48-bit leading zero count for the 
//floating-point adder. I'm not sure if this is the
//proper way to re-normalize something, but it should work.

// r244 by christopher.h.fenton on Aug 7, 2014

//
// Debuged by Zorislav Shoyat, 18/3/2015, 20:41
//

// Define the CRAY computer type in "Cray_type.vh"
`include "../Cray_type.vh"

// Define the use of physical device producer cores etc.
`include "../Cray_implementation.vh"

// Define the data sizes, timings and other parameters
`include "../Cray_VI_construction.vh"


module float_add_lz(sj, lz_final_result);

    input wire [47:0] sj;
    output wire [5:0] lz_final_result;	// Only 6 bits necessary for count to 48/49

    wire [23:0] lz_result;
    
    wire zb0, zb1, zb2, zb3, zb4, zb5, zb6, zbl;                   //zero_bar output wires
    wire [2:0] zs0, zs1, zs2, zs3, zs4, zs5, /*zs6, zs7,*/ lz_hi_results;             //"zeros" output wires

    wire lz_msb_result;

    reg [2:0] lz_low_results;


    lz_sub lz_sub0(.i_data(sj[7:0]),  .z_bar(zb0), .o_zeros(zs0));
    lz_sub lz_sub1(.i_data(sj[15:8]), .z_bar(zb1), .o_zeros(zs1));
    lz_sub lz_sub2(.i_data(sj[23:16]),.z_bar(zb2), .o_zeros(zs2));
    lz_sub lz_sub3(.i_data(sj[31:24]),.z_bar(zb3), .o_zeros(zs3));
    lz_sub lz_sub4(.i_data(sj[39:32]),.z_bar(zb4), .o_zeros(zs4));
    lz_sub lz_sub5(.i_data(sj[47:40]),.z_bar(zb5), .o_zeros(zs5));
    //lz_sub lz_sub6(.i_data({7'b0,sj[48]}),.z_bar(zb6), .o_zeros(zs6));

    lz_sub lz_sub_lower(.i_data({zb5,zb4,zb3,zb2,zb1,zb0,2'b00}),.z_bar(zbl), .o_zeros(lz_hi_results)); // To count properly zeros we must left align

    //calculate leading zero count
    assign lz_msb_result = ~|{zb0, zb1, zb2, zb3, zb4, zb5};
    assign lz_final_result = (sj == 0) ? 6'b0 : /*6'b000001*/ + {lz_msb_result, lz_hi_results[2:0], lz_low_results[2:0]}; //add one so that I get the amount to shift to renormalize

    //mux in second stage of pipeline to choose LSBs of the final LZC;
    always@*
    begin
        case(lz_hi_results[2:0])
            3'b000:lz_low_results[2:0]=zs5;
            3'b001:lz_low_results[2:0]=zs4;
            3'b010:lz_low_results[2:0]=zs3;
            3'b011:lz_low_results[2:0]=zs2;
            3'b100:lz_low_results[2:0]=zs1;
            3'b101:lz_low_results[2:0]=zs0;
            default: lz_low_results = 3'b0;
        endcase
    end

endmodule
