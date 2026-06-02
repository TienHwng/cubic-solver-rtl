`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/30/2026 04:34:46 PM
// Design Name: 
// Module Name: fp32_addsub_tb
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


module fp32_addsub_tb;

reg [31:0] a;
reg [31:0] b;
reg op;
wire [31:0] result;

fp32_addsub dut (.a( a), .b( b), .op( op), .result(result));

initial begin
    op = 0;
    a = 32'h43764700;
    b = 32'h415338DD;
    #5;
    op = 1;
    #5;
    op = 0;
    a = 32'h3F800000;
    b = 32'hBF800000;
    #5;
    op = 0;
    a = 32'h3F800001;
    b = 32'hBF800000;
    #5;
    op = 1;
    a = 32'h3F800001;
    b = 32'h3F800001;
    #5;
    op = 1;
    a = 32'h7F800000;
    b = 32'h7F800000;
    #5;
    op = 0;
    a = 32'h7F800000;
    b = 32'h7F800000;
    #5;
    op = 0;
    a = 32'h00000000;
    b = 32'h00000000;
    #5;
    op = 1;
    #5;
    op = 0;
    a = 32'h40A66666;
    b = 32'h00000000;
    #5;
    op = 1;
    #5;
    
    $finish;
end

endmodule
