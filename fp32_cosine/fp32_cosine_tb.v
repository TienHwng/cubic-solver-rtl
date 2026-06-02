`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/30/2026 09:27:18 PM
// Design Name: 
// Module Name: fp32_cosine_tb
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


module fp32_cosine_tb;

reg [31:0] in_x;
wire [31:0] cosine;

fp32_cosine dut (.x_in( in_x), .cos_out(cosine));

initial begin
    in_x = 32'h3f060a92;
    #5;
    in_x = 32'h00000000;
    #5;
    in_x = 32'h40c90fdb;
    #5;
    in_x = 32'h40490fdb;
    #5;
    in_x = 32'h420DAE14;
    #5;
    in_x = 32'h43E15C29;
    #5;
    $finish;
end

endmodule
