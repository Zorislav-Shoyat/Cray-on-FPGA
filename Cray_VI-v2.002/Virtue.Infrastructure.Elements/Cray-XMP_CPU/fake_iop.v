module fake_iop(clk, rst, o_mem_addr, o_mem_data, o_mem_req, o_mem_wr, i_mem_ack);

input  wire        clk;
input  wire        rst;
output reg  [21:0] o_mem_addr;
output reg  [63:0] o_mem_data;
output wire        o_mem_wr;
output wire        o_mem_req;
input  wire        i_mem_ack;

reg [3:0] count;     
reg [1:0] state;

//assign o_mem_wr = 1'b1;
//assign o_mem_req = (state[1:0]==2'h1);

always@*
   begin
	case(count[3:0])
		4'h0:begin
//		        o_mem_data[63:0] = 64'h0000000000000001;
//				  o_mem_addr[21:0] = 22'h8DA;
			  end
		4'h1:begin
//		        o_mem_data[63:0] = 64'h0000000000000001;
//				  o_mem_addr[21:0] = 22'h8DB;
			  end
		4'h2:begin
//		        o_mem_data[63:0] = 64'h7C9;
//				  o_mem_addr[21:0] = 22'h8DC;
		     end
		4'h3:begin
//		        o_mem_data[63:0] = 64'hB;
//				  o_mem_addr[21:0] = 22'h8DD;
		     end
		4'h4:begin
//		        o_mem_data[63:0] = 64'h20;
//				  o_mem_addr[21:0] = 22'h8DE;
		     end
		4'h5:begin
//		        o_mem_data[63:0] = 64'h14;
//				  o_mem_addr[21:0] = 22'h8DF;
		     end
		4'h6:begin
					//This should patch it to avoid the memory test
		        o_mem_data[63:0] = 64'h0C008207A04008C7;
				  o_mem_addr[21:0] = 22'h207B;
		     end
		default:begin
//		        o_mem_data[63:0] = 64'h0;
//				  o_mem_addr[21:0] = 22'h0;
		     end
			  
	endcase
	end

always@(posedge clk)
   count[3:0] <= rst ? 4'h0 : (count[3:0] + i_mem_ack);

/*
 1046770 IOP0.CO: set 0x0008DA value 0x0000000000000001
 1046770 IOP0.CO: set 0x0008DB value 0x0000000000000001
 1046770 IOP0.CO: set 0x0008DC value 0x00000000000007C9
 1046770 IOP0.CO: set 0x0008DD value 0x000000000000000B
 1046770 IOP0.CO: set 0x0008DE value 0x0000000000000020
 1046770 IOP0.CO: set 0x0008DF value 0x0000000000000014
*/
always@(posedge clk)
    if(rst)
	     state <= 2'h0;
	 else case(state[1:0])
			//IDLE
			2'h0:state <= 2'h1;
			//WRITE
			2'h1:if (i_mem_ack)
			        state <= 2'h2;
			//ACK
			2'h2:if (count[3:0] < 4'h7)
			        state <= 2'h1;
				  else
				     state <= 2'h3;
			//DONE
			2'h3:state <= 2'h3;
	 endcase

endmodule