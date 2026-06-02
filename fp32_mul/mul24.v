module mul24 (
  input  wire [23:0] a,
  input  wire [23:0] b,
  output wire [47:0] p
);

  wire [47:0] accum [0:23];
  genvar i;

  generate
    assign accum[0] = b[0] ? {24'd0, a} : 48'd0;

    for (i = 1; i < 24; i = i + 1) begin : adder_stage
      
      wire [47:0] partial_product = b[i] ? ({24'd0, a} << i) : 48'd0;

      adder #(
        .WIDTH(48)
      ) u_adder (
        .a    (accum[i-1]),
        .b    (partial_product),
        .cin  (1'b0),
        .sum  (accum[i]),
        .cout ()
      );

    end
  endgenerate

  assign p = accum[23];

endmodule