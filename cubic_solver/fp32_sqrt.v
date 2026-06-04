module fp32_sqrt (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] x_in,
    output reg  [31:0] sqrt_out,
    output reg         done
);

    localparam [31:0] HALF  = 32'h3F000000;
    localparam [31:0] MAGIC = 32'h1FBD1DF5;

    localparam [3:0]
        S_IDLE       = 4'd0,
        S_CHECK_EDGE = 4'd1,
        S_DO_DIV     = 4'd2,
        S_WAIT_DIV   = 4'd3,
        S_DO_ADD     = 4'd4,
        S_WAIT_ADD   = 4'd5,
        S_DO_MUL     = 4'd6,
        S_WAIT_MUL   = 4'd7,
        S_LOOP_CHECK = 4'd8,
        S_DONE       = 4'd9;

    reg [3:0] state;
    reg [1:0] iter;

    reg [31:0] x_in_reg;
    reg [31:0] y_reg;
    reg [31:0] div_res_reg;
    reg [31:0] add_res_reg;

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

    reg        mul_start;
    reg [31:0] mul_a;
    reg [31:0] mul_b;
    wire [31:0] mul_y;
    wire       mul_done;

    wire [31:0] y0_sum;

    adder #(
        .WIDTH(32)
    ) u_adder_y0 (
        .a({1'b0, x_in_reg[31:1]}),
        .b(MAGIC),
        .cin(1'b0),
        .sum(y0_sum),
        .cout()
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

    fp32_mul u_mul_shared (
        .clk(clk),
        .rst_n(rst_n),
        .start(mul_start),
        .a(mul_a),
        .b(mul_b),
        .y(mul_y),
        .done(mul_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            iter <= 2'd0;
            done <= 1'b0;
            sqrt_out <= 32'd0;
            x_in_reg <= 32'd0;
            y_reg <= 32'd0;
            div_res_reg <= 32'd0;
            add_res_reg <= 32'd0;
            div_start <= 1'b0;
            div_a <= 32'd0;
            div_b <= 32'd0;
            add_start <= 1'b0;
            add_a <= 32'd0;
            add_b <= 32'd0;
            add_op <= 1'b0;
            mul_start <= 1'b0;
            mul_a <= 32'd0;
            mul_b <= 32'd0;
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
                    if (x_in_reg == 32'h00000000) begin
                        sqrt_out <= 32'h00000000;
                        state <= S_DONE;
                    end else begin
                        y_reg <= y0_sum;
                        iter <= 2'd0;
                        state <= S_DO_DIV;
                    end
                end

                S_DO_DIV: begin
                    div_a <= x_in_reg;
                    div_b <= y_reg;
                    div_start <= 1'b1;
                    state <= S_WAIT_DIV;
                end

                S_WAIT_DIV: begin
                    div_start <= 1'b0;
                    if (div_done) begin
                        div_res_reg <= div_y;
                        state <= S_DO_ADD;
                    end
                end

                S_DO_ADD: begin
                    add_a <= y_reg;
                    add_b <= div_res_reg;
                    add_op <= 1'b0;
                    add_start <= 1'b1;
                    state <= S_WAIT_ADD;
                end

                S_WAIT_ADD: begin
                    add_start <= 1'b0;
                    if (add_done) begin
                        add_res_reg <= add_y;
                        state <= S_DO_MUL;
                    end
                end

                S_DO_MUL: begin
                    mul_a <= add_res_reg;
                    mul_b <= HALF;
                    mul_start <= 1'b1;
                    state <= S_WAIT_MUL;
                end

                S_WAIT_MUL: begin
                    mul_start <= 1'b0;
                    if (mul_done) begin
                        y_reg <= mul_y;
                        state <= S_LOOP_CHECK;
                    end
                end

                S_LOOP_CHECK: begin
                    if (iter == 2'd2) begin
                        sqrt_out <= y_reg;
                        state <= S_DONE;
                    end else begin
                        iter <= iter + 1'b1;
                        state <= S_DO_DIV;
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