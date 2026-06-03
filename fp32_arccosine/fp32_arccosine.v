module fp32_arccosine (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] x_in,
    output reg  [31:0] acos_out,
    output reg         done
);

    localparam [31:0] ONE_FP32     = 32'h3F800000; 
    localparam [31:0] NEG_ONE_FP32 = 32'hBF800000; 
    localparam [31:0] ZERO_FP32    = 32'h00000000; 
    localparam [31:0] PI_FP32      = 32'h40490FDB; 

    localparam [31:0] C_A8 = 32'h3B65DAB1;
    localparam [31:0] C_A7 = 32'h3D8A097F;
    localparam [31:0] C_A6 = 32'hBE4D5315;
    localparam [31:0] C_A5 = 32'hBF2571A4;
    localparam [31:0] C_A4 = 32'h3FAB597C;
    localparam [31:0] C_A3 = 32'h3FC27125;
    localparam [31:0] C_A2 = 32'hC0297833;
    localparam [31:0] C_P  = 32'h3FC90FDB; 

    localparam [31:0] C_B  = 32'h3B12546C;
    localparam [31:0] C_C  = 32'hBE02B6B2;
    localparam [31:0] C_D  = 32'h3F5A2B45;
    localparam [31:0] C_E  = 32'hBFD7C67A;

    localparam [5:0]
        S_IDLE       = 6'd0,
        S_DO_MUL     = 6'd1,
        S_WAIT_MUL   = 6'd2,
        S_DO_ADD     = 6'd3,
        S_WAIT_ADD   = 6'd4,
        S_DO_DIV     = 6'd5,
        S_WAIT_DIV   = 6'd6,
        S_CHECK_EDGE = 6'd7,
        S_MUL_X2     = 6'd8,
        S_N_MUL1     = 6'd9,
        S_N_ADD1     = 6'd10,
        S_N_MUL2     = 6'd11,
        S_N_ADD2     = 6'd12,
        S_N_MUL3     = 6'd13,
        S_N_ADD3     = 6'd14,
        S_N_MUL4     = 6'd15,
        S_N_ADD4     = 6'd16,
        S_N_MUL5     = 6'd17,
        S_N_ADD5     = 6'd18,
        S_N_MUL6     = 6'd19,
        S_N_ADD6     = 6'd20,
        S_N_MUL7     = 6'd21,
        S_N_SUB7     = 6'd22,
        S_N_MUL8     = 6'd23,
        S_N_ADD8     = 6'd24,
        S_SAVE_NUM   = 6'd25,
        S_D_MUL1     = 6'd26,
        S_D_ADD1     = 6'd27,
        S_D_MUL2     = 6'd28,
        S_D_ADD2     = 6'd29,
        S_D_MUL3     = 6'd30,
        S_D_ADD3     = 6'd31,
        S_D_MUL4     = 6'd32,
        S_D_ADD4     = 6'd33,
        S_SAVE_DEN   = 6'd34,
        S_DIV_FINAL  = 6'd35,
        S_DONE       = 6'd36;

    reg [5:0] state;
    reg [5:0] return_state;

    reg [31:0] x_in_reg;
    reg [31:0] x2_reg;
    reg [31:0] num_reg;
    reg [31:0] den_reg;

    reg [31:0] mul_result_reg;
    reg [31:0] add_result_reg;

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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            return_state <= S_IDLE;
            done <= 1'b0;
            acos_out <= 32'd0;
            
            mul_start <= 1'b0;
            add_start <= 1'b0;
            div_start <= 1'b0;
            
            x_in_reg <= 32'd0;
            x2_reg <= 32'd0;
            num_reg <= 32'd0;
            den_reg <= 32'd0;
            
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
                        state <= S_CHECK_EDGE;
                    end
                end

                S_CHECK_EDGE: begin
                    if (x_in_reg == NEG_ONE_FP32) begin
                        acos_out <= PI_FP32;
                        state <= S_DONE;
                    end else if (x_in_reg == ONE_FP32) begin
                        acos_out <= ZERO_FP32;
                        state <= S_DONE;
                    end else begin
                        state <= S_MUL_X2;
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
                        acos_out <= div_y_wire;
                        state <= return_state;
                    end
                end

                S_MUL_X2: begin
                    mul_a_reg <= x_in_reg;
                    mul_b_reg <= x_in_reg;
                    return_state <= S_N_MUL1;
                    state <= S_DO_MUL;
                end

                S_N_MUL1: begin x2_reg <= mul_result_reg; mul_a_reg <= C_A8; mul_b_reg <= x_in_reg; return_state <= S_N_ADD1; state <= S_DO_MUL; end
                S_N_ADD1: begin add_a_reg <= mul_result_reg; add_b_reg <= C_A7; add_op_reg <= 1'b0; return_state <= S_N_MUL2; state <= S_DO_ADD; end
                
                S_N_MUL2: begin mul_a_reg <= add_result_reg; mul_b_reg <= x_in_reg; return_state <= S_N_ADD2; state <= S_DO_MUL; end
                S_N_ADD2: begin add_a_reg <= mul_result_reg; add_b_reg <= C_A6; add_op_reg <= 1'b0; return_state <= S_N_MUL3; state <= S_DO_ADD; end
                
                S_N_MUL3: begin mul_a_reg <= add_result_reg; mul_b_reg <= x_in_reg; return_state <= S_N_ADD3; state <= S_DO_MUL; end
                S_N_ADD3: begin add_a_reg <= mul_result_reg; add_b_reg <= C_A5; add_op_reg <= 1'b0; return_state <= S_N_MUL4; state <= S_DO_ADD; end
                
                S_N_MUL4: begin mul_a_reg <= add_result_reg; mul_b_reg <= x_in_reg; return_state <= S_N_ADD4; state <= S_DO_MUL; end
                S_N_ADD4: begin add_a_reg <= mul_result_reg; add_b_reg <= C_A4; add_op_reg <= 1'b0; return_state <= S_N_MUL5; state <= S_DO_ADD; end
                
                S_N_MUL5: begin mul_a_reg <= add_result_reg; mul_b_reg <= x_in_reg; return_state <= S_N_ADD5; state <= S_DO_MUL; end
                S_N_ADD5: begin add_a_reg <= mul_result_reg; add_b_reg <= C_A3; add_op_reg <= 1'b0; return_state <= S_N_MUL6; state <= S_DO_ADD; end
                
                S_N_MUL6: begin mul_a_reg <= add_result_reg; mul_b_reg <= x_in_reg; return_state <= S_N_ADD6; state <= S_DO_MUL; end
                S_N_ADD6: begin add_a_reg <= mul_result_reg; add_b_reg <= C_A2; add_op_reg <= 1'b0; return_state <= S_N_MUL7; state <= S_DO_ADD; end
                
                S_N_MUL7: begin mul_a_reg <= add_result_reg; mul_b_reg <= x_in_reg; return_state <= S_N_SUB7; state <= S_DO_MUL; end
                S_N_SUB7: begin add_a_reg <= mul_result_reg; add_b_reg <= ONE_FP32; add_op_reg <= 1'b1; return_state <= S_N_MUL8; state <= S_DO_ADD; end
                
                S_N_MUL8: begin mul_a_reg <= add_result_reg; mul_b_reg <= x_in_reg; return_state <= S_N_ADD8; state <= S_DO_MUL; end
                S_N_ADD8: begin add_a_reg <= mul_result_reg; add_b_reg <= C_P; add_op_reg <= 1'b0; return_state <= S_SAVE_NUM; state <= S_DO_ADD; end

                S_SAVE_NUM: begin
                    num_reg <= add_result_reg;
                    state <= S_D_MUL1;
                end

                S_D_MUL1: begin mul_a_reg <= C_B; mul_b_reg <= x2_reg; return_state <= S_D_ADD1; state <= S_DO_MUL; end
                S_D_ADD1: begin add_a_reg <= mul_result_reg; add_b_reg <= C_C; add_op_reg <= 1'b0; return_state <= S_D_MUL2; state <= S_DO_ADD; end
                
                S_D_MUL2: begin mul_a_reg <= add_result_reg; mul_b_reg <= x2_reg; return_state <= S_D_ADD2; state <= S_DO_MUL; end
                S_D_ADD2: begin add_a_reg <= mul_result_reg; add_b_reg <= C_D; add_op_reg <= 1'b0; return_state <= S_D_MUL3; state <= S_DO_ADD; end
                
                S_D_MUL3: begin mul_a_reg <= add_result_reg; mul_b_reg <= x2_reg; return_state <= S_D_ADD3; state <= S_DO_MUL; end
                S_D_ADD3: begin add_a_reg <= mul_result_reg; add_b_reg <= C_E; add_op_reg <= 1'b0; return_state <= S_D_MUL4; state <= S_DO_ADD; end
                
                S_D_MUL4: begin mul_a_reg <= add_result_reg; mul_b_reg <= x2_reg; return_state <= S_D_ADD4; state <= S_DO_MUL; end
                S_D_ADD4: begin add_a_reg <= mul_result_reg; add_b_reg <= ONE_FP32; add_op_reg <= 1'b0; return_state <= S_SAVE_DEN; state <= S_DO_ADD; end

                S_SAVE_DEN: begin
                    den_reg <= add_result_reg;
                    state <= S_DIV_FINAL;
                end

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