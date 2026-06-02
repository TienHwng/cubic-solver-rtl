module fp32_cosine (
    input  wire [31:0] x_in,
    output wire [31:0] cos_out
);
    wire [31:0] PI_MAG     = 32'h40490FDB; 
    wire [31:0] TWO_PI     = 32'h40C90FDB; 
    wire [31:0] INV_TWO_PI = 32'h3E22F983; 
    wire [31:0] ONE_FP32   = 32'h3F800000; 

    wire [31:0] C_A = 32'h3665A2D1;
    wire [31:0] C_B = 32'hBA19EABC;
    wire [31:0] C_C = 32'h3CFCA933;
    wire [31:0] C_D = 32'hBEF4AA97;

    wire [31:0] C_E = 32'h31D65204;
    wire [31:0] C_F = 32'h35DFB8AB;
    wire [31:0] C_G = 32'h39804661;
    wire [31:0] C_H = 32'h3CB55A1F;

    wire [31:0] y_div;      
    wire [31:0] k_float;    
    wire [31:0] k_times_2pi;
    wire [31:0] rem1;       

    fp32_mul u_mul_inv (.a(x_in), .b(INV_TWO_PI), .y(y_div));
    fp32_trunc u_trunc (.f_in(y_div), .f_out(k_float));
    fp32_mul u_mul_k (.a(k_float), .b(TWO_PI), .y(k_times_2pi));
    fp32_addsub u_sub_k (.a(x_in), .b(k_times_2pi), .op(1'b1), .result(rem1));

    wire        rem1_is_neg = rem1[31];
    wire [30:0] rem1_mag    = rem1[30:0];
    wire        rem1_gt_pi  = (rem1_is_neg == 1'b0) && (rem1_mag > PI_MAG[30:0]);
    wire        rem1_lt_neg_pi = (rem1_is_neg == 1'b1) && (rem1_mag > PI_MAG[30:0]);

    wire [31:0] rem_adj;
    fp32_addsub u_add_rem_adj (
        .a(rem1), 
        .b(TWO_PI), 
        .op(rem1_gt_pi ? 1'b1 : 1'b0), 
        .result(rem_adj)
    );

    wire [31:0] x_reduced = (rem1_gt_pi || rem1_lt_neg_pi) ? rem_adj : rem1;

    wire [31:0] x2;
    fp32_mul u_mul_x2 (
        .a(x_reduced), .b(x_reduced), .y(x2)
    );

    wire [31:0] n_p1, n_p2, n_p3, n_p4, n_p5, n_p6, n_p7, num_final;

    fp32_mul    u_n_mul1 (.a(C_A),  .b(x2),   .y(n_p1));
    fp32_addsub u_n_add1 (.a(n_p1), .b(C_B),  .op(1'b0), .result(n_p2));
    fp32_mul    u_n_mul2 (.a(n_p2), .b(x2),   .y(n_p3));
    fp32_addsub u_n_add2 (.a(n_p3), .b(C_C),  .op(1'b0), .result(n_p4));
    fp32_mul    u_n_mul3 (.a(n_p4), .b(x2),   .y(n_p5));
    fp32_addsub u_n_add3 (.a(n_p5), .b(C_D),  .op(1'b0), .result(n_p6));
    fp32_mul    u_n_mul4 (.a(n_p6), .b(x2),   .y(n_p7));
    fp32_addsub u_n_add4 (.a(n_p7), .b(ONE_FP32), .op(1'b0), .result(num_final));

    wire [31:0] d_p1, d_p2, d_p3, d_p4, d_p5, d_p6, d_p7, den_final;

    fp32_mul    u_d_mul1 (.a(C_E),  .b(x2),   .y(d_p1));
    fp32_addsub u_d_add1 (.a(d_p1), .b(C_F),  .op(1'b0), .result(d_p2));
    fp32_mul    u_d_mul2 (.a(d_p2), .b(x2),   .y(d_p3));
    fp32_addsub u_d_add2 (.a(d_p3), .b(C_G),  .op(1'b0), .result(d_p4));
    fp32_mul    u_d_mul3 (.a(d_p4), .b(x2),   .y(d_p5));
    fp32_addsub u_d_add3 (.a(d_p5), .b(C_H),  .op(1'b0), .result(d_p6));
    fp32_mul    u_d_mul4 (.a(d_p6), .b(x2),   .y(d_p7));
    fp32_addsub u_d_add4 (.a(d_p7), .b(ONE_FP32), .op(1'b0), .result(den_final));

    fp32_div u_final_div (
        .a(num_final),
        .b(den_final),
        .y(cos_out)
    );

endmodule

module fp32_trunc (
    input  wire [31:0] f_in,
    output reg  [31:0] f_out
);
    wire        sign = f_in[31];
    wire [7:0]  exp  = f_in[30:23];
    wire [22:0] frac = f_in[22:0];
    
    wire [7:0] shift_amt;
    adder #(.WIDTH(8)) u_sub_exp (
        .a(8'd150),
        .b(~exp),
        .cin(1'b1),
        .sum(shift_amt),
        .cout()
    );

    wire [22:0] shift_val = 23'd1 << shift_amt;
    wire [22:0] sub_result;
    
    adder #(.WIDTH(23)) u_sub_frac_mask (
        .a(shift_val),
        .b(~23'd1), 
        .cin(1'b1),
        .sum(sub_result),
        .cout()
    );
    
    wire [22:0] frac_mask_wire = ~sub_result;

    always @(*) begin
        if (exp < 8'd127) begin
            f_out = {sign, 31'd0};
        end else if (exp >= 8'd150) begin
            f_out = f_in;
        end else begin
            f_out = {sign, exp, frac & frac_mask_wire};
        end
    end

endmodule