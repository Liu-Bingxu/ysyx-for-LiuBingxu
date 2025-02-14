module FF_D_with_addr#(parameter ADDR_LEN = 2, RST_DATA=0, DATA_LEN = 2 ** ADDR_LEN)(
    input                   clk,
    input                   rst_n,
    input                   syn_rst,
	input 			        wen,
    input  [ADDR_LEN-1:0]   addr,
	input  	                data_in,
	output [DATA_LEN-1:0]	data_out
);

reg  [DATA_LEN-1:0]         data;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        data <= RST_DATA;
    end
    else if(syn_rst)begin
        data <= RST_DATA;
    end
    else if(wen)begin
        data[addr] <= data_in;
    end
end

assign data_out = data;

endmodule //FF_D_with_addr
