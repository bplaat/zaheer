/*
 * Copyright (c) 2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

`timescale 1ns/1ps

module uart_rx_tb;
    localparam integer BAUD_TICKS = 10;

    reg clk = 0;
    reg rst = 1;
    reg rx = 1;
    wire data_ready;
    wire framing_error;
    wire [7:0] data;
    integer ready_count = 0;
    integer error_count = 0;

    always #5 clk = ~clk;

    uart_rx #(
        .CLK_FREQ(100),
        .BAUD_RATE(10)
    ) dut (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .data_ready(data_ready),
        .framing_error(framing_error),
        .data(data)
    );

    always @(posedge clk) begin
        if (data_ready)
            ready_count <= ready_count + 1;
        if (framing_error)
            error_count <= error_count + 1;
    end

    task send_bit;
        input value;
        begin
            rx = value;
            repeat (BAUD_TICKS) @(negedge clk);
        end
    endtask

    task send_byte;
        input [7:0] value;
        input stop_bit;
        integer index;
        begin
            send_bit(0);
            for (index = 0; index < 8; index = index + 1)
                send_bit(value[index]);
            send_bit(stop_bit);
            rx = 1;
            repeat (3) @(negedge clk);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        rst = 0;
        repeat (3) @(negedge clk);

        send_byte(8'h3C, 1);
        if (ready_count !== 1 || data !== 8'h3C || error_count !== 0)
            $fatal(1, "Valid RX frame was not decoded correctly");

        // A short low pulse must be rejected as a false start.
        rx = 0;
        repeat (2) @(negedge clk);
        rx = 1;
        repeat (BAUD_TICKS) @(negedge clk);
        if (ready_count !== 1 || error_count !== 0)
            $fatal(1, "False start produced an RX event");

        send_byte(8'h55, 0);
        if (ready_count !== 1 || error_count !== 1)
            $fatal(1, "Invalid stop bit did not produce a framing error");

        $display("uart_rx_tb: PASS");
        $finish;
    end
endmodule
