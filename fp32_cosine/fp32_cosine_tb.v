`timescale 1ns / 1ps

module fp32_cosine_tb;

reg clk;
reg rst_n;
reg start;
reg [31:0] in_x;
wire [31:0] cosine;
wire done;

fp32_cosine dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .x_in(in_x),
    .cos_out(cosine),
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
    in_x = 32'h3f060a92;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in_x = 32'h00000000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in_x = 32'h40c90fdb;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in_x = 32'h40490fdb;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in_x = 32'h420DAE14;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in_x = 32'h43E15C29;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #20;
    $finish;
end

endmodule