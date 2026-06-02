module gp1(
  input  wire a,
  input  wire b,
  output wire g,
  output wire p
);
  assign g = a & b;
  assign p = a | b;
endmodule

module gp4(
  input  wire [3:0] g,
  input  wire [3:0] p,
  input  wire       c0,
  output wire [2:0] c,
  output wire       G,
  output wire       P
);
  assign P = &p;

  wire c1 = g[0] | (p[0] & c0);
  wire c2 = g[1] | (p[1] & c1);
  wire c3 = g[2] | (p[2] & c2);
  assign c = {c3, c2, c1};

  assign G = g[3]
           | (p[3] & g[2])
           | (p[3] & p[2] & g[1])
           | (p[3] & p[2] & p[1] & g[0]);
endmodule

module adder #(
  parameter WIDTH = 32
)(
  input  wire [WIDTH-1:0] a,
  input  wire [WIDTH-1:0] b,
  input  wire             cin,
  output wire [WIDTH-1:0] sum,
  output wire             cout
);

  generate
    if (WIDTH <= 16) begin : GEN_RCA
      wire [WIDTH:0] carry;
      assign carry[0] = cin;

      genvar i;
      for (i = 0; i < WIDTH; i = i + 1) begin : RCA_BITS
        wire p_sum = a[i] ^ b[i];
        wire g_val = a[i] & b[i];
        
        assign sum[i]   = p_sum ^ carry[i];
        assign carry[i+1] = g_val | (p_sum & carry[i]);
      end
      assign cout = carry[WIDTH];

    end else if (WIDTH <= 48) begin : GEN_CLA
      
      localparam PAD_WIDTH = ((WIDTH + 3) / 4) * 4;
      localparam NUM_BLOCKS = PAD_WIDTH / 4;

      wire [PAD_WIDTH-1:0] a_pad = {{PAD_WIDTH - WIDTH{1'b0}}, a};
      wire [PAD_WIDTH-1:0] b_pad = {{PAD_WIDTH - WIDTH{1'b0}}, b};

      wire [PAD_WIDTH-1:0] g_vec, p_vec;

      genvar i;
      for (i = 0; i < PAD_WIDTH; i = i + 1) begin : GP1_STAGE
        gp1 u_gp1 (.a(a_pad[i]), .b(b_pad[i]), .g(g_vec[i]), .p(p_vec[i]));
      end

      wire [NUM_BLOCKS-1:0] G4, P4;
      wire [2:0] c_internal [NUM_BLOCKS-1:0];
      wire [NUM_BLOCKS:0] c_blocks;
      assign c_blocks[0] = cin;

      genvar x;
      for (x = 0; x < NUM_BLOCKS; x = x + 1) begin : GP4_STAGE
        gp4 u_gp4 (
          .g  (g_vec[4*x+3 : 4*x]),
          .p  (p_vec[4*x+3 : 4*x]),
          .c0 (c_blocks[x]),
          .c  (c_internal[x]),
          .G  (G4[x]),
          .P  (P4[x])
        );
      end

      genvar b_idx;
      for (b_idx = 0; b_idx < NUM_BLOCKS; b_idx = b_idx + 1) begin : BLOCK_CARRY
        assign c_blocks[b_idx+1] = G4[b_idx] | (P4[b_idx] & c_blocks[b_idx]);
      end

      wire [PAD_WIDTH:0] c_vector; 
      genvar z;
      for (z = 0; z < NUM_BLOCKS; z = z + 1) begin : CIN_BITS
        assign c_vector[4*z+0] = c_blocks[z];
        assign c_vector[4*z+1] = c_internal[z][0];
        assign c_vector[4*z+2] = c_internal[z][1];
        assign c_vector[4*z+3] = c_internal[z][2];
      end

      assign c_vector[PAD_WIDTH] = c_blocks[NUM_BLOCKS];

      wire [PAD_WIDTH-1:0] sum_pad;
      assign sum_pad = (a_pad ^ b_pad) ^ c_vector[PAD_WIDTH-1:0];

      assign sum  = sum_pad[WIDTH-1:0];
      assign cout = c_vector[WIDTH];

    end
  endgenerate

endmodule