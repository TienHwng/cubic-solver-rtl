`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/31/2026 01:14:11 AM
// Design Name: 
// Module Name: fp32_cbrt_tb
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


module fp32_cbrt_tb;

reg [31:0] in;
wire [31:0] out;

fp32_cbrt dut (.x_in(in), .cbrt_out(out));

initial begin
    in = 32'h00000000;
    #5;
    in = 32'h3f800000;
    #5;
    in = 32'h41000000;
    #5;
    in = 32'h41d80000;
    #5;
    in = 32'h40000000;
    #5;
    in = 32'h40400000;
    #5;
    in = 32'h41200000;
    #5;
    in = 32'h42c80000;
    #5;
    in = 32'h3e000000;
    #5;
    in = 32'hc1000000;
    #5;
    in = 32'hc1200000;
    #5;
    $finish;
end


endmodule
