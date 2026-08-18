/*
 * Copyright (c) 2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

`timescale 1ns/1ps

module text_mode_tb;
    reg cpu_clk = 0;
    reg cpu_we = 0;
    reg [11:0] cpu_addr = 0;
    reg [31:0] cpu_wdata = 0;
    reg [3:0] cpu_wstrb = 0;
    wire [31:0] cpu_rdata;

    reg px_clk = 0;
    reg px_reset = 1;
    reg [9:0] hcnt = 0;
    reg [9:0] vcnt = 0;
    reg de = 0;
    reg hsync = 1;
    reg vsync = 1;
    wire [7:0] px_r, px_g, px_b;
    wire de_out, hsync_out, vsync_out;

    integer color_index;

    always #5 cpu_clk = ~cpu_clk;
    always #7 px_clk = ~px_clk;

    text_mode dut(
        .cpu_clk(cpu_clk),
        .cpu_we(cpu_we),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_wstrb(cpu_wstrb),
        .cpu_rdata(cpu_rdata),
        .px_clk(px_clk),
        .px_reset(px_reset),
        .hcnt(hcnt),
        .vcnt(vcnt),
        .de(de),
        .hsync(hsync),
        .vsync(vsync),
        .px_r(px_r),
        .px_g(px_g),
        .px_b(px_b),
        .de_out(de_out),
        .hsync_out(hsync_out),
        .vsync_out(vsync_out)
    );

    function [23:0] palette;
        input [3:0] index;
        begin
            case (index)
                4'h0: palette = 24'h000000;
                4'h1: palette = 24'h0000AA;
                4'h2: palette = 24'h00AA00;
                4'h3: palette = 24'h00AAAA;
                4'h4: palette = 24'hAA0000;
                4'h5: palette = 24'hAA00AA;
                4'h6: palette = 24'hAA5500;
                4'h7: palette = 24'hAAAAAA;
                4'h8: palette = 24'h555555;
                4'h9: palette = 24'h5555FF;
                4'hA: palette = 24'h55FF55;
                4'hB: palette = 24'h55FFFF;
                4'hC: palette = 24'hFF5555;
                4'hD: palette = 24'hFF55FF;
                4'hE: palette = 24'hFFFF55;
                default: palette = 24'hFFFFFF;
            endcase
        end
    endfunction

    task cpu_write;
        input [11:0] addr;
        input [31:0] data;
        input [3:0] strobes;
        begin
            @(negedge cpu_clk);
            cpu_addr = addr;
            cpu_wdata = data;
            cpu_wstrb = strobes;
            cpu_we = 1;
            @(posedge cpu_clk);
            #1;
            cpu_we = 0;
            cpu_wstrb = 0;
        end
    endtask

    task cpu_expect;
        input [11:0] addr;
        input [31:0] expected;
        begin
            @(negedge cpu_clk);
            cpu_addr = addr;
            @(posedge cpu_clk);
            #1;
            if (cpu_rdata !== expected) begin
                $display("CPU read mismatch at %0d: got %08x expected %08x",
                         addr, cpu_rdata, expected);
                $fatal(1);
            end
        end
    endtask

    task pixel_expect;
        input [9:0] x;
        input [9:0] y;
        input [23:0] expected;
        begin
            hcnt = x;
            vcnt = y;
            de = 1;
            hsync = 1;
            vsync = 1;
            repeat (6) @(posedge px_clk);
            #1;
            if ({px_r, px_g, px_b} !== expected || !de_out) begin
                $display("Pixel mismatch at (%0d,%0d): got %06x expected %06x de=%b",
                         x, y, {px_r, px_g, px_b}, expected, de_out);
                $fatal(1);
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge px_clk);
        px_reset = 0;

        // Two adjacent cells and all four byte lanes.
        cpu_write(0, 32'h4CDB1F41, 4'b1111);
        cpu_expect(0, 32'h4CDB1F41);
        cpu_write(0, 32'h12345678, 4'b0101);
        cpu_expect(0, 32'h4C341F78);

        // Restore 'A' and a solid block. Row zero of 'A' is 00111000.
        cpu_write(0, 32'h4CDB1F41, 4'b1111);
        pixel_expect(0, 0, 24'h0000AA);
        pixel_expect(2, 0, 24'hFFFFFF);
        pixel_expect(8, 0, 24'hFF5555);

        // Exercise every foreground palette entry with the solid glyph.
        for (color_index = 0; color_index < 16; color_index = color_index + 1) begin
            cpu_write(1, {16'b0, 4'h0, color_index[3:0], 8'hDB}, 4'b0011);
            pixel_expect(16, 0, palette(color_index[3:0]));
        end

        // Exercise every background palette entry with the blank glyph.
        for (color_index = 0; color_index < 16; color_index = color_index + 1) begin
            cpu_write(1, {16'b0, color_index[3:0], 4'h0, 8'h20}, 4'b0011);
            pixel_expect(16, 0, palette(color_index[3:0]));
        end

        // Out-of-range accesses read zero and cannot alias valid word zero.
        cpu_write(2400, 32'hDEADBEEF, 4'b1111);
        cpu_expect(2400, 32'h00000000);
        cpu_expect(0, 32'h4CDB1F41);

        // Last framebuffer cell: word 2399, odd half, pixel (639,479).
        cpu_write(2399, 32'h0CDB0000, 4'b1111);
        cpu_expect(2399, 32'h0CDB0000);
        pixel_expect(639, 479, 24'hFF5555);

        // Blanking and sync controls travel through the same pipeline.
        de = 0;
        hsync = 0;
        vsync = 0;
        repeat (6) @(posedge px_clk);
        #1;
        if (de_out !== 0 || hsync_out !== 0 || vsync_out !== 0)
            $fatal(1, "Video control pipeline mismatch");

        $display("text_mode_tb: PASS");
        $finish;
    end
endmodule
