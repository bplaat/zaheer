/*
 * Copyright (c) 2025-2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

module uart_tx #(
    parameter integer CLK_FREQ = 27000000,
    parameter integer BAUD_RATE = 115200
) (
    input wire clk,
    input wire rst,
    input wire [7:0] data,
    input wire start,
    output reg busy,
    output reg tx
);
    localparam integer BAUD_DIVISOR =
        (CLK_FREQ + BAUD_RATE / 2) / BAUD_RATE;
    localparam integer BAUD_TICKS = BAUD_DIVISOR > 0 ? BAUD_DIVISOR : 1;
    localparam integer BAUD_COUNTER_WIDTH =
        BAUD_TICKS > 1 ? $clog2(BAUD_TICKS) : 1;

    localparam [1:0] STATE_IDLE  = 2'b00;
    localparam [1:0] STATE_START = 2'b01;
    localparam [1:0] STATE_DATA  = 2'b10;
    localparam [1:0] STATE_STOP  = 2'b11;

    reg [1:0] state;
    reg [2:0] bit_index;
    reg [BAUD_COUNTER_WIDTH - 1:0] baud_counter;
    reg [7:0] data_latch;

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            bit_index <= 0;
            baud_counter <= 0;
            data_latch <= 0;
            busy <= 0;
            tx <= 1;
        end else begin
            case (state)
                STATE_IDLE: begin
                    baud_counter <= 0;
                    busy <= 0;
                    tx <= 1;
                    if (start) begin
                        data_latch <= data;
                        busy <= 1;
                        tx <= 0;
                        state <= STATE_START;
                    end
                end
                STATE_START: begin
                    if (baud_counter == BAUD_TICKS - 1) begin
                        baud_counter <= 0;
                        bit_index <= 0;
                        tx <= data_latch[0];
                        state <= STATE_DATA;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end
                STATE_DATA: begin
                    if (baud_counter == BAUD_TICKS - 1) begin
                        baud_counter <= 0;
                        if (bit_index == 7) begin
                            tx <= 1;
                            state <= STATE_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                            tx <= data_latch[bit_index + 1'b1];
                        end
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end
                STATE_STOP: begin
                    if (baud_counter == BAUD_TICKS - 1) begin
                        baud_counter <= 0;
                        busy <= 0;
                        state <= STATE_IDLE;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end
                default: begin
                    state <= STATE_IDLE;
                    busy <= 0;
                    tx <= 1;
                end
            endcase
        end
    end
endmodule
