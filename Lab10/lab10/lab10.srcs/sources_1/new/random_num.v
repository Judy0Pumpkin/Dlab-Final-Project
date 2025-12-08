`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/07 23:48:12
// Design Name: 
// Module Name: random_num
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


//8级斐波那契LFSR（多到1型LFSR）设计
//同或门作为反馈函数，反馈多项式为 f(x)=x^8 + x^6 + x^5 + x^4 + 1
module random_num
#(parameter mod = 10)
(
	input 				clk,
    input	     	 	rst,	
	output reg [5:0]	rand_num
);

    reg [7:0]lfsr;
    
    always @(posedge clk) begin
        if(rst) begin
            //同或门种子可以选取全0，同时FPGA复位后也会复位到0，比较方便
            lfsr <= 0;	
            rand_num <= 0;
        end
        else begin
            //抽头从1开始为8、6、5、4
            lfsr[0] <= ~(lfsr[3] ^ lfsr[4] ^ lfsr[5] ^ lfsr[7]);
            //低位移动到高位
            lfsr[7:1] <= lfsr[6:0];
            
            rand_num <= lfsr % mod;
        end
    end
endmodule

