module lzc_27 (
  input  wire [26:0] in,
  output wire [4:0]  out
);
  assign out = in[26] ? 5'd0  : in[25] ? 5'd1  : in[24] ? 5'd2  :
               in[23] ? 5'd3  : in[22] ? 5'd4  : in[21] ? 5'd5  :
               in[20] ? 5'd6  : in[19] ? 5'd7  : in[18] ? 5'd8  :
               in[17] ? 5'd9  : in[16] ? 5'd10 : in[15] ? 5'd11 :
               in[14] ? 5'd12 : in[13] ? 5'd13 : in[12] ? 5'd14 :
               in[11] ? 5'd15 : in[10] ? 5'd16 : in[9]  ? 5'd17 :
               in[8]  ? 5'd18 : in[7]  ? 5'd19 : in[6]  ? 5'd20 :
               in[5]  ? 5'd21 : in[4]  ? 5'd22 : in[3]  ? 5'd23 :
               in[2]  ? 5'd24 : in[1]  ? 5'd25 : in[0]  ? 5'd26 : 5'd27;
endmodule


module fp32_addsub(
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire        op,     // 0: add, 1: sub  => a + (b ^ op_sign)
    output reg  [31:0] result
);

    wire sa = a[31];
    wire sb = b[31] ^ op; 

    wire [7:0] ea = a[30:23];
    wire [7:0] eb = b[30:23];
    wire [22:0] fa = a[22:0];
    wire [22:0] fb = b[22:0];

    wire a_exp_all1 = &ea;
    wire b_exp_all1 = &eb;
    wire a_exp_all0 = (ea == 8'd0);
    wire b_exp_all0 = (eb == 8'd0);

    wire a_frac_zero = (fa == 23'd0);
    wire b_frac_zero = (fb == 23'd0);

    wire a_is_nan = a_exp_all1 & ~a_frac_zero;
    wire b_is_nan = b_exp_all1 & ~b_frac_zero;
    wire a_is_inf = a_exp_all1 & a_frac_zero;
    wire b_is_inf = b_exp_all1 & b_frac_zero;
    wire a_is_zero = a_exp_all0 & a_frac_zero;
    wire b_is_zero = b_exp_all0 & b_frac_zero;

    wire [31:0] qnan = {1'b0, 8'hFF, 1'b1, 22'd0};

    wire [23:0] ma = a_exp_all0 ? {1'b0, fa} : {1'b1, fa};
    wire [23:0] mb0 = b_exp_all0 ? {1'b0, fb} : {1'b1, fb};

    wire [7:0] ea_eff = a_exp_all0 ? 8'd1 : ea;
    wire [7:0] eb_eff = b_exp_all0 ? 8'd1 : eb;

    wire any_nan = a_is_nan | b_is_nan;
    wire inf_opp_sign = a_is_inf & b_is_inf & (sa ^ sb);

    wire exp_a_gt_b = (ea_eff > eb_eff);
    wire exp_a_eq_b = (ea_eff == eb_eff);
    wire mant_a_ge_b = (ma >= mb0);

    wire a_is_big = exp_a_gt_b | (exp_a_eq_b & mant_a_ge_b);

    wire sign_big   = a_is_big ? sa : sb;
    wire sign_small = a_is_big ? sb : sa;

    wire [7:0] exp_big   = a_is_big ? ea_eff : eb_eff;
    wire [7:0] exp_small = a_is_big ? eb_eff : ea_eff;

    wire [23:0] mant_big_24   = a_is_big ? ma : mb0;
    wire [23:0] mant_small_24 = a_is_big ? mb0 : ma;

    wire [7:0] shift_amt;
    adder #(.WIDTH(8)) u_exp_diff(
        .a(exp_big), .b(~exp_small), .cin(1'b1), .sum(shift_amt), .cout()
    );

    wire [26:0] big_ext   = {mant_big_24, 3'b000};
    wire [26:0] small_ext = {mant_small_24, 3'b000};

    wire [26:0] mask_shifted = ~(27'h7FFFFFF << shift_amt);
    wire sticky_raw = |(small_ext & mask_shifted);
    wire [26:0] small_align = (shift_amt >= 8'd27) ? {26'd0, |small_ext} : ((small_ext >> shift_amt) | {26'd0, sticky_raw});

    wire same_sign = ~(sign_big ^ sign_small);

    wire [27:0] mant_add_sum;
    adder #(.WIDTH(28)) u_mant_add(
        .a({1'b0, big_ext}), .b({1'b0, small_align}), .cin(1'b0), .sum(mant_add_sum), .cout()
    );

    wire [27:0] mant_sub_diff;
    adder #(.WIDTH(28)) u_mant_sub(
        .a({1'b0, big_ext}), .b(~{1'b0, small_align}), .cin(1'b1), .sum(mant_sub_diff), .cout()
    );

    wire [27:0] mant_raw_w = same_sign ? mant_add_sum : mant_sub_diff;

    wire [7:0] exp_big_plus_1;
    adder #(.WIDTH(8)) u_exp_big_inc(
        .a(exp_big), .b(8'd0), .cin(1'b1), .sum(exp_big_plus_1), .cout()
    );
    
    wire [26:0] mant_norm_same = mant_raw_w[27] ? mant_raw_w[27:1] : mant_raw_w[26:0];
    wire [7:0]  exp_norm_same  = mant_raw_w[27] ? exp_big_plus_1   : exp_big;

    wire [4:0] lz;
    lzc_27 u_lzc (.in(mant_raw_w[26:0]), .out(lz));

    wire [7:0] exp_big_minus_1;
    adder #(.WIDTH(8)) u_exp_big_dec(
        .a(exp_big), .b(~8'd1), .cin(1'b1), .sum(exp_big_minus_1), .cout()
    );

    wire shift_limited = ({3'd0, lz} > exp_big_minus_1);
    wire [7:0] actual_shift_for_exp = shift_limited ? exp_big_minus_1 : {3'd0, lz};

    wire [7:0] exp_norm_diff;
    adder #(.WIDTH(8)) u_exp_norm_sub(
        .a(exp_big), .b(~actual_shift_for_exp), .cin(1'b1), .sum(exp_norm_diff), .cout()
    );
    wire [26:0] mant_norm_diff = mant_raw_w[26:0] << lz;

    wire [26:0] mant_norm_w = same_sign ? mant_norm_same : mant_norm_diff;
    wire [7:0]  exp_norm_w  = same_sign ? exp_norm_same  : exp_norm_diff;
    wire sign_norm_w = sign_big;

    wire [23:0] main24_w = mant_norm_w[26:3];
    wire round_up_w = mant_norm_w[2] & (mant_norm_w[1] | mant_norm_w[0] | main24_w[0]);

    wire [24:0] main24_rounded_sum;
    adder #(.WIDTH(25)) u_main24_inc(
        .a({1'b0, main24_w}), .b(25'd0), .cin(round_up_w), .sum(main24_rounded_sum), .cout()
    );

    wire [7:0] exp_norm_w_plus_1;
    adder #(.WIDTH(8)) u_exp_norm_inc(
        .a(exp_norm_w), .b(8'd0), .cin(1'b1), .sum(exp_norm_w_plus_1), .cout()
    );

    wire [26:0] mant_subnorm_w = mant_norm_w >> 1;
    wire [22:0] frac_subnorm_w = mant_subnorm_w[25:3];
    wire round_up2_w = mant_subnorm_w[2] & (mant_subnorm_w[1] | mant_subnorm_w[0] | frac_subnorm_w[0]);

    wire [23:0] frac23_rounded_sum;
    adder #(.WIDTH(24)) u_frac23_inc(
        .a({1'b0, frac_subnorm_w}), .b(24'd0), .cin(round_up2_w), .sum(frac23_rounded_sum), .cout()
    );

    always @* begin
        result = 32'd0;

        if (any_nan || inf_opp_sign) begin
            result = qnan;
        end else if (a_is_inf) begin
            result = {sa, 8'hFF, 23'd0};
        end else if (b_is_inf) begin
            result = {sb, 8'hFF, 23'd0};
        end else if (a_is_zero && b_is_zero) begin
            result = {(sa & sb), 8'd0, 23'd0};
        end else if (a_is_zero) begin
            result = {sb, eb, fb};
        end else if (b_is_zero) begin
            result = {sa, ea, fa};
        end else if (!same_sign && mant_raw_w[26:0] == 27'd0) begin
            result = {1'b0, 8'd0, 23'd0};
        end else begin
            if (exp_norm_w >= 8'hFF) begin
                result = {sign_norm_w, 8'hFF, 23'd0};
            end else begin
                if (main24_rounded_sum[24]) begin
                    if (exp_norm_w == 8'hFE) result = {sign_norm_w, 8'hFF, 23'd0};
                    else                     result = {sign_norm_w, exp_norm_w_plus_1, 23'd0};
                end else begin
                    if (exp_norm_w == 8'd1 && main24_rounded_sum[23] == 1'b0) begin
                        if (frac23_rounded_sum[23]) result = {sign_norm_w, 8'd1, 23'd0};
                        else                         result = {sign_norm_w, 8'd0, frac23_rounded_sum[22:0]};
                    end else if (exp_norm_w == 8'd1 && main24_rounded_sum[23] == 1'b1 && mant_norm_w[26] == 1'b0) begin
                        result = {sign_norm_w, 8'd0, main24_rounded_sum[22:0]};
                    end else if (exp_norm_w == 8'd1 && mant_norm_w[26] == 1'b0) begin
                        if (frac23_rounded_sum[23]) result = {sign_norm_w, 8'd1, 23'd0};
                        else                         result = {sign_norm_w, 8'd0, frac23_rounded_sum[22:0]};
                    end else begin
                        result = {sign_norm_w, exp_norm_w, main24_rounded_sum[22:0]};
                    end
                end
            end
        end
    end

endmodule