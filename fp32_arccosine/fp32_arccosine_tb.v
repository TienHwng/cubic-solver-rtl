`timescale 1ns / 1ps

module fp32_arccosine_tb;

reg clk;
reg rst_n;
reg start;
reg [31:0] in_x;
wire [31:0] arccosine;
wire done;

fp32_arccosine dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .x_in(in_x),
    .acos_out(arccosine),
    .done(done)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 0;
    start = 0;
    in_x = 32'h00000000;
    
    #15;
    rst_n = 1;
    #10;

    @(posedge clk);
    in_x = 32'hbf800000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in_x = 32'hbf7ff972;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in_x = 32'hbf7d70a4;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in_x = 32'hbf000000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in_x = 32'h3dcccccd;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in_x = 32'h3f3504f3;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in_x = 32'h3f800000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #20;
    $finish;
end

endmodule