/*
 * Copyright (c) 2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

`timescale 1ns/1ps

module tmds_encoder_tb;
    reg clk = 0;
    reg resetn = 0;
    reg de = 0;
    reg [1:0] ctrl = 0;
    reg [7:0] din = 0;
    wire [9:0] dout;

    reg [9:0] expected_previous = 10'b1101010100;
    integer disparity = 0;
    integer index;
    reg [7:0] samples [0:9];

    always #5 clk = ~clk;

    tmds_encoder dut (
        .clk(clk),
        .resetn(resetn),
        .de(de),
        .ctrl(ctrl),
        .din(din),
        .dout(dout)
    );

    function integer count_ones;
        input [7:0] value;
        integer bit_index;
        begin
            count_ones = 0;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                count_ones = count_ones + value[bit_index];
        end
    endfunction

    task reference_symbol;
        input symbol_de;
        input [1:0] symbol_ctrl;
        input [7:0] symbol_data;
        output [9:0] symbol;
        reg [8:0] transition;
        integer ones;
        integer zeros;
        integer bit_index;
        begin
            if (!symbol_de) begin
                disparity = 0;
                case (symbol_ctrl)
                    2'b00: symbol = 10'b1101010100;
                    2'b01: symbol = 10'b0010101011;
                    2'b10: symbol = 10'b0101010100;
                    default: symbol = 10'b1010101011;
                endcase
            end else begin
                transition[0] = symbol_data[0];
                if (count_ones(symbol_data) > 4 ||
                    (count_ones(symbol_data) == 4 && !symbol_data[0])) begin
                    for (bit_index = 1; bit_index < 8; bit_index = bit_index + 1)
                        transition[bit_index] = transition[bit_index - 1] ^~ symbol_data[bit_index];
                    transition[8] = 0;
                end else begin
                    for (bit_index = 1; bit_index < 8; bit_index = bit_index + 1)
                        transition[bit_index] = transition[bit_index - 1] ^ symbol_data[bit_index];
                    transition[8] = 1;
                end

                ones = count_ones(transition[7:0]);
                zeros = 8 - ones;
                if (disparity == 0 || ones == zeros) begin
                    symbol = {~transition[8], transition[8],
                              transition[8] ? transition[7:0] : ~transition[7:0]};
                    disparity = disparity + (transition[8] ? ones - zeros : zeros - ones);
                end else if ((disparity > 0 && ones > zeros) ||
                             (disparity < 0 && zeros > ones)) begin
                    symbol = {1'b1, transition[8], ~transition[7:0]};
                    disparity = disparity + zeros - ones + (transition[8] ? 2 : 0);
                end else begin
                    symbol = {1'b0, transition[8], transition[7:0]};
                    disparity = disparity + ones - zeros - (transition[8] ? 0 : 2);
                end
            end
        end
    endtask

    task apply_symbol;
        input symbol_de;
        input [1:0] symbol_ctrl;
        input [7:0] symbol_data;
        reg [9:0] expected_next;
        begin
            reference_symbol(symbol_de, symbol_ctrl, symbol_data, expected_next);
            @(negedge clk);
            de = symbol_de;
            ctrl = symbol_ctrl;
            din = symbol_data;
            @(posedge clk);
            #1;
            if (dout !== expected_previous)
                $fatal(1, "TMDS mismatch: got %010b expected %010b", dout, expected_previous);
            expected_previous = expected_next;
        end
    endtask

    initial begin
        samples[0] = 8'h00;
        samples[1] = 8'hFF;
        samples[2] = 8'h55;
        samples[3] = 8'hAA;
        samples[4] = 8'h0F;
        samples[5] = 8'hF0;
        samples[6] = 8'h81;
        samples[7] = 8'h7E;
        samples[8] = 8'h18;
        samples[9] = 8'hE7;

        repeat (2) @(posedge clk);
        #1;
        if (dout !== 10'b1101010100)
            $fatal(1, "TMDS reset token mismatch");
        resetn = 1;

        apply_symbol(0, 2'b00, 0);
        apply_symbol(0, 2'b01, 0);
        apply_symbol(0, 2'b10, 0);
        apply_symbol(0, 2'b11, 0);
        for (index = 0; index < 10; index = index + 1)
            apply_symbol(1, 0, samples[index]);
        apply_symbol(0, 2'b00, 0);
        apply_symbol(1, 0, 8'h33);
        apply_symbol(1, 0, 8'hCC);
        apply_symbol(0, 2'b11, 0);
        apply_symbol(0, 2'b00, 0);

        $display("tmds_encoder_tb: PASS");
        $finish;
    end
endmodule
