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
  output wire         is_zero
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
    else              r = 5'd23;
  end
  assign shamt = r;
endmodule

module udiv_restoring_seq #(
  parameter N = 50,
  parameter M = 24
)(
  input  wire         clk,
  input  wire         rst_n,
  input  wire         start,
  input  wire [N-1:0] dividend,
  input  wire [M-1:0] divisor,
  output reg  [N-1:0] quotient,
  output reg  [M:0]   remainder,
  output reg          done
);
  localparam IDLE = 1'b0;
  localparam CALC = 1'b1;
  reg state;

  reg [M:0]   rem_r;
  reg [N-1:0] q_r;
  reg [N-1:0] divd_r;
  reg [M-1:0] div_r;
  reg [5:0]   count;

  wire bring = divd_r[N-1];
  wire [M:0] rem_shift = {rem_r[M-1:0], bring};
  wire [M:0] div_ext = {1'b0, div_r};
  wire [M:0] rem_sub;
  wire       no_borrow;

  subN #(.W(M+1)) u_sub_stage(
    .a(rem_shift),
    .b(div_ext),
    .d(rem_sub),
    .no_borrow(no_borrow)
  );

  wire [5:0] count_next;
  adder #(.WIDTH(6)) u_count_inc (
    .a  (count),
    .b  (6'd1),
    .cin(1'b0),
    .sum(count_next),
    .cout()
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      quotient  <= 0;
      remainder <= 0;
      done      <= 0;
      count     <= 0;
      rem_r     <= 0;
      q_r       <= 0;
      divd_r    <= 0;
      div_r     <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            divd_r <= dividend;
            div_r  <= divisor;
            rem_r  <= {(M+1){1'b0}};
            q_r    <= 0;
            count  <= 0;
            state  <= CALC;
          end
        end
        CALC: begin
          divd_r <= {divd_r[N-2:0], 1'b0};
          q_r    <= {q_r[N-2:0], no_borrow};
          rem_r  <= no_borrow ? rem_sub : rem_shift;
          
          if (count == N-1) begin
            quotient  <= {q_r[N-2:0], no_borrow};
            remainder <= no_borrow ? rem_sub : rem_shift;
            done      <= 1'b1;
            state     <= IDLE;
          end else begin
            count <= count_next;
          end
        end
      endcase
    end
  end
endmodule

module fp32_div (
  input  wire         clk,
  input  wire         rst_n,
  input  wire         start,
  input  wire [31:0]  a,
  input  wire [31:0]  b,
  output wire [31:0]  y,
  output wire         done
);

  localparam ST_IDLE      = 2'd0;
  localparam ST_START_DIV = 2'd1;
  localparam ST_DIV       = 2'd2;
  localparam ST_ROUND     = 2'd3;
  reg [1:0] state;

  reg [31:0] a_reg, b_reg;
  reg [31:0] y_out;
  reg         done_out;

  assign y    = y_out;
  assign done = done_out;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_reg <= 0;
      b_reg <= 0;
    end else if (state == ST_IDLE && start) begin
      a_reg <= a;
      b_reg <= b;
    end
  end

  wire sa = a_reg[31];
  wire sb = b_reg[31];
  wire sy = sa ^ sb;

  wire [7:0] ea = a_reg[30:23];
  wire [7:0] eb = b_reg[30:23];
  wire [22:0] fa = a_reg[22:0];
  wire [22:0] fb = b_reg[22:0];

  wire a_exp_all1  = (ea == 8'hFF);
  wire b_exp_all1  = (eb == 8'hFF);
  wire a_exp_zero  = (ea == 8'h00);
  wire b_exp_zero  = (eb == 8'h00);
  wire a_frac_zero = (fa == 23'b0);
  wire b_frac_zero = (fb == 23'b0);

  wire a_is_nan  = a_exp_all1 & ~a_frac_zero;
  wire b_is_nan  = b_exp_all1 & ~b_frac_zero;
  wire a_is_inf  = a_exp_all1 & a_frac_zero;
  wire b_is_inf  = b_exp_all1 & b_frac_zero;
  wire a_is_zero = a_exp_zero & a_frac_zero;
  wire b_is_zero = b_exp_zero & b_frac_zero;

  wire [31:0] QNAN  = 32'h7FC00000;
  wire [31:0] PINF  = {1'b0, 8'hFF, 23'b0};
  wire [31:0] NINF  = {1'b1, 8'hFF, 23'b0};
  wire [31:0] PZERO = 32'h00000000;
  wire [31:0] NZERO = 32'h80000000;

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
  wire [9:0] one10       = 10'b0000000001;
  wire [9:0] sh_a10      = {5'b0, sh_a};
  wire [9:0] sh_b10      = {5'b0, sh_b};

  wire [9:0] ea_eff_sub, eb_eff_sub;
  wire       ea_sub_no_borrow, eb_sub_no_borrow;
  subN #(.W(10)) u_ea_eff_sub(.a(one10), .b(sh_a10), .d(ea_eff_sub), .no_borrow(ea_sub_no_borrow));
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
  
  reg              div_start;
  wire             div_done;
  wire [DIV_N-1:0] quot_full_wire;
  wire [24:0]      rem_raw_wire;

  udiv_restoring_seq #(.N(DIV_N), .M(24)) u_div_mant (
    .clk(clk),
    .rst_n(rst_n),
    .start(div_start),
    .dividend(dividend_ext),
    .divisor(mant_b),
    .quotient(quot_full_wire),
    .remainder(rem_raw_wire),
    .done(div_done)
  );

  reg [DIV_N-1:0] quot_full_reg;
  reg [24:0]      rem_raw_reg;

  wire [QW-1:0] quot_raw = quot_full_reg[QW-1:0];
  wire lead1             = quot_raw[QBITS+23];
  wire [QW-1:0] quot_norm = lead1 ? quot_raw : (quot_raw << 1);

  wire [9:0] exp_after_norm;
  wire       exp_dec_no_borrow;
  wire [9:0] exp_dec;
  decN #(.W(10)) u_dec_exp(.a(exp_pre_norm), .y(exp_dec), .no_borrow(exp_dec_no_borrow));
  assign exp_after_norm = lead1 ? exp_pre_norm : exp_dec;

  wire [23:0] mant24     = quot_norm[QBITS+23:QBITS];
  wire         guard      = quot_norm[QBITS-1];
  wire         roundb     = (QBITS >= 2) ? quot_norm[QBITS-2] : 1'b0;
  wire         sticky_low = (QBITS >= 3) ? (|quot_norm[QBITS-3:0]) : 1'b0;
  wire         sticky_rem = |rem_raw_reg;
  wire         sticky     = sticky_low | sticky_rem;

  wire lsb      = mant24[0];
  wire round_up = guard & (roundb | sticky | lsb);

  wire [23:0] mant24_rounded;
  wire         mant24_cout;
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

  wire exp_is_neg   = exp_post_round[9];
  wire true_exp_ovf = exp_ge_255 & ~exp_is_neg;
  wire true_exp_udf = exp_is_neg | (exp_post_round == 10'b0);

  wire [7:0]   exp_field_norm = exp_post_round[7:0];
  wire [22:0] frac_sub       = mant24_post[22:0] >> 1;
  wire [22:0] frac_norm      = mant24_post[22:0];

  wire is_special = a_is_nan | b_is_nan | (a_is_inf && b_is_inf) | (a_is_zero && b_is_zero) |
                    (~a_is_inf && ~a_is_nan && ~a_is_zero && b_is_zero) |
                    (a_is_zero && ~b_is_zero && ~b_is_nan) |
                    (a_is_inf && ~b_is_inf && ~b_is_nan && ~b_is_zero) |
                    (~a_is_inf && ~a_is_nan && b_is_inf);

  reg [31:0] y_r;
  always @* begin
    if (a_is_nan)                                                                    y_r = {1'b0, 8'hFF, 1'b1, a_reg[21:0]};
    else if (b_is_nan)                                                              y_r = {1'b0, 8'hFF, 1'b1, b_reg[21:0]};
    else if (a_is_inf && b_is_inf)                                                  y_r = QNAN;
    else if (a_is_zero && b_is_zero)                                                y_r = QNAN;
    else if (~a_is_inf && ~a_is_nan && ~a_is_zero && b_is_zero)                     y_r = sy ? NINF : PINF;
    else if (a_is_zero && ~b_is_zero && ~b_is_nan)                                  y_r = sy ? NZERO : PZERO;
    else if (a_is_inf && ~b_is_inf && ~b_is_nan && ~b_is_zero)                      y_r = sy ? NINF : PINF;
    else if (~a_is_inf && ~a_is_nan && b_is_inf)                                    y_r = sy ? NZERO : PZERO;
    else begin
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

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= ST_IDLE;
      div_start     <= 1'b0;
      quot_full_reg <= 0;
      rem_raw_reg   <= 0;
      y_out         <= 0;
      done_out      <= 1'b0;
    end else begin
      case (state)
        ST_IDLE: begin
          done_out <= 1'b0;
          if (start) begin
            state <= ST_START_DIV;
          end
        end
        
        ST_START_DIV: begin
          if (is_special) begin
            state <= ST_ROUND; 
          end else begin
            div_start <= 1'b1;
            state     <= ST_DIV;
          end
        end
        
        ST_DIV: begin
          div_start <= 1'b0; 
          if (div_done) begin
            quot_full_reg <= quot_full_wire;
            rem_raw_reg   <= rem_raw_wire;
            state         <= ST_ROUND;
          end
        end
        
        ST_ROUND: begin
          y_out    <= y_r;
          done_out <= 1'b1;
          state    <= ST_IDLE;
        end
        
        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule