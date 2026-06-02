module fp32_cbrt (
    input  wire [31:0] x_in,
    output wire [31:0] cbrt_out
);
    wire [31:0] ONE_THIRD = 32'h3EAAAAAB;
    wire [31:0] TWO       = 32'h40000000;

    wire [31:0] y [0:3];
    wire [30:0] x_mag     = x_in[30:0];
    
    wire [30:0] x_div3;
    
    div_by_3 u_div3 (
        .dividend(x_mag),
        .quotient(x_div3)
    );

    wire [30:0] y0_sum;
    adder #(
        .WIDTH(31)
    ) u_adder_y0 (
        .a(x_div3),
        .b(31'h2A5119F9),
        .cin(1'b0),
        .sum(y0_sum),
        .cout()
    );
    
    assign y[0] = {x_in[31], y0_sum};

    genvar i;
    generate
        for (i = 0; i < 3; i = i + 1) begin : gen_cbrt
            wire [31:0] y2;
            wire [31:0] div_res;
            wire [31:0] two_y;
            wire [31:0] add_res;

            fp32_mul u_mul_y2 (
                .a(y[i]),
                .b(y[i]),
                .y(y2)
            );

            fp32_div u_div (
                .a(x_in),
                .b(y2),
                .y(div_res)
            );

            fp32_mul u_mul_2y (
                .a(y[i]),
                .b(TWO),
                .y(two_y)
            );

            fp32_addsub u_add (
                .a(two_y),
                .b(div_res),
                .op(1'b0),
                .result(add_res)
            );

            fp32_mul u_mul_third (
                .a(add_res),
                .b(ONE_THIRD),
                .y(y[i+1])
            );
        end
    endgenerate

    assign cbrt_out = (x_mag == 31'h00000000) ? x_in : y[3];

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