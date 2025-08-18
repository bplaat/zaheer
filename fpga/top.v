/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

`include "uart_tx.v"

localparam CLK_FREQ = 27000000;

module top(
    input clk,
    output [5:0] led,
    input btn1,
    input uart_rx,
    output uart_tx,
);

wire rst = ~btn1;

// UART
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

// ROM
reg [7:0] rom [0:1023];
initial begin
    $readmemh("boot.mem", rom);
end

// LED counter
localparam WAIT_TIME = CLK_FREQ / 32;

reg [23:0] clock_counter;
reg [5:0] led_counter;
reg [31:0] instruction_pointer;

assign led = ~led_counter;

always @(posedge clk) begin
    if (rst) begin
        clock_counter = 0;
        led_counter = 0;
        instruction_pointer = 0;
    end else begin
        clock_counter <= clock_counter + 1;
        if (clock_counter == WAIT_TIME) begin
            clock_counter <= 0;
            led_counter <= led_counter + 1;

            if (rom[instruction_pointer] == 8'h00) begin
                instruction_pointer <= 0;
            end else begin
                uart_data <= rom[instruction_pointer];
                uart_start <= 1;

                instruction_pointer <= instruction_pointer + 1;
            end
        end else begin
            uart_start <= 0;
        end
    end
end

endmodule
