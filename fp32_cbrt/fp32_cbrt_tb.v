`timescale 1ns / 1ps

module fp32_cbrt_tb;

reg clk;
reg rst_n;
reg start;
reg [31:0] in;
wire [31:0] out;
wire done;

fp32_cbrt dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .x_in(in),
    .cbrt_out(out),
    .done(done)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 0;
    start = 0;
    in = 32'h00000000;
    
    #15;
    rst_n = 1;
    #10;

    @(posedge clk);
    in = 32'h00000000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in = 32'h3f800000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in = 32'h41000000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in = 32'h41d80000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in = 32'h40000000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in = 32'h40400000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in = 32'h41200000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in = 32'h42c80000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in = 32'h3e000000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in = 32'hc1000000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #10;
    @(posedge clk);
    in = 32'hc1200000;
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge done);

    #20;
    $finish;
end

endmodule