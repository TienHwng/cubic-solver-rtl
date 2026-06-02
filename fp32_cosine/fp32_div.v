module addN #(parameter W=8) (
  input  wire [W-1:0] a,
  input  wire [W-1:0] b,
  input  wire         cin,
  output wire [W-1:0] s,
  output wire         cout
);
  adder #(.WIDTH(W)) u_add(.a(a), .b(b), .cin(cin), .sum(s), .cout(cout));
endmodule

module subN #(parameter W=8) (
  input  wire [W-1:0] a,
  input  wire [W-1:0] b,
  output wire [W-1:0] d,
  output wire         no_borrow
);
  wire [W-1:0] b_inv = ~b;
  adder #(.WIDTH(W)) u_sub(.a(a), .b(b_inv), .cin(1'b1), .sum(d), .cout(no_borrow));
endmodule

module incN #(parameter W=8) (
  input  wire [W-1:0] a,
  output wire [W-1:0] y,
  output wire         cout
);
  wire [W-1:0] one = {{(W-1){1'b0}},1'b1};
  adder #(.WIDTH(W)) u_inc(.a(a), .b(one), .cin(1'b0), .sum(y), .cout(cout));
endmodule

module decN #(parameter W=8) (
  input  wire [W-1:0] a,
  output wire [W-1:0] y,
  output wire         no_borrow
);
  wire [W-1:0] one = {{(W-1){1'b0}},1'b1};
  subN #(.W(W)) u_dec(.a(a), .b(one), .d(y), .no_borrow(no_borrow));
endmodule

module lzc23(
  input  wire [22:0] in,
  output wire [4:0]  shamt,
  output wire        is_zero
);
  assign is_zero = (in == 23'b0);

  reg [4:0] r;
  always @* begin
    if (in[22])      r = 5'd0;
    else if (in[21]) r = 5'd1;
    else if (in[20]) r = 5'd2;
    else if (in[19]) r = 5'd3;
    else if (in[18]) r = 5'd4;
    else if (in[17]) r = 5'd5;
    else if (in[16]) r = 5'd6;
    else if (in[15]) r = 5'd7;
    else if (in[14]) r = 5'd8;
    else if (in[13]) r = 5'd9;
    else if (in[12]) r = 5'd10;
    else if (in[11]) r = 5'd11;
    else if (in[10]) r = 5'd12;
    else if (in[9])  r = 5'd13;
    else if (in[8])  r = 5'd14;
    else if (in[7])  r = 5'd15;
    else if (in[6])  r = 5'd16;
    else if (in[5])  r = 5'd17;
    else if (in[4])  r = 5'd18;
    else if (in[3])  r = 5'd19;
    else if (in[2])  r = 5'd20;
    else if (in[1])  r = 5'd21;
    else if (in[0])  r = 5'd22;
    else             r = 5'd23;
  end
  assign shamt = r;
endmodule

module udiv_restoring #(
  parameter N = 27,
  parameter M = 24
)(
  input  wire [N-1:0] dividend,
  input  wire [M-1:0] divisor,
  output wire [N-1:0] quotient,
  output wire [M:0]   remainder
);
  wire [M:0] rem [0:N];
  wire [N-1:0] q;

  assign rem[0] = {(M+1){1'b0}};

  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : DIV_STAGE
      wire bring = dividend[N-1-i];
      wire [M:0] rem_shift = {rem[i][M-1:0], bring};
      wire [M:0] div_ext = {1'b0, divisor};
      wire [M:0] rem_sub;
      wire       no_borrow;

      subN #(.W(M+1)) u_sub_stage(
        .a(rem_shift),
        .b(div_ext),
        .d(rem_sub),
        .no_borrow(no_borrow)
      );

      assign q[N-1-i]  = no_borrow;
      assign rem[i+1]  = no_borrow ? rem_sub : rem_shift;
    end
  endgenerate

  assign quotient  = q;
  assign remainder = rem[N];
endmodule

module fp32_div (
  input  wire [31:0] a,
  input  wire [31:0] b,
  output wire [31:0] y
);
  wire sa = a[31];
  wire sb = b[31];
  wire sy = sa ^ sb;

  wire [7:0] ea = a[30:23];
  wire [7:0] eb = b[30:23];
  wire [22:0] fa = a[22:0];
  wire [22:0] fb = b[22:0];

  wire a_exp_all1 = (ea == 8'hFF);
  wire b_exp_all1 = (eb == 8'hFF);
  wire a_exp_zero = (ea == 8'h00);
  wire b_exp_zero = (eb == 8'h00);

  wire a_frac_zero = (fa == 23'b0);
  wire b_frac_zero = (fb == 23'b0);

  wire a_is_nan = a_exp_all1 & ~a_frac_zero;
  wire b_is_nan = b_exp_all1 & ~b_frac_zero;

  wire a_is_inf = a_exp_all1 & a_frac_zero;
  wire b_is_inf = b_exp_all1 & b_frac_zero;

  wire a_is_zero = a_exp_zero & a_frac_zero;
  wire b_is_zero = b_exp_zero & b_frac_zero;

  wire [31:0] QNAN = 32'h7FC00000;
  wire [31:0] PINF = {1'b0, 8'hFF, 23'b0};
  wire [31:0] NINF = {1'b1, 8'hFF, 23'b0};
  wire [31:0] PZERO= 32'h00000000;
  wire [31:0] NZERO= 32'h80000000;

  wire [4:0] sh_a, sh_b;
  wire a_frac_is0, b_frac_is0;

  lzc23 u_lzc_a(.in(fa), .shamt(sh_a), .is_zero(a_frac_is0));
  lzc23 u_lzc_b(.in(fb), .shamt(sh_b), .is_zero(b_frac_is0));

  wire [23:0] mant_a_norm = {1'b1, fa};
  wire [23:0] mant_b_norm = {1'b1, fb};

  wire [23:0] mant_a_sub  = {fa, 1'b0} << sh_a;
  wire [23:0] mant_b_sub  = {fb, 1'b0} << sh_b;

  wire a_is_sub = a_exp_zero & ~a_frac_zero;
  wire b_is_sub = b_exp_zero & ~b_frac_zero;

  wire [23:0] mant_a = a_is_sub ? mant_a_sub : mant_a_norm;
  wire [23:0] mant_b = b_is_sub ? mant_b_sub : mant_b_norm;

  wire [9:0] ea_eff_norm = {2'b00, ea};
  wire [9:0] eb_eff_norm = {2'b00, eb};

  wire [9:0] one10 = 10'b0000000001;
  wire [9:0] sh_a10 = {5'b0, sh_a};
  wire [9:0] sh_b10 = {5'b0, sh_b};

  wire [9:0] ea_eff_sub;
  wire       ea_sub_no_borrow;
  subN #(.W(10)) u_ea_eff_sub(.a(one10), .b(sh_a10), .d(ea_eff_sub), .no_borrow(ea_sub_no_borrow));

  wire [9:0] eb_eff_sub;
  wire       eb_sub_no_borrow;
  subN #(.W(10)) u_eb_eff_sub(.a(one10), .b(sh_b10), .d(eb_eff_sub), .no_borrow(eb_sub_no_borrow));

  wire [9:0] ea_eff = a_is_sub ? ea_eff_sub : ea_eff_norm;
  wire [9:0] eb_eff = b_is_sub ? eb_eff_sub : eb_eff_norm;

  wire [9:0] exp_diff;
  wire       exp_no_borrow;
  subN #(.W(10)) u_exp_diff(.a(ea_eff), .b(eb_eff), .d(exp_diff), .no_borrow(exp_no_borrow));

  wire [9:0] bias10 = 10'd127;
  wire [9:0] exp_pre_norm;
  wire       exp_add_cout;
  addN #(.W(10)) u_exp_add_bias(.a(exp_diff), .b(bias10), .cin(1'b0), .s(exp_pre_norm), .cout(exp_add_cout));

  localparam integer QBITS = 3;
  localparam integer QW    = 24 + QBITS;
  localparam integer DIV_N = 24 + QW - 1;

  wire [DIV_N-1:0] dividend_ext = {mant_a, {(DIV_N-24){1'b0}}};
  wire [DIV_N-1:0] quot_full;
  wire [24:0]      rem_raw;

  udiv_restoring #(.N(DIV_N), .M(24)) u_div_mant(
    .dividend(dividend_ext),
    .divisor(mant_b),
    .quotient(quot_full),
    .remainder(rem_raw)
  );

  wire [QW-1:0] quot_raw = quot_full[QW-1:0];

  wire lead1 = quot_raw[QBITS+23];
  wire [QW-1:0] quot_norm = lead1 ? quot_raw : (quot_raw << 1);

  wire [9:0] exp_after_norm;
  wire       exp_dec_no_borrow;
  wire [9:0] exp_dec;
  decN #(.W(10)) u_dec_exp(.a(exp_pre_norm), .y(exp_dec), .no_borrow(exp_dec_no_borrow));
  assign exp_after_norm = lead1 ? exp_pre_norm : exp_dec;

  wire [23:0] mant24 = quot_norm[QBITS+23:QBITS];
  wire        guard  = quot_norm[QBITS-1];
  wire        roundb = (QBITS >= 2) ? quot_norm[QBITS-2] : 1'b0;

  wire sticky_low = (QBITS >= 3) ? (|quot_norm[QBITS-3:0]) : 1'b0;
  wire sticky_rem = |rem_raw;
  wire sticky = sticky_low | sticky_rem;

  wire lsb = mant24[0];
  wire round_up = guard & (roundb | sticky | lsb);

  wire [23:0] mant24_rounded;
  wire        mant24_cout;
  wire [23:0] round_inc = {{23{1'b0}}, round_up};

  addN #(.W(24)) u_round_add(.a(mant24), .b(round_inc), .cin(1'b0), .s(mant24_rounded), .cout(mant24_cout));

  wire [23:0] mant24_post = mant24_cout ? {1'b1, mant24_rounded[23:1]} : mant24_rounded;

  wire [9:0] exp_post_round;
  wire       exp_inc_cout;
  wire [9:0] exp_inc;
  incN #(.W(10)) u_inc_exp(.a(exp_after_norm), .y(exp_inc), .cout(exp_inc_cout));
  assign exp_post_round = mant24_cout ? exp_inc : exp_after_norm;

  wire [9:0] exp_255 = 10'd255;
  wire [9:0] exp_minus_255;
  wire       exp_ge_255;
  subN #(.W(10)) u_cmp_ov(.a(exp_post_round), .b(exp_255), .d(exp_minus_255), .no_borrow(exp_ge_255));

  wire exp_is_neg = exp_post_round[9];
  wire true_exp_ovf = exp_ge_255 & ~exp_is_neg;
  wire true_exp_udf = exp_is_neg | (exp_post_round == 10'b0);

  wire [7:0] exp_field_norm = exp_post_round[7:0];
  wire [22:0] frac_sub = mant24_post[22:0] >> 1;
  wire [22:0] frac_norm = mant24_post[22:0];

  reg [31:0] y_r;
  always @* begin
    if (a_is_nan) begin
      y_r = {1'b0, 8'hFF, 1'b1, a[21:0]};
    end else if (b_is_nan) begin
      y_r = {1'b0, 8'hFF, 1'b1, b[21:0]};
    end else if (a_is_inf && b_is_inf) begin
      y_r = QNAN;
    end else if (a_is_zero && b_is_zero) begin
      y_r = QNAN;
    end else if (~a_is_inf && ~a_is_nan && ~a_is_zero && b_is_zero) begin
      y_r = sy ? NINF : PINF;
    end else if (a_is_zero && ~b_is_zero && ~b_is_nan) begin
      y_r = sy ? NZERO : PZERO;
    end else if (a_is_inf && ~b_is_inf && ~b_is_nan && ~b_is_zero) begin
      y_r = sy ? NINF : PINF;
    end else if (~a_is_inf && ~a_is_nan && b_is_inf) begin
      y_r = sy ? NZERO : PZERO;
    end else begin
      if (true_exp_ovf) begin
        y_r = sy ? NINF : PINF;
      end else if (true_exp_udf) begin
        if (exp_post_round == 10'b0) begin
          y_r = {sy, 8'h00, frac_sub};
        end else begin
          y_r = {sy, 31'b0};
        end
      end else begin
        y_r = {sy, exp_field_norm, frac_norm};
      end
    end
  end

  assign y = y_r;

endmodule