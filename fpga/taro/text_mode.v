/*
 * Copyright (c) 2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 *
 * 80x60 text-mode renderer for a 640x480 active video area.
 */

module text_mode(
    input  wire        cpu_clk,
    input  wire        cpu_we,
    input  wire [11:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire [3:0]  cpu_wstrb,
    output reg  [31:0] cpu_rdata,

    input  wire       px_clk,
    input  wire       px_reset,
    input  wire [9:0] hcnt,
    input  wire [9:0] vcnt,
    input  wire       de,
    input  wire       hsync,
    input  wire       vsync,
    output reg  [7:0] px_r,
    output reg  [7:0] px_g,
    output reg  [7:0] px_b,
    output wire       de_out,
    output wire       hsync_out,
    output wire       vsync_out
);

localparam TEXT_WORDS = 2400;

// Each CPU word contains two adjacent 16-bit character cells. Splitting even
// and odd cells into separate memories permits a 32-bit CPU access alongside
// the single-cell display read port.
(* syn_ramstyle = "block_ram" *) reg [15:0] text_even [0:TEXT_WORDS - 1];
(* syn_ramstyle = "block_ram" *) reg [15:0] text_odd  [0:TEXT_WORDS - 1];

wire cpu_addr_valid = cpu_addr < TEXT_WORDS;
wire [11:0] safe_cpu_addr = cpu_addr_valid ? cpu_addr : 12'b0;

always @(posedge cpu_clk) begin
    cpu_rdata <= cpu_addr_valid ?
        {text_odd[safe_cpu_addr], text_even[safe_cpu_addr]} : 32'b0;
    if (cpu_we && cpu_addr_valid) begin
        if (cpu_wstrb[0]) text_even[safe_cpu_addr][7:0]  <= cpu_wdata[7:0];
        if (cpu_wstrb[1]) text_even[safe_cpu_addr][15:8] <= cpu_wdata[15:8];
        if (cpu_wstrb[2]) text_odd[safe_cpu_addr][7:0]   <= cpu_wdata[23:16];
        if (cpu_wstrb[3]) text_odd[safe_cpu_addr][15:8]  <= cpu_wdata[31:24];
    end
end

wire [6:0] text_col = hcnt[9:3];
wire [6:0] text_row = vcnt[9:3];
wire [12:0] extended_text_row = {6'b0, text_row};
wire [12:0] extended_text_col = {6'b0, text_col};
wire [12:0] active_cell_addr = (extended_text_row << 6) +
                                (extended_text_row << 4) + extended_text_col;
wire [12:0] display_cell_addr = de ? active_cell_addr : 13'b0;
wire [11:0] display_word_addr = display_cell_addr[12:1];

reg [15:0] display_even_q;
reg [15:0] display_odd_q;
always @(posedge px_clk) begin
    display_even_q <= text_even[display_word_addr];
    display_odd_q  <= text_odd[display_word_addr];
end

// Stage 1 accompanies the synchronous text-memory read.
reg       cell_odd_s1;
reg [2:0] glyph_x_s1;
reg [2:0] glyph_y_s1;
reg       de_s1, hsync_s1, vsync_s1;

// Stage 2 accompanies the synchronous font-memory read.
reg [7:0] attr_s2;
reg [2:0] glyph_x_s2;
reg       de_s2, hsync_s2, vsync_s2;
reg [10:0] font_addr;

// Stage 3 aligns the cell attribute and video control signals with font_q.
reg [7:0] attr_s3;
reg [2:0] glyph_x_s3;
reg       de_s3, hsync_s3, vsync_s3;

wire [15:0] display_cell = cell_odd_s1 ? display_odd_q : display_even_q;

(* syn_ramstyle = "block_ram" *) reg [7:0] font [0:2047];
reg [7:0] font_q;
initial begin
    $readmemh("target/taro_font.mem", font);
end

always @(posedge px_clk) begin
    font_q <= font[font_addr];

    if (px_reset) begin
        cell_odd_s1 <= 0;
        glyph_x_s1 <= 0;
        glyph_y_s1 <= 0;
        de_s1 <= 0;
        hsync_s1 <= 1;
        vsync_s1 <= 1;

        attr_s2 <= 0;
        glyph_x_s2 <= 0;
        de_s2 <= 0;
        hsync_s2 <= 1;
        vsync_s2 <= 1;
        font_addr <= 0;

        attr_s3 <= 0;
        glyph_x_s3 <= 0;
        de_s3 <= 0;
        hsync_s3 <= 1;
        vsync_s3 <= 1;
    end else begin
        cell_odd_s1 <= display_cell_addr[0];
        glyph_x_s1 <= hcnt[2:0];
        glyph_y_s1 <= vcnt[2:0];
        de_s1 <= de;
        hsync_s1 <= hsync;
        vsync_s1 <= vsync;

        attr_s2 <= display_cell[15:8];
        glyph_x_s2 <= glyph_x_s1;
        de_s2 <= de_s1;
        hsync_s2 <= hsync_s1;
        vsync_s2 <= vsync_s1;
        font_addr <= {display_cell[7:0], glyph_y_s1};

        attr_s3 <= attr_s2;
        glyph_x_s3 <= glyph_x_s2;
        de_s3 <= de_s2;
        hsync_s3 <= hsync_s2;
        vsync_s3 <= vsync_s2;
    end
end

wire glyph_pixel = font_q[7 - glyph_x_s3];
wire [3:0] color = glyph_pixel ? attr_s3[3:0] : attr_s3[7:4];

always @(*) begin
    case (color)
        4'h0: begin px_r = 8'h00; px_g = 8'h00; px_b = 8'h00; end
        4'h1: begin px_r = 8'h00; px_g = 8'h00; px_b = 8'hAA; end
        4'h2: begin px_r = 8'h00; px_g = 8'hAA; px_b = 8'h00; end
        4'h3: begin px_r = 8'h00; px_g = 8'hAA; px_b = 8'hAA; end
        4'h4: begin px_r = 8'hAA; px_g = 8'h00; px_b = 8'h00; end
        4'h5: begin px_r = 8'hAA; px_g = 8'h00; px_b = 8'hAA; end
        4'h6: begin px_r = 8'hAA; px_g = 8'h55; px_b = 8'h00; end
        4'h7: begin px_r = 8'hAA; px_g = 8'hAA; px_b = 8'hAA; end
        4'h8: begin px_r = 8'h55; px_g = 8'h55; px_b = 8'h55; end
        4'h9: begin px_r = 8'h55; px_g = 8'h55; px_b = 8'hFF; end
        4'hA: begin px_r = 8'h55; px_g = 8'hFF; px_b = 8'h55; end
        4'hB: begin px_r = 8'h55; px_g = 8'hFF; px_b = 8'hFF; end
        4'hC: begin px_r = 8'hFF; px_g = 8'h55; px_b = 8'h55; end
        4'hD: begin px_r = 8'hFF; px_g = 8'h55; px_b = 8'hFF; end
        4'hE: begin px_r = 8'hFF; px_g = 8'hFF; px_b = 8'h55; end
        default: begin px_r = 8'hFF; px_g = 8'hFF; px_b = 8'hFF; end
    endcase
end

assign de_out = de_s3;
assign hsync_out = hsync_s3;
assign vsync_out = vsync_s3;

endmodule
