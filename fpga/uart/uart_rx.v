/*
 * Copyright (c) 2025-2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

module uart_rx #(
    parameter integer CLK_FREQ = 27000000,
    parameter integer BAUD_RATE = 115200
) (
    input wire clk,
    input wire rst,
    input wire rx,
    output reg data_ready,
    output reg framing_error,
    output reg [7:0] data
);
    localparam integer BAUD_DIVISOR =
        (CLK_FREQ + BAUD_RATE / 2) / BAUD_RATE;
    localparam integer BAUD_TICKS = BAUD_DIVISOR > 0 ? BAUD_DIVISOR : 1;
    localparam integer HALF_BAUD_TICKS =
        BAUD_TICKS > 1 ? BAUD_TICKS / 2 : 1;
    localparam integer BAUD_COUNTER_WIDTH =
        BAUD_TICKS > 1 ? $clog2(BAUD_TICKS) : 1;

    localparam [1:0] STATE_IDLE  = 2'b00;
    localparam [1:0] STATE_START = 2'b01;
    localparam [1:0] STATE_DATA  = 2'b10;
    localparam [1:0] STATE_STOP  = 2'b11;

    reg rx_meta;
    reg rx_sync;
    reg [1:0] state;
    reg [2:0] bit_index;
    reg [BAUD_COUNTER_WIDTH - 1:0] baud_counter;
    reg [7:0] data_latch;

    always @(posedge clk) begin
        if (rst) begin
            rx_meta <= 1;
            rx_sync <= 1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            bit_index <= 0;
            baud_counter <= 0;
            data_latch <= 0;
            data_ready <= 0;
            framing_error <= 0;
            data <= 0;
        end else begin
            data_ready <= 0;
            framing_error <= 0;

            case (state)
                STATE_IDLE: begin
                    baud_counter <= 0;
                    if (!rx_sync)
                        state <= STATE_START;
                end
                STATE_START: begin
                    if (baud_counter == HALF_BAUD_TICKS - 1) begin
                        baud_counter <= 0;
                        if (!rx_sync) begin
                            bit_index <= 0;
                            state <= STATE_DATA;
                        end else begin
                            state <= STATE_IDLE;
                        end
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end
                STATE_DATA: begin
                    if (baud_counter == BAUD_TICKS - 1) begin
                        baud_counter <= 0;
                        data_latch[bit_index] <= rx_sync;
                        if (bit_index == 7) begin
                            state <= STATE_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end
                STATE_STOP: begin
                    if (baud_counter == BAUD_TICKS - 1) begin
                        baud_counter <= 0;
                        if (rx_sync) begin
                            data <= data_latch;
                            data_ready <= 1;
                        end else begin
                            framing_error <= 1;
                        end
                        state <= STATE_IDLE;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end
                default: state <= STATE_IDLE;
            endcase
        end
    end
endmodule
