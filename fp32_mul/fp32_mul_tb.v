`timescale 1ns / 1ps

module fp32_mul_tb;

  reg         clk;
  reg         rst_n;
  reg         start;
  reg  [31:0] a;
  reg  [31:0] b;
  
  wire [31:0] out;
  wire         done;

  fp32_mul dut (
    .clk   (clk),
    .rst_n (rst_n),
    .start (start),
    .a     (a),
    .b     (b),
    .y     (out),
    .done  (done)
  );

  always #5 clk = ~clk;

  task send_packet(input [31:0] val_a, input [31:0] val_b);
    begin
      @(posedge clk);
      a     = val_a;
      b     = val_b;
      start = 1'b1;   
      
      @(posedge clk);
      start = 1'b0;   
      
      while (!done) begin
        @(posedge clk);
      end
      
      #10; 
    end
  endtask

  initial begin
    clk   = 1'b0;
    rst_n = 1'b0;
    start = 1'b0;
    a     = 32'd0;
    b     = 32'd0;

    #20;
    rst_n = 1'b1;
    #20;

    send_packet(32'h1234abcd, 32'habcd1234);
    send_packet(32'h42F18000, 32'hC1640000);
    send_packet(32'h00000000, 32'h00000000);
    send_packet(32'h00000000, 32'h80000000);
    send_packet(32'h80000000, 32'h80000000);
    send_packet(32'h00000000, 32'hC1640000);
    send_packet(32'h80000000, 32'hC1640000);
    send_packet(32'hC0000000, 32'h7F800000); 
    send_packet(32'h00000000, 32'h7F800000); 
    send_packet(32'h40A66666, 32'h40F33333);
    send_packet(32'h40400000, 32'h40000000);

    #50;
    $finish;
  end

endmodule