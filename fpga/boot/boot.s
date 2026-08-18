; Copyright (c) 2025-2026 Bastiaan van der Plaat
; SPDX-License-Identifier: MIT

.equ STACK_TOP,       0x20001000
.equ CMD_BUF,         0x20000000
.equ CMD_MAX,         255
.equ SECTOR_BUF,      0x20000200
.equ FS_BASE,         0x20000400
.equ FS_PART_LBA,     0
.equ FS_FAT_LBA,      4
.equ FS_DATA_LBA,     8
.equ FS_FAT_SIZE,     12
.equ FS_ROOT_CLUSTER, 16
.equ FS_CWD_CLUSTER,  20
.equ FS_SPC_SHIFT,    24
.equ FS_SPC,          25
.equ FS_FAT_COUNT,    26
.equ FS_READY,        27
.equ FS_CONTROL,      28
.equ CWD_PATH,        0x20000440
.equ NAME_BUF,        0x20000540
.equ VIDEO_STATE,     0x20000580
.equ VIDEO_CURSOR,    0
.equ VIDEO_COLUMN,    4
.equ VIDEO_ROW,       8

.equ UART_TX_DATA,    0x40000000
.equ UART_TX_STATUS,  0x40000004
.equ UART_RX_STATUS,  0x40000008
.equ UART_RX_DATA,    0x4000000C
.equ LED_REG,         0x60000000
.equ VIDEO_BASE,      0x80000000
.equ VIDEO_END,       0x80002580
.equ VIDEO_LAST_ROW,  0x800024e0
.equ VIDEO_COLS,      80
.equ VIDEO_ROWS,      60
.equ VIDEO_ROW_BYTES, 160
.equ VIDEO_BLANK,     0x07200720
.equ SD_DATA,         0xa0000000
.equ SD_STATUS,       0xa0000004
.equ SD_CONTROL,      0xa0000008

_start:
    li sp, STACK_TOP

    ; Clear text video RAM and initialise the cursor.
    li t0, VIDEO_BASE
    li t1, VIDEO_END
    li t2, VIDEO_BLANK
video_clear_loop:
    sw t2, 0(t0)
    addi t0, t0, 4
    blt t0, t1, video_clear_loop
    li t0, VIDEO_STATE
    li t1, VIDEO_BASE
    sw t1, VIDEO_CURSOR(t0)
    sw zero, VIDEO_COLUMN(t0)
    sw zero, VIDEO_ROW(t0)

    li t0, LED_REG
    addi t1, zero, 1
    sw t1, 0(t0)

    la a0, str_banner
    jal ra, print_string

    ; Mount the card once at startup. The shell remains usable if this fails.
    li t0, FS_BASE
    sb zero, FS_READY(t0)
    sw zero, FS_CONTROL(t0)
    li t0, CWD_PATH
    addi t1, zero, 47
    sb t1, 0(t0)
    sb zero, 1(t0)
    jal ra, sd_init
    bne a0, zero, mount_failed
    jal ra, fat_mount
    beq a0, zero, mount_done
mount_failed:
    la a0, str_sd_error
    jal ra, print_string
mount_done:
    li t0, LED_REG
    addi t1, zero, 0x3f
    sw t1, 0(t0)

repl:
    li a0, CWD_PATH
    jal ra, print_string
    la a0, str_prompt
    jal ra, print_string

    li s0, CMD_BUF
    li s1, CMD_BUF

read_loop:
    li t0, UART_RX_STATUS
wait_rx:
    lw t1, 0(t0)
    andi t1, t1, 1
    beq t1, zero, wait_rx

    li t0, UART_RX_DATA
    lbu a0, 0(t0)
    addi t1, zero, 13
    beq a0, t1, enter_pressed
    addi t1, zero, 10
    beq a0, t1, enter_pressed
    addi t1, zero, 8
    beq a0, t1, do_backspace
    addi t1, zero, 127
    beq a0, t1, do_backspace

    sub t2, s0, s1
    addi t3, zero, CMD_MAX
    bge t2, t3, read_loop
    jal ra, print_char
    sb a0, 0(s0)
    addi s0, s0, 1
    j read_loop

do_backspace:
    beq s0, s1, read_loop
    addi s0, s0, -1
    addi a0, zero, 8
    jal ra, print_char
    addi a0, zero, 32
    jal ra, print_char
    addi a0, zero, 8
    jal ra, print_char
    j read_loop

enter_pressed:
    sb zero, 0(s0)
    la a0, str_crlf
    jal ra, print_string

    ; Empty line.
    lbu t0, 0(s1)
    beq t0, zero, repl

    ; char
    addi t1, zero, 99
    bne t0, t1, dispatch_ls
    lbu t0, 1(s1)
    addi t1, zero, 104
    bne t0, t1, dispatch_ls
    lbu t0, 2(s1)
    addi t1, zero, 97
    bne t0, t1, dispatch_ls
    lbu t0, 3(s1)
    addi t1, zero, 114
    bne t0, t1, dispatch_ls
    lbu t0, 4(s1)
    bne t0, zero, dispatch_ls
    jal ra, command_char
    j repl

dispatch_ls:
    lbu t0, 0(s1)
    addi t1, zero, 108
    bne t0, t1, dispatch_cat
    lbu t0, 1(s1)
    addi t1, zero, 115
    bne t0, t1, dispatch_cat
    lbu t0, 2(s1)
    bne t0, zero, dispatch_cat
    jal ra, fs_ls
    j repl

dispatch_cat:
    la a0, prefix_cat
    mv a1, s1
    jal ra, match_prefix
    beq a0, zero, dispatch_cd
    jal ra, fs_cat
    j repl

dispatch_cd:
    la a0, prefix_cd
    mv a1, s1
    jal ra, match_prefix
    beq a0, zero, dispatch_touch
    jal ra, fs_cd
    j repl

dispatch_touch:
    la a0, prefix_touch
    mv a1, s1
    jal ra, match_prefix
    beq a0, zero, dispatch_echo
    jal ra, fs_touch
    j repl

dispatch_echo:
    la a0, prefix_echo
    mv a1, s1
    jal ra, match_prefix
    beq a0, zero, dispatch_format
    jal ra, fs_echo
    j repl

dispatch_format:
    la a0, command_format
    mv a1, s1
    jal ra, string_equal
    beq a0, zero, unknown_command
    jal ra, fat_format
    j repl

unknown_command:
    la a0, str_unknown
    jal ra, print_string
    j repl

; a0 = prefix, a1 = text. Return a0 = text after prefix or zero.
match_prefix:
    mv t0, a0
    mv t1, a1
match_prefix_loop:
    lbu t2, 0(t0)
    beq t2, zero, match_prefix_yes
    lbu t3, 0(t1)
    bne t2, t3, match_prefix_no
    addi t0, t0, 1
    addi t1, t1, 1
    j match_prefix_loop
match_prefix_yes:
    mv a0, t1
    ret
match_prefix_no:
    addi a0, zero, 0
    ret

; a0 and a1 are zero-terminated strings. Return one when equal.
string_equal:
    lbu t0, 0(a0)
    lbu t1, 0(a1)
    bne t0, t1, string_equal_no
    beq t0, zero, string_equal_yes
    addi a0, a0, 1
    addi a1, a1, 1
    j string_equal
string_equal_yes:
    addi a0, zero, 1
    ret
string_equal_no:
    addi a0, zero, 0
    ret

; Display all 256 font glyphs as a 16 x 16 grid.
command_char:
    addi sp, sp, -8
    sw ra, 4(sp)
    sw s8, 0(sp)
    addi s8, zero, 0
command_char_loop:
    mv a0, s8
    jal ra, print_glyph
    addi s8, s8, 1
    andi t0, s8, 15
    bne t0, zero, command_char_next
    la a0, str_crlf
    jal ra, print_string
command_char_next:
    addi t0, zero, 256
    blt s8, t0, command_char_loop
    lw s8, 0(sp)
    lw ra, 4(sp)
    addi sp, sp, 8
    ret

print_string:
    addi sp, sp, -8
    sw s5, 0(sp)
    sw ra, 4(sp)
    mv s5, a0
print_str_loop:
    lbu a0, 0(s5)
    beq a0, zero, print_str_done
    jal ra, print_char
    addi s5, s5, 1
    j print_str_loop
print_str_done:
    lw s5, 0(sp)
    lw ra, 4(sp)
    addi sp, sp, 8
    ret

print_char:
    li t2, UART_TX_DATA
    li t3, UART_TX_STATUS
print_char_wait:
    lw t1, 0(t3)
    andi t1, t1, 1
    bne t1, zero, print_char_wait
    sb a0, 0(t2)

    addi t0, zero, 13
    beq a0, t0, video_carriage_return
    addi t0, zero, 10
    beq a0, t0, video_line_feed
    addi t0, zero, 8
    beq a0, t0, video_backspace

video_write_glyph:
    li t0, 0x0700
    or t0, t0, a0
    li t1, VIDEO_STATE
    lw t2, VIDEO_CURSOR(t1)
    sh t0, 0(t2)
    addi t2, t2, 2
    sw t2, VIDEO_CURSOR(t1)
    lw t2, VIDEO_COLUMN(t1)
    addi t2, t2, 1
    sw t2, VIDEO_COLUMN(t1)
    addi t0, zero, VIDEO_COLS
    blt t2, t0, video_done
    sw zero, VIDEO_COLUMN(t1)
    lw t2, VIDEO_ROW(t1)
    addi t2, t2, 1
    sw t2, VIDEO_ROW(t1)
    j video_check_scroll

print_glyph:
    li t2, UART_TX_DATA
    li t3, UART_TX_STATUS
print_glyph_wait:
    lw t1, 0(t3)
    andi t1, t1, 1
    bne t1, zero, print_glyph_wait
    sb a0, 0(t2)
    j video_write_glyph

video_carriage_return:
    li t0, VIDEO_STATE
    lw t1, VIDEO_COLUMN(t0)
    slli t1, t1, 1
    lw t2, VIDEO_CURSOR(t0)
    sub t2, t2, t1
    sw t2, VIDEO_CURSOR(t0)
    sw zero, VIDEO_COLUMN(t0)
    ret
video_line_feed:
    li t0, VIDEO_STATE
    lw t1, VIDEO_CURSOR(t0)
    addi t1, t1, VIDEO_ROW_BYTES
    sw t1, VIDEO_CURSOR(t0)
    lw t1, VIDEO_ROW(t0)
    addi t1, t1, 1
    sw t1, VIDEO_ROW(t0)
    j video_check_scroll
video_backspace:
    li t0, VIDEO_STATE
    lw t1, VIDEO_COLUMN(t0)
    beq t1, zero, video_done
    addi t1, t1, -1
    sw t1, VIDEO_COLUMN(t0)
    lw t1, VIDEO_CURSOR(t0)
    addi t1, t1, -2
    sw t1, VIDEO_CURSOR(t0)
    ret
video_check_scroll:
    li t1, VIDEO_STATE
    lw t2, VIDEO_ROW(t1)
    addi t0, zero, VIDEO_ROWS
    blt t2, t0, video_done
    li t0, VIDEO_BASE
    addi t1, t0, VIDEO_ROW_BYTES
    li t2, VIDEO_END
video_scroll_loop:
    lw t3, 0(t1)
    sw t3, 0(t0)
    addi t0, t0, 4
    addi t1, t1, 4
    blt t1, t2, video_scroll_loop
    li t1, VIDEO_END
    li t2, VIDEO_BLANK
video_clear_last_row:
    sw t2, 0(t0)
    addi t0, t0, 4
    blt t0, t1, video_clear_last_row
    li t1, VIDEO_STATE
    lw t0, VIDEO_COLUMN(t1)
    slli t0, t0, 1
    li t2, VIDEO_LAST_ROW
    add t2, t2, t0
    sw t2, VIDEO_CURSOR(t1)
    addi t0, zero, 59
    sw t0, VIDEO_ROW(t1)
video_done:
    ret

; Transfer one SPI byte. a0 is both transmitted and received data.
spi_xfer:
    li t0, SD_DATA
    sw a0, 0(t0)
    li t0, SD_STATUS
spi_xfer_wait:
    lw t1, 0(t0)
    andi t1, t1, 1
    bne t1, zero, spi_xfer_wait
    li t0, SD_DATA
    lbu a0, 0(t0)
    ret

sd_deselect:
    addi sp, sp, -4
    sw ra, 0(sp)
    li t0, FS_BASE
    lw t1, FS_CONTROL(t0)
    li t0, SD_CONTROL
    sw t1, 0(t0)
    addi a0, zero, 255
    jal ra, spi_xfer
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

; a0 = command, a1 = argument, a2 = CRC. Return the R1 response.
sd_command:
    addi sp, sp, -20
    sw ra, 16(sp)
    sw s0, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)
    mv s0, a0
    mv s1, a1
    mv s2, a2
    jal ra, sd_deselect
    li t0, FS_BASE
    lw t1, FS_CONTROL(t0)
    ori t1, t1, 1
    li t0, SD_CONTROL
    sw t1, 0(t0)
    ori a0, s0, 0x40
    jal ra, spi_xfer
    srli a0, s1, 24
    jal ra, spi_xfer
    srli a0, s1, 16
    jal ra, spi_xfer
    srli a0, s1, 8
    jal ra, spi_xfer
    mv a0, s1
    jal ra, spi_xfer
    mv a0, s2
    jal ra, spi_xfer
    addi s3, zero, 16
sd_command_response:
    addi a0, zero, 255
    jal ra, spi_xfer
    andi t0, a0, 0x80
    beq t0, zero, sd_command_done
    addi s3, s3, -1
    bne s3, zero, sd_command_response
sd_command_done:
    lw s3, 0(sp)
    lw s2, 4(sp)
    lw s1, 8(sp)
    lw s0, 12(sp)
    lw ra, 16(sp)
    addi sp, sp, 20
    ret

sd_init:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s0, 4(sp)
    sw s1, 0(sp)
    li t0, FS_BASE
    sw zero, FS_CONTROL(t0)
    li t0, SD_CONTROL
    sw zero, 0(t0)
    addi s0, zero, 10
sd_init_clocks:
    addi a0, zero, 255
    jal ra, spi_xfer
    addi s0, s0, -1
    bne s0, zero, sd_init_clocks

    addi a0, zero, 0
    addi a1, zero, 0
    addi a2, zero, 0x95
    jal ra, sd_command
    addi t0, zero, 1
    bne a0, t0, sd_init_fail

    addi a0, zero, 8
    li a1, 0x000001aa
    addi a2, zero, 0x87
    jal ra, sd_command
    addi t0, zero, 1
    bne a0, t0, sd_init_fail
    addi s0, zero, 4
sd_init_r7:
    addi a0, zero, 255
    jal ra, spi_xfer
    mv s1, a0
    addi s0, s0, -1
    bne s0, zero, sd_init_r7
    addi t0, zero, 0xaa
    bne s1, t0, sd_init_fail

    li s0, 4096
sd_init_acmd41:
    addi a0, zero, 55
    addi a1, zero, 0
    addi a2, zero, 255
    jal ra, sd_command
    addi t0, zero, 1
    bltu t0, a0, sd_init_fail
    addi a0, zero, 41
    li a1, 0x40000000
    addi a2, zero, 255
    jal ra, sd_command
    beq a0, zero, sd_init_ready
    addi s0, s0, -1
    bne s0, zero, sd_init_acmd41
    j sd_init_fail

sd_init_ready:
    addi a0, zero, 58
    addi a1, zero, 0
    addi a2, zero, 255
    jal ra, sd_command
    bne a0, zero, sd_init_fail
    addi a0, zero, 255
    jal ra, spi_xfer
    mv s1, a0
    addi s0, zero, 3
sd_init_ocr:
    addi a0, zero, 255
    jal ra, spi_xfer
    addi s0, s0, -1
    bne s0, zero, sd_init_ocr
    andi t0, s1, 0x40
    beq t0, zero, sd_init_fail
    jal ra, sd_deselect
    li t0, FS_BASE
    addi t1, zero, 2
    sw t1, FS_CONTROL(t0)
    li t0, SD_CONTROL
    sw t1, 0(t0)
    addi a0, zero, 0
    j sd_init_exit
sd_init_fail:
    jal ra, sd_deselect
    addi a0, zero, 1
sd_init_exit:
    lw s1, 0(sp)
    lw s0, 4(sp)
    lw ra, 8(sp)
    addi sp, sp, 12
    ret

; a0 = sector LBA, a1 = destination.
sd_read_sector:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)
    sw s2, 0(sp)
    mv s0, a1
    mv a1, a0
    addi a0, zero, 17
    addi a2, zero, 255
    jal ra, sd_command
    bne a0, zero, sd_read_fail
    li s2, 65535
sd_read_token:
    addi a0, zero, 255
    jal ra, spi_xfer
    addi t0, zero, 0xfe
    beq a0, t0, sd_read_data
    addi s2, s2, -1
    bne s2, zero, sd_read_token
    j sd_read_fail
sd_read_data:
    li s1, 512
sd_read_loop:
    addi a0, zero, 255
    jal ra, spi_xfer
    sb a0, 0(s0)
    addi s0, s0, 1
    addi s1, s1, -1
    bne s1, zero, sd_read_loop
    addi a0, zero, 255
    jal ra, spi_xfer
    addi a0, zero, 255
    jal ra, spi_xfer
    jal ra, sd_deselect
    addi a0, zero, 0
    j sd_read_exit
sd_read_fail:
    jal ra, sd_deselect
    addi a0, zero, 1
sd_read_exit:
    lw s2, 0(sp)
    lw s1, 4(sp)
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

; a0 = sector LBA, a1 = source.
sd_write_sector:
    addi sp, sp, -20
    sw ra, 16(sp)
    sw s0, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)
    mv s0, a1
    mv a1, a0
    addi a0, zero, 24
    addi a2, zero, 255
    jal ra, sd_command
    bne a0, zero, sd_write_fail
    addi a0, zero, 255
    jal ra, spi_xfer
    addi a0, zero, 0xfe
    jal ra, spi_xfer
    li s1, 512
sd_write_loop:
    lbu a0, 0(s0)
    jal ra, spi_xfer
    addi s0, s0, 1
    addi s1, s1, -1
    bne s1, zero, sd_write_loop
    addi a0, zero, 255
    jal ra, spi_xfer
    addi a0, zero, 255
    jal ra, spi_xfer
    addi a0, zero, 255
    jal ra, spi_xfer
    andi t0, a0, 0x1f
    addi t1, zero, 5
    bne t0, t1, sd_write_fail
    li s2, 65535
sd_write_busy:
    addi a0, zero, 255
    jal ra, spi_xfer
    addi t0, zero, 255
    beq a0, t0, sd_write_done
    addi s2, s2, -1
    bne s2, zero, sd_write_busy
    j sd_write_fail
sd_write_done:
    jal ra, sd_deselect
    addi a0, zero, 0
    j sd_write_exit
sd_write_fail:
    jal ra, sd_deselect
    addi a0, zero, 1
sd_write_exit:
    lw s3, 0(sp)
    lw s2, 4(sp)
    lw s1, 8(sp)
    lw s0, 12(sp)
    lw ra, 16(sp)
    addi sp, sp, 20
    ret

read_u16:
    lbu t0, 0(a0)
    lbu t1, 1(a0)
    slli t1, t1, 8
    or a0, t0, t1
    ret

read_u32:
    lbu t0, 0(a0)
    lbu t1, 1(a0)
    lbu t2, 2(a0)
    lbu t3, 3(a0)
    slli t1, t1, 8
    slli t2, t2, 16
    slli t3, t3, 24
    or t0, t0, t1
    or t0, t0, t2
    or a0, t0, t3
    ret

; Find a data partition in an MBR or GPT. SECTOR_BUF must contain LBA 0.
; Return a0 = start LBA, a1 = sector count, a2 = MBR entry or zero.
find_partition:
    addi sp, sp, -20
    sw ra, 16(sp)
    sw s0, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)
    li s0, SECTOR_BUF
    addi s0, s0, 446
    addi s1, zero, 4
find_mbr_loop:
    lbu t0, 4(s0)
    addi t1, zero, 0xee
    beq t0, t1, find_gpt
    beq t0, zero, find_mbr_next
    addi a0, s0, 8
    jal ra, read_u32
    mv s2, a0
    addi a0, s0, 12
    jal ra, read_u32
    mv a1, a0
    beq s2, zero, find_mbr_next
    beq a1, zero, find_mbr_next
    mv a0, s2
    mv a2, s0
    j find_partition_exit
find_mbr_next:
    addi s0, s0, 16
    addi s1, s1, -1
    bne s1, zero, find_mbr_loop
    j find_partition_fail

find_gpt:
    addi a0, zero, 1
    li a1, SECTOR_BUF
    jal ra, sd_read_sector
    bne a0, zero, find_partition_fail
    li s0, SECTOR_BUF
    lw t0, 0(s0)
    li t1, 0x20494645
    bne t0, t1, find_partition_fail
    lw t0, 4(s0)
    li t1, 0x54524150
    bne t0, t1, find_partition_fail
    lw a0, 72(s0)
    li a1, SECTOR_BUF
    jal ra, sd_read_sector
    bne a0, zero, find_partition_fail
    li s0, SECTOR_BUF
    addi s1, zero, 4
find_gpt_loop:
    lw t0, 0(s0)
    li t1, 0xebd0a0a2
    bne t0, t1, find_gpt_next
    addi a0, s0, 32
    jal ra, read_u32
    mv s2, a0
    addi a0, s0, 40
    jal ra, read_u32
    sub a1, a0, s2
    addi a1, a1, 1
    mv a0, s2
    addi a2, zero, 0
    j find_partition_exit
find_gpt_next:
    addi s0, s0, 128
    addi s1, s1, -1
    bne s1, zero, find_gpt_loop
find_partition_fail:
    addi a0, zero, 0
    addi a1, zero, 0
    addi a2, zero, 0
find_partition_exit:
    lw s3, 0(sp)
    lw s2, 4(sp)
    lw s1, 8(sp)
    lw s0, 12(sp)
    lw ra, 16(sp)
    addi sp, sp, 20
    ret

fat_mount:
    addi sp, sp, -24
    sw ra, 20(sp)
    sw s0, 16(sp)
    sw s1, 12(sp)
    sw s2, 8(sp)
    sw s3, 4(sp)
    sw s4, 0(sp)
    addi a0, zero, 0
    li a1, SECTOR_BUF
    jal ra, sd_read_sector
    bne a0, zero, fat_mount_fail
    li s0, SECTOR_BUF
    addi a0, s0, 11
    jal ra, read_u16
    addi t0, zero, 512
    beq a0, t0, fat_mount_bpb
    jal ra, find_partition
    mv s1, a0
    beq s1, zero, fat_mount_fail
    mv a0, s1
    li a1, SECTOR_BUF
    jal ra, sd_read_sector
    bne a0, zero, fat_mount_fail
    j fat_mount_parse
fat_mount_bpb:
    addi s1, zero, 0
fat_mount_parse:
    li s0, SECTOR_BUF
    addi a0, s0, 11
    jal ra, read_u16
    addi t0, zero, 512
    bne a0, t0, fat_mount_fail
    lbu s2, 13(s0)
    beq s2, zero, fat_mount_fail
    addi s3, zero, 0
    addi t0, zero, 1
fat_mount_shift:
    beq t0, s2, fat_mount_shift_done
    bltu s2, t0, fat_mount_fail
    slli t0, t0, 1
    addi s3, s3, 1
    j fat_mount_shift
fat_mount_shift_done:
    addi a0, s0, 14
    jal ra, read_u16
    mv s4, a0
    li t0, FS_BASE
    sw s1, FS_PART_LBA(t0)
    sb s3, FS_SPC_SHIFT(t0)
    sb s2, FS_SPC(t0)
    lbu t2, 16(s0)
    beq t2, zero, fat_mount_fail
    sb t2, FS_FAT_COUNT(t0)
    addi a0, s0, 36
    jal ra, read_u32
    beq a0, zero, fat_mount_fail
    li t0, FS_BASE
    sw a0, FS_FAT_SIZE(t0)
    addi a0, s0, 44
    jal ra, read_u32
    li t0, 0x0fffffff
    and t4, a0, t0
    li t0, FS_BASE
    sw t4, FS_ROOT_CLUSTER(t0)
    sw t4, FS_CWD_CLUSTER(t0)
    lw t3, FS_FAT_SIZE(t0)
    lbu t2, FS_FAT_COUNT(t0)
    add t5, s1, s4
    mv t6, t5
    mv t0, t2
fat_mount_data_lba:
    beq t0, zero, fat_mount_store
    add t6, t6, t3
    addi t0, t0, -1
    j fat_mount_data_lba
fat_mount_store:
    li t0, FS_BASE
    sw t5, FS_FAT_LBA(t0)
    sw t6, FS_DATA_LBA(t0)
    addi t1, zero, 1
    sb t1, FS_READY(t0)
    addi a0, zero, 0
    j fat_mount_exit
fat_mount_fail:
    addi a0, zero, 1
fat_mount_exit:
    lw s4, 0(sp)
    lw s3, 4(sp)
    lw s2, 8(sp)
    lw s1, 12(sp)
    lw s0, 16(sp)
    lw ra, 20(sp)
    addi sp, sp, 24
    ret

; a0 = cluster, return its first sector LBA.
cluster_lba:
    addi a0, a0, -2
    li t0, FS_BASE
    lbu t1, FS_SPC_SHIFT(t0)
    sll a0, a0, t1
    lw t1, FS_DATA_LBA(t0)
    add a0, a0, t1
    ret

; a0 = cluster, return next cluster or an EOC value.
fat_next:
    addi sp, sp, -8
    sw ra, 4(sp)
    sw s0, 0(sp)
    mv s0, a0
    srli t0, s0, 7
    li t1, FS_BASE
    lw a0, FS_FAT_LBA(t1)
    add a0, a0, t0
    li a1, SECTOR_BUF
    jal ra, sd_read_sector
    bne a0, zero, fat_next_eoc
    andi t0, s0, 127
    slli t0, t0, 2
    li t1, SECTOR_BUF
    add a0, t1, t0
    jal ra, read_u32
    li t0, 0x0fffffff
    and a0, a0, t0
    j fat_next_exit
fat_next_eoc:
    li a0, 0x0fffffff
fat_next_exit:
    lw s0, 0(sp)
    lw ra, 4(sp)
    addi sp, sp, 8
    ret

; Convert a shell name to an uppercase, space-padded FAT 8.3 name.
; a0 = input, a1 = 11-byte output. Return zero on success.
make_name83:
    mv t0, a0
    mv t1, a1
    addi t2, zero, 11
    addi t3, zero, 32
make_name_clear:
    sb t3, 0(t1)
    addi t1, t1, 1
    addi t2, t2, -1
    bne t2, zero, make_name_clear
    lbu t1, 0(t0)
    addi t2, zero, 46
    bne t1, t2, make_name_regular
    lbu t1, 1(t0)
    bne t1, t2, make_name_regular
    li t1, NAME_BUF
    sb t2, 0(t1)
    sb t2, 1(t1)
    addi a0, zero, 0
    ret
make_name_regular:
    li t1, NAME_BUF
    addi t2, zero, 0
    addi t3, zero, 0
make_name_loop:
    lbu t4, 0(t0)
    beq t4, zero, make_name_done
    addi t5, zero, 47
    beq t4, t5, make_name_done
    addi t5, zero, 46
    beq t4, t5, make_name_dot
    addi t5, zero, 97
    bltu t4, t5, make_name_store
    addi t5, zero, 123
    bgeu t4, t5, make_name_store
    addi t4, t4, -32
make_name_store:
    beq t3, zero, make_name_base
    addi t5, zero, 3
    bgeu t2, t5, make_name_fail
    addi t6, t2, 8
    add t6, t1, t6
    sb t4, 0(t6)
    addi t2, t2, 1
    j make_name_advance
make_name_base:
    addi t5, zero, 8
    bgeu t2, t5, make_name_fail
    add t6, t1, t2
    sb t4, 0(t6)
    addi t2, t2, 1
make_name_advance:
    addi t0, t0, 1
    j make_name_loop
make_name_dot:
    bne t3, zero, make_name_fail
    addi t3, zero, 1
    addi t2, zero, 0
    addi t0, t0, 1
    j make_name_loop
make_name_done:
    addi a0, zero, 0
    ret
make_name_fail:
    addi a0, zero, 1
    ret

; a0 = directory cluster, a1 = FAT name. Return entry pointer and sector LBA.
dir_find:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    sw s3, 12(sp)
    sw s4, 8(sp)
    sw s5, 4(sp)
    sw s6, 0(sp)
    mv s0, a0
    mv s1, a1
dir_find_cluster:
    li t0, 0x0ffffff8
    bgeu s0, t0, dir_find_no
    mv a0, s0
    jal ra, cluster_lba
    mv s3, a0
    li t0, FS_BASE
    lbu s2, FS_SPC(t0)
    addi s4, zero, 0
dir_find_sector:
    add s5, s3, s4
    mv a0, s5
    li a1, SECTOR_BUF
    jal ra, sd_read_sector
    bne a0, zero, dir_find_no
    li s6, SECTOR_BUF
dir_find_entry:
    lbu t0, 0(s6)
    beq t0, zero, dir_find_no
    addi t1, zero, 0xe5
    beq t0, t1, dir_find_next_entry
    lbu t0, 11(s6)
    addi t1, zero, 0x0f
    beq t0, t1, dir_find_next_entry
    andi t0, t0, 8
    bne t0, zero, dir_find_next_entry
    addi t0, zero, 0
dir_find_compare:
    add t1, s6, t0
    lbu t2, 0(t1)
    add t1, s1, t0
    lbu t3, 0(t1)
    bne t2, t3, dir_find_next_entry
    addi t0, t0, 1
    addi t1, zero, 11
    blt t0, t1, dir_find_compare
    mv a0, s6
    mv a1, s5
    j dir_find_exit
dir_find_next_entry:
    addi s6, s6, 32
    li t0, SECTOR_BUF
    addi t0, t0, 512
    bltu s6, t0, dir_find_entry
    addi s4, s4, 1
    bltu s4, s2, dir_find_sector
    mv a0, s0
    jal ra, fat_next
    mv s0, a0
    j dir_find_cluster
dir_find_no:
    addi a0, zero, 0
    addi a1, zero, 0
dir_find_exit:
    lw s6, 0(sp)
    lw s5, 4(sp)
    lw s4, 8(sp)
    lw s3, 12(sp)
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

; Return the first unused directory entry and its sector LBA.
dir_find_free:
    addi sp, sp, -28
    sw ra, 24(sp)
    sw s0, 20(sp)
    sw s1, 16(sp)
    sw s2, 12(sp)
    sw s3, 8(sp)
    sw s4, 4(sp)
    sw s5, 0(sp)
    mv s0, a0
dir_free_cluster:
    li t0, 0x0ffffff8
    bgeu s0, t0, dir_free_no
    mv a0, s0
    jal ra, cluster_lba
    mv s2, a0
    li t0, FS_BASE
    lbu s1, FS_SPC(t0)
    addi s3, zero, 0
dir_free_sector:
    add s4, s2, s3
    mv a0, s4
    li a1, SECTOR_BUF
    jal ra, sd_read_sector
    bne a0, zero, dir_free_no
    li s5, SECTOR_BUF
dir_free_entry:
    lbu t0, 0(s5)
    beq t0, zero, dir_free_yes
    addi t1, zero, 0xe5
    beq t0, t1, dir_free_yes
    addi s5, s5, 32
    li t0, SECTOR_BUF
    addi t0, t0, 512
    bltu s5, t0, dir_free_entry
    addi s3, s3, 1
    bltu s3, s1, dir_free_sector
    mv a0, s0
    jal ra, fat_next
    mv s0, a0
    j dir_free_cluster
dir_free_yes:
    mv a0, s5
    mv a1, s4
    j dir_free_exit
dir_free_no:
    addi a0, zero, 0
    addi a1, zero, 0
dir_free_exit:
    lw s5, 0(sp)
    lw s4, 4(sp)
    lw s3, 8(sp)
    lw s2, 12(sp)
    lw s1, 16(sp)
    lw s0, 20(sp)
    lw ra, 24(sp)
    addi sp, sp, 28
    ret

entry_cluster:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s0, 4(sp)
    sw s1, 0(sp)
    mv s0, a0
    addi a0, s0, 20
    jal ra, read_u16
    slli s1, a0, 16
    addi a0, s0, 26
    jal ra, read_u16
    or a0, a0, s1
    lw s1, 0(sp)
    lw s0, 4(sp)
    lw ra, 8(sp)
    addi sp, sp, 12
    ret

fs_check_ready:
    li t0, FS_BASE
    lbu t0, FS_READY(t0)
    bne t0, zero, fs_ready_yes
    addi sp, sp, -4
    sw ra, 0(sp)
    la a0, str_not_mounted
    jal ra, print_string
    lw ra, 0(sp)
    addi sp, sp, 4
    addi a0, zero, 1
    ret
fs_ready_yes:
    addi a0, zero, 0
    ret

print_entry_name:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s0, 4(sp)
    sw s1, 0(sp)
    mv s0, a0
    addi s1, zero, 0
print_name_base:
    add t0, s0, s1
    lbu a0, 0(t0)
    addi t1, zero, 32
    beq a0, t1, print_name_ext_check
    jal ra, print_char
    addi s1, s1, 1
    addi t0, zero, 8
    blt s1, t0, print_name_base
print_name_ext_check:
    lbu t0, 8(s0)
    addi t1, zero, 32
    beq t0, t1, print_name_dir
    addi a0, zero, 46
    jal ra, print_char
    addi s1, zero, 8
print_name_ext:
    add t0, s0, s1
    lbu a0, 0(t0)
    addi t1, zero, 32
    beq a0, t1, print_name_dir
    jal ra, print_char
    addi s1, s1, 1
    addi t0, zero, 11
    blt s1, t0, print_name_ext
print_name_dir:
    lbu t0, 11(s0)
    andi t0, t0, 0x10
    beq t0, zero, print_name_done
    addi a0, zero, 47
    jal ra, print_char
print_name_done:
    la a0, str_crlf
    jal ra, print_string
    lw s1, 0(sp)
    lw s0, 4(sp)
    lw ra, 8(sp)
    addi sp, sp, 12
    ret

fs_ls:
    addi sp, sp, -28
    sw ra, 24(sp)
    sw s0, 20(sp)
    sw s1, 16(sp)
    sw s2, 12(sp)
    sw s3, 8(sp)
    sw s4, 4(sp)
    sw s5, 0(sp)
    jal ra, fs_check_ready
    bne a0, zero, fs_ls_exit
    li t0, FS_BASE
    lw s0, FS_CWD_CLUSTER(t0)
fs_ls_cluster:
    li t0, 0x0ffffff8
    bgeu s0, t0, fs_ls_exit
    mv a0, s0
    jal ra, cluster_lba
    mv s2, a0
    li t0, FS_BASE
    lbu s1, FS_SPC(t0)
    addi s3, zero, 0
fs_ls_sector:
    add a0, s2, s3
    li a1, SECTOR_BUF
    jal ra, sd_read_sector
    bne a0, zero, fs_io_error
    li s4, SECTOR_BUF
fs_ls_entry:
    lbu t0, 0(s4)
    beq t0, zero, fs_ls_exit
    addi t1, zero, 0xe5
    beq t0, t1, fs_ls_next
    lbu t0, 11(s4)
    addi t1, zero, 0x0f
    beq t0, t1, fs_ls_next
    andi t1, t0, 8
    bne t1, zero, fs_ls_next
    mv a0, s4
    jal ra, print_entry_name
fs_ls_next:
    addi s4, s4, 32
    li t0, SECTOR_BUF
    addi t0, t0, 512
    bltu s4, t0, fs_ls_entry
    addi s3, s3, 1
    bltu s3, s1, fs_ls_sector
    mv a0, s0
    jal ra, fat_next
    mv s0, a0
    j fs_ls_cluster
fs_io_error:
    la a0, str_io_error
    jal ra, print_string
fs_ls_exit:
    lw s5, 0(sp)
    lw s4, 4(sp)
    lw s3, 8(sp)
    lw s2, 12(sp)
    lw s1, 16(sp)
    lw s0, 20(sp)
    lw ra, 24(sp)
    addi sp, sp, 28
    ret

fs_cat:
    addi sp, sp, -24
    sw ra, 20(sp)
    sw s0, 16(sp)
    sw s1, 12(sp)
    sw s2, 8(sp)
    sw s3, 4(sp)
    sw s4, 0(sp)
    mv s4, a0
    jal ra, fs_check_ready
    bne a0, zero, fs_cat_exit
    mv a0, s4
    li a1, NAME_BUF
    jal ra, make_name83
    bne a0, zero, fs_bad_name
    li t0, FS_BASE
    lw a0, FS_CWD_CLUSTER(t0)
    li a1, NAME_BUF
    jal ra, dir_find
    beq a0, zero, fs_not_found
    lbu t0, 11(a0)
    andi t0, t0, 0x10
    bne t0, zero, fs_not_found
    mv s4, a0
    addi a0, s4, 28
    jal ra, read_u32
    mv s1, a0
    mv a0, s4
    jal ra, entry_cluster
    mv s0, a0
fs_cat_cluster:
    beq s1, zero, fs_cat_done
    li t0, 0x0ffffff8
    bgeu s0, t0, fs_cat_done
    mv a0, s0
    jal ra, cluster_lba
    mv s3, a0
    li t0, FS_BASE
    lbu s2, FS_SPC(t0)
fs_cat_sector:
    mv a0, s3
    li a1, SECTOR_BUF
    jal ra, sd_read_sector
    bne a0, zero, fs_io_error_cat
    li s4, SECTOR_BUF
    li t4, 512
fs_cat_byte:
    beq s1, zero, fs_cat_done
    lbu a0, 0(s4)
    jal ra, print_char
    addi s4, s4, 1
    addi s1, s1, -1
    addi t4, t4, -1
    bne t4, zero, fs_cat_byte
    addi s3, s3, 1
    addi s2, s2, -1
    bne s2, zero, fs_cat_sector
    mv a0, s0
    jal ra, fat_next
    mv s0, a0
    j fs_cat_cluster
fs_cat_done:
    la a0, str_crlf
    jal ra, print_string
    j fs_cat_exit
fs_io_error_cat:
    la a0, str_io_error
    jal ra, print_string
    j fs_cat_exit
fs_not_found:
    la a0, str_not_found
    jal ra, print_string
    j fs_cat_exit
fs_bad_name:
    la a0, str_bad_name
    jal ra, print_string
fs_cat_exit:
    lw s4, 0(sp)
    lw s3, 4(sp)
    lw s2, 8(sp)
    lw s1, 12(sp)
    lw s0, 16(sp)
    lw ra, 20(sp)
    addi sp, sp, 24
    ret

fs_cd:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s0, 4(sp)
    sw s1, 0(sp)
    mv s0, a0
    jal ra, fs_check_ready
    bne a0, zero, fs_cd_exit
    lbu t0, 0(s0)
    addi t1, zero, 47
    bne t0, t1, fs_cd_lookup
    lbu t0, 1(s0)
    bne t0, zero, fs_bad_name_cd
    li t0, FS_BASE
    lw t1, FS_ROOT_CLUSTER(t0)
    sw t1, FS_CWD_CLUSTER(t0)
    li t0, CWD_PATH
    addi t1, zero, 47
    sb t1, 0(t0)
    sb zero, 1(t0)
    j fs_cd_exit
fs_cd_lookup:
    mv a0, s0
    li a1, NAME_BUF
    jal ra, make_name83
    bne a0, zero, fs_bad_name_cd
    li t0, FS_BASE
    lw a0, FS_CWD_CLUSTER(t0)
    li a1, NAME_BUF
    jal ra, dir_find
    beq a0, zero, fs_not_found_cd
    lbu t0, 11(a0)
    andi t0, t0, 0x10
    beq t0, zero, fs_not_found_cd
    mv s1, a0
    jal ra, entry_cluster
    bne a0, zero, fs_cd_store
    li t0, FS_BASE
    lw a0, FS_ROOT_CLUSTER(t0)
fs_cd_store:
    li t0, FS_BASE
    sw a0, FS_CWD_CLUSTER(t0)
    lbu t0, 0(s0)
    addi t1, zero, 46
    bne t0, t1, fs_cd_append
    lbu t0, 1(s0)
    bne t0, t1, fs_cd_append
    jal ra, path_pop
    j fs_cd_exit
fs_cd_append:
    mv a0, s0
    jal ra, path_append
    j fs_cd_exit
fs_not_found_cd:
    la a0, str_not_directory
    jal ra, print_string
    j fs_cd_exit
fs_bad_name_cd:
    la a0, str_bad_name
    jal ra, print_string
fs_cd_exit:
    lw s1, 0(sp)
    lw s0, 4(sp)
    lw ra, 8(sp)
    addi sp, sp, 12
    ret

path_append:
    li t0, CWD_PATH
path_append_end:
    lbu t1, 0(t0)
    beq t1, zero, path_append_copy
    addi t0, t0, 1
    j path_append_end
path_append_copy:
    lbu t1, 0(a0)
    beq t1, zero, path_append_slash
    addi t2, zero, 47
    beq t1, t2, path_append_slash
    sb t1, 0(t0)
    addi t0, t0, 1
    addi a0, a0, 1
    j path_append_copy
path_append_slash:
    addi t1, zero, 47
    sb t1, 0(t0)
    sb zero, 1(t0)
    ret

path_pop:
    li t0, CWD_PATH
path_pop_end:
    lbu t1, 0(t0)
    beq t1, zero, path_pop_back
    addi t0, t0, 1
    j path_pop_end
path_pop_back:
    li t1, CWD_PATH
    addi t1, t1, 1
    bgeu t1, t0, path_pop_done
    addi t0, t0, -2
path_pop_scan:
    lbu t2, 0(t0)
    addi t3, zero, 47
    beq t2, t3, path_pop_cut
    addi t0, t0, -1
    j path_pop_scan
path_pop_cut:
    sb zero, 1(t0)
path_pop_done:
    ret

; Create an empty 8.3 entry if it does not already exist.
fs_touch:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s0, 4(sp)
    sw s1, 0(sp)
    mv s0, a0
    jal ra, fs_check_ready
    bne a0, zero, fs_touch_exit
    mv a0, s0
    li a1, NAME_BUF
    jal ra, make_name83
    bne a0, zero, fs_bad_name_touch
    li t0, FS_BASE
    lw s1, FS_CWD_CLUSTER(t0)
    mv a0, s1
    li a1, NAME_BUF
    jal ra, dir_find
    bne a0, zero, fs_touch_exit
    mv a0, s1
    jal ra, dir_find_free
    beq a0, zero, fs_no_space_touch
    mv s0, a0
    mv s1, a1
    addi t0, zero, 32
fs_touch_clear:
    sb zero, 0(s0)
    addi s0, s0, 1
    addi t0, t0, -1
    bne t0, zero, fs_touch_clear
    addi s0, s0, -32
    li t0, NAME_BUF
    addi t1, zero, 11
fs_touch_name:
    lbu t2, 0(t0)
    sb t2, 0(s0)
    addi t0, t0, 1
    addi s0, s0, 1
    addi t1, t1, -1
    bne t1, zero, fs_touch_name
    addi s0, s0, -11
    addi t0, zero, 0x20
    sb t0, 11(s0)
    mv a0, s1
    li a1, SECTOR_BUF
    jal ra, sd_write_sector
    bne a0, zero, fs_io_error_touch
    j fs_touch_exit
fs_bad_name_touch:
    la a0, str_bad_name
    jal ra, print_string
    j fs_touch_exit
fs_no_space_touch:
    la a0, str_no_space
    jal ra, print_string
    j fs_touch_exit
fs_io_error_touch:
    la a0, str_io_error
    jal ra, print_string
fs_touch_exit:
    lw s1, 0(sp)
    lw s0, 4(sp)
    lw ra, 8(sp)
    addi sp, sp, 12
    ret

; Find a free FAT entry, mark it EOC in every FAT, and return its cluster.
fat_alloc:
    addi sp, sp, -28
    sw ra, 24(sp)
    sw s0, 20(sp)
    sw s1, 16(sp)
    sw s2, 12(sp)
    sw s3, 8(sp)
    sw s4, 4(sp)
    sw s5, 0(sp)
    li t0, FS_BASE
    lw s4, FS_FAT_SIZE(t0)
    addi s0, zero, 0
fat_alloc_sector:
    bgeu s0, s4, fat_alloc_fail
    li t0, FS_BASE
    lw a0, FS_FAT_LBA(t0)
    add a0, a0, s0
    li a1, SECTOR_BUF
    jal ra, sd_read_sector
    bne a0, zero, fat_alloc_fail
    addi s1, zero, 0
    bne s0, zero, fat_alloc_entry
    addi s1, zero, 2
fat_alloc_entry:
    addi t0, zero, 128
    bgeu s1, t0, fat_alloc_next_sector
    slli t0, s1, 2
    li t1, SECTOR_BUF
    add t1, t1, t0
    lw t2, 0(t1)
    beq t2, zero, fat_alloc_found
    addi s1, s1, 1
    j fat_alloc_entry
fat_alloc_next_sector:
    addi s0, s0, 1
    j fat_alloc_sector
fat_alloc_found:
    slli s5, s0, 7
    add s5, s5, s1
    li t2, 0x0fffffff
    sw t2, 0(t1)
    li t0, FS_BASE
    lw s2, FS_FAT_LBA(t0)
    add s2, s2, s0
    lbu s3, FS_FAT_COUNT(t0)
fat_alloc_write:
    mv a0, s2
    li a1, SECTOR_BUF
    jal ra, sd_write_sector
    bne a0, zero, fat_alloc_fail
    add s2, s2, s4
    addi s3, s3, -1
    bne s3, zero, fat_alloc_write
    mv a0, s5
    j fat_alloc_exit
fat_alloc_fail:
    addi a0, zero, 0
fat_alloc_exit:
    lw s5, 0(sp)
    lw s4, 4(sp)
    lw s3, 8(sp)
    lw s2, 12(sp)
    lw s1, 16(sp)
    lw s0, 20(sp)
    lw ra, 24(sp)
    addi sp, sp, 28
    ret

; echo text > file, limited to one 512-byte sector and 8.3 names.
fs_echo:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    sw s3, 12(sp)
    sw s4, 8(sp)
    sw s5, 4(sp)
    sw s6, 0(sp)
    mv s0, a0
    jal ra, fs_check_ready
    bne a0, zero, fs_echo_exit
    mv t0, s0
fs_echo_parse:
    lbu t1, 0(t0)
    beq t1, zero, fs_echo_usage
    addi t2, zero, 32
    bne t1, t2, fs_echo_parse_next
    lbu t1, 1(t0)
    addi t2, zero, 62
    bne t1, t2, fs_echo_parse_next
    lbu t1, 2(t0)
    addi t2, zero, 32
    beq t1, t2, fs_echo_split
fs_echo_parse_next:
    addi t0, t0, 1
    j fs_echo_parse
fs_echo_split:
    sb zero, 0(t0)
    sub s1, t0, s0
    addi s2, t0, 3
    mv a0, s2
    li a1, NAME_BUF
    jal ra, make_name83
    bne a0, zero, fs_bad_name_echo
    li t0, FS_BASE
    lw s3, FS_CWD_CLUSTER(t0)
    mv a0, s3
    li a1, NAME_BUF
    jal ra, dir_find
    addi s6, zero, 0
    bne a0, zero, fs_echo_have_entry
    mv a0, s3
    jal ra, dir_find_free
    beq a0, zero, fs_no_space_echo
    addi s6, zero, 1
fs_echo_have_entry:
    li t0, SECTOR_BUF
    sub s4, a0, t0
    mv s5, a1
    beq s6, zero, fs_echo_existing_cluster
    addi s3, zero, 0
    j fs_echo_need_cluster
fs_echo_existing_cluster:
    lbu t0, 11(a0)
    andi t0, t0, 0x10
    bne t0, zero, fs_bad_name_echo
    jal ra, entry_cluster
    mv s3, a0
fs_echo_need_cluster:
    bne s3, zero, fs_echo_fill
    jal ra, fat_alloc
    beq a0, zero, fs_no_space_echo
    mv s3, a0
fs_echo_fill:
    li t0, SECTOR_BUF
    li t1, 512
fs_echo_clear:
    sb zero, 0(t0)
    addi t0, t0, 1
    addi t1, t1, -1
    bne t1, zero, fs_echo_clear
    li t0, SECTOR_BUF
    mv t1, s0
    mv t2, s1
fs_echo_copy:
    beq t2, zero, fs_echo_write_data
    lbu t3, 0(t1)
    sb t3, 0(t0)
    addi t0, t0, 1
    addi t1, t1, 1
    addi t2, t2, -1
    j fs_echo_copy
fs_echo_write_data:
    mv a0, s3
    jal ra, cluster_lba
    li a1, SECTOR_BUF
    jal ra, sd_write_sector
    bne a0, zero, fs_io_error_echo
    mv a0, s5
    li a1, SECTOR_BUF
    jal ra, sd_read_sector
    bne a0, zero, fs_io_error_echo
    li t0, SECTOR_BUF
    add s4, t0, s4
    beq s6, zero, fs_echo_update_entry
    mv t0, s4
    addi t1, zero, 32
fs_echo_clear_entry:
    sb zero, 0(t0)
    addi t0, t0, 1
    addi t1, t1, -1
    bne t1, zero, fs_echo_clear_entry
    li t0, NAME_BUF
    mv t1, s4
    addi t2, zero, 11
fs_echo_copy_name:
    lbu t3, 0(t0)
    sb t3, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    addi t2, t2, -1
    bne t2, zero, fs_echo_copy_name
    addi t0, zero, 0x20
    sb t0, 11(s4)
fs_echo_update_entry:
    srli t0, s3, 16
    sh t0, 20(s4)
    sh s3, 26(s4)
    sw s1, 28(s4)
    mv a0, s5
    li a1, SECTOR_BUF
    jal ra, sd_write_sector
    bne a0, zero, fs_io_error_echo
    j fs_echo_exit
fs_echo_usage:
    la a0, str_echo_usage
    jal ra, print_string
    j fs_echo_exit
fs_bad_name_echo:
    la a0, str_bad_name
    jal ra, print_string
    j fs_echo_exit
fs_no_space_echo:
    la a0, str_no_space
    jal ra, print_string
    j fs_echo_exit
fs_io_error_echo:
    la a0, str_io_error
    jal ra, print_string
fs_echo_exit:
    lw s6, 0(sp)
    lw s5, 4(sp)
    lw s4, 8(sp)
    lw s3, 12(sp)
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

; Clear the shared 512-byte sector buffer.
clear_sector:
    li t0, SECTOR_BUF
    addi t1, zero, 512
clear_sector_loop:
    sb zero, 0(t0)
    addi t0, t0, 1
    addi t1, t1, -1
    bne t1, zero, clear_sector_loop
    ret

; Copy a2 bytes from a0 to a1.
copy_bytes:
    beq a2, zero, copy_bytes_done
copy_bytes_loop:
    lbu t0, 0(a0)
    sb t0, 0(a1)
    addi a0, a0, 1
    addi a1, a1, 1
    addi a2, a2, -1
    bne a2, zero, copy_bytes_loop
copy_bytes_done:
    ret

; Unsigned a0 / a1. Return the quotient in a0.
udiv32:
    addi t0, zero, 0
    addi t1, zero, 1
udiv32_align:
    li t2, 0x80000000
    and t2, a1, t2
    bne t2, zero, udiv32_loop
    slli t2, a1, 1
    bltu a0, t2, udiv32_loop
    mv a1, t2
    slli t1, t1, 1
    j udiv32_align
udiv32_loop:
    bltu a0, a1, udiv32_skip
    sub a0, a0, a1
    or t0, t0, t1
udiv32_skip:
    srli a1, a1, 1
    srli t1, t1, 1
    bne t1, zero, udiv32_loop
    mv a0, t0
    ret

; Destructively format the first MBR/GPT data partition as FAT32.
; The exact command name is deliberately "format FAT32".
fat_format:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    sw s3, 12(sp)
    sw s4, 8(sp)
    sw s5, 4(sp)
    sw s6, 0(sp)
    la a0, str_formatting
    jal ra, print_string
    addi a0, zero, 0
    li a1, SECTOR_BUF
    jal ra, sd_read_sector
    bne a0, zero, fat_format_fail
    jal ra, find_partition
    mv s0, a0
    mv s1, a1
    mv s6, a2
    beq s0, zero, fat_format_no_partition
    li t0, 66600
    bltu s1, t0, fat_format_too_small

    ; Turn a legacy MBR partition into FAT32 LBA before overwriting it.
    beq s6, zero, fat_format_choose_spc
    addi t0, zero, 0x0c
    sb t0, 4(s6)
    addi a0, zero, 0
    li a1, SECTOR_BUF
    jal ra, sd_write_sector
    bne a0, zero, fat_format_fail

fat_format_choose_spc:
    addi s2, zero, 64
    li t0, 67108864
    bltu t0, s1, fat_format_spc_done
    addi s2, zero, 32
    li t0, 33554432
    bltu t0, s1, fat_format_spc_done
    addi s2, zero, 16
    li t0, 16777216
    bltu t0, s1, fat_format_spc_done
    addi s2, zero, 8
    li t0, 532480
    bltu t0, s1, fat_format_spc_done
    addi s2, zero, 1
fat_format_spc_done:
    ; FAT sectors = ceil((total - 32) / (128 * sectors/cluster + 2)).
    slli a1, s2, 7
    addi a1, a1, 2
    addi a0, s1, -32
    addi t0, a1, -1
    add a0, a0, t0
    jal ra, udiv32
    mv s3, a0
    beq s3, zero, fat_format_fail

    ; Primary and backup FAT32 boot sectors.
    jal ra, clear_sector
    li t0, SECTOR_BUF
    addi t1, zero, 0xeb
    sb t1, 0(t0)
    addi t1, zero, 0x58
    sb t1, 1(t0)
    addi t1, zero, 0x90
    sb t1, 2(t0)
    la a0, fat_oem
    addi a1, t0, 3
    addi a2, zero, 8
    jal ra, copy_bytes
    li t0, SECTOR_BUF
    sb zero, 11(t0)
    addi t1, zero, 2
    sb t1, 12(t0)
    sb s2, 13(t0)
    addi t1, zero, 32
    sh t1, 14(t0)
    addi t1, zero, 2
    sb t1, 16(t0)
    addi t1, zero, 0xf8
    sb t1, 21(t0)
    addi t1, zero, 63
    sh t1, 24(t0)
    addi t1, zero, 255
    sh t1, 26(t0)
    sw s0, 28(t0)
    sw s1, 32(t0)
    sw s3, 36(t0)
    addi t1, zero, 2
    sw t1, 44(t0)
    addi t1, zero, 1
    sh t1, 48(t0)
    addi t1, zero, 6
    sh t1, 50(t0)
    addi t1, zero, 0x80
    sb t1, 64(t0)
    addi t1, zero, 0x29
    sb t1, 66(t0)
    addi t1, zero, 0x52
    sb t1, 67(t0)
    addi t1, zero, 0x48
    sb t1, 68(t0)
    addi t1, zero, 0x41
    sb t1, 69(t0)
    addi t1, zero, 0x5a
    sb t1, 70(t0)
    la a0, fat_label
    li a1, SECTOR_BUF
    addi a1, a1, 71
    addi a2, zero, 11
    jal ra, copy_bytes
    la a0, fat_type
    li a1, SECTOR_BUF
    addi a1, a1, 82
    addi a2, zero, 8
    jal ra, copy_bytes
    li t0, SECTOR_BUF
    li t1, 0xaa55
    sh t1, 510(t0)
    mv a0, s0
    li a1, SECTOR_BUF
    jal ra, sd_write_sector
    bne a0, zero, fat_format_fail
    addi a0, s0, 6
    li a1, SECTOR_BUF
    jal ra, sd_write_sector
    bne a0, zero, fat_format_fail

    ; Primary and backup FSInfo sectors. Unknown free count is valid.
    jal ra, clear_sector
    li t0, SECTOR_BUF
    li t1, 0x41615252
    sw t1, 0(t0)
    li t1, 0x61417272
    sw t1, 484(t0)
    addi t1, zero, -1
    sw t1, 488(t0)
    addi t1, zero, 3
    sw t1, 492(t0)
    li t1, 0xaa550000
    sw t1, 508(t0)
    addi a0, s0, 1
    li a1, SECTOR_BUF
    jal ra, sd_write_sector
    bne a0, zero, fat_format_fail
    addi a0, s0, 7
    li a1, SECTOR_BUF
    jal ra, sd_write_sector
    bne a0, zero, fat_format_fail

    ; Clear both FATs and reserve clusters 0, 1, and root cluster 2.
    addi s4, s0, 32
    addi s5, zero, 2
fat_format_fat:
    mv s6, s3
fat_format_fat_sector:
    jal ra, clear_sector
    bne s6, s3, fat_format_write_fat
    li t0, SECTOR_BUF
    li t1, 0x0ffffff8
    sw t1, 0(t0)
    addi t1, zero, -1
    sw t1, 4(t0)
    li t1, 0x0fffffff
    sw t1, 8(t0)
fat_format_write_fat:
    mv a0, s4
    li a1, SECTOR_BUF
    jal ra, sd_write_sector
    bne a0, zero, fat_format_fail
    addi s4, s4, 1
    addi s6, s6, -1
    bne s6, zero, fat_format_fat_sector
    addi s5, s5, -1
    bne s5, zero, fat_format_fat

    ; s4 now points at root cluster 2. Clear every sector in it.
    mv s5, s2
fat_format_root:
    jal ra, clear_sector
    mv a0, s4
    li a1, SECTOR_BUF
    jal ra, sd_write_sector
    bne a0, zero, fat_format_fail
    addi s4, s4, 1
    addi s5, s5, -1
    bne s5, zero, fat_format_root

    jal ra, fat_mount
    bne a0, zero, fat_format_fail
    li t0, CWD_PATH
    addi t1, zero, 47
    sb t1, 0(t0)
    sb zero, 1(t0)
    la a0, str_format_done
    jal ra, print_string
    j fat_format_exit
fat_format_no_partition:
    la a0, str_format_partition
    jal ra, print_string
    j fat_format_exit
fat_format_too_small:
    la a0, str_format_small
    jal ra, print_string
    j fat_format_exit
fat_format_fail:
    la a0, str_io_error
    jal ra, print_string
fat_format_exit:
    lw s6, 0(sp)
    lw s5, 4(sp)
    lw s4, 8(sp)
    lw s3, 12(sp)
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

str_banner:        .asciz "Zaheer REPL\r\n"
str_prompt:        .asciz "$ "
str_crlf:          .asciz "\r\n"
str_sd_error:      .asciz "SD/FAT32 mount failed\r\n"
str_not_mounted:   .asciz "SD card not mounted\r\n"
str_unknown:       .asciz "Unknown command\r\n"
str_not_found:     .asciz "File not found\r\n"
str_not_directory: .asciz "Directory not found\r\n"
str_bad_name:      .asciz "Use an 8.3 name\r\n"
str_no_space:      .asciz "No free directory entry or cluster\r\n"
str_io_error:      .asciz "SD card I/O error\r\n"
str_echo_usage:    .asciz "Usage: echo text > file.txt\r\n"
str_formatting:     .asciz "Formatting FAT32...\r\n"
str_format_done:    .asciz "Format complete\r\n"
str_format_partition: .asciz "Format needs an MBR/GPT data partition\r\n"
str_format_small:   .asciz "Partition too small for FAT32\r\n"
prefix_cat:        .asciz "cat "
prefix_cd:         .asciz "cd "
prefix_touch:      .asciz "touch "
prefix_echo:       .asciz "echo "
command_format:    .asciz "format FAT32"
fat_oem:           .ascii "ZAHEER  "
fat_label:         .ascii "ZAHEER     "
fat_type:          .ascii "FAT32   "
