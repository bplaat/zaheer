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

assign rst = ~btn1;

// UART
// picocom -b 115200 /dev/tty.usbserial-11101
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
    rom[0] = "B";
    rom[1] = "a";
    rom[2] = "s";
    rom[3] = "t";
    rom[4] = "i";
    rom[5] = "a";
    rom[6] = "a";
    rom[7] = "n";
    rom[8] = " ";
    rom[9] = 8'h00;
end

// LED counter
localparam WAIT_TIME = CLK_FREQ / 16;

reg [23:0] clock_counter = 0;
reg [5:0] led_counter = 0;
reg [31:0] instruction_pointer = 0;

always @(posedge clk) begin
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

assign led = ~led_counter;

endmodule
