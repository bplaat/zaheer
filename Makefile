BOARD=tangnano9k
FAMILY=GW1N-9C
DEVICE=GW1NR-LV9QN88PC6/I5

CC=cc
TARGET=target
FPGA=fpga
VERILOG_FLAGS=-I$(FPGA)
BOOT_ROOT=boot/boot.s
BOOT_SOURCES=$(wildcard boot/*.s)
ASM_TEST_SOURCES=$(wildcard tools/asm_test/*.s tools/asm_test/*/*.s)

all: $(TARGET)/top.fs

.PHONY: build
build: $(TARGET)/top.fs

$(TARGET):
	mkdir -p $(TARGET)

# Assembler tool
$(TARGET)/asm: tools/asm.c | $(TARGET)
	$(CC) -Wall -Wextra -std=c99 -O2 -o $@ $<

# Boot firmware
$(TARGET)/boot.mem: $(BOOT_SOURCES) $(TARGET)/asm | $(TARGET)
	$(TARGET)/asm $(BOOT_ROOT) $@

# Convert the raw 256 x 8-byte font to one hexadecimal byte per line.
$(TARGET)/taro_font.mem: $(FPGA)/taro/font.pf | $(TARGET)
	test $$(wc -c < $<) -eq 2048
	xxd -p -c 1 $< > $@

# Synthesis
$(TARGET)/top.json: $(FPGA)/top.v $(FPGA)/cpu.v $(FPGA)/uart/uart.v $(FPGA)/uart/uart_tx.v $(FPGA)/uart/uart_rx.v $(FPGA)/taro/taro.v $(FPGA)/taro/text_mode.v $(FPGA)/taro/hdmi.v $(TARGET)/boot.mem $(TARGET)/taro_font.mem | $(TARGET)
	yosys -p "read_verilog $(VERILOG_FLAGS) $(FPGA)/top.v; synth_gowin -no-rw-check -top top -json $@"

# Place and Route
$(TARGET)/top_pnr.json: $(TARGET)/top.json $(FPGA)/nextpnr_constraints.py $(FPGA)/$(BOARD).cst | $(TARGET)
	nextpnr-himbaechel --json $< --freq 27 --write $@ --device $(DEVICE) --vopt family=$(FAMILY) --vopt cst=$(FPGA)/$(BOARD).cst --pre-place $(FPGA)/nextpnr_constraints.py

# Generate Bitstream
$(TARGET)/top.fs: $(TARGET)/top_pnr.json | $(TARGET)
	gowin_pack -d $(FAMILY) -o $@ $<

# Tests
$(TARGET)/asm_test.mem: $(ASM_TEST_SOURCES) $(TARGET)/asm | $(TARGET)
	$(TARGET)/asm tools/asm_test/main.s $@

$(TARGET)/text_mode_tb: $(FPGA)/taro/text_mode_tb.v $(FPGA)/taro/text_mode.v $(TARGET)/taro_font.mem | $(TARGET)
	iverilog -g2012 $(VERILOG_FLAGS) -s text_mode_tb -o $@ $(FPGA)/taro/text_mode_tb.v $(FPGA)/taro/text_mode.v

$(TARGET)/uart_tx_tb: $(FPGA)/uart/uart_tx_tb.v $(FPGA)/uart/uart_tx.v | $(TARGET)
	iverilog -g2012 $(VERILOG_FLAGS) -s uart_tx_tb -o $@ $^

$(TARGET)/uart_rx_tb: $(FPGA)/uart/uart_rx_tb.v $(FPGA)/uart/uart_rx.v | $(TARGET)
	iverilog -g2012 $(VERILOG_FLAGS) -s uart_rx_tb -o $@ $^

$(TARGET)/uart_tb: $(FPGA)/uart/uart_tb.v $(FPGA)/uart/uart.v $(FPGA)/uart/uart_tx.v $(FPGA)/uart/uart_rx.v | $(TARGET)
	iverilog -g2012 $(VERILOG_FLAGS) -s uart_tb -o $@ $^

.PHONY: test
test: $(TARGET)/asm_test.mem $(TARGET)/text_mode_tb $(TARGET)/uart_tx_tb $(TARGET)/uart_rx_tb $(TARGET)/uart_tb
	test "$$(sed -n '1p' $(TARGET)/asm_test.mem)" = 02a00513
	test "$$(sed -n '2p' $(TARGET)/asm_test.mem)" = 00700593
	vvp $(TARGET)/text_mode_tb
	vvp $(TARGET)/uart_tx_tb
	vvp $(TARGET)/uart_rx_tb
	vvp $(TARGET)/uart_tb

# Actions
.PHONY: load
load: $(TARGET)/top.fs
	openFPGALoader -b $(BOARD) $<

.PHONY: flash
flash: $(TARGET)/top.fs
	openFPGALoader -b $(BOARD) $< -f

.PHONY: serial
serial:
	picocom -b 115200 /dev/tty.usbserial-11101

.PHONY: clean
clean:
	rm -rf $(TARGET)
