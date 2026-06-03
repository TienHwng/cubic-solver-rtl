module fp32_mul (
  input  wire         clk,
  input  wire         rst_n,
  input  wire         start,
  input  wire [31:0]  a,
  input  wire [31:0]  b,
  output reg  [31:0]  y,
  output reg          done
);

  localparam ST_IDLE      = 2'd0;
  localparam ST_START_MUL = 2'd1;
  localparam ST_MUL       = 2'd2;
  localparam ST_ROUND     = 2'd3;
  reg [1:0] state;

  reg [31:0] a_reg, b_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_reg <= 32'd0;
      b_reg <= 32'd0;
    end else if (state == ST_IDLE && start) begin
      a_reg <= a;
      b_reg <= b;
    end
  end

  wire        sa = a_reg[31];
  wire [7:0]  ea = a_reg[30:23];
  wire [22:0] fa = a_reg[22:0];

  wire        sb = b_reg[31];
  wire [7:0]  eb = b_reg[30:23];
  wire [22:0] fb = b_reg[22:0];

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

  reg         mul_start;
  wire        mul_done;
  wire [47:0] prod_wire;
  reg  [47:0] prod_reg;

  mul24 multiply (
    .clk  (clk),
    .rst_n(rst_n),
    .start(mul_start),
    .a    (ma),
    .b    (mb),
    .p    (prod_wire),
    .done (mul_done)
  );

  wire need_shift_r1 = prod_reg[47];

  wire [47:0] norm0 = need_shift_r1 ? (prod_reg >> 1) : prod_reg;

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

  wire is_special = a_is_nan | b_is_nan | 
                    ((a_is_inf && b_is_zero) || (b_is_inf && a_is_zero)) | 
                    a_is_inf | b_is_inf | a_is_zero | b_is_zero;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= ST_IDLE;
      mul_start <= 1'b0;
      prod_reg  <= 48'd0;
      y         <= 32'd0;
      done      <= 1'b0;
    end else begin
      case (state)
        ST_IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= ST_START_MUL;
          end
        end
        
        ST_START_MUL: begin
          if (is_special) begin
            state <= ST_ROUND;
          end else begin
            mul_start <= 1'b1;
            state     <= ST_MUL;
          end
        end
        
        ST_MUL: begin
          mul_start <= 1'b0;
          if (mul_done) begin
            prod_reg <= prod_wire;
            state    <= ST_ROUND;
          end
        end
        
        ST_ROUND: begin
          y     <= y_r;
          done  <= 1'b1;
          state <= ST_IDLE;
        end
        
        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule

module mul24 (
  input  wire         clk,
  input  wire         rst_n,
  input  wire         start,
  input  wire [23:0]  a,
  input  wire [23:0]  b,
  output reg  [47:0]  p,
  output reg          done
);
  localparam IDLE = 1'b0;
  localparam CALC = 1'b1;
  reg state;

  reg [47:0] accum;
  reg [47:0] a_ext;
  reg [23:0] b_reg;
  reg [4:0]  count;

  wire [47:0] sum_wire;
  
  adder #(.WIDTH(48)) u_mul_add (
    .a   (accum),
    .b   (a_ext),
    .cin (1'b0),
    .sum (sum_wire),
    .cout()
  );

  wire [4:0] next_count;
  adder #(.WIDTH(5)) u_count_inc (
    .a   (count),
    .b   (5'd1),
    .cin (1'b0),
    .sum (next_count),
    .cout()
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      accum <= 48'd0;
      a_ext <= 48'd0;
      b_reg <= 24'd0;
      count <= 5'd0;
      p     <= 48'd0;
      done  <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            accum <= 48'd0;
            a_ext <= {24'd0, a};
            b_reg <= b;
            count <= 5'd0;
            state <= CALC;
          end
        end
        
        CALC: begin
          accum <= b_reg[0] ? sum_wire : accum;
          a_ext <= a_ext << 1;
          b_reg <= b_reg >> 1;
          
          if (count == 5'd23) begin
            p     <= b_reg[0] ? sum_wire : accum;
            done  <= 1'b1;
            state <= IDLE;
          end else begin
            count <= next_count;
          end
        end
      endcase
    end
  end
endmodule