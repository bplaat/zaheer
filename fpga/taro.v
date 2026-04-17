/*
 * Copyright (c) 2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 *
 * Taro - 80x60 tile renderer with 8x8 pixel characters.
 *
 * Memory map (CPU side, system clock):
 *   0x30000000 - 0x3000257F : Tilemap VRAM  (80x60 x 2 bytes = 9600 bytes)
 *                             byte 2n+0 = character index (0-255)
 *                             byte 2n+1 = attribute: [7:4]=fg color, [3:0]=bg color
 *   0x50000000 - 0x500007FF : Font RAM (256 chars x 8 rows = 2048 bytes)
 *                             each byte = 1 row of pixels, MSB = leftmost pixel
 *
 * Render pipeline (pixel clock domain, 2-cycle latency):
 *   Cycle 0 : BRAM address presented (tile_addr from hcnt+2 prefetch, font_addr queued)
 *   Cycle 1 : Tilemap BRAM output captured; font BRAM address presented
 *   Cycle 2 : Font BRAM output captured; palette lookup -> r/g/b valid
 *
 * 16-color EGA palette (indices 0-15).
 */

module taro(
    // CPU write port (system clock)
    input  wire        clk,
    input  wire        tilemap_sel,
    input  wire        font_sel,
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire        cpu_we,
    input  wire [3:0]  cpu_wstrb,

    // Render port (pixel clock)
    input  wire        clk_px,
    input  wire [9:0]  hcnt,
    input  wire [9:0]  vcnt,
    output reg  [7:0]  r,
    output reg  [7:0]  g,
    output reg  [7:0]  b
);

// === Tilemap BRAM: separate char and attr arrays (80x60 = 4800 entries each) ===
(* syn_ramstyle = "block_ram" *) reg [7:0] tilemap_char [0:4799];
(* syn_ramstyle = "block_ram" *) reg [7:0] tilemap_attr [0:4799];

// CPU write (word-aligned: each 32-bit word covers 2 consecutive cells)
wire [12:0] cell_lo = {cpu_addr[13:2], 1'b0};  // cell index 2k
wire [12:0] cell_hi = {cpu_addr[13:2], 1'b1};  // cell index 2k+1

always @(posedge clk) begin
    if (tilemap_sel && cpu_we) begin
        if (cpu_wstrb[0]) tilemap_char[cell_lo] <= cpu_wdata[7:0];
        if (cpu_wstrb[1]) tilemap_attr[cell_lo] <= cpu_wdata[15:8];
        if (cpu_wstrb[2]) tilemap_char[cell_hi] <= cpu_wdata[23:16];
        if (cpu_wstrb[3]) tilemap_attr[cell_hi] <= cpu_wdata[31:24];
    end
end

// === Font BRAM: 256 chars x 8 rows = 2048 bytes ===
(* syn_ramstyle = "block_ram" *) reg [7:0] font_mem [0:2047];

always @(posedge clk) begin
    if (font_sel && cpu_we) begin
        if (cpu_wstrb[0]) font_mem[{cpu_addr[9:2], 2'b00}] <= cpu_wdata[7:0];
        if (cpu_wstrb[1]) font_mem[{cpu_addr[9:2], 2'b01}] <= cpu_wdata[15:8];
        if (cpu_wstrb[2]) font_mem[{cpu_addr[9:2], 2'b10}] <= cpu_wdata[23:16];
        if (cpu_wstrb[3]) font_mem[{cpu_addr[9:2], 2'b11}] <= cpu_wdata[31:24];
    end
end

// === Render pipeline (pixel clock domain) ===
// Stage 0: Compute tile address using prefetched hcnt+2, latch vcnt
wire [9:0] hcnt_pre = hcnt + 10'd4;  // 4-cycle prefetch (3 render stages + 1 TMDS stage)

// tile_addr = (vcnt/8)*80 + (hcnt_pre/8)
// row*80 = row*64 + row*16
wire [5:0]  tile_row  = vcnt[8:3];
wire [6:0]  tile_col  = hcnt_pre[9:3];
wire [12:0] tile_addr = ({7'b0, tile_row} << 6) + ({7'b0, tile_row} << 4) + {6'b0, tile_col};

reg [7:0] char_s1, attr_s1;
reg [2:0] pix_col_s1;  // hcnt_pre[2:0] registered for stage 2
reg [2:0] vcnt_row_s1; // vcnt[2:0] for font row address

always @(posedge clk_px) begin
    char_s1     <= tilemap_char[tile_addr];
    attr_s1     <= tilemap_attr[tile_addr];
    pix_col_s1  <= hcnt_pre[2:0];
    vcnt_row_s1 <= vcnt[2:0];
end

// Stage 1: Read font using char+vcnt_row from stage 0
wire [10:0] font_addr = {char_s1, vcnt_row_s1};

reg [7:0] font_byte_s2;
reg [3:0] fg_s2, bg_s2;
reg [2:0] pix_col_s2;

always @(posedge clk_px) begin
    font_byte_s2 <= font_mem[font_addr];
    fg_s2        <= attr_s1[7:4];
    bg_s2        <= attr_s1[3:0];
    pix_col_s2   <= pix_col_s1;
end

// Stage 2: Palette lookup
// font MSB = leftmost pixel (pixel column 0)
wire pix_bit = font_byte_s2[3'd7 - pix_col_s2];
wire [3:0] color_idx = pix_bit ? fg_s2 : bg_s2;

// EGA 16-color palette
function [23:0] ega_color;
    input [3:0] idx;
    case (idx)
        4'd0:  ega_color = 24'h000000; // black
        4'd1:  ega_color = 24'h0000AA; // dark blue
        4'd2:  ega_color = 24'h00AA00; // dark green
        4'd3:  ega_color = 24'h00AAAA; // dark cyan
        4'd4:  ega_color = 24'hAA0000; // dark red
        4'd5:  ega_color = 24'hAA00AA; // dark magenta
        4'd6:  ega_color = 24'hAA5500; // brown
        4'd7:  ega_color = 24'hAAAAAA; // light gray
        4'd8:  ega_color = 24'h555555; // dark gray
        4'd9:  ega_color = 24'h5555FF; // light blue
        4'd10: ega_color = 24'h55FF55; // light green
        4'd11: ega_color = 24'h55FFFF; // light cyan
        4'd12: ega_color = 24'hFF5555; // light red
        4'd13: ega_color = 24'hFF55FF; // light magenta
        4'd14: ega_color = 24'hFFFF55; // yellow
        default: ega_color = 24'hFFFFFF; // white
    endcase
endfunction

always @(posedge clk_px) begin
    {r, g, b} <= ega_color(color_idx);
end

endmodule
