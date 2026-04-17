/*
 * Copyright (c) 2025-2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

module uart_tx #(
    parameter CLK_FREQ = 27000000,
    parameter BAUD_RATE = 115200
) (
    input wire clk,
    input wire rst,
    input wire [7:0] data,
    input wire start,
    output reg busy,
    output reg tx
);
    localparam BAUD_TICK = CLK_FREQ / BAUD_RATE;

    reg [1:0] state;
    reg [3:0] bit_cnt;
    reg [7:0] baud_cnt;
    reg [7:0] data_reg;

    localparam STATE_IDLE = 2'b00,
        STATE_START = 2'b01,
        STATE_DATA = 2'b10,
        STATE_STOP = 2'b11;

    always @(posedge clk) begin
        if (rst) begin
            tx <= 1'b1;
            busy <= 1'b0;
            state <= STATE_IDLE;
            bit_cnt <= 0;
            baud_cnt <= 0;
            data_reg <= 8'h00;
        end else begin
            case (state)
                STATE_IDLE: begin
                    tx <= 1'b1;
                    busy <= 1'b0;
                    bit_cnt <= 0;
                    baud_cnt <= 0;
                    if (start) begin
                        data_reg <= data;
                        state <= STATE_START;
                        busy <= 1'b1;
                    end
                end
                STATE_START: begin
                    tx <= 1'b0;
                    if (baud_cnt < BAUD_TICK - 1) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        state <= STATE_DATA;
                    end
                end
                STATE_DATA: begin
                    tx <= data_reg[bit_cnt];
                    if (baud_cnt < BAUD_TICK - 1) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        if (bit_cnt < 7) begin
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            bit_cnt <= 0;
                            state <= STATE_STOP;
                        end
                    end
                end
                STATE_STOP: begin
                    tx <= 1'b1;
                    if (baud_cnt < BAUD_TICK - 1) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        state <= STATE_IDLE;
                    end
                end
            endcase
        end
    end
endmodule
