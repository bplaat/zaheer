/*
 * Copyright (c) 2025-2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

`include "cpu.v"
`include "uart/uart_tx.v"
`include "uart/uart_rx.v"
`include "uart/uart.v"
`include "taro/taro.v"

module top(
    input clk,
    output [5:0] led,
    input btn1,
    input uart_rx,
    output uart_tx,
    output tmds_clk_p,
    output tmds_clk_n,
    output [2:0] tmds_d_p,
    output [2:0] tmds_d_n
);

localparam CLK_FREQ = 27000000;

// Power-on reset: hold reset high for 255 clock cycles after configuration
reg [7:0] por_cnt = 8'h00;
wire por_active = (por_cnt != 8'hFF);
always @(posedge clk) begin
    if (por_cnt != 8'hFF)
        por_cnt <= por_cnt + 1;
end

// Combined reset: POR or button press (active-low button inverted)
wire rst = por_active | ~btn1;

// === CPU ===
wire [31:0] cpu_mem_addr;
wire [31:0] cpu_mem_wdata;
reg [31:0] cpu_mem_rdata;
wire cpu_mem_we;
wire cpu_mem_re;
wire [3:0] cpu_mem_wstrb;

cpu cpu_inst(
    .clk(clk),
    .rst(rst),
    .mem_addr(cpu_mem_addr),
    .mem_wdata(cpu_mem_wdata),
    .mem_rdata(cpu_mem_rdata),
    .mem_we(cpu_mem_we),
    .mem_re(cpu_mem_re),
    .mem_wstrb(cpu_mem_wstrb)
);

// === ROM (4KB, word-addressed, read-only) ===
reg [31:0] rom [0:1023];
initial begin
    $readmemh("target/boot.mem", rom);
end

wire rom_sel = (cpu_mem_addr[31:28] == 4'h0);
wire [31:0] rom_rdata = rom[cpu_mem_addr[11:2]];

// === RAM (4KB, byte-addressable via write strobes) ===
(* syn_ramstyle = "block_ram" *) reg [7:0] ram0 [0:1023]; // byte 0
(* syn_ramstyle = "block_ram" *) reg [7:0] ram1 [0:1023]; // byte 1
(* syn_ramstyle = "block_ram" *) reg [7:0] ram2 [0:1023]; // byte 2
(* syn_ramstyle = "block_ram" *) reg [7:0] ram3 [0:1023]; // byte 3

wire ram_sel = (cpu_mem_addr[31:28] == 4'h2);
wire [9:0] ram_word_addr = cpu_mem_addr[11:2];
wire [31:0] ram_rdata = {ram3[ram_word_addr], ram2[ram_word_addr],
                         ram1[ram_word_addr], ram0[ram_word_addr]};

always @(posedge clk) begin
    if (ram_sel && cpu_mem_we) begin
        if (cpu_mem_wstrb[0]) ram0[ram_word_addr] <= cpu_mem_wdata[7:0];
        if (cpu_mem_wstrb[1]) ram1[ram_word_addr] <= cpu_mem_wdata[15:8];
        if (cpu_mem_wstrb[2]) ram2[ram_word_addr] <= cpu_mem_wdata[23:16];
        if (cpu_mem_wstrb[3]) ram3[ram_word_addr] <= cpu_mem_wdata[31:24];
    end
end

// === UART Device ===
wire uart_sel = (cpu_mem_addr[31:28] == 4'h4);
wire [31:0] uart_rdata;

uart #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(115200)
) uart_inst (
    .clk(clk),
    .rst(rst),
    .addr(cpu_mem_addr[3:2]),
    .wdata(cpu_mem_wdata),
    .we(uart_sel && cpu_mem_we),
    .re(uart_sel && cpu_mem_re),
    .rdata(uart_rdata),
    .rx(uart_rx),
    .tx(uart_tx)
);

// === LED Register ===
reg [5:0] led_reg;
assign led = ~led_reg;

wire led_sel = (cpu_mem_addr[31:28] == 4'h6);
wire [31:0] led_rdata = {26'b0, led_reg};

always @(posedge clk) begin
    if (rst) begin
        led_reg <= 6'b0;
    end else if (led_sel && cpu_mem_we) begin
        led_reg <= cpu_mem_wdata[5:0];
    end
end

// === Taro Text Video Device ===
localparam VIDEO_BASE = 32'h80000000;
localparam VIDEO_SIZE = 32'h00002580;
wire video_sel = (cpu_mem_addr >= VIDEO_BASE) &&
                 (cpu_mem_addr < VIDEO_BASE + VIDEO_SIZE);
wire [11:0] video_word_addr = video_sel ? cpu_mem_addr[13:2] : 12'b0;
wire [31:0] video_rdata;

// === Address Decoder (read mux) ===
always @(*) begin
    if (rom_sel)
        cpu_mem_rdata = rom_rdata;
    else if (ram_sel)
        cpu_mem_rdata = ram_rdata;
    else if (uart_sel)
        cpu_mem_rdata = uart_rdata;
    else if (led_sel)
        cpu_mem_rdata = led_rdata;
    else if (video_sel)
        cpu_mem_rdata = video_rdata;
    else
        cpu_mem_rdata = 32'h00000000;
end

// === Taro ===
taro taro_inst(
    .clk(clk),
    .video_we(video_sel && cpu_mem_we),
    .video_addr(video_word_addr),
    .video_wdata(cpu_mem_wdata),
    .video_wstrb(cpu_mem_wstrb),
    .video_rdata(video_rdata),
    .tmds_clk_p(tmds_clk_p),
    .tmds_clk_n(tmds_clk_n),
    .tmds_d_p(tmds_d_p),
    .tmds_d_n(tmds_d_n)
);

endmodule
