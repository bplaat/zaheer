/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

module memory (
    input wire clk,
    input wire [31:0] addr,
    input wire read,
    output reg [31:0] read_data,
    input wire [3:0] write_mask,
    input wire [31:0] write_data
);
    // 1024 * 4 = 4 KiB
    reg [31:0] mem [0:1023];

    initial begin
        $readmemh("boot.mem", mem);
    end

    wire [29:0] word_addr = addr[31:2];

    always @(posedge clk) begin
        if (read)
            read_data <= mem[word_addr];

        if (|write_mask) begin
            if (write_mask[0]) mem[word_addr][7:0] <= write_data[7:0];
            if (write_mask[1]) mem[word_addr][15:8] <= write_data[15:8];
            if (write_mask[2]) mem[word_addr][23:16] <= write_data[23:16];
            if (write_mask[3]) mem[word_addr][31:24] <= write_data[31:24];
        end
    end
endmodule
