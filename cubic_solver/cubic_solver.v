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
    localparam FP_NAN       = 32'h7FC00000;

    reg [5:0] state;
    reg       req_start;
    reg       active_done;

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

    reg        add_start;
    reg  [31:0] add_a, add_b;
    reg        add_op;
    wire [31:0] add_out;
    wire        add_done;
    fp32_addsub u_add( .clk(clk), .rst_n(rst_n), .start(add_start), .a(add_a), .b(add_b), .op(add_op), .result(add_out), .done(add_done) );

    reg        mul_start;
    reg  [31:0] mul_a, mul_b;
    wire [31:0] mul_out;
    wire        mul_done;
    fp32_mul    u_mul( .clk(clk), .rst_n(rst_n), .start(mul_start), .a(mul_a), .b(mul_b), .y(mul_out), .done(mul_done) );

    reg        div_start;
    reg  [31:0] div_a, div_b;
    wire [31:0] div_out;
    wire        div_done;
    fp32_div    u_div( .clk(clk), .rst_n(rst_n), .start(div_start), .a(div_a), .b(div_b), .y(div_out), .done(div_done) );

    reg        sqrt_start;
    reg  [31:0] sqrt_in;
    wire [31:0] sqrt_out;
    wire        sqrt_done;
    fp32_sqrt   u_sqrt( .clk(clk), .rst_n(rst_n), .start(sqrt_start), .x_in(sqrt_in), .sqrt_out(sqrt_out), .done(sqrt_done) );

    reg        cbrt_start;
    reg  [31:0] cbrt_in;
    wire [31:0] cbrt_out;
    wire        cbrt_done;
    fp32_cbrt   u_cbrt( .clk(clk), .rst_n(rst_n), .start(cbrt_start), .x_in(cbrt_in), .cbrt_out(cbrt_out), .done(cbrt_done) );

    reg        acos_start;
    reg  [31:0] acos_in;
    wire [31:0] acos_out;
    wire        acos_done;
    fp32_arccosine u_acos( .clk(clk), .rst_n(rst_n), .start(acos_start), .x_in(acos_in), .acos_out(acos_out), .done(acos_done) );

    reg        cos_start;
    reg  [31:0] cos_in;
    wire [31:0] cos_out;
    wire        cos_done;
    fp32_cosine u_cos( .clk(clk), .rst_n(rst_n), .start(cos_start), .x_in(cos_in), .cos_out(cos_out), .done(cos_done) );

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

    always @(*) begin
        case (state)
            CALC_P, CALC_Q_TMP, CALC_Q, CALC_DELTA,
            C_U_INNER, C_V_INNER, C_T1, C_U_V_SUB, C_X1_RE, C_X23_RE,
            V_ANG1, V_ANG2, V_X1, V_X2, V_X3: 
                active_done = add_done;

            CALC_B3A_SQ, CALC_TERM_Q2, CALC_TERM_P2, CALC_B3A_CB, CALC_TERM_Q1,
            CALC_Q2_SQ, CALC_P3_SQ, CALC_P3_CB, C_T23_RE_PRE, C_T23_IM_PRE,
            V_DENOM, V_COEF, V_T1, V_T2, V_T3:
                active_done = mul_done;

            CALC_BA, CALC_CA, CALC_DA, CALC_B3A, CALC_Q2, CALC_P3,
            V_ACOS_IN, V_THETA_3:
                active_done = div_done;

            C_SQRT_DELTA, V_SQRT:
                active_done = sqrt_done;

            C_CBRT_U, C_CBRT_V:
                active_done = cbrt_done;

            V_THETA:
                active_done = acos_done;

            V_COS0, V_COS1, V_COS2:
                active_done = cos_done;
            
            default: active_done = 1'b1;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            add_start  <= 1'b0;
            mul_start  <= 1'b0;
            div_start  <= 1'b0;
            sqrt_start <= 1'b0;
            cbrt_start <= 1'b0;
            acos_start <= 1'b0;
            cos_start  <= 1'b0;
        end else begin
            add_start  <= 1'b0;
            mul_start  <= 1'b0;
            div_start  <= 1'b0;
            sqrt_start <= 1'b0;
            cbrt_start <= 1'b0;
            acos_start <= 1'b0;
            cos_start  <= 1'b0;

            if (req_start) begin
                case (state)
                    CALC_P, CALC_Q_TMP, CALC_Q, CALC_DELTA,
                    C_U_INNER, C_V_INNER, C_T1, C_U_V_SUB, C_X1_RE, C_X23_RE,
                    V_ANG1, V_ANG2, V_X1, V_X2, V_X3: 
                        add_start <= 1'b1;

                    CALC_B3A_SQ, CALC_TERM_Q2, CALC_TERM_P2, CALC_B3A_CB, CALC_TERM_Q1,
                    CALC_Q2_SQ, CALC_P3_SQ, CALC_P3_CB, C_T23_RE_PRE, C_T23_IM_PRE,
                    V_DENOM, V_COEF, V_T1, V_T2, V_T3:
                        mul_start <= 1'b1;

                    CALC_BA, CALC_CA, CALC_DA, CALC_B3A, CALC_Q2, CALC_P3,
                    V_ACOS_IN, V_THETA_3:
                        div_start <= 1'b1;

                    C_SQRT_DELTA, V_SQRT:
                        sqrt_start <= 1'b1;

                    C_CBRT_U, C_CBRT_V:
                        cbrt_start <= 1'b1;

                    V_THETA:
                        acos_start <= 1'b1;

                    V_COS0, V_COS1, V_COS2:
                        cos_start <= 1'b1;
                    default: ;
                endcase
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done  <= 0;
            x1_re <= 0; x1_im <= 0;
            x2_re <= 0; x2_im <= 0;
            x3_re <= 0; x3_im <= 0;
            req_start <= 0;
            a_reg <= 0; b_reg <= 0; c_reg <= 0; d_reg <= 0;
            ba <= 0; ca <= 0; da <= 0; b3a <= 0;
            b3a_sq <= 0; term_q2 <= 0; term_p2 <= 0; b3a_cb <= 0; term_q1 <= 0;
            p <= 0; q_tmp <= 0; q <= 0; q2 <= 0; p3 <= 0;
            q2_sq <= 0; p3_sq <= 0; p3_cb <= 0; delta <= 0;
            minus_q2 <= 0; minus_p3 <= 0;
            sqrt_delta <= 0; u_inner <= 0; v_inner <= 0; u <= 0; v <= 0; u_v_add <= 0; u_v_sub <= 0;
            t23_re <= 0; t23_im_mag <= 0;
            sqrt_minus_p3 <= 0; denom <= 0; acos_inner <= 0; theta <= 0; theta_3 <= 0;
            angle1 <= 0; angle2 <= 0; cos0 <= 0; cos1 <= 0; cos2 <= 0; coef <= 0; t1 <= 0; t2 <= 0; t3 <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        if (a[30:0] == 31'd0) begin
                            x1_re <= FP_NAN; x1_im <= FP_NAN;
                            x2_re <= FP_NAN; x2_im <= FP_NAN;
                            x3_re <= FP_NAN; x3_im <= FP_NAN;
                            done  <= 1'b1;
                            state <= IDLE;
                        end else begin
                            a_reg <= a; b_reg <= b; c_reg <= c; d_reg <= d;
                            state <= CALC_BA;
                            req_start <= 1'b1;
                        end
                    end
                end
                
                CHECK_DELTA: begin
                    minus_q2 <= {~q2[31], q2[30:0]};
                    minus_p3 <= {~p3[31], p3[30:0]};
                    req_start <= 1'b1;
                    if (delta[31]) begin
                        state <= V_SQRT; 
                    end else begin
                        state <= C_SQRT_DELTA; 
                    end
                end

                C_FINISH: begin
                    x1_im <= t23_im_mag;
                    x2_im <= {~t23_im_mag[31], t23_im_mag[30:0]}; 
                    x3_im <= FP_0;
                    done  <= 1;
                    state <= IDLE;
                end

                V_FINISH: begin
                    x1_im <= FP_0;
                    x2_im <= FP_0;
                    x3_im <= FP_0;
                    done  <= 1;
                    state <= IDLE;
                end

                default: begin
                    if (req_start) begin
                        req_start <= 1'b0;
                    end else if (active_done) begin
                        req_start <= 1'b1;
                        case (state)
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
                            
                            C_SQRT_DELTA: begin sqrt_delta <= sqrt_out; state <= C_U_INNER; end
                            C_U_INNER:    begin u_inner    <= add_out;  state <= C_V_INNER; end
                            C_V_INNER:    begin v_inner    <= add_out;  state <= C_CBRT_U; end
                            C_CBRT_U:     begin u          <= cbrt_out; state <= C_CBRT_V; end
                            C_CBRT_V:     begin v          <= cbrt_out; state <= C_T1; end
                            C_T1:         begin u_v_add    <= add_out;  state <= C_U_V_SUB; end
                            C_U_V_SUB:    begin u_v_sub    <= add_out;  state <= C_X1_RE; end
                            
                            C_X1_RE:      begin x3_re      <= add_out;  state <= C_T23_RE_PRE; end
                            C_T23_RE_PRE: begin t23_re     <= mul_out;  state <= C_T23_IM_PRE; end
                            C_T23_IM_PRE: begin t23_im_mag <= mul_out;  state <= C_X23_RE; end
                            C_X23_RE: begin
                                x1_re <= add_out; 
                                x2_re <= add_out;
                                state <= C_FINISH;
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
                            default:      state <= IDLE;
                        endcase
                    end
                end
            endcase
        end
    end

endmodule