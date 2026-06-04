`timescale 1ns / 1ps

module fp32_div_tb;

  reg         clk;
  reg         rst_n;
  reg         start;
  reg  [31:0] a;
  reg  [31:0] b;
  wire [31:0] result;
  wire         done;

  fp32_div dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .a(a),
    .b(b),
    .y(result),
    .done(done)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  task run_test(input [31:0] test_a, input [31:0] test_b);
  begin
    @(posedge clk);
    a     = test_a;
    b     = test_b;
    start = 1'b1;   
    
    while (!done) begin
      @(posedge clk);
      start = 1'b0;
    end
    
    #5; 
  end
  endtask

  initial begin
    rst_n = 1'b0;
    start = 1'b0;
    a     = 32'd0;
    b     = 32'd0;
    
    #20;
    rst_n = 1'b1;
    #10;

    run_test(32'hC3038800, 32'hC1740000);
    run_test(32'hC1740000, 32'hC3038800);
    run_test(32'h40400000, 32'h40000000);
    run_test(32'h40000000, 32'h40400000);
    run_test(32'h40A66666, 32'h40F33333);
    run_test(32'h40F33333, 32'h40A66666);
    
    run_test(32'h00000000, 32'h00000000);
    run_test(32'h7f800000, 32'h7f800000);
    run_test(32'h40000000, 32'h00000000);
    run_test(32'h00000000, 32'h40000000);
    run_test(32'h7f800000, 32'h40000000);
    run_test(32'h40000000, 32'h40000000);
    run_test(32'h3F800000, 32'h40400000);
    run_test(32'h40400000, 32'h3F800000);
    
    $finish;
  end

endmodule