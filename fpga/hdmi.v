/*
 * Copyright (c) 2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 *
 * 640x480@60Hz DVI/HDMI output. Accepts r/g/b pixel data from external source.
 *
 * Clock plan (input 27 MHz):
 *   rPLL  : 27 * 14 / 3 = 126 MHz  (5x pixel clock, clk_5x)
 *             IDIV_SEL=2, FBDIV_SEL=13, ODIV_SEL=4
 *             VCO = 27 * (13+1) * 4 / (2+1) = 504 MHz (in 400-1200 MHz range)
 *             CLKOUT = VCO / ODIV_SEL = 504 / 4 = 126 MHz
 *   CLKDIV: 126 / 5 = 25.2 MHz          (pixel clock, clk_px)
 *
 * 640x480@60Hz timing (pixel clock 25.175 MHz, 25.2 MHz close enough):
 *   H: 640 active + 16 fp + 96 sync + 48 bp = 800 total  (hsync active low)
 *   V: 480 active + 10 fp +  2 sync + 33 bp = 525 total  (vsync active low)
 */

module hdmi(
    input  wire       clk,
    input  wire [7:0] r,
    input  wire [7:0] g,
    input  wire [7:0] b,
    output wire       clk_px,
    output wire [9:0] hcnt,
    output wire [9:0] vcnt,
    output wire       de,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n
);

// === PLL: 27 MHz -> 126 MHz (5x pixel clock), VCO=504 MHz ===
wire clk_5x, pll_lock;

rPLL #(
    .FCLKIN("27"),
    .IDIV_SEL(2),
    .FBDIV_SEL(13),
    .ODIV_SEL(4),
    .DYN_IDIV_SEL("false"),
    .DYN_FBDIV_SEL("false"),
    .DYN_ODIV_SEL("false"),
    .CLKFB_SEL("internal"),
    .CLKOUT_BYPASS("false"),
    .CLKOUTP_BYPASS("false"),
    .CLKOUTD_BYPASS("false"),
    .DEVICE("GW1NR-9C")
) pll_inst (
    .CLKIN(clk),
    .CLKOUT(clk_5x),
    .LOCK(pll_lock),
    .CLKOUTP(),
    .CLKOUTD(),
    .CLKOUTD3(),
    .RESET(1'b0),
    .RESET_P(1'b0),
    .CLKFB(1'b0),
    .FBDSEL(6'b0),
    .IDSEL(6'b0),
    .ODSEL(6'b0),
    .PSDA(4'b0),
    .DUTYDA(4'b0),
    .FDLY(4'b0)
);

// === CLKDIV: 126 MHz / 5 = 25.2 MHz (pixel clock) ===

CLKDIV #(
    .DIV_MODE("5"),
    .GSREN("false")
) clkdiv_inst (
    .CLKOUT(clk_px),
    .HCLKIN(clk_5x),
    .RESETN(pll_lock),
    .CALIB(1'b0)
);

// === VGA timing counters ===
localparam H_ACTIVE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48;
localparam V_ACTIVE = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33;
localparam H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP;  // 800
localparam V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;  // 525

reg [9:0] hcnt_r = 0;
reg [9:0] vcnt_r = 0;
assign hcnt = hcnt_r;
assign vcnt = vcnt_r;

always @(posedge clk_px) begin
    if (hcnt_r == H_TOTAL - 1) begin
        hcnt_r <= 0;
        if (vcnt_r == V_TOTAL - 1)
            vcnt_r <= 0;
        else
            vcnt_r <= vcnt_r + 1;
    end else begin
        hcnt_r <= hcnt_r + 1;
    end
end

wire hsync = ~(hcnt_r >= H_ACTIVE + H_FP && hcnt_r < H_ACTIVE + H_FP + H_SYNC);
wire vsync = ~(vcnt_r >= V_ACTIVE + V_FP && vcnt_r < V_ACTIVE + V_FP + V_SYNC);
assign de  = (hcnt_r < H_ACTIVE) && (vcnt_r < V_ACTIVE);

// Delay de/hsync/vsync by 3 cycles to match taro render pipeline latency
reg [2:0] de_d;
reg [2:0] hsync_d;
reg [2:0] vsync_d;
always @(posedge clk_px) begin
    de_d    <= {de_d[1:0], de};
    hsync_d <= {hsync_d[1:0], hsync};
    vsync_d <= {vsync_d[1:0], vsync};
end

// === TMDS encoders (one per channel) ===
wire [9:0] tmds_r, tmds_g, tmds_b;

tmds_encoder enc_r(
    .clk(clk_px), .resetn(pll_lock),
    .de(de_d[2]), .ctrl(2'b00),
    .din(r), .dout(tmds_r)
);
tmds_encoder enc_g(
    .clk(clk_px), .resetn(pll_lock),
    .de(de_d[2]), .ctrl(2'b00),
    .din(g), .dout(tmds_g)
);
tmds_encoder enc_b(
    .clk(clk_px), .resetn(pll_lock),
    .de(de_d[2]), .ctrl({vsync_d[2], hsync_d[2]}),
    .din(b), .dout(tmds_b)
);

// === OSER10 serializers: 10:1 at clk_5x ===
wire ser_r, ser_g, ser_b, ser_clk;

// TMDS clock channel: constant 10'b1111100000 (50% duty cycle pixel clock)
localparam [9:0] TMDS_CLK_WORD = 10'b1111100000;

OSER10 ser_r_inst(
    .Q(ser_r),
    .D0(tmds_r[0]), .D1(tmds_r[1]), .D2(tmds_r[2]), .D3(tmds_r[3]), .D4(tmds_r[4]),
    .D5(tmds_r[5]), .D6(tmds_r[6]), .D7(tmds_r[7]), .D8(tmds_r[8]), .D9(tmds_r[9]),
    .PCLK(clk_px), .FCLK(clk_5x), .RESET(~pll_lock)
);
OSER10 ser_g_inst(
    .Q(ser_g),
    .D0(tmds_g[0]), .D1(tmds_g[1]), .D2(tmds_g[2]), .D3(tmds_g[3]), .D4(tmds_g[4]),
    .D5(tmds_g[5]), .D6(tmds_g[6]), .D7(tmds_g[7]), .D8(tmds_g[8]), .D9(tmds_g[9]),
    .PCLK(clk_px), .FCLK(clk_5x), .RESET(~pll_lock)
);
OSER10 ser_b_inst(
    .Q(ser_b),
    .D0(tmds_b[0]), .D1(tmds_b[1]), .D2(tmds_b[2]), .D3(tmds_b[3]), .D4(tmds_b[4]),
    .D5(tmds_b[5]), .D6(tmds_b[6]), .D7(tmds_b[7]), .D8(tmds_b[8]), .D9(tmds_b[9]),
    .PCLK(clk_px), .FCLK(clk_5x), .RESET(~pll_lock)
);
OSER10 ser_clk_inst(
    .Q(ser_clk),
    .D0(TMDS_CLK_WORD[0]), .D1(TMDS_CLK_WORD[1]),
    .D2(TMDS_CLK_WORD[2]), .D3(TMDS_CLK_WORD[3]),
    .D4(TMDS_CLK_WORD[4]), .D5(TMDS_CLK_WORD[5]),
    .D6(TMDS_CLK_WORD[6]), .D7(TMDS_CLK_WORD[7]),
    .D8(TMDS_CLK_WORD[8]), .D9(TMDS_CLK_WORD[9]),
    .PCLK(clk_px), .FCLK(clk_5x), .RESET(~pll_lock)
);

// === ELVDS differential output buffers ===
ELVDS_OBUF buf_d0(.I(ser_b),   .O(tmds_d_p[0]), .OB(tmds_d_n[0]));
ELVDS_OBUF buf_d1(.I(ser_g),   .O(tmds_d_p[1]), .OB(tmds_d_n[1]));
ELVDS_OBUF buf_d2(.I(ser_r),   .O(tmds_d_p[2]), .OB(tmds_d_n[2]));
ELVDS_OBUF buf_clk(.I(ser_clk),.O(tmds_clk_p),  .OB(tmds_clk_n));

endmodule

// =============================================================================
// TMDS encoder (DVI 1.0 spec, 8b/10b with DC balance).
// During blanking (de=0): outputs control tokens (hsync/vsync via ctrl[1:0]).
// During active (de=1): encodes 8-bit pixel data with running disparity.
// Based on proven structure from Sipeed TangNano-9K-example.
// =============================================================================
module tmds_encoder(
    input  wire       clk,
    input  wire       resetn,
    input  wire       de,
    input  wire [1:0] ctrl,
    input  wire [7:0] din,
    output reg  [9:0] dout
);
    function [3:0] N1;
        input [7:0] b;
        integer i;
        begin
            N1 = 0;
            for (i = 0; i < 8; i = i + 1)
                N1 = N1 + b[i];
        end
    endfunction

    function [3:0] N0;
        input [7:0] b;
        integer i;
        begin
            N0 = 0;
            for (i = 0; i < 8; i = i + 1)
                N0 = N0 + !b[i];
        end
    endfunction

    reg [9:0] q_out, q_out_next;
    reg [3:0] N0_q_m, N1_q_m;
    reg signed [7:0] cnt, cnt_next, cnt_tmp;
    reg [8:0] q_m;

    always @(posedge clk) begin
        if (!resetn) begin
            cnt  <= 0;
            q_out <= 0;
        end else if (!de) begin
            cnt <= 0;
            case (ctrl)
                2'b00: q_out <= 10'b1101010100;
                2'b01: q_out <= 10'b0010101011;
                2'b10: q_out <= 10'b0101010100;
                2'b11: q_out <= 10'b1010101011;
            endcase
        end else begin
            // q_m: transition-minimised symbol (blocking = sequential evaluation)
            if ((N1(din) > 4) || ((N1(din) == 4) && (din[0] == 0))) begin
                q_m[0] =           din[0];
                q_m[1] = q_m[0] ^~ din[1];
                q_m[2] = q_m[1] ^~ din[2];
                q_m[3] = q_m[2] ^~ din[3];
                q_m[4] = q_m[3] ^~ din[4];
                q_m[5] = q_m[4] ^~ din[5];
                q_m[6] = q_m[5] ^~ din[6];
                q_m[7] = q_m[6] ^~ din[7];
                q_m[8] = 1'b0;
            end else begin
                q_m[0] =          din[0];
                q_m[1] = q_m[0] ^ din[1];
                q_m[2] = q_m[1] ^ din[2];
                q_m[3] = q_m[2] ^ din[3];
                q_m[4] = q_m[3] ^ din[4];
                q_m[5] = q_m[4] ^ din[5];
                q_m[6] = q_m[5] ^ din[6];
                q_m[7] = q_m[6] ^ din[7];
                q_m[8] = 1'b1;
            end

            N0_q_m = N0(q_m[7:0]);
            N1_q_m = N1(q_m[7:0]);

            if ((cnt == 0) || (N1_q_m == N0_q_m)) begin
                q_out_next[9]   = ~q_m[8];
                q_out_next[8]   =  q_m[8];
                q_out_next[7:0] = (q_m[8] ? q_m[7:0] : ~q_m[7:0]);
                if (q_m[8] == 0)
                    cnt_next = cnt + $signed({1'b0, N0_q_m}) - $signed({1'b0, N1_q_m});
                else
                    cnt_next = cnt + $signed({1'b0, N1_q_m}) - $signed({1'b0, N0_q_m});
            end else if (((cnt > 0) && (N1_q_m > N0_q_m)) || ((cnt < 0) && (N0_q_m > N1_q_m))) begin
                q_out_next[9]   = 1'b1;
                q_out_next[8]   = q_m[8];
                q_out_next[7:0] = ~q_m[7:0];
                cnt_tmp         = cnt + $signed({1'b0, N0_q_m}) - $signed({1'b0, N1_q_m});
                cnt_next        = q_m[8] ? cnt_tmp + 8'sd2 : cnt_tmp;
            end else begin
                q_out_next[9]   = 1'b0;
                q_out_next[8]   = q_m[8];
                q_out_next[7:0] = q_m[7:0];
                cnt_tmp         = cnt + $signed({1'b0, N1_q_m}) - $signed({1'b0, N0_q_m});
                cnt_next        = q_m[8] ? cnt_tmp : cnt_tmp - 8'sd2;
            end

            cnt  <= cnt_next;
            q_out <= q_out_next;
        end
        dout <= q_out;
    end
endmodule
