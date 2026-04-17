/*
 * Copyright (c) 2025-2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

`include "cpu.v"
`include "uart_tx.v"
`include "uart_rx.v"

module top(
    input clk,
    output [5:0] led,
    input btn1,
    input uart_rx,
    output uart_tx
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
reg [7:0] ram0 [0:1023]; // byte 0
reg [7:0] ram1 [0:1023]; // byte 1
reg [7:0] ram2 [0:1023]; // byte 2
reg [7:0] ram3 [0:1023]; // byte 3

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

// === UART TX ===
reg [7:0] uart_tx_data;
reg uart_tx_start;
wire uart_tx_busy;

uart_tx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(115200)
) uart_tx_inst (
    .clk(clk),
    .rst(rst),
    .data(uart_tx_data),
    .start(uart_tx_start),
    .busy(uart_tx_busy),
    .tx(uart_tx)
);

// === UART RX ===
wire uart_rx_data_ready;
wire [7:0] uart_rx_data_wire;

uart_rx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(115200)
) uart_rx_inst (
    .clk(clk),
    .rst(rst),
    .rx(uart_rx),
    .data_ready(uart_rx_data_ready),
    .data(uart_rx_data_wire)
);

reg [7:0] uart_rx_buf;
reg uart_rx_ready;

wire uart_sel = (cpu_mem_addr[31:28] == 4'h4);

// UART register read mux:
//   0x40000000 - TX data (write-only, reads zero)
//   0x40000004 - TX status: bit 0 = busy
//   0x40000008 - RX status: bit 0 = data ready
//   0x4000000C - RX data:   byte received (read clears ready flag)
wire [31:0] uart_rdata =
    (cpu_mem_addr[3:2] == 2'b01) ? {31'b0, uart_tx_busy}  :
    (cpu_mem_addr[3:2] == 2'b10) ? {31'b0, uart_rx_ready} :
    (cpu_mem_addr[3:2] == 2'b11) ? {24'b0, uart_rx_buf}   :
    32'b0;

always @(posedge clk) begin
    if (rst) begin
        uart_tx_start <= 0;
        uart_tx_data  <= 8'h00;
    end else begin
        uart_tx_start <= 0;
        if (uart_sel && cpu_mem_we && cpu_mem_addr[3:2] == 2'b00) begin
            uart_tx_data  <= cpu_mem_wdata[7:0];
            uart_tx_start <= 1;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        uart_rx_buf   <= 8'h00;
        uart_rx_ready <= 0;
    end else begin
        if (uart_rx_data_ready) begin
            uart_rx_buf   <= uart_rx_data_wire;
            uart_rx_ready <= 1;
        end else if (uart_sel && cpu_mem_re && cpu_mem_addr[3:2] == 2'b11) begin
            uart_rx_ready <= 0;
        end
    end
end

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
    else
        cpu_mem_rdata = 32'h00000000;
end

endmodule
