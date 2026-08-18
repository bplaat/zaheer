`timescale 1ns/1ps

module boot_tb;
reg clk = 0;
reg rst = 1;
wire [31:0] mem_addr;
wire [31:0] mem_wdata;
reg [31:0] mem_rdata;
wire mem_we;
wire mem_re;
wire [3:0] mem_wstrb;

cpu dut(
    .clk(clk),
    .rst(rst),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata),
    .mem_we(mem_we),
    .mem_re(mem_re),
    .mem_wstrb(mem_wstrb)
);

always #5 clk = ~clk;

reg [31:0] rom [0:4095];
reg [7:0] ram [0:4095];
reg [7:0] disk [0:599999];
reg [7:0] sd_queue [0:1023];
reg [7:0] sd_command [0:5];
integer sd_queue_head = 0;
integer sd_queue_tail = 0;
integer sd_command_index = 0;
integer sd_write_state = 0;
integer sd_write_count = 0;
integer sd_write_lba = 0;
reg sd_selected = 0;
reg sd_initialized = 0;
reg [7:0] sd_rx = 8'hff;
reg [1:0] sd_control = 0;

reg [7:0] uart_rx_data = 0;
reg uart_rx_ready = 0;
reg [31:0] uart_shift = 0;
integer prompt_count = 0;
integer uart_count = 0;
reg [7:0] uart_log [0:4095];

integer i;

task disk_u16;
    input integer offset;
    input [15:0] value;
    begin
        disk[offset] = value[7:0];
        disk[offset + 1] = value[15:8];
    end
endtask

task disk_u32;
    input integer offset;
    input [31:0] value;
    begin
        disk[offset] = value[7:0];
        disk[offset + 1] = value[15:8];
        disk[offset + 2] = value[23:16];
        disk[offset + 3] = value[31:24];
    end
endtask

task queue_byte;
    input [7:0] value;
    begin
        sd_queue[sd_queue_tail] = value;
        sd_queue_tail = sd_queue_tail + 1;
    end
endtask

task execute_sd_command;
    integer command_number;
    integer argument;
    integer offset;
    begin
        command_number = sd_command[0] & 8'h3f;
        argument = (sd_command[1] << 24) | (sd_command[2] << 16) |
                   (sd_command[3] << 8) | sd_command[4];
        case (command_number)
            0: queue_byte(8'h01);
            8: begin
                queue_byte(8'h01);
                queue_byte(8'h00);
                queue_byte(8'h00);
                queue_byte(8'h01);
                queue_byte(8'haa);
            end
            55: queue_byte(sd_initialized ? 8'h00 : 8'h01);
            41: begin
                sd_initialized = 1;
                queue_byte(8'h00);
            end
            58: begin
                queue_byte(8'h00);
                queue_byte(8'hc0);
                queue_byte(8'hff);
                queue_byte(8'h80);
                queue_byte(8'h00);
            end
            17: begin
                queue_byte(8'h00);
                queue_byte(8'hff);
                queue_byte(8'hfe);
                offset = argument * 512;
                for (i = 0; i < 512; i = i + 1)
                    queue_byte(disk[offset + i]);
                queue_byte(8'hff);
                queue_byte(8'hff);
            end
            24: begin
                queue_byte(8'h00);
                sd_write_lba = argument;
                sd_write_state = 1;
                sd_write_count = 0;
            end
            default: queue_byte(8'h04);
        endcase
    end
endtask

task spi_transfer;
    input [7:0] tx;
    output [7:0] rx;
    begin
        rx = 8'hff;
        if (!sd_selected) begin
            sd_command_index = 0;
        end else if (sd_queue_head < sd_queue_tail) begin
            rx = sd_queue[sd_queue_head];
            sd_queue_head = sd_queue_head + 1;
            if (sd_queue_head == sd_queue_tail) begin
                sd_queue_head = 0;
                sd_queue_tail = 0;
            end
        end else if (sd_write_state == 1) begin
            if (tx == 8'hfe)
                sd_write_state = 2;
        end else if (sd_write_state == 2) begin
            disk[sd_write_lba * 512 + sd_write_count] = tx;
            sd_write_count = sd_write_count + 1;
            if (sd_write_count == 512) begin
                sd_write_state = 3;
                sd_write_count = 0;
            end
        end else if (sd_write_state == 3) begin
            sd_write_count = sd_write_count + 1;
            if (sd_write_count == 2) begin
                sd_write_state = 0;
                queue_byte(8'h05);
                queue_byte(8'h00);
                queue_byte(8'hff);
            end
        end else if (sd_command_index != 0 || tx[7:6] == 2'b01) begin
            sd_command[sd_command_index] = tx;
            sd_command_index = sd_command_index + 1;
            if (sd_command_index == 6) begin
                sd_command_index = 0;
                execute_sd_command;
            end
        end
    end
endtask

task send_byte;
    input [7:0] value;
    begin
        while (uart_rx_ready) @(posedge clk);
        @(negedge clk);
        uart_rx_data = value;
        uart_rx_ready = 1;
        while (uart_rx_ready) @(posedge clk);
    end
endtask

task send_line;
    input [8 * 32 - 1:0] text;
    input integer length;
    integer index;
    begin
        for (index = 0; index < length; index = index + 1)
            send_byte(text[8 * (length - index) - 1 -: 8]);
        send_byte(8'h0d);
    end
endtask

always @(*) begin
    mem_rdata = 32'b0;
    case (mem_addr[31:28])
        4'h0: mem_rdata = rom[mem_addr[13:2]];
        4'h2: mem_rdata = {ram[{mem_addr[11:2], 2'b11}],
                           ram[{mem_addr[11:2], 2'b10}],
                           ram[{mem_addr[11:2], 2'b01}],
                           ram[{mem_addr[11:2], 2'b00}]};
        4'h4: begin
            case (mem_addr[3:2])
                2'b01: mem_rdata = 0;
                2'b10: mem_rdata = uart_rx_ready;
                2'b11: mem_rdata = uart_rx_data;
                default: mem_rdata = 0;
            endcase
        end
        4'ha: begin
            case (mem_addr[3:2])
                2'b00: mem_rdata = sd_rx;
                2'b01: mem_rdata = 0;
                2'b10: mem_rdata = sd_control;
                default: mem_rdata = 0;
            endcase
        end
    endcase
end

always @(posedge clk) begin
    if (mem_we && mem_addr[31:28] == 4'h2) begin
        if (mem_wstrb[0]) ram[{mem_addr[11:2], 2'b00}] <= mem_wdata[7:0];
        if (mem_wstrb[1]) ram[{mem_addr[11:2], 2'b01}] <= mem_wdata[15:8];
        if (mem_wstrb[2]) ram[{mem_addr[11:2], 2'b10}] <= mem_wdata[23:16];
        if (mem_wstrb[3]) ram[{mem_addr[11:2], 2'b11}] <= mem_wdata[31:24];
    end

    if (mem_we && mem_addr == 32'h40000000) begin
        uart_log[uart_count] <= mem_wdata[7:0];
        uart_count <= uart_count + 1;
        uart_shift <= {uart_shift[23:0], mem_wdata[7:0]};
        if ({uart_shift[23:0], mem_wdata[7:0]} == 32'h2f202420)
            prompt_count <= prompt_count + 1;
    end
    if (mem_re && mem_addr == 32'h4000000c)
        uart_rx_ready <= 0;

    if (mem_we && mem_addr == 32'ha0000008) begin
        sd_control <= mem_wdata[1:0];
        sd_selected <= mem_wdata[0];
        if (!mem_wdata[0]) begin
            sd_command_index = 0;
            sd_queue_head = 0;
            sd_queue_tail = 0;
        end
    end
    if (mem_we && mem_addr == 32'ha0000000)
        spi_transfer(mem_wdata[7:0], sd_rx);
end

initial begin
    $readmemh("target/boot.mem", rom);
    for (i = 0; i < 32; i = i + 1)
        dut.regs[i] = 0;
    for (i = 0; i < 4096; i = i + 1)
        ram[i] = 0;
    for (i = 0; i < 600000; i = i + 1)
        disk[i] = 0;

    // Legacy MBR with FAT32 in partition entry two, starting at LBA 1.
    disk[462 + 4] = 8'h0c;
    disk_u32(462 + 8, 1);
    disk_u32(462 + 12, 16);
    disk[510] = 8'h55; disk[511] = 8'haa;
    disk_u16(512 + 11, 512);
    disk[512 + 13] = 1;
    disk_u16(512 + 14, 1);
    disk[512 + 16] = 1;
    disk_u32(512 + 32, 16);
    disk_u32(512 + 36, 1);
    disk_u32(512 + 44, 2);
    disk[512 + 82] = "F"; disk[512 + 83] = "A"; disk[512 + 84] = "T";
    disk[512 + 85] = "3"; disk[512 + 86] = "2";
    disk[512 + 510] = 8'h55; disk[512 + 511] = 8'haa;

    disk_u32(1024 + 0, 32'h0ffffff8);
    disk_u32(1024 + 4, 32'h0fffffff);
    disk_u32(1024 + 8, 32'h0fffffff);
    disk_u32(1024 + 12, 32'h0fffffff);
    disk_u32(1024 + 16, 32'h0fffffff);

    // Root directory, cluster 2 / sector 3.
    {disk[1536], disk[1537], disk[1538], disk[1539], disk[1540],
     disk[1541], disk[1542], disk[1543], disk[1544], disk[1545],
     disk[1546]} = "HELLO      ";
    disk[1536 + 11] = 8'h10;
    disk_u16(1536 + 26, 3);
    {disk[1568], disk[1569], disk[1570], disk[1571], disk[1572],
     disk[1573], disk[1574], disk[1575], disk[1576], disk[1577],
     disk[1578]} = "README  TXT";
    disk[1568 + 11] = 8'h20;
    disk_u16(1568 + 26, 4);
    disk_u32(1568 + 28, 5);

    // HELLO directory, cluster 3 / sector 4.
    disk[2048] = "."; disk[2049] = " "; disk[2050] = " ";
    disk[2051] = " "; disk[2052] = " "; disk[2053] = " ";
    disk[2054] = " "; disk[2055] = " "; disk[2056] = " ";
    disk[2057] = " "; disk[2058] = " ";
    disk[2048 + 11] = 8'h10;
    disk_u16(2048 + 26, 3);
    disk[2080] = "."; disk[2081] = ".";
    for (i = 2082; i < 2091; i = i + 1) disk[i] = " ";
    disk[2080 + 11] = 8'h10;
    disk_u16(2080 + 26, 2);

    // README.TXT, cluster 4 / sector 5.
    disk[2560] = "h"; disk[2561] = "e"; disk[2562] = "l";
    disk[2563] = "l"; disk[2564] = "o";

    repeat (5) @(posedge clk);
    @(negedge clk);
    rst = 0;

    wait (prompt_count == 1);
    send_line("ls", 2);
    wait (prompt_count == 2);
    send_line("cat README.TXT", 14);
    wait (prompt_count == 3);
    send_line("cd HELLO/", 9);
    wait (prompt_count == 4);
    send_line("touch FILE.X", 12);
    wait (prompt_count == 5);
    send_line("echo hoi > TEST.TXT", 19);
    wait (prompt_count == 6);
    send_line("ls", 2);
    wait (prompt_count == 7);
    send_line("cat TEST.TXT", 12);
    wait (prompt_count == 8);
    send_line("cd ..", 5);
    wait (prompt_count == 9);

    if ({disk[2112], disk[2113], disk[2114], disk[2115], disk[2116],
         disk[2117], disk[2118], disk[2119], disk[2120], disk[2121],
         disk[2122]} != "FILE    X  ")
        $fatal(1, "touch did not create FILE.X");
    if ({disk[2144], disk[2145], disk[2146], disk[2147], disk[2148],
         disk[2149], disk[2150], disk[2151], disk[2152], disk[2153],
         disk[2154]} != "TEST    TXT")
        $fatal(1, "echo did not create TEST.TXT");
    if ({disk[3072], disk[3073], disk[3074]} != "hoi")
        $fatal(1, "echo wrote incorrect file data");
    if ({disk[1024 + 23], disk[1024 + 22], disk[1024 + 21], disk[1024 + 20]} != 32'h0fffffff)
        $fatal(1, "echo did not allocate cluster 5");

    // Reformat the MBR partition and validate the BPB, FSInfo, FATs, and root.
    disk_u32(462 + 12, 66600);
    send_line("format FAT32", 12);
    wait (prompt_count == 10);
    if (disk[462 + 4] != 8'h0c)
        $fatal(1, "format did not set the FAT32 LBA partition type");
    if ({disk[512 + 12], disk[512 + 11]} != 16'd512 || disk[512 + 13] != 1)
        $fatal(1, "format wrote an invalid sector or cluster size");
    if ({disk[512 + 39], disk[512 + 38], disk[512 + 37], disk[512 + 36]} != 32'd513)
        $fatal(1, "format wrote an incorrect FAT size");
    if ({disk[512 + 35], disk[512 + 34], disk[512 + 33], disk[512 + 32]} != 32'd66600)
        $fatal(1, "format wrote an incorrect volume size");
    if ({disk[512 + 511], disk[512 + 510]} != 16'haa55)
        $fatal(1, "format omitted the boot signature");
    if ({disk[1024 + 3], disk[1024 + 2], disk[1024 + 1], disk[1024]} != 32'h41615252)
        $fatal(1, "format wrote an invalid FSInfo sector");
    if ({disk[16896 + 11], disk[16896 + 10], disk[16896 + 9], disk[16896 + 8]} != 32'h0fffffff)
        $fatal(1, "format did not reserve root cluster 2 in FAT 1");
    if ({disk[279552 + 11], disk[279552 + 10], disk[279552 + 9], disk[279552 + 8]} != 32'h0fffffff)
        $fatal(1, "format did not reserve root cluster 2 in FAT 2");
    if (disk[542208] != 0)
        $fatal(1, "format did not clear the root directory");

    $display("boot_tb: PASS");
    $finish;
end

initial begin
    repeat (100000000) @(posedge clk);
    $display("pc=%08x instr=%08x state=%0d mem_addr=%08x uart_count=%0d", dut.pc, dut.instr, dut.state, mem_addr, uart_count);
    $display("t0=%08x t1=%08x t2=%08x s2=%08x s3=%0d s4=%0d sp=%08x", dut.regs[5], dut.regs[6], dut.regs[7], dut.regs[18], dut.regs[19], dut.regs[20], dut.regs[2]);
    $display("sector buffer: %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x attr=%02x next=%02x", ram[512], ram[513], ram[514], ram[515], ram[516], ram[517], ram[518], ram[519], ram[520], ram[521], ram[522], ram[523], ram[544]);
    $display("fs: fat=%0d data=%0d root=%0d cwd=%0d spc=%0d ready=%0d", {ram[1031],ram[1030],ram[1029],ram[1028]}, {ram[1035],ram[1034],ram[1033],ram[1032]}, {ram[1043],ram[1042],ram[1041],ram[1040]}, {ram[1047],ram[1046],ram[1045],ram[1044]}, ram[1049], ram[1051]);
    for (i = (uart_count > 64 ? uart_count - 64 : 0); i < uart_count; i = i + 1)
        $write("%c", uart_log[i]);
    $display("");
    $fatal(1, "boot test timed out; prompts=%0d", prompt_count);
end
endmodule
