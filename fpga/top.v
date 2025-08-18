/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

`include "uart_tx.v"
`include "memory.v"
`include "cpu.v"

localparam CLK_FREQ = 27000000;

module top(
    input wire clk,
    input wire btn1,
    input wire uart_rx,
    output wire uart_tx,
    output wire [5:0] led
);

wire rst = ~btn1;

// MARK: Slow clock
localparam WAIT_TIME = CLK_FREQ / 128;
reg [23:0] clock_counter;
reg slow_clk;
always @(posedge clk) begin
    if (rst) begin
        clock_counter <= 0;
        slow_clk <= 0;
    end else begin
        clock_counter <= clock_counter + 1;
        if (clock_counter == WAIT_TIME) begin
            clock_counter <= 0;
            slow_clk <= ~slow_clk;
        end
    end
end

// MARK: UART TX
reg [7:0] uart_data = 8'h00;
reg uart_start = 0;
wire uart_busy;
uart_tx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(115200)
) uart_tx_inst (
    .clk(clk),
    .rst(rst),
    .data(uart_data),
    .start(uart_start),
    .busy(uart_busy),
    .tx(uart_tx)
);

// MARK: Bus
wire [31:0] bus_addr;
wire bus_is_io = bus_addr[23];
wire bus_is_ram = ~bus_is_io;

wire bus_read;
reg [31:0] io_read_data;
wire [31:0] mem_read_data;
wire [31:0] bus_read_data = bus_is_io ? io_read_data : mem_read_data;

wire [3:0] bus_write_mask;
wire [31:0] bus_write_data;

memory mem_inst (
    .clk(slow_clk),
    .addr(bus_addr),
    .read(bus_is_ram & bus_read),
    .read_data(mem_read_data),
    .write_mask({4{bus_is_ram}} & bus_write_mask),
    .write_data(bus_write_data)
);

localparam UART_TX_DATA = 32'h00800000;
localparam UART_TX_BUSY = 32'h00800001;

reg uart_written = 0;

always @(posedge slow_clk) begin
    led <= ~bus_addr[7:2];

    // if (bus_is_io & bus_read) begin
    //     if (bus_addr[1:0] == UART_TX_BUSY[1:0]) begin
    //         io_read_data <= {31'b0, uart_busy};
    //     end else begin
    //         io_read_data <= 32'h00000000;
    //     end
    // end

    if (bus_is_io & |bus_write_mask) begin
        if (bus_addr[1:0] == UART_TX_DATA[1:0]) begin
            if (!uart_written) begin
                uart_data <= bus_write_data[7:0];
                uart_start <= 1;
                uart_written <= 1;
            end else begin
                uart_start <= 0;
            end
        end
    end else begin
        uart_written <= 0;
    end
end

// MARK: CPU
reg cpu_mem_rbusy = 0;
reg cpu_mem_wbusy = 0;
cpu cpu_inst (
    .clk(slow_clk),
    .mem_addr(bus_addr),
    .mem_wdata(bus_write_data),
    .mem_wmask(bus_write_mask),
    .mem_rdata(bus_read_data),
    .mem_rstrb(bus_read),
    .mem_rbusy(cpu_mem_rbusy),
    .mem_wbusy(cpu_mem_wbusy),
    .reset(~rst)
);

endmodule
