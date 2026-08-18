/*
 * Copyright (c) 2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

`timescale 1ns/1ps

module uart_tx_tb;
    localparam integer BAUD_TICKS = 10;

    reg clk = 0;
    reg rst = 1;
    reg [7:0] data = 0;
    reg [7:0] expected_data = 8'hA5;
    reg start = 0;
    wire busy;
    wire tx;
    integer bit_index;

    always #5 clk = ~clk;

    uart_tx #(
        .CLK_FREQ(100),
        .BAUD_RATE(10)
    ) dut (
        .clk(clk),
        .rst(rst),
        .data(data),
        .start(start),
        .busy(busy),
        .tx(tx)
    );

    task expect_bit;
        input expected;
        begin
            if (tx !== expected)
                $fatal(1, "TX bit mismatch: got %b expected %b", tx, expected);
            repeat (BAUD_TICKS) @(posedge clk);
            #1;
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        rst = 0;
        @(posedge clk);
        #1;
        if (tx !== 1 || busy !== 0)
            $fatal(1, "TX did not reset to idle");

        @(negedge clk);
        data = expected_data;
        start = 1;
        @(posedge clk);
        #1;
        start = 0;
        data = 8'h00;

        if (!busy)
            $fatal(1, "TX busy was not asserted");
        expect_bit(0);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
            expect_bit(expected_data[bit_index]);
        expect_bit(1);

        if (busy !== 0 || tx !== 1)
            $fatal(1, "TX did not return to idle");

        $display("uart_tx_tb: PASS");
        $finish;
    end
endmodule
