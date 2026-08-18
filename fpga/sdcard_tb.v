`timescale 1ns/1ps

module sdcard_tb;
reg clk = 0;
reg rst = 1;
reg we = 0;
reg [1:0] addr = 0;
reg [31:0] wdata = 0;
wire [31:0] rdata;
wire sd_clk;
wire sd_mosi;
reg sd_miso = 1;
wire sd_cs;

sdcard dut(
    .clk(clk),
    .rst(rst),
    .we(we),
    .addr(addr),
    .wdata(wdata),
    .rdata(rdata),
    .sd_clk(sd_clk),
    .sd_mosi(sd_mosi),
    .sd_miso(sd_miso),
    .sd_cs(sd_cs)
);

always #5 clk = ~clk;

task write_reg;
    input [1:0] reg_addr;
    input [31:0] value;
    begin
        @(negedge clk);
        addr = reg_addr;
        wdata = value;
        we = 1;
        @(negedge clk);
        we = 0;
    end
endtask

integer tx_bits;
integer cycles;
reg [7:0] captured_tx;
reg [7:0] response;

always @(posedge sd_clk) begin
    captured_tx = {captured_tx[6:0], sd_mosi};
    tx_bits = tx_bits + 1;
end

always @(negedge sd_clk) begin
    if (tx_bits < 8)
        sd_miso = response[7 - tx_bits];
end

initial begin
    repeat (3) @(posedge clk);
    rst = 0;

    write_reg(2'b10, 32'b11);
    if (sd_cs !== 0) $fatal(1, "CS was not asserted");

    response = 8'h3C;
    sd_miso = response[7];
    captured_tx = 0;
    tx_bits = 0;
    cycles = 0;
    write_reg(2'b00, 8'hA5);
    addr = 2'b01;
    while (rdata[0]) begin
        @(posedge clk);
        cycles = cycles + 1;
    end
    if (tx_bits != 8) $fatal(1, "expected 8 SPI clock pulses");
    if (captured_tx != 8'hA5) $fatal(1, "wrong transmitted byte");
    addr = 2'b00;
    #1;
    if (rdata[7:0] != response) $fatal(1, "wrong received byte");
    if (cycles > 20) $fatal(1, "fast transfer took too long");

    write_reg(2'b10, 0);
    if (sd_cs !== 1) $fatal(1, "CS was not released");

    $display("sdcard_tb: PASS");
    $finish;
end
endmodule
