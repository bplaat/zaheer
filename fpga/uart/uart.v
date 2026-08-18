/*
 * Copyright (c) 2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

module uart #(
    parameter integer CLK_FREQ = 27000000,
    parameter integer BAUD_RATE = 115200
) (
    input wire clk,
    input wire rst,
    input wire [1:0] addr,
    input wire [31:0] wdata,
    input wire we,
    input wire re,
    output reg [31:0] rdata,
    input wire rx,
    output wire tx
);
    wire tx_busy;
    wire tx_start = we && addr == 2'b00 && !tx_busy;

    wire [7:0] rx_data;
    wire rx_data_ready;
    wire rx_framing_error;
    reg [7:0] rx_buffer;
    reg rx_ready;
    reg rx_overrun;
    reg rx_frame_error_status;

    // Register map:
    //   0 - TX data (write-only)
    //   1 - TX status: bit 0 busy
    //   2 - RX status: bit 0 ready, bit 1 overrun, bit 2 framing error
    //   3 - RX data (reading clears RX status)

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) tx_inst (
        .clk(clk),
        .rst(rst),
        .data(wdata[7:0]),
        .start(tx_start),
        .busy(tx_busy),
        .tx(tx)
    );

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) rx_inst (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .data_ready(rx_data_ready),
        .framing_error(rx_framing_error),
        .data(rx_data)
    );

    always @(*) begin
        case (addr)
            2'b01: rdata = {31'b0, tx_busy};
            2'b10: rdata = {29'b0, rx_frame_error_status,
                            rx_overrun, rx_ready};
            2'b11: rdata = {24'b0, rx_buffer};
            default: rdata = 0;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            rx_buffer <= 0;
            rx_ready <= 0;
            rx_overrun <= 0;
            rx_frame_error_status <= 0;
        end else begin
            if (re && addr == 2'b11) begin
                rx_ready <= 0;
                rx_overrun <= 0;
                rx_frame_error_status <= 0;
            end

            if (rx_framing_error)
                rx_frame_error_status <= 1;

            if (rx_data_ready) begin
                rx_buffer <= rx_data;
                rx_ready <= 1;
                if (rx_ready)
                    rx_overrun <= 1;
            end
        end
    end
endmodule
