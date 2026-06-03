module fp32_cosine (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] x_in,
    output reg  [31:0] cos_out,
    output reg         done
);

    localparam [31:0] PI_MAG     = 32'h40490FDB;
    localparam [31:0] TWO_PI     = 32'h40C90FDB;
    localparam [31:0] INV_TWO_PI = 32'h3E22F983;
    localparam [31:0] ONE_FP32   = 32'h3F800000;

    localparam [31:0] C_A = 32'h3665A2D1;
    localparam [31:0] C_B = 32'hBA19EABC;
    localparam [31:0] C_C = 32'h3CFCA933;
    localparam [31:0] C_D = 32'hBEF4AA97;

    localparam [31:0] C_E = 32'h31D65204;
    localparam [31:0] C_F = 32'h35DFB8AB;
    localparam [31:0] C_G = 32'h39804661;
    localparam [31:0] C_H = 32'h3CB55A1F;

    localparam [5:0]
        S_IDLE          = 6'd0,
        S_DO_MUL        = 6'd1,
        S_WAIT_MUL      = 6'd2,
        S_DO_ADD        = 6'd3,
        S_WAIT_ADD      = 6'd4,
        S_DO_DIV        = 6'd5,
        S_WAIT_DIV      = 6'd6,
        S_MUL_INV       = 6'd7,
        S_TRUNC         = 6'd8,
        S_MUL_K         = 6'd9,
        S_SUB_K         = 6'd10,
        S_EVAL_REM      = 6'd11,
        S_ADD_REM_ADJ   = 6'd12,
        S_SET_X_REDUCED = 6'd13,
        S_MUL_X2        = 6'd14,
        S_N_MUL1        = 6'd15,
        S_N_ADD1        = 6'd16,
        S_N_MUL2        = 6'd17,
        S_N_ADD2        = 6'd18,
        S_N_MUL3        = 6'd19,
        S_N_ADD3        = 6'd20,
        S_N_MUL4        = 6'd21,
        S_N_ADD4        = 6'd22,
        S_SAVE_NUM      = 6'd23,
        S_D_MUL1        = 6'd24,
        S_D_ADD1        = 6'd25,
        S_D_MUL2        = 6'd26,
        S_D_ADD2        = 6'd27,
        S_D_MUL3        = 6'd28,
        S_D_ADD3        = 6'd29,
        S_D_MUL4        = 6'd30,
        S_D_ADD4        = 6'd31,
        S_SAVE_DEN      = 6'd32,
        S_DIV_FINAL     = 6'd33,
        S_DONE          = 6'd34;

    reg [5:0] state;
    reg [5:0] return_state;

    reg [31:0] x_in_reg;
    reg [31:0] mul_result_reg;
    reg [31:0] add_result_reg;
    reg [31:0] k_float_reg;
    reg [31:0] rem1_reg;
    reg [31:0] x_reduced_reg;
    reg [31:0] x2_reg;
    reg [31:0] num_reg;
    reg [31:0] den_reg;

    reg        mul_start;
    reg [31:0] mul_a_reg;
    reg [31:0] mul_b_reg;
    wire [31:0] mul_y_wire;
    wire       mul_done_wire;

    reg        add_start;
    reg [31:0] add_a_reg;
    reg [31:0] add_b_reg;
    reg        add_op_reg;
    wire [31:0] add_y_wire;
    wire       add_done_wire;

    reg        div_start;
    reg [31:0] div_a_reg;
    reg [31:0] div_b_reg;
    wire [31:0] div_y_wire;
    wire       div_done_wire;

    wire [31:0] k_float_wire;

    fp32_mul u_mul_shared (
        .clk(clk),
        .rst_n(rst_n),
        .start(mul_start),
        .a(mul_a_reg),
        .b(mul_b_reg),
        .y(mul_y_wire),
        .done(mul_done_wire)
    );

    fp32_addsub u_add_shared (
        .clk(clk),
        .rst_n(rst_n),
        .start(add_start),
        .a(add_a_reg),
        .b(add_b_reg),
        .op(add_op_reg),
        .result(add_y_wire),
        .done(add_done_wire)
    );

    fp32_div u_div_shared (
        .clk(clk),
        .rst_n(rst_n),
        .start(div_start),
        .a(div_a_reg),
        .b(div_b_reg),
        .y(div_y_wire),
        .done(div_done_wire)
    );

    fp32_trunc u_trunc (
        .f_in(mul_result_reg),
        .f_out(k_float_wire)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            return_state <= S_IDLE;
            done <= 1'b0;
            cos_out <= 32'd0;
            mul_start <= 1'b0;
            add_start <= 1'b0;
            div_start <= 1'b0;
            x_in_reg <= 32'd0;
            mul_a_reg <= 32'd0;
            mul_b_reg <= 32'd0;
            add_a_reg <= 32'd0;
            add_b_reg <= 32'd0;
            add_op_reg <= 1'b0;
            div_a_reg <= 32'd0;
            div_b_reg <= 32'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x_in_reg <= x_in;
                        state <= S_MUL_INV;
                    end
                end

                S_DO_MUL: begin
                    mul_start <= 1'b1;
                    state <= S_WAIT_MUL;
                end
                S_WAIT_MUL: begin
                    mul_start <= 1'b0;
                    if (mul_done_wire) begin
                        mul_result_reg <= mul_y_wire;
                        state <= return_state;
                    end
                end

                S_DO_ADD: begin
                    add_start <= 1'b1;
                    state <= S_WAIT_ADD;
                end
                S_WAIT_ADD: begin
                    add_start <= 1'b0;
                    if (add_done_wire) begin
                        add_result_reg <= add_y_wire;
                        state <= return_state;
                    end
                end

                S_DO_DIV: begin
                    div_start <= 1'b1;
                    state <= S_WAIT_DIV;
                end
                S_WAIT_DIV: begin
                    div_start <= 1'b0;
                    if (div_done_wire) begin
                        cos_out <= div_y_wire;
                        state <= return_state;
                    end
                end

                S_MUL_INV: begin
                    mul_a_reg <= x_in_reg;
                    mul_b_reg <= INV_TWO_PI;
                    return_state <= S_TRUNC;
                    state <= S_DO_MUL;
                end

                S_TRUNC: begin
                    k_float_reg <= k_float_wire;
                    state <= S_MUL_K;
                end

                S_MUL_K: begin
                    mul_a_reg <= k_float_reg;
                    mul_b_reg <= TWO_PI;
                    return_state <= S_SUB_K;
                    state <= S_DO_MUL;
                end

                S_SUB_K: begin
                    add_a_reg <= x_in_reg;
                    add_b_reg <= mul_result_reg;
                    add_op_reg <= 1'b1;
                    return_state <= S_EVAL_REM;
                    state <= S_DO_ADD;
                end

                S_EVAL_REM: begin
                    rem1_reg <= add_result_reg;
                    if (add_result_reg[30:0] > PI_MAG[30:0]) begin
                        state <= S_ADD_REM_ADJ;
                    end else begin
                        x_reduced_reg <= add_result_reg;
                        state <= S_MUL_X2;
                    end
                end

                S_ADD_REM_ADJ: begin
                    add_a_reg <= rem1_reg;
                    add_b_reg <= TWO_PI;
                    add_op_reg <= (rem1_reg[31] == 1'b0) ? 1'b1 : 1'b0;
                    return_state <= S_SET_X_REDUCED;
                    state <= S_DO_ADD;
                end

                S_SET_X_REDUCED: begin
                    x_reduced_reg <= add_result_reg;
                    state <= S_MUL_X2;
                end

                S_MUL_X2: begin
                    mul_a_reg <= x_reduced_reg;
                    mul_b_reg <= x_reduced_reg;
                    return_state <= S_N_MUL1;
                    state <= S_DO_MUL;
                end

                S_N_MUL1: begin x2_reg <= mul_result_reg; mul_a_reg <= C_A; mul_b_reg <= mul_result_reg; return_state <= S_N_ADD1; state <= S_DO_MUL; end
                S_N_ADD1: begin add_a_reg <= mul_result_reg; add_b_reg <= C_B; add_op_reg <= 1'b0; return_state <= S_N_MUL2; state <= S_DO_ADD; end
                S_N_MUL2: begin mul_a_reg <= add_result_reg; mul_b_reg <= x2_reg; return_state <= S_N_ADD2; state <= S_DO_MUL; end
                S_N_ADD2: begin add_a_reg <= mul_result_reg; add_b_reg <= C_C; add_op_reg <= 1'b0; return_state <= S_N_MUL3; state <= S_DO_ADD; end
                S_N_MUL3: begin mul_a_reg <= add_result_reg; mul_b_reg <= x2_reg; return_state <= S_N_ADD3; state <= S_DO_MUL; end
                S_N_ADD3: begin add_a_reg <= mul_result_reg; add_b_reg <= C_D; add_op_reg <= 1'b0; return_state <= S_N_MUL4; state <= S_DO_ADD; end
                S_N_MUL4: begin mul_a_reg <= add_result_reg; mul_b_reg <= x2_reg; return_state <= S_N_ADD4; state <= S_DO_MUL; end
                S_N_ADD4: begin add_a_reg <= mul_result_reg; add_b_reg <= ONE_FP32; add_op_reg <= 1'b0; return_state <= S_SAVE_NUM; state <= S_DO_ADD; end
                
                S_SAVE_NUM: begin num_reg <= add_result_reg; state <= S_D_MUL1; end

                S_D_MUL1: begin mul_a_reg <= C_E; mul_b_reg <= x2_reg; return_state <= S_D_ADD1; state <= S_DO_MUL; end
                S_D_ADD1: begin add_a_reg <= mul_result_reg; add_b_reg <= C_F; add_op_reg <= 1'b0; return_state <= S_D_MUL2; state <= S_DO_ADD; end
                S_D_MUL2: begin mul_a_reg <= add_result_reg; mul_b_reg <= x2_reg; return_state <= S_D_ADD2; state <= S_DO_MUL; end
                S_D_ADD2: begin add_a_reg <= mul_result_reg; add_b_reg <= C_G; add_op_reg <= 1'b0; return_state <= S_D_MUL3; state <= S_DO_ADD; end
                S_D_MUL3: begin mul_a_reg <= add_result_reg; mul_b_reg <= x2_reg; return_state <= S_D_ADD3; state <= S_DO_MUL; end
                S_D_ADD3: begin add_a_reg <= mul_result_reg; add_b_reg <= C_H; add_op_reg <= 1'b0; return_state <= S_D_MUL4; state <= S_DO_ADD; end
                S_D_MUL4: begin mul_a_reg <= add_result_reg; mul_b_reg <= x2_reg; return_state <= S_D_ADD4; state <= S_DO_MUL; end
                S_D_ADD4: begin add_a_reg <= mul_result_reg; add_b_reg <= ONE_FP32; add_op_reg <= 1'b0; return_state <= S_SAVE_DEN; state <= S_DO_ADD; end
                
                S_SAVE_DEN: begin den_reg <= add_result_reg; state <= S_DIV_FINAL; end

                S_DIV_FINAL: begin
                    div_a_reg <= num_reg;
                    div_b_reg <= den_reg;
                    return_state <= S_DONE;
                    state <= S_DO_DIV;
                end

                S_DONE: begin
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
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