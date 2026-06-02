module cubic_solver(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [31:0] c,
    input  wire [31:0] d,
    
    output reg         done,
    output reg  [31:0] x1_re,
    output reg  [31:0] x1_im,
    output reg  [31:0] x2_re,
    output reg  [31:0] x2_im,
    output reg  [31:0] x3_re,
    output reg  [31:0] x3_im
);

    localparam FP_2         = 32'h40000000;
    localparam FP_3         = 32'h40400000;
    localparam FP_MINUS_0_5 = 32'hBF000000;
    localparam FP_SQRT3_2   = 32'h3F5DB3D7;
    localparam FP_2PI_3     = 32'h40060A92;
    localparam FP_4PI_3     = 32'h40860A92;
    localparam FP_0         = 32'h00000000;

    reg [5:0] state;

    localparam IDLE         = 0;
    localparam CALC_BA      = 1;
    localparam CALC_CA      = 2;
    localparam CALC_DA      = 3;
    localparam CALC_B3A     = 4;
    localparam CALC_B3A_SQ  = 5;
    localparam CALC_TERM_Q2 = 6;
    localparam CALC_TERM_P2 = 7;
    localparam CALC_B3A_CB  = 8;
    localparam CALC_TERM_Q1 = 9;
    localparam CALC_P       = 10;
    localparam CALC_Q_TMP   = 11;
    localparam CALC_Q       = 12;
    localparam CALC_Q2      = 13;
    localparam CALC_P3      = 14;
    localparam CALC_Q2_SQ   = 15;
    localparam CALC_P3_SQ   = 16;
    localparam CALC_P3_CB   = 17;
    localparam CALC_DELTA   = 18;
    localparam CHECK_DELTA  = 19;

    localparam C_SQRT_DELTA = 20;
    localparam C_U_INNER    = 21;
    localparam C_V_INNER    = 22;
    localparam C_CBRT_U     = 23;
    localparam C_CBRT_V     = 24;
    localparam C_T1         = 25;
    localparam C_U_V_SUB    = 26;
    localparam C_X1_RE      = 27;
    localparam C_T23_RE_PRE = 28;
    localparam C_T23_IM_PRE = 29;
    localparam C_X23_RE     = 30;
    localparam C_FINISH     = 31;

    localparam V_SQRT       = 32;
    localparam V_DENOM      = 33;
    localparam V_ACOS_IN    = 34;
    localparam V_THETA      = 35;
    localparam V_THETA_3    = 36;
    localparam V_ANG1       = 37;
    localparam V_ANG2       = 38;
    localparam V_COS0       = 39;
    localparam V_COS1       = 40;
    localparam V_COS2       = 41;
    localparam V_COEF       = 42;
    localparam V_T1         = 43;
    localparam V_T2         = 44;
    localparam V_T3         = 45;
    localparam V_X1         = 46;
    localparam V_X2         = 47;
    localparam V_X3         = 48;
    localparam V_FINISH     = 49;

    reg [31:0] a_reg, b_reg, c_reg, d_reg;
    reg [31:0] ba, ca, da, b3a;
    reg [31:0] b3a_sq, term_q2, term_p2, b3a_cb, term_q1;
    reg [31:0] p, q_tmp, q, q2, p3;
    reg [31:0] q2_sq, p3_sq, p3_cb, delta;
    reg [31:0] minus_q2, minus_p3;

    reg [31:0] sqrt_delta, u_inner, v_inner, u, v, u_v_add, u_v_sub;
    reg [31:0] t23_re, t23_im_mag;

    reg [31:0] sqrt_minus_p3, denom, acos_inner, theta, theta_3;
    reg [31:0] angle1, angle2, cos0, cos1, cos2, coef, t1, t2, t3;

    reg  [31:0] add_a, add_b;
    reg         add_op;
    wire [31:0] add_out;
    fp32_addsub u_add( .a(add_a), .b(add_b), .op(add_op), .result(add_out) );

    reg  [31:0] mul_a, mul_b;
    wire [31:0] mul_out;
    fp32_mul    u_mul( .a(mul_a), .b(mul_b), .y(mul_out) );

    reg  [31:0] div_a, div_b;
    wire [31:0] div_out;
    fp32_div    u_div( .a(div_a), .b(div_b), .y(div_out) );

    reg  [31:0] sqrt_in;
    wire [31:0] sqrt_out;
    fp32_sqrt   u_sqrt( .x_in(sqrt_in), .sqrt_out(sqrt_out) );

    reg  [31:0] cbrt_in;
    wire [31:0] cbrt_out;
    fp32_cbrt   u_cbrt( .x_in(cbrt_in), .cbrt_out(cbrt_out) );

    reg  [31:0] acos_in;
    wire [31:0] acos_out;
    fp32_arccosine u_acos( .x_in(acos_in), .acos_out(acos_out) );

    reg  [31:0] cos_in;
    wire [31:0] cos_out;
    fp32_cosine u_cos( .x_in(cos_in), .cos_out(cos_out) );

    always @(*) begin
        add_a = FP_0; add_b = FP_0; add_op = 0;
        mul_a = FP_0; mul_b = FP_0;
        div_a = FP_0; div_b = FP_0;
        sqrt_in = FP_0; cbrt_in = FP_0;
        acos_in = FP_0; cos_in = FP_0;

        case (state)
            CALC_BA:      begin div_a = b_reg; div_b = a_reg; end
            CALC_CA:      begin div_a = c_reg; div_b = a_reg; end
            CALC_DA:      begin div_a = d_reg; div_b = a_reg; end
            CALC_B3A:     begin div_a = ba; div_b = FP_3; end
            CALC_B3A_SQ:  begin mul_a = b3a; mul_b = b3a; end
            CALC_TERM_Q2: begin mul_a = b3a; mul_b = ca; end
            CALC_TERM_P2: begin mul_a = FP_3; mul_b = b3a_sq; end
            CALC_B3A_CB:  begin mul_a = b3a_sq; mul_b = b3a; end
            CALC_TERM_Q1: begin mul_a = FP_2; mul_b = b3a_cb; end
            CALC_P:       begin add_a = ca; add_b = term_p2; add_op = 1; end
            CALC_Q_TMP:   begin add_a = term_q1; add_b = term_q2; add_op = 1; end
            CALC_Q:       begin add_a = q_tmp; add_b = da; add_op = 0; end
            CALC_Q2:      begin div_a = q; div_b = FP_2; end
            CALC_P3:      begin div_a = p; div_b = FP_3; end
            CALC_Q2_SQ:   begin mul_a = q2; mul_b = q2; end
            CALC_P3_SQ:   begin mul_a = p3; mul_b = p3; end
            CALC_P3_CB:   begin mul_a = p3_sq; mul_b = p3; end
            CALC_DELTA:   begin add_a = q2_sq; add_b = p3_cb; add_op = 0; end

            C_SQRT_DELTA: begin sqrt_in = delta; end
            C_U_INNER:    begin add_a = minus_q2; add_b = sqrt_delta; add_op = 0; end
            C_V_INNER:    begin add_a = minus_q2; add_b = sqrt_delta; add_op = 1; end
            C_CBRT_U:     begin cbrt_in = u_inner; end
            C_CBRT_V:     begin cbrt_in = v_inner; end
            C_T1:         begin add_a = u; add_b = v; add_op = 0; end
            C_U_V_SUB:    begin add_a = u; add_b = v; add_op = 1; end
            C_X1_RE:      begin add_a = u_v_add; add_b = b3a; add_op = 1; end
            C_T23_RE_PRE: begin mul_a = FP_MINUS_0_5; mul_b = u_v_add; end
            C_T23_IM_PRE: begin mul_a = FP_SQRT3_2; mul_b = u_v_sub; end
            C_X23_RE:     begin add_a = t23_re; add_b = b3a; add_op = 1; end

            V_SQRT:       begin sqrt_in = minus_p3; end
            V_DENOM:      begin mul_a = minus_p3; mul_b = sqrt_minus_p3; end
            V_ACOS_IN:    begin div_a = minus_q2; div_b = denom; end
            V_THETA:      begin acos_in = acos_inner; end
            V_THETA_3:    begin div_a = theta; div_b = FP_3; end
            V_ANG1:       begin add_a = theta_3; add_b = FP_2PI_3; add_op = 0; end
            V_ANG2:       begin add_a = theta_3; add_b = FP_4PI_3; add_op = 0; end
            V_COS0:       begin cos_in = theta_3; end
            V_COS1:       begin cos_in = angle1; end
            V_COS2:       begin cos_in = angle2; end
            V_COEF:       begin mul_a = FP_2; mul_b = sqrt_minus_p3; end
            V_T1:         begin mul_a = coef; mul_b = cos0; end
            V_T2:         begin mul_a = coef; mul_b = cos1; end
            V_T3:         begin mul_a = coef; mul_b = cos2; end
            V_X1:         begin add_a = t1; add_b = b3a; add_op = 1; end
            V_X2:         begin add_a = t2; add_b = b3a; add_op = 1; end
            V_X3:         begin add_a = t3; add_b = b3a; add_op = 1; end
            default: ;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done  <= 0;
            x1_re <= 0; x1_im <= 0;
            x2_re <= 0; x2_im <= 0;
            x3_re <= 0; x3_im <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        a_reg <= a; b_reg <= b; c_reg <= c; d_reg <= d;
                        state <= CALC_BA;
                    end
                end
                
                CALC_BA:      begin ba      <= div_out; state <= CALC_CA; end
                CALC_CA:      begin ca      <= div_out; state <= CALC_DA; end
                CALC_DA:      begin da      <= div_out; state <= CALC_B3A; end
                CALC_B3A:     begin b3a     <= div_out; state <= CALC_B3A_SQ; end
                CALC_B3A_SQ:  begin b3a_sq  <= mul_out; state <= CALC_TERM_Q2; end
                CALC_TERM_Q2: begin term_q2 <= mul_out; state <= CALC_TERM_P2; end
                CALC_TERM_P2: begin term_p2 <= mul_out; state <= CALC_B3A_CB; end
                CALC_B3A_CB:  begin b3a_cb  <= mul_out; state <= CALC_TERM_Q1; end
                CALC_TERM_Q1: begin term_q1 <= mul_out; state <= CALC_P; end
                CALC_P:       begin p       <= add_out; state <= CALC_Q_TMP; end
                CALC_Q_TMP:   begin q_tmp   <= add_out; state <= CALC_Q; end
                CALC_Q:       begin q       <= add_out; state <= CALC_Q2; end
                CALC_Q2:      begin q2      <= div_out; state <= CALC_P3; end
                CALC_P3:      begin p3      <= div_out; state <= CALC_Q2_SQ; end
                CALC_Q2_SQ:   begin q2_sq   <= mul_out; state <= CALC_P3_SQ; end
                CALC_P3_SQ:   begin p3_sq   <= mul_out; state <= CALC_P3_CB; end
                CALC_P3_CB:   begin p3_cb   <= mul_out; state <= CALC_DELTA; end
                CALC_DELTA:   begin delta   <= add_out; state <= CHECK_DELTA; end
                
                CHECK_DELTA: begin
                    minus_q2 <= {~q2[31], q2[30:0]};
                    minus_p3 <= {~p3[31], p3[30:0]};
                    
                    if (delta[31]) begin
                        state <= V_SQRT; 
                    end else begin
                        state <= C_SQRT_DELTA; 
                    end
                end

                C_SQRT_DELTA: begin sqrt_delta <= sqrt_out; state <= C_U_INNER; end
                C_U_INNER:    begin u_inner    <= add_out;  state <= C_V_INNER; end
                C_V_INNER:    begin v_inner    <= add_out;  state <= C_CBRT_U; end
                C_CBRT_U:     begin u          <= cbrt_out; state <= C_CBRT_V; end
                C_CBRT_V:     begin v          <= cbrt_out; state <= C_T1; end
                C_T1:         begin u_v_add    <= add_out;  state <= C_U_V_SUB; end
                C_U_V_SUB:    begin u_v_sub    <= add_out;  state <= C_X1_RE; end
                C_X1_RE:      begin x1_re      <= add_out;  x1_im <= FP_0; state <= C_T23_RE_PRE; end
                C_T23_RE_PRE: begin t23_re     <= mul_out;  state <= C_T23_IM_PRE; end
                C_T23_IM_PRE: begin t23_im_mag <= mul_out;  state <= C_X23_RE; end
                C_X23_RE: begin
                    x2_re <= add_out; 
                    x3_re <= add_out;
                    state <= C_FINISH;
                end
                C_FINISH: begin
                    x2_im <= t23_im_mag;
                    x3_im <= {~t23_im_mag[31], t23_im_mag[30:0]}; 
                    done  <= 1;
                    state <= IDLE;
                end

                V_SQRT:       begin sqrt_minus_p3 <= sqrt_out; state <= V_DENOM; end
                V_DENOM:      begin denom         <= mul_out;  state <= V_ACOS_IN; end
                V_ACOS_IN:    begin acos_inner    <= div_out;  state <= V_THETA; end
                V_THETA:      begin theta         <= acos_out; state <= V_THETA_3; end
                V_THETA_3:    begin theta_3       <= div_out;  state <= V_ANG1; end
                V_ANG1:       begin angle1        <= add_out;  state <= V_ANG2; end
                V_ANG2:       begin angle2        <= add_out;  state <= V_COS0; end
                V_COS0:       begin cos0          <= cos_out;  state <= V_COS1; end
                V_COS1:       begin cos1          <= cos_out;  state <= V_COS2; end
                V_COS2:       begin cos2          <= cos_out;  state <= V_COEF; end
                V_COEF:       begin coef          <= mul_out;  state <= V_T1; end
                V_T1:         begin t1            <= mul_out;  state <= V_T2; end
                V_T2:         begin t2            <= mul_out;  state <= V_T3; end
                V_T3:         begin t3            <= mul_out;  state <= V_X1; end
                V_X1:         begin x1_re         <= add_out;  state <= V_X2; end
                V_X2:         begin x2_re         <= add_out;  state <= V_X3; end
                V_X3:         begin x3_re         <= add_out;  state <= V_FINISH; end
                V_FINISH: begin
                    x1_im <= FP_0;
                    x2_im <= FP_0;
                    x3_im <= FP_0;
                    done  <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule