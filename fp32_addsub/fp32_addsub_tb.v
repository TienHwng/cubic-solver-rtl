`timescale 1ns / 1ps

module fp32_addsub_tb;

reg         clk;
reg         rst_n;
reg         start;
reg  [31:0] a;
reg  [31:0] b;
reg         op;
wire [31:0] result;
wire         done;

fp32_addsub dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .a(a),
    .b(b),
    .op(op),
    .result(result),
    .done(done)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

task run_test(input [31:0] test_a, input [31:0] test_b, input test_op);
begin
    @(posedge clk);
    a     = test_a;
    b     = test_b;
    op    = test_op;
    start = 1'b1;   
    
    @(posedge clk);
    start = 1'b0;   
    
    while (!done) begin
        @(posedge clk);
    end
    
    #5; 
end
endtask

initial begin
    rst_n = 0;
    start = 0;
    a     = 32'd0;
    b     = 32'd0;
    op    = 1'b0;
    
    #20;
    rst_n = 1;
    #10;

    run_test(32'h43764700, 32'h415338DD, 0);
    run_test(32'h43764700, 32'h415338DD, 1);
    
    run_test(32'h3F800000, 32'hBF800000, 0);
    
    run_test(32'h3F800001, 32'hBF800000, 0);
    
    run_test(32'h3F800001, 32'h3F800001, 1);
    
    run_test(32'h7F800000, 32'h7F800000, 1);
    
    run_test(32'h7F800000, 32'h7F800000, 0);
    
    run_test(32'h00000000, 32'h00000000, 0);
    run_test(32'h00000000, 32'h00000000, 1);
    
    run_test(32'h40A66666, 32'h00000000, 0);
    run_test(32'h40A66666, 32'h00000000, 1);
    
    $finish;
end

endmodule