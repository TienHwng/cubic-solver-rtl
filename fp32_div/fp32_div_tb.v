`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/30/2026 05:39:42 PM
// Design Name: 
// Module Name: fp32_div_tb
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


module fp32_div_tb;

reg [31:0] a;
reg [31:0] b;
wire [31:0] result;

fp32_div dut (.a( a), .b( b), .y(result));

initial begin
    a = 32'hC3038800;
    b = 32'hC1740000;
    #5;
    a = 32'hC1740000;
    b = 32'hC3038800;
    #5;
    a = 32'h40400000;
    b = 32'h40000000;
    #5;
    a = 32'h40000000;
    b = 32'h40400000;
    #5;
    a = 32'h40A66666;
    b = 32'h40F33333;
    #5;
    a = 32'h40F33333;
    b = 32'h40A66666;
    #5;
    
    
    a = 32'h00000000;
    b = 32'h00000000;
    #5;
    a = 32'h7f800000;
    b = 32'h7f800000;
    #5;
    a = 32'h40000000;
    b = 32'h00000000;
    #5;
    a = 32'h00000000;
    b = 32'h40000000;
    #5;
    a = 32'h7f800000;
    b = 32'h40000000;
    #5;
    a = 32'h40000000;
    b = 32'h40000000;
    #5;
    a = 32'h3F800000;
    b = 32'h40400000;
    #5;
    a = 32'h40400000;
    b = 32'h3F800000;
    #5;
    
    $finish;
end

endmodule
