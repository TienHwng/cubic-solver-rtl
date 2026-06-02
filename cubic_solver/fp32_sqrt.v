module fp32_sqrt (
    input  wire [31:0] x_in,
    output wire [31:0] sqrt_out
);

    wire [31:0] HALF = 32'h3F000000;
    wire [31:0] y [0:3];
    
    wire [31:0] y0_sum;
    adder #(
        .WIDTH(32)
    ) u_adder_y0 (
        .a({1'b0, x_in[31:1]}),
        .b(32'h1FBD1DF5),
        .cin(1'b0),
        .sum(y0_sum),
        .cout()
    );
    
    assign y[0] = y0_sum;

    genvar i;
    generate
        for (i = 0; i < 3; i = i + 1) begin : gen_sqrt
            wire [31:0] div_res;
            wire [31:0] add_res;

            fp32_div u_div (
                .a(x_in),
                .b(y[i]),
                .y(div_res)
            );

            fp32_addsub u_add (
                .a(y[i]),
                .b(div_res),
                .op(1'b0),
                .result(add_res)
            );

            fp32_mul u_mul (
                .a(add_res),
                .b(HALF),
                .y(y[i+1])
            );
        end
    endgenerate

    assign sqrt_out = (x_in == 32'h00000000) ? 32'h00000000 : y[3];

endmodule