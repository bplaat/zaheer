/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

module top(
    input clk,
    output [5:0] led
);

localparam WAIT_TIME = 13500000;

reg [23:0] clock_counter = 0;
reg [5:0] led_counter = 0;

always @(posedge clk) begin
    clock_counter <= clock_counter + 1;
    if (clock_counter == WAIT_TIME) begin
        clock_counter <= 0;
        led_counter <= led_counter + 1;
    end
end

assign led = ~led_counter;

endmodule
