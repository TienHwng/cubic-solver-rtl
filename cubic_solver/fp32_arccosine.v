module fp32_arccosine (
    input  wire [31:0] x_in,
    output wire [31:0] acos_out
);

    wire [31:0] ONE_FP32     = 32'h3F800000; 
    wire [31:0] NEG_ONE_FP32 = 32'hBF800000; 
    wire [31:0] ZERO_FP32    = 32'h00000000; 
    wire [31:0] PI_FP32      = 32'h40490FDB; 

    wire [31:0] C_A8 = 32'h3B65DAB1;
    wire [31:0] C_A7 = 32'h3D8A097F;
    wire [31:0] C_A6 = 32'hBE4D5315;
    wire [31:0] C_A5 = 32'hBF2571A4;
    wire [31:0] C_A4 = 32'h3FAB597C;
    wire [31:0] C_A3 = 32'h3FC27125;
    wire [31:0] C_A2 = 32'hC0297833;
    wire [31:0] C_P  = 32'h3FC90FDB; 

    wire [31:0] C_B  = 32'h3B12546C;
    wire [31:0] C_C  = 32'hBE02B6B2;
    wire [31:0] C_D  = 32'h3F5A2B45;
    wire [31:0] C_E  = 32'hBFD7C67A;

    wire [31:0] x2;
    fp32_mul u_mul_x2 (
        .a(x_in), .b(x_in), .y(x2)
    );

    wire [31:0] n_p1, n_s1;
    wire [31:0] n_p2, n_s2;
    wire [31:0] n_p3, n_s3;
    wire [31:0] n_p4, n_s4;
    wire [31:0] n_p5, n_s5;
    wire [31:0] n_p6, n_s6;
    wire [31:0] n_p7, n_s7;
    wire [31:0] n_p8, num_final;

    fp32_mul    u_n_mul1 (.a(C_A8), .b(x_in), .y(n_p1));
    fp32_addsub u_n_add1 (.a(n_p1), .b(C_A7), .op(1'b0), .result(n_s1));
    
    fp32_mul    u_n_mul2 (.a(n_s1), .b(x_in), .y(n_p2));
    fp32_addsub u_n_add2 (.a(n_p2), .b(C_A6), .op(1'b0), .result(n_s2));
    
    fp32_mul    u_n_mul3 (.a(n_s2), .b(x_in), .y(n_p3));
    fp32_addsub u_n_add3 (.a(n_p3), .b(C_A5), .op(1'b0), .result(n_s3));
    
    fp32_mul    u_n_mul4 (.a(n_s3), .b(x_in), .y(n_p4));
    fp32_addsub u_n_add4 (.a(n_p4), .b(C_A4), .op(1'b0), .result(n_s4));
    
    fp32_mul    u_n_mul5 (.a(n_s4), .b(x_in), .y(n_p5));
    fp32_addsub u_n_add5 (.a(n_p5), .b(C_A3), .op(1'b0), .result(n_s5));
    
    fp32_mul    u_n_mul6 (.a(n_s5), .b(x_in), .y(n_p6));
    fp32_addsub u_n_add6 (.a(n_p6), .b(C_A2), .op(1'b0), .result(n_s6));
    
    fp32_mul    u_n_mul7 (.a(n_s6), .b(x_in), .y(n_p7));
    fp32_addsub u_n_add7 (.a(n_p7), .b(ONE_FP32), .op(1'b1), .result(n_s7));
    
    fp32_mul    u_n_mul8 (.a(n_s7), .b(x_in), .y(n_p8));
    fp32_addsub u_n_add8 (.a(n_p8), .b(C_P), .op(1'b0), .result(num_final));

    wire [31:0] d_p1, d_s1;
    wire [31:0] d_p2, d_s2;
    wire [31:0] d_p3, d_s3;
    wire [31:0] d_p4, den_final;

    fp32_mul    u_d_mul1 (.a(C_B),  .b(x2), .y(d_p1));
    fp32_addsub u_d_add1 (.a(d_p1), .b(C_C), .op(1'b0), .result(d_s1));
    
    fp32_mul    u_d_mul2 (.a(d_s1), .b(x2), .y(d_p2));
    fp32_addsub u_d_add2 (.a(d_p2), .b(C_D), .op(1'b0), .result(d_s2));
    
    fp32_mul    u_d_mul3 (.a(d_s2), .b(x2), .y(d_p3));
    fp32_addsub u_d_add3 (.a(d_p3), .b(C_E), .op(1'b0), .result(d_s3));
    
    fp32_mul    u_d_mul4 (.a(d_s3), .b(x2), .y(d_p4));
    fp32_addsub u_d_add4 (.a(d_p4), .b(ONE_FP32), .op(1'b0), .result(den_final));

    wire [31:0] acos_poly;
    fp32_div u_final_div (
        .a(num_final),
        .b(den_final),
        .y(acos_poly)
    );

    assign acos_out = (x_in == NEG_ONE_FP32) ? PI_FP32 : 
                      (x_in == ONE_FP32)     ? ZERO_FP32 : 
                                               acos_poly;

endmodule