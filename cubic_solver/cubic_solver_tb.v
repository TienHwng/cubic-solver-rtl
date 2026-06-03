`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/31/2026 11:22:29 AM
// Design Name: 
// Module Name: cubic_solver_tb
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


module cubic_solver_tb;

reg clk;
reg rst_n;
reg start;

reg [31:0] a;
reg [31:0] b;
reg [31:0] c;
reg [31:0] d;

wire done;
wire [31:0] x1_re;
wire [31:0] x1_im;
wire [31:0] x2_re;
wire [31:0] x2_im;
wire [31:0] x3_re;
wire [31:0] x3_im;

cubic_solver dut (.clk(clk), .rst_n(rst_n), .start(start), .a(a), .b(b), .c(c), .d(d),
 .x1_re(x1_re),
 .x1_im(x1_im),
 .x2_re(x2_re),
 .x2_im(x2_im),
 .x3_re(x3_re),
 .x3_im(x3_im),
 .done(done)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 0;
    start = 0;
    a = 0;
    b = 0;
    c = 0;
    d = 0;
    # 10;
    rst_n = 1;
    solve(32'h3f800000, 32'h00000000, 32'h3f800000, 32'h3f800000);
    solve(32'h3f800000, 32'h00000000, 32'hc0400000, 32'h40000000);
    solve(32'h3f800000, 32'hc0c00000, 32'h41300000, 32'hc0c00000);
    solve(32'h3f800000, 32'hc0400000, 32'h40400000, 32'hbf800000);
    solve(32'h3f800000, 32'h00000000, 32'h00000000, 32'h00000000);
    
    solve(32'h40200000, 32'h00000000, 32'h40200000, 32'h40200000); 
    solve(32'h3f000000, 32'h00000000, 32'hbfc00000, 32'h3f800000); 
    solve(32'hbfc00000, 32'h41100000, 32'hc1840000, 32'h41100000); 
    solve(32'h40800000, 32'hc1400000, 32'h41400000, 32'hc0800000); 
    solve(32'h3e800000, 32'h00000000, 32'h00000000, 32'h00000000); 
    
    solve(32'h00000000, 32'h41100000, 32'hc1840000, 32'h41100000);
    #500;
    $finish;
end

task solve;
    input [31:0] _a;
    input [31:0] _b;
    input [31:0] _c;
    input [31:0] _d;
    
    begin
        @(posedge clk);
        #1;
        start = 1;
        a = _a;
        b = _b;
        c = _c;
        d = _d;
        
        @(posedge clk);
        #1;
        start = 0;
        
        wait(done == 1);
        #1;    
    end

endtask

endmodule
