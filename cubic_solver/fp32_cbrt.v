module fp32_cbrt (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] x_in,
    output reg  [31:0] cbrt_out,
    output reg         done
);

    localparam [31:0] ONE_THIRD = 32'h3EAAAAAB;
    localparam [31:0] TWO       = 32'h40000000;
    localparam [30:0] MAGIC     = 31'h2A5119F9;

    localparam [4:0]
        S_IDLE            = 5'd0,
        S_CHECK_EDGE      = 5'd1,
        S_DO_MUL          = 5'd2,
        S_WAIT_MUL        = 5'd3,
        S_DO_DIV          = 5'd4,
        S_WAIT_DIV        = 5'd5,
        S_DO_ADD          = 5'd6,
        S_WAIT_ADD        = 5'd7,
        S_LOOP_START      = 5'd8,
        S_DIV_SETUP       = 5'd9,
        S_MUL_2Y_SETUP    = 5'd10,
        S_ADD_SETUP       = 5'd11,
        S_MUL_THIRD_SETUP = 5'd12,
        S_LOOP_CHECK      = 5'd13,
        S_DONE            = 5'd14;

    reg [4:0] state;
    reg [4:0] return_state;
    reg [1:0] iter;

    reg [31:0] x_in_reg;
    reg [31:0] y_reg;
    reg [31:0] div_res_reg;

    reg [31:0] mul_result_reg;
    reg [31:0] div_result_reg;
    reg [31:0] add_result_reg;

    reg        mul_start;
    reg [31:0] mul_a;
    reg [31:0] mul_b;
    wire [31:0] mul_y;
    wire       mul_done;

    reg        div_start;
    reg [31:0] div_a;
    reg [31:0] div_b;
    wire [31:0] div_y;
    wire       div_done;

    reg        add_start;
    reg [31:0] add_a;
    reg [31:0] add_b;
    reg        add_op;
    wire [31:0] add_y;
    wire       add_done;

    wire [30:0] x_div3;
    wire [30:0] y0_sum;

    div_by_3 u_div3 (
        .dividend(x_in_reg[30:0]),
        .quotient(x_div3)
    );

    adder #(
        .WIDTH(31)
    ) u_adder_y0 (
        .a(x_div3),
        .b(MAGIC),
        .cin(1'b0),
        .sum(y0_sum),
        .cout()
    );

    fp32_mul u_mul_shared (
        .clk(clk),
        .rst_n(rst_n),
        .start(mul_start),
        .a(mul_a),
        .b(mul_b),
        .y(mul_y),
        .done(mul_done)
    );

    fp32_div u_div_shared (
        .clk(clk),
        .rst_n(rst_n),
        .start(div_start),
        .a(div_a),
        .b(div_b),
        .y(div_y),
        .done(div_done)
    );

    fp32_addsub u_add_shared (
        .clk(clk),
        .rst_n(rst_n),
        .start(add_start),
        .a(add_a),
        .b(add_b),
        .op(add_op),
        .result(add_y),
        .done(add_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            return_state <= S_IDLE;
            iter <= 2'd0;
            done <= 1'b0;
            cbrt_out <= 32'd0;
            x_in_reg <= 32'd0;
            y_reg <= 32'd0;
            div_res_reg <= 32'd0;
            mul_result_reg <= 32'd0;
            div_result_reg <= 32'd0;
            add_result_reg <= 32'd0;
            mul_start <= 1'b0;
            mul_a <= 32'd0;
            mul_b <= 32'd0;
            div_start <= 1'b0;
            div_a <= 32'd0;
            div_b <= 32'd0;
            add_start <= 1'b0;
            add_a <= 32'd0;
            add_b <= 32'd0;
            add_op <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x_in_reg <= x_in;
                        state <= S_CHECK_EDGE;
                    end
                end

                S_CHECK_EDGE: begin
                    if (x_in_reg[30:0] == 31'h00000000) begin
                        cbrt_out <= x_in_reg;
                        state <= S_DONE;
                    end else begin
                        y_reg <= {x_in_reg[31], y0_sum};
                        iter <= 2'd0;
                        state <= S_LOOP_START;
                    end
                end

                S_DO_MUL: begin
                    mul_start <= 1'b1;
                    state <= S_WAIT_MUL;
                end
                S_WAIT_MUL: begin
                    mul_start <= 1'b0;
                    if (mul_done) begin
                        mul_result_reg <= mul_y;
                        state <= return_state;
                    end
                end

                S_DO_DIV: begin
                    div_start <= 1'b1;
                    state <= S_WAIT_DIV;
                end
                S_WAIT_DIV: begin
                    div_start <= 1'b0;
                    if (div_done) begin
                        div_result_reg <= div_y;
                        state <= return_state;
                    end
                end

                S_DO_ADD: begin
                    add_start <= 1'b1;
                    state <= S_WAIT_ADD;
                end
                S_WAIT_ADD: begin
                    add_start <= 1'b0;
                    if (add_done) begin
                        add_result_reg <= add_y;
                        state <= return_state;
                    end
                end

                S_LOOP_START: begin
                    mul_a <= y_reg;
                    mul_b <= y_reg;
                    return_state <= S_DIV_SETUP;
                    state <= S_DO_MUL;
                end

                S_DIV_SETUP: begin
                    div_a <= x_in_reg;
                    div_b <= mul_result_reg;
                    return_state <= S_MUL_2Y_SETUP;
                    state <= S_DO_DIV;
                end

                S_MUL_2Y_SETUP: begin
                    div_res_reg <= div_result_reg;
                    mul_a <= y_reg;
                    mul_b <= TWO;
                    return_state <= S_ADD_SETUP;
                    state <= S_DO_MUL;
                end

                S_ADD_SETUP: begin
                    add_a <= mul_result_reg;
                    add_b <= div_res_reg;
                    add_op <= 1'b0;
                    return_state <= S_MUL_THIRD_SETUP;
                    state <= S_DO_ADD;
                end

                S_MUL_THIRD_SETUP: begin
                    mul_a <= add_result_reg;
                    mul_b <= ONE_THIRD;
                    return_state <= S_LOOP_CHECK;
                    state <= S_DO_MUL;
                end

                S_LOOP_CHECK: begin
                    y_reg <= mul_result_reg;
                    if (iter == 2'd2) begin
                        cbrt_out <= mul_result_reg;
                        state <= S_DONE;
                    end else begin
                        iter <= iter + 1'b1;
                        state <= S_LOOP_START;
                    end
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

module div_by_3 (
    input  wire [30:0] dividend,
    output wire [30:0] quotient
);
    wire [1:0] rem [0:31];
    assign rem[0] = 2'b00;

    genvar i;
    generate
        for (i = 0; i < 31; i = i + 1) begin : gen_div
            div3_cell u_cell (
                .rem_in(rem[i]),
                .bit_in(dividend[30-i]),
                .rem_out(rem[i+1]),
                .q_out(quotient[30-i])
            );
        end
    endgenerate
endmodule

module div3_cell (
    input  wire [1:0] rem_in,
    input  wire       bit_in,
    output wire [1:0] rem_out,
    output wire       q_out
);
    wire [2:0] a;
    assign a = {rem_in, bit_in};
    assign q_out = a[2] | (a[1] & a[0]);
    assign rem_out[1] = (~a[2] & a[1] & ~a[0]) | (a[2] & ~a[1] & a[0]);
    assign rem_out[0] = (~a[2] & ~a[1] & a[0]) | (a[2] & ~a[1] & ~a[0]);
endmodule