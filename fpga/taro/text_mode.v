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
localparam FONT_WORDS = 512;
localparam FONT_WORD_BASE = TEXT_WORDS;
localparam TOTAL_WORDS = TEXT_WORDS + FONT_WORDS;

// Each CPU word contains two adjacent 16-bit character cells. Separate byte
// banks match the block RAM write granularity while permitting a 32-bit CPU
// access alongside the single-cell display read port.
(* syn_ramstyle = "block_ram" *) reg [7:0] text_even_char [0:TEXT_WORDS - 1];
(* syn_ramstyle = "block_ram" *) reg [7:0] text_even_attr [0:TEXT_WORDS - 1];
(* syn_ramstyle = "block_ram" *) reg [7:0] text_odd_char  [0:TEXT_WORDS - 1];
(* syn_ramstyle = "block_ram" *) reg [7:0] text_odd_attr  [0:TEXT_WORDS - 1];

wire text_addr_valid = cpu_addr < TEXT_WORDS;
wire font_addr_valid = cpu_addr >= FONT_WORD_BASE && cpu_addr < TOTAL_WORDS;
wire [11:0] safe_text_addr = text_addr_valid ? cpu_addr : 12'b0;
wire [8:0] safe_font_addr = font_addr_valid ? cpu_addr - FONT_WORD_BASE : 9'b0;

// Four banks hold four consecutive font rows. These memories are written by
// the CPU during boot and read by the display on the pixel clock.
(* syn_ramstyle = "block_ram" *) reg [7:0] font_byte0 [0:FONT_WORDS - 1];
(* syn_ramstyle = "block_ram" *) reg [7:0] font_byte1 [0:FONT_WORDS - 1];
(* syn_ramstyle = "block_ram" *) reg [7:0] font_byte2 [0:FONT_WORDS - 1];
(* syn_ramstyle = "block_ram" *) reg [7:0] font_byte3 [0:FONT_WORDS - 1];

reg [7:0] cpu_text_even_char_q;
reg [7:0] cpu_text_even_attr_q;
reg [7:0] cpu_text_odd_char_q;
reg [7:0] cpu_text_odd_attr_q;
reg [7:0] cpu_font_byte0_q;
reg [7:0] cpu_font_byte1_q;
reg [7:0] cpu_font_byte2_q;
reg [7:0] cpu_font_byte3_q;
reg [1:0] cpu_read_select_q;

always @(posedge cpu_clk) begin
    cpu_text_even_char_q <= text_even_char[safe_text_addr];
    cpu_text_even_attr_q <= text_even_attr[safe_text_addr];
    cpu_text_odd_char_q <= text_odd_char[safe_text_addr];
    cpu_text_odd_attr_q <= text_odd_attr[safe_text_addr];
    cpu_font_byte0_q <= font_byte0[safe_font_addr];
    cpu_font_byte1_q <= font_byte1[safe_font_addr];
    cpu_font_byte2_q <= font_byte2[safe_font_addr];
    cpu_font_byte3_q <= font_byte3[safe_font_addr];
    cpu_read_select_q <= text_addr_valid ? 2'b01 :
                         font_addr_valid ? 2'b10 : 2'b00;

    if (cpu_we && text_addr_valid) begin
        if (cpu_wstrb[0]) text_even_char[safe_text_addr] <= cpu_wdata[7:0];
        if (cpu_wstrb[1]) text_even_attr[safe_text_addr] <= cpu_wdata[15:8];
        if (cpu_wstrb[2]) text_odd_char[safe_text_addr]  <= cpu_wdata[23:16];
        if (cpu_wstrb[3]) text_odd_attr[safe_text_addr]  <= cpu_wdata[31:24];
    end
    if (cpu_we && font_addr_valid) begin
        if (cpu_wstrb[0]) font_byte0[safe_font_addr] <= cpu_wdata[7:0];
        if (cpu_wstrb[1]) font_byte1[safe_font_addr] <= cpu_wdata[15:8];
        if (cpu_wstrb[2]) font_byte2[safe_font_addr] <= cpu_wdata[23:16];
        if (cpu_wstrb[3]) font_byte3[safe_font_addr] <= cpu_wdata[31:24];
    end
end

always @(*) begin
    case (cpu_read_select_q)
        2'b01: cpu_rdata = {
            cpu_text_odd_attr_q,
            cpu_text_odd_char_q,
            cpu_text_even_attr_q,
            cpu_text_even_char_q
        };
        2'b10: cpu_rdata = {
            cpu_font_byte3_q,
            cpu_font_byte2_q,
            cpu_font_byte1_q,
            cpu_font_byte0_q
        };
        default: cpu_rdata = 32'b0;
    endcase
end

wire [6:0] text_col = hcnt[9:3];
wire [6:0] text_row = vcnt[9:3];
wire [12:0] extended_text_row = {6'b0, text_row};
wire [12:0] extended_text_col = {6'b0, text_col};
wire [12:0] active_cell_addr = (extended_text_row << 6) +
                                (extended_text_row << 4) + extended_text_col;
wire [12:0] display_cell_addr = de ? active_cell_addr : 13'b0;
wire [11:0] display_word_addr = display_cell_addr[12:1];

reg [7:0] display_even_char_q;
reg [7:0] display_even_attr_q;
reg [7:0] display_odd_char_q;
reg [7:0] display_odd_attr_q;
always @(posedge px_clk) begin
    display_even_char_q <= text_even_char[display_word_addr];
    display_even_attr_q <= text_even_attr[display_word_addr];
    display_odd_char_q <= text_odd_char[display_word_addr];
    display_odd_attr_q <= text_odd_attr[display_word_addr];
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

// Stage 3 aligns the cell attribute and video control signals with font_word_q.
reg [7:0] attr_s3;
reg [2:0] glyph_x_s3;
reg       de_s3, hsync_s3, vsync_s3;

wire [15:0] display_cell = cell_odd_s1 ?
    {display_odd_attr_q, display_odd_char_q} :
    {display_even_attr_q, display_even_char_q};

reg [31:0] font_word_q;
reg [1:0] font_byte_s3;

always @(posedge px_clk) begin
    font_word_q <= {
        font_byte3[font_addr[10:2]],
        font_byte2[font_addr[10:2]],
        font_byte1[font_addr[10:2]],
        font_byte0[font_addr[10:2]]
    };
    font_byte_s3 <= font_addr[1:0];

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

reg [7:0] font_byte;
always @(*) begin
    case (font_byte_s3)
        2'b00: font_byte = font_word_q[7:0];
        2'b01: font_byte = font_word_q[15:8];
        2'b10: font_byte = font_word_q[23:16];
        default: font_byte = font_word_q[31:24];
    endcase
end

wire glyph_pixel = font_byte[7 - glyph_x_s3];
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
