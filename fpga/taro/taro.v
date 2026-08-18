/*
 * Copyright (c) 2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 *
 * Taro 80x60 text-mode video device.
 */

`include "taro/text_mode.v"
`include "taro/hdmi.v"

module taro(
    input  wire        clk,
    input  wire        video_we,
    input  wire [11:0] video_addr,
    input  wire [31:0] video_wdata,
    input  wire [3:0]  video_wstrb,
    output wire [31:0] video_rdata,
    output wire        tmds_clk_p,
    output wire        tmds_clk_n,
    output wire [2:0]  tmds_d_p,
    output wire [2:0]  tmds_d_n
);

hdmi hdmi_inst(
    .clk(clk),
    .video_we(video_we),
    .video_addr(video_addr),
    .video_wdata(video_wdata),
    .video_wstrb(video_wstrb),
    .video_rdata(video_rdata),
    .tmds_clk_p(tmds_clk_p),
    .tmds_clk_n(tmds_clk_n),
    .tmds_d_p(tmds_d_p),
    .tmds_d_n(tmds_d_n)
);

endmodule
