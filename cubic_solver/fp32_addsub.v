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
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire        op,     
    output reg  [31:0] result,
    output reg         done
);

    localparam S_IDLE      = 3'd0;
    localparam S_UNPACK    = 3'd1;
    localparam S_ALIGN     = 3'd2;
    localparam S_CALC      = 3'd3;
    localparam S_NORMALIZE = 3'd4;
    localparam S_ROUND     = 3'd5;
    localparam S_PACK      = 3'd6;

    reg [2:0] state;

    reg [31:0] a_r, b_r;
    reg op_r;

    wire sa = a_r[31];
    wire sb = b_r[31] ^ op_r; 
    wire [7:0] ea = a_r[30:23];
    wire [7:0] eb = b_r[30:23];
    wire [22:0] fa = a_r[22:0];
    wire [22:0] fb = b_r[22:0];

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

    wire sign_big_w   = a_is_big ? sa : sb;
    wire sign_small_w = a_is_big ? sb : sa;
    wire [7:0] exp_big_w   = a_is_big ? ea_eff : eb_eff;
    wire [7:0] exp_small_w = a_is_big ? eb_eff : ea_eff;
    wire [23:0] mant_big_24_w   = a_is_big ? ma : mb0;
    wire [23:0] mant_small_24_w = a_is_big ? mb0 : ma;

    reg sign_big, same_sign;
    reg [7:0] exp_big, exp_small;
    reg [26:0] big_ext, small_ext;

    reg is_special;
    reg [31:0] special_res;

    reg [26:0] small_align;
    reg [27:0] mant_raw;

    reg [7:0] exp_norm;
    reg [26:0] mant_norm;

    reg [24:0] main24_rounded_sum_r;
    reg [23:0] frac23_rounded_sum_r;
    reg [7:0]  exp_norm_plus_1_r;

    wire [7:0] shift_amt_w;
    adder #(.WIDTH(8)) u_sub_shift_amt (
        .a   (exp_big),
        .b   (~exp_small),
        .cin (1'b1),
        .sum (shift_amt_w),
        .cout()
    );

    wire [26:0] mask_shifted_w = ~(27'h7FFFFFF << shift_amt_w);
    wire sticky_raw_w = |(small_ext & mask_shifted_w);
    wire [26:0] small_align_w = (shift_amt_w >= 8'd27) ? {26'd0, |small_ext} : ((small_ext >> shift_amt_w) | {26'd0, sticky_raw_w});

    wire [4:0] lz;
    lzc_27 u_lzc (.in(mant_raw[26:0]), .out(lz));

    wire [7:0] exp_big_minus_1;
    adder #(.WIDTH(8)) u_sub_exp_big_minus_1 (
        .a   (exp_big),
        .b   (~8'd1),
        .cin (1'b1),
        .sum (exp_big_minus_1),
        .cout()
    );

    wire shift_limited_w = ({3'd0, lz} > exp_big_minus_1);
    wire [7:0] actual_shift_w = shift_limited_w ? exp_big_minus_1 : {3'd0, lz};

    wire [27:0] calc_op2 = same_sign ? {1'b0, small_align} : ~{1'b0, small_align};
    wire        calc_cin = ~same_sign;
    wire [27:0] calc_sum;
    adder #(.WIDTH(28)) u_calc_adder (
        .a   ({1'b0, big_ext}),
        .b   (calc_op2),
        .cin (calc_cin),
        .sum (calc_sum),
        .cout()
    );

    wire [7:0] exp_big_plus_1;
    adder #(.WIDTH(8)) u_add_exp_big_plus_1 (
        .a   (exp_big),
        .b   (8'd1),
        .cin (1'b0),
        .sum (exp_big_plus_1),
        .cout()
    );

    wire [7:0] exp_big_minus_actual_shift;
    adder #(.WIDTH(8)) u_sub_exp_big_minus_actual_shift (
        .a   (exp_big),
        .b   (~actual_shift_w),
        .cin (1'b1),
        .sum (exp_big_minus_actual_shift),
        .cout()
    );

    wire [23:0] main24_w = mant_norm[26:3];
    wire round_up_w = mant_norm[2] & (mant_norm[1] | mant_norm[0] | main24_w[0]);
    wire [26:0] mant_subnorm_w = mant_norm >> 1;
    wire [22:0] frac_subnorm_w = mant_subnorm_w[25:3];
    wire round_up2_w = mant_subnorm_w[2] & (mant_subnorm_w[1] | mant_subnorm_w[0] | frac_subnorm_w[0]);

    wire [24:0] main24_rounded_sum_w;
    adder #(.WIDTH(25)) u_add_main24_round (
        .a   ({1'b0, main24_w}),
        .b   (25'd0),
        .cin (round_up_w),
        .sum (main24_rounded_sum_w),
        .cout()
    );

    wire [23:0] frac23_rounded_sum_w;
    adder #(.WIDTH(24)) u_add_frac23_round (
        .a   ({1'b0, frac_subnorm_w}),
        .b   (24'd0),
        .cin (round_up2_w),
        .sum (frac23_rounded_sum_w),
        .cout()
    );

    wire [7:0] exp_norm_plus_1_w;
    adder #(.WIDTH(8)) u_add_exp_norm_plus_1 (
        .a   (exp_norm),
        .b   (8'd1),
        .cin (1'b0),
        .sum (exp_norm_plus_1_w),
        .cout()
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0; 
                    if (start) begin
                        a_r <= a;
                        b_r <= b;
                        op_r <= op;
                        state <= S_UNPACK;
                    end
                end

                S_UNPACK: begin
                    is_special <= 1'b0;
                    if (any_nan || inf_opp_sign) begin
                        is_special <= 1'b1; special_res <= qnan;
                    end else if (a_is_inf) begin
                        is_special <= 1'b1; special_res <= {sa, 8'hFF, 23'd0};
                    end else if (b_is_inf) begin
                        is_special <= 1'b1; special_res <= {sb, 8'hFF, 23'd0};
                    end else if (a_is_zero && b_is_zero) begin
                        is_special <= 1'b1; special_res <= {(sa & sb), 8'd0, 23'd0};
                    end else if (a_is_zero) begin
                        is_special <= 1'b1; special_res <= {sb, eb, fb};
                    end else if (b_is_zero) begin
                        is_special <= 1'b1; special_res <= {sa, ea, fa};
                    end

                    sign_big   <= sign_big_w;
                    same_sign  <= ~(sign_big_w ^ sign_small_w);
                    exp_big    <= exp_big_w;
                    exp_small  <= exp_small_w;
                    big_ext    <= {mant_big_24_w, 3'b000};
                    small_ext  <= {mant_small_24_w, 3'b000};

                    state <= S_ALIGN;
                end

                S_ALIGN: begin
                    if (is_special) begin
                        state <= S_PACK; 
                    end else begin
                        small_align <= small_align_w; 
                        state <= S_CALC;
                    end
                end

                S_CALC: begin
                    mant_raw <= calc_sum;
                    state <= S_NORMALIZE;
                end

                S_NORMALIZE: begin
                    if (!same_sign && mant_raw[26:0] == 27'd0) begin
                        is_special <= 1'b1;
                        special_res <= {1'b0, 8'd0, 23'd0};
                        state <= S_PACK;
                    end else begin
                        if (same_sign) begin
                            mant_norm <= mant_raw[27] ? mant_raw[27:1] : mant_raw[26:0];
                            exp_norm  <= mant_raw[27] ? exp_big_plus_1 : exp_big;
                        end else begin
                            exp_norm  <= exp_big_minus_actual_shift;
                            mant_norm <= mant_raw[26:0] << lz; 
                        end
                        state <= S_ROUND;
                    end
                end

                S_ROUND: begin
                    main24_rounded_sum_r <= main24_rounded_sum_w;
                    frac23_rounded_sum_r <= frac23_rounded_sum_w;
                    exp_norm_plus_1_r    <= exp_norm_plus_1_w;
                    state <= S_PACK;
                end

                S_PACK: begin
                    if (is_special) begin
                        result <= special_res;
                    end else begin
                        if (exp_norm >= 8'hFF) begin
                            result <= {sign_big, 8'hFF, 23'd0};
                        end else begin
                            if (main24_rounded_sum_r[24]) begin
                                if (exp_norm == 8'hFE) result <= {sign_big, 8'hFF, 23'd0};
                                else                   result <= {sign_big, exp_norm_plus_1_r, 23'd0};
                            end else begin
                                if (exp_norm == 8'd1 && main24_rounded_sum_r[23] == 1'b0) begin
                                    if (frac23_rounded_sum_r[23]) result <= {sign_big, 8'd1, 23'd0};
                                    else                          result <= {sign_big, 8'd0, frac23_rounded_sum_r[22:0]};
                                end else if (exp_norm == 8'd1 && main24_rounded_sum_r[23] == 1'b1 && mant_norm[26] == 1'b0) begin
                                    result <= {sign_big, 8'd0, main24_rounded_sum_r[22:0]};
                                end else if (exp_norm == 8'd1 && mant_norm[26] == 1'b0) begin
                                    if (frac23_rounded_sum_r[23]) result <= {sign_big, 8'd1, 23'd0};
                                    else                          result <= {sign_big, 8'd0, frac23_rounded_sum_r[22:0]};
                                end else begin
                                    result <= {sign_big, exp_norm, main24_rounded_sum_r[22:0]};
                                end
                            end
                        end
                    end
                    done <= 1'b1;
                    state <= S_IDLE; 
                end
            endcase
        end
    end

endmodule