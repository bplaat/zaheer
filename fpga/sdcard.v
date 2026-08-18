/*
 * Copyright (c) 2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 *
 * Memory-mapped SPI-mode SD card controller.
 *
 * Registers:
 *   0x00 DATA    write starts one byte transfer, read returns received byte
 *   0x04 STATUS  bit 0 is set while a transfer is active
 *   0x08 CONTROL bit 0 asserts CS, bit 1 selects 13.5 MHz fast mode
 */

module sdcard(
    input  wire        clk,
    input  wire        rst,
    input  wire        we,
    input  wire [1:0]  addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output reg         sd_clk,
    output reg         sd_mosi,
    input  wire        sd_miso,
    output wire        sd_cs
);

reg        cs_active;
reg        fast;
reg        busy;
reg [5:0]  divider_count;
reg [2:0]  bit_count;
reg [7:0]  tx_shift;
reg [7:0]  rx_shift;
reg [7:0]  rx_data;

assign sd_cs = ~cs_active;

always @(*) begin
    case (addr)
        2'b00: rdata = {24'b0, rx_data};
        2'b01: rdata = {31'b0, busy};
        2'b10: rdata = {30'b0, fast, cs_active};
        default: rdata = 32'b0;
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        cs_active <= 0;
        fast <= 0;
        busy <= 0;
        divider_count <= 0;
        bit_count <= 0;
        tx_shift <= 8'hFF;
        rx_shift <= 0;
        rx_data <= 8'hFF;
        sd_clk <= 0;
        sd_mosi <= 1;
    end else begin
        if (we && addr == 2'b10) begin
            cs_active <= wdata[0];
            fast <= wdata[1];
        end

        if (we && addr == 2'b00 && !busy) begin
            busy <= 1;
            divider_count <= fast ? 0 : 6'd63;
            bit_count <= 0;
            tx_shift <= wdata[7:0];
            rx_shift <= 0;
            sd_clk <= 0;
            sd_mosi <= wdata[7];
        end else if (busy) begin
            if (divider_count != 0) begin
                divider_count <= divider_count - 1;
            end else if (!sd_clk) begin
                sd_clk <= 1;
                rx_shift <= {rx_shift[6:0], sd_miso};
                divider_count <= fast ? 0 : 6'd63;
            end else begin
                sd_clk <= 0;
                if (bit_count == 7) begin
                    busy <= 0;
                    rx_data <= rx_shift;
                    sd_mosi <= 1;
                end else begin
                    bit_count <= bit_count + 1;
                    tx_shift <= {tx_shift[6:0], 1'b1};
                    sd_mosi <= tx_shift[6];
                    divider_count <= fast ? 0 : 6'd63;
                end
            end
        end
    end
end

endmodule
