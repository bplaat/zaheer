/*
 * Copyright (c) 2025-2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

module uart_rx #(
    parameter CLK_FREQ = 27000000,
    parameter BAUD_RATE = 115200
) (
    input wire clk,
    input wire rst,
    input wire rx,
    output reg data_ready,
    output reg [7:0] data
);
    localparam BAUD_TICK      = CLK_FREQ / BAUD_RATE;
    localparam HALF_BAUD_TICK = BAUD_TICK / 2;

    localparam STATE_IDLE  = 2'b00,
               STATE_START = 2'b01,
               STATE_DATA  = 2'b10,
               STATE_STOP  = 2'b11;

    // Two-stage synchronizer to cross RX into the clock domain
    reg rx_meta, rx_sync;
    always @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
    end

    reg [1:0] state;
    reg [3:0] bit_cnt;
    reg [7:0] baud_cnt;
    reg [7:0] data_reg;

    always @(posedge clk) begin
        if (rst) begin
            state      <= STATE_IDLE;
            bit_cnt    <= 0;
            baud_cnt   <= 0;
            data_ready <= 0;
            data       <= 8'h00;
            data_reg   <= 8'h00;
        end else begin
            data_ready <= 0;
            case (state)
                STATE_IDLE: begin
                    if (!rx_sync) begin
                        baud_cnt <= 0;
                        state    <= STATE_START;
                    end
                end
                STATE_START: begin
                    // Wait half baud period to sample in the middle of the start bit
                    if (baud_cnt < HALF_BAUD_TICK - 1) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        if (!rx_sync) begin
                            baud_cnt <= 0;
                            bit_cnt  <= 0;
                            state    <= STATE_DATA;
                        end else begin
                            state <= STATE_IDLE;  // false start bit
                        end
                    end
                end
                STATE_DATA: begin
                    if (baud_cnt < BAUD_TICK - 1) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        data_reg <= {rx_sync, data_reg[7:1]};  // shift in LSB first
                        if (bit_cnt < 7) begin
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            bit_cnt <= 0;
                            state   <= STATE_STOP;
                        end
                    end
                end
                STATE_STOP: begin
                    if (baud_cnt < BAUD_TICK - 1) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        if (rx_sync) begin
                            data       <= data_reg;
                            data_ready <= 1;
                        end
                        state <= STATE_IDLE;
                    end
                end
            endcase
        end
    end
endmodule
