`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/30/2026 11:18:49 PM
// Design Name: 
// Module Name: fp32_arccosine_tb
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


module fp32_arccosine_tb;

reg [31:0] in_x;
wire [31:0] arccosine;

fp32_arccosine dut (.x_in( in_x), .acos_out(arccosine));

initial begin
    in_x = 32'hbf800000;
    #5;
    in_x = 32'hbf7ff972;
    #5;
    in_x = 32'hbf7d70a4;
    #5;
    in_x = 32'hbf000000;
    #5;
    in_x = 32'h3dcccccd;
    #5;
    in_x = 32'h3f3504f3;
    #5;
    in_x = 32'h3f800000;
    #5;
    $finish;
end

endmodule
