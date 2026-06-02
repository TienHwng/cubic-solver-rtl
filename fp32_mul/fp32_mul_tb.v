`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/30/2026 01:55:21 PM
// Design Name: 
// Module Name: tb
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


module fp32_mul_tb;

reg [31:0] a;
reg [31:0] b;

wire [31:0] out;

fp32_mul dut (.a(a), .b(b), .y(out));

initial begin

    a = 32'h1234abcd;
    b = 32'habcd1234;
    #5;
    a = 32'h42F18000;
    b = 32'hC1640000;
    #5;
    a = 32'h00000000;
    b = 32'h00000000;
    #5;
    a = 32'h00000000;
    b = 32'h80000000;
    #5;
    a = 32'h80000000;
    b = 32'h80000000;
    #5;
    a = 32'h00000000;
    b = 32'hC1640000;
    #5;
    a = 32'h80000000;
    b = 32'hC1640000;
    #5;
    a = 32'hC0000000;
    b = 32'h7F800000;
    #5;
    a = 32'h00000000;
    b = 32'h7F800000;
    #5;
    a = 32'h40A66666;
    b = 32'h40F33333;
    #5;
    a = 32'h40400000;
    b = 32'h40000000;
    #5;
    $finish;
end
    
endmodule
