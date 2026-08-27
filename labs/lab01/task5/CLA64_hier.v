module cla64_hier(
  input  [63:0] a,
  input  [63:0] b,
  input         cin,
  output [63:0] sum,
  output        cout
);

  // ------------------------------------------------------------
  // 16 four-bit CLA blocks
  // ------------------------------------------------------------

  wire [15:0] Pblk;
  wire [15:0] Gblk;
  wire [15:0] cblk;

  // Individual bit P/G signals for each 4-bit block
  wire [15:0] p0, p1, p2, p3;
  wire [15:0] g0, g1, g2, g3;

  // Internal carries inside each 4-bit block
  wire [15:0] c1, c2, c3;

  // ------------------------------------------------------------
  // Generate P/G for all 64 bits
  // ------------------------------------------------------------

  genvar k;

  generate
    for (k = 0; k < 16; k = k + 1) begin : GEN_BITS

      xor #(2) (p0[k], a[4*k],   b[4*k]);
      xor #(2) (p1[k], a[4*k+1], b[4*k+1]);
      xor #(2) (p2[k], a[4*k+2], b[4*k+2]);
      xor #(2) (p3[k], a[4*k+3], b[4*k+3]);

      and #(2) (g0[k], a[4*k],   b[4*k]);
      and #(2) (g1[k], a[4*k+1], b[4*k+1]);
      and #(2) (g2[k], a[4*k+2], b[4*k+2]);
      and #(2) (g3[k], a[4*k+3], b[4*k+3]);

    end
  endgenerate

  // ------------------------------------------------------------
  // Block propagate
  // Pblk = p3 p2 p1 p0
  // ------------------------------------------------------------

  generate
    for (k = 0; k < 16; k = k + 1) begin : GEN_PBLK

      and #(2) (
        Pblk[k],
        p3[k],
        p2[k],
        p1[k],
        p0[k]
      );

    end
  endgenerate

  // ------------------------------------------------------------
  // Block generate
  //
  // Gblk = g3
  //      + p3.g2
  //      + p3.p2.g1
  //      + p3.p2.p1.g0
  // ------------------------------------------------------------

  wire [15:0] bg2;
  wire [15:0] bg1;
  wire [15:0] bg0;

  generate
    for (k = 0; k < 16; k = k + 1) begin : GEN_GBLK

      and #(2) (bg2[k], p3[k], g2[k]);
      and #(2) (bg1[k], p3[k], p2[k], g1[k]);
      and #(2) (bg0[k], p3[k], p2[k], p1[k], g0[k]);

      or #(2) (
        Gblk[k],
        g3[k],
        bg2[k],
        bg1[k],
        bg0[k]
      );

    end
  endgenerate

  // ------------------------------------------------------------
  // Block-level carry lookahead
  // ------------------------------------------------------------

  assign #(2) cblk[0] = cin;

  // C1
  wire c1_t0;

  and #(2) (c1_t0, Pblk[0], cin);
  or #(2) (cblk[1], Gblk[0], c1_t0);

  // C2
  wire c2_t0, c2_t1;

  and #(2) (c2_t0, Pblk[1], Gblk[0]);
  and #(2) (c2_t1, Pblk[1], Pblk[0], cin);

  or #(2) (cblk[2], Gblk[1], c2_t0, c2_t1);

  // C3
  wire c3_t0, c3_t1, c3_t2;

  and #(2) (c3_t0, Pblk[2], Gblk[1]);
  and #(2) (c3_t1, Pblk[2], Pblk[1], Gblk[0]);
  and #(2) (c3_t2, Pblk[2], Pblk[1], Pblk[0], cin);

  or #(2) (cblk[3], Gblk[2], c3_t0, c3_t1, c3_t2);

  // C4
  wire c4_t0, c4_t1, c4_t2, c4_t3;

  and #(2) (c4_t0, Pblk[3], Gblk[2]);
  and #(2) (c4_t1, Pblk[3], Pblk[2], Gblk[1]);
  and #(2) (c4_t2, Pblk[3], Pblk[2], Pblk[1], Gblk[0]);
  and #(2) (c4_t3, Pblk[3], Pblk[2], Pblk[1], Pblk[0], cin);

  or #(2) (
    cblk[4],
    Gblk[3],
    c4_t0,
    c4_t1,
    c4_t2,
    c4_t3
  );

  // ------------------------------------------------------------
  // Remaining block carries
  // ------------------------------------------------------------

  wire [15:5] carry_term;

  generate
    for (k = 5; k < 16; k = k + 1) begin : GEN_REMAINING_CARRIES

      and #(2) (
        carry_term[k],
        Pblk[k-1],
        cblk[k-1]
      );

      or #(2) (
        cblk[k],
        Gblk[k-1],
        carry_term[k]
      );

    end
  endgenerate

  // ------------------------------------------------------------
  // Internal CLA logic for each 4-bit block
  // ------------------------------------------------------------

  wire [15:0] t10;
  wire [15:0] t20, t21;
  wire [15:0] t30, t31, t32;
  wire [15:0] t40, t41, t42, t43;

  generate
    for (k = 0; k < 16; k = k + 1) begin : GEN_SUM

      // c1
      and #(2) (t10[k], p0[k], cblk[k]);
      or #(2) (c1[k], g0[k], t10[k]);

      // c2
      and #(2) (t20[k], p1[k], g0[k]);
      and #(2) (t21[k], p1[k], p0[k], cblk[k]);
      or #(2) (c2[k], g1[k], t20[k], t21[k]);

      // c3
      and #(2) (t30[k], p2[k], g1[k]);
      and #(2) (t31[k], p2[k], p1[k], g0[k]);
      and #(2) (t32[k], p2[k], p1[k], p0[k], cblk[k]);
      or #(2) (c3[k], g2[k], t30[k], t31[k], t32[k]);

      // Sum bits
      xor #(2) (sum[4*k],   p0[k], cblk[k]);
      xor #(2) (sum[4*k+1], p1[k], c1[k]);
      xor #(2) (sum[4*k+2], p2[k], c2[k]);
      xor #(2) (sum[4*k+3], p3[k], c3[k]);

    end
  endgenerate

  // ------------------------------------------------------------
  // Final carry out
  // ------------------------------------------------------------

  wire cout_term;

  and #(2) (cout_term, Pblk[15], cblk[15]);
  or #(2) (cout, Gblk[15], cout_term);

endmodule