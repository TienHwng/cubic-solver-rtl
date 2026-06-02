module fp32_mul (
  input  wire [31:0] a,
  input  wire [31:0] b,
  output wire [31:0] y
);

  wire        sa = a[31];
  wire [7:0]  ea = a[30:23];
  wire [22:0] fa = a[22:0];

  wire        sb = b[31];
  wire [7:0]  eb = b[30:23];
  wire [22:0] fb = b[22:0];

  wire s_out = sa ^ sb;

  wire a_is_zero = (ea == 8'h00) && (fa == 23'd0);
  wire b_is_zero = (eb == 8'h00) && (fb == 23'd0);

  wire a_is_sub  = (ea == 8'h00) && (fa != 23'd0);
  wire b_is_sub  = (eb == 8'h00) && (fb != 23'd0);

  wire a_is_inf  = (ea == 8'hFF) && (fa == 23'd0);
  wire b_is_inf  = (eb == 8'hFF) && (fb == 23'd0);

  wire a_is_nan  = (ea == 8'hFF) && (fa != 23'd0);
  wire b_is_nan  = (eb == 8'hFF) && (fb != 23'd0);

  wire [31:0] qnan = {1'b0, 8'hFF, 1'b1, 22'd0};

  wire [23:0] ma = (ea == 8'h00) ? {1'b0, fa} : {1'b1, fa};
  wire [23:0] mb = (eb == 8'h00) ? {1'b0, fb} : {1'b1, fb};

  wire [7:0] ea_eff = (ea == 8'h00) ? 8'd1 : ea;
  wire [7:0] eb_eff = (eb == 8'h00) ? 8'd1 : eb;

  wire [31:0] ea_ext = {24'd0, ea_eff};
  wire [31:0] eb_ext = {24'd0, eb_eff};

  wire [31:0] exp_add;
  wire        exp_add_cout;

  adder #(.WIDTH(32)) u_exp_add (
    .a   (ea_ext),
    .b   (eb_ext),
    .cin (1'b0),
    .sum (exp_add),
    .cout(exp_add_cout)
  );

  localparam [31:0] BIAS = 32'd127;
  wire [31:0] neg_bias = ~BIAS;

  wire [31:0] exp_unadj;
  wire        exp_unadj_cout;

  adder #(.WIDTH(32)) u_exp_sub_bias (
    .a   (exp_add),
    .b   (neg_bias),
    .cin (1'b1),
    .sum (exp_unadj),
    .cout(exp_unadj_cout)
  );

  wire [47:0] prod;
  
  mul24 multiply (.a(ma), .b(mb), .p(prod));

  wire need_shift_r1 = prod[47];

  wire [47:0] norm0 = need_shift_r1 ? (prod >> 1) : prod;

  wire [31:0] exp_norm;
  wire        exp_norm_cout;

  adder #(.WIDTH(32)) u_exp_norm_inc (
    .a   (exp_unadj),
    .b   (32'd0),
    .cin (need_shift_r1),
    .sum (exp_norm),
    .cout(exp_norm_cout)
  );

  wire exp_is_zero_or_neg = (exp_norm[31] == 1'b1) || (exp_norm[7:0] == 8'd0) || (exp_norm[31:8] != 24'd0);

  wire [31:0] one32 = 32'd1;
  wire [31:0] neg_exp_norm = ~exp_norm;
  wire [31:0] one_minus_exp;
  wire        one_minus_exp_cout;

  adder #(.WIDTH(32)) u_one_minus_exp (
    .a   (one32),
    .b   (neg_exp_norm),
    .cin (1'b1),
    .sum (one_minus_exp),
    .cout(one_minus_exp_cout)
  );

  wire [7:0] shift_amt = (exp_norm[7:0] == 8'd0) ? 8'd1 : one_minus_exp[7:0];

  wire shift_too_much = (shift_amt >= 8'd48);

  wire [47:0] sub_shifted = shift_too_much ? 48'd0 : (norm0 >> shift_amt);

  wire use_subnormal = (exp_norm[31:8] != 24'd0) ? 1'b1 :
                       (exp_norm[7:0] == 8'd0)    ? 1'b1 :
                       (exp_norm[7:0] < 8'd1)     ? 1'b1 : 1'b0;

  wire [47:0] work_sig = use_subnormal ? sub_shifted : norm0;

  wire [7:0] exp_field_pre = use_subnormal ? 8'h00 : exp_norm[7:0];

  wire [22:0] frac_pre = work_sig[45:23];
  wire        guard    = work_sig[22];
  wire        roundb   = work_sig[21];
  wire        sticky   = |work_sig[20:0];

  wire        lsb       = frac_pre[0];
  wire        inc       = guard & (roundb | sticky | lsb);

  wire [22:0] frac_rounded;
  wire        renorm_after_round;

  adder #(.WIDTH(23)) u_frac_round (
    .a   (frac_pre),
    .b   (23'd0),
    .cin (inc),
    .sum (frac_rounded),
    .cout(renorm_after_round)
  );

  wire [7:0] exp_field_post;

  adder #(.WIDTH(8)) u_exp_after_round (
    .a   (exp_field_pre),
    .b   (8'd0),
    .cin (renorm_after_round & ~use_subnormal),
    .sum (exp_field_post),
    .cout()
  );

  wire [22:0] mant_field_post = (renorm_after_round & ~use_subnormal) ? 23'd0 : frac_rounded;

  wire overflow_to_inf = (~use_subnormal) && (exp_field_post == 8'hFF);

  wire sub_becomes_zero = use_subnormal && ( (work_sig[45:0] == 46'd0) );

  reg [31:0] y_r;

  always @* begin
    if (a_is_nan) begin
      y_r = {1'b0, 8'hFF, 1'b1, fa[21:0]};
    end else if (b_is_nan) begin
      y_r = {1'b0, 8'hFF, 1'b1, fb[21:0]};
    end
    else if ( (a_is_inf && b_is_zero) || (b_is_inf && a_is_zero) ) begin
      y_r = qnan;
    end
    else if (a_is_inf || b_is_inf) begin
      y_r = {s_out, 8'hFF, 23'd0};
    end
    else if (a_is_zero || b_is_zero || sub_becomes_zero) begin
      y_r = {s_out, 8'h00, 23'd0};
    end
    else if (overflow_to_inf) begin
      y_r = {s_out, 8'hFF, 23'd0};
    end
    else begin
      y_r = {s_out, exp_field_post, mant_field_post};
    end
  end

  assign y = y_r;

endmodule