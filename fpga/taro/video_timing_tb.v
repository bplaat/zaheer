/*
 * Copyright (c) 2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

`timescale 1ns/1ps

module video_timing_tb;
    localparam integer H_TOTAL = 10;
    localparam integer V_TOTAL = 7;

    reg clk = 0;
    reg reset = 1;
    wire [9:0] hcnt;
    wire [9:0] vcnt;
    wire de;
    wire hsync;
    wire vsync;
    integer frame;
    integer x;
    integer y;

    always #5 clk = ~clk;

    video_timing #(
        .H_ACTIVE(4), .H_FP(2), .H_SYNC(3), .H_BP(1),
        .V_ACTIVE(3), .V_FP(1), .V_SYNC(2), .V_BP(1)
    ) dut (
        .clk(clk),
        .reset(reset),
        .hcnt(hcnt),
        .vcnt(vcnt),
        .de(de),
        .hsync(hsync),
        .vsync(vsync)
    );

    task expect_timing;
        input integer expected_x;
        input integer expected_y;
        reg expected_de;
        reg expected_hsync;
        reg expected_vsync;
        begin
            expected_de = expected_x < 4 && expected_y < 3;
            expected_hsync = !(expected_x >= 6 && expected_x < 9);
            expected_vsync = !(expected_y >= 4 && expected_y < 6);
            if (hcnt !== expected_x || vcnt !== expected_y ||
                de !== expected_de || hsync !== expected_hsync ||
                vsync !== expected_vsync) begin
                $fatal(1, "Timing mismatch at (%0d,%0d): got (%0d,%0d) de=%b hs=%b vs=%b",
                       expected_x, expected_y, hcnt, vcnt, de, hsync, vsync);
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        #1;
        expect_timing(0, 0);
        reset = 0;

        for (frame = 0; frame < 2; frame = frame + 1) begin
            for (y = 0; y < V_TOTAL; y = y + 1) begin
                for (x = 0; x < H_TOTAL; x = x + 1) begin
                    expect_timing(x, y);
                    @(posedge clk);
                    #1;
                end
            end
        end

        expect_timing(0, 0);
        $display("video_timing_tb: PASS");
        $finish;
    end
endmodule
