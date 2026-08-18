/*
 * Copyright (c) 2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

`timescale 1ns/1ps

module uart_tb;
    localparam integer BAUD_TICKS = 10;

    reg clk = 0;
    reg rst = 1;
    reg [1:0] addr = 0;
    reg [31:0] wdata = 0;
    reg we = 0;
    reg re = 0;
    reg rx = 1;
    wire [31:0] rdata;
    wire tx;

    always #5 clk = ~clk;

    uart #(
        .CLK_FREQ(100),
        .BAUD_RATE(10)
    ) dut (
        .clk(clk),
        .rst(rst),
        .addr(addr),
        .wdata(wdata),
        .we(we),
        .re(re),
        .rdata(rdata),
        .rx(rx),
        .tx(tx)
    );

    task write_tx;
        input [7:0] value;
        begin
            @(negedge clk);
            addr = 0;
            wdata = {24'b0, value};
            we = 1;
            @(posedge clk);
            #1;
            we = 0;
        end
    endtask

    task send_bit;
        input value;
        begin
            rx = value;
            repeat (BAUD_TICKS) @(negedge clk);
        end
    endtask

    task send_byte;
        input [7:0] value;
        integer index;
        begin
            send_bit(0);
            for (index = 0; index < 8; index = index + 1)
                send_bit(value[index]);
            send_bit(1);
            rx = 1;
            repeat (3) @(negedge clk);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        rst = 0;
        repeat (2) @(posedge clk);

        write_tx(8'hA6);
        addr = 1;
        #1;
        if (rdata !== 32'h00000001 || tx !== 0)
            $fatal(1, "TX did not start: status=%08x tx=%b", rdata, tx);
        repeat (BAUD_TICKS * 10) @(posedge clk);
        #1;
        if (rdata !== 0 || tx !== 1)
            $fatal(1, "TX status did not return to idle");

        send_byte(8'h12);
        addr = 2;
        #1;
        if (rdata !== 32'h00000001)
            $fatal(1, "RX ready status was not set");
        addr = 3;
        #1;
        if (rdata !== 32'h00000012)
            $fatal(1, "RX data register mismatch");

        // Receiving again before reading reports overrun and keeps the latest byte.
        send_byte(8'h34);
        addr = 2;
        #1;
        if (rdata !== 32'h00000003)
            $fatal(1, "RX overrun status was not set");
        addr = 3;
        #1;
        if (rdata !== 32'h00000034)
            $fatal(1, "RX buffer did not contain the latest byte");

        re = 1;
        @(posedge clk);
        #1;
        re = 0;
        addr = 2;
        #1;
        if (rdata !== 0)
            $fatal(1, "Reading RX data did not clear status");

        $display("uart_tb: PASS");
        $finish;
    end
endmodule
