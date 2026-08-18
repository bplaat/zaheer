BOARD=tangnano9k
FAMILY=GW1N-9C
DEVICE=GW1NR-LV9QN88PC6/I5

CC=cc
TARGET=target

all: $(TARGET)/top.fs

.PHONY: build
build: $(TARGET)/top.fs

$(TARGET):
	mkdir -p $(TARGET)

# Assembler tool
$(TARGET)/asm: ../tools/asm.c | $(TARGET)
	$(CC) -Wall -Wextra -std=c99 -O2 -o $@ $<

# Boot firmware
$(TARGET)/boot.mem: boot/boot.s $(TARGET)/asm | $(TARGET)
	$(TARGET)/asm $< $@

# Convert the raw 256 x 8-byte font to one hexadecimal byte per line.
$(TARGET)/taro_font.mem: taro/font.pf | $(TARGET)
	test $$(wc -c < $<) -eq 2048
	xxd -p -c 1 $< > $@

# Synthesis
$(TARGET)/top.json: top.v cpu.v uart_tx.v uart_rx.v taro/taro.v taro/text_mode.v taro/hdmi.v $(TARGET)/boot.mem $(TARGET)/taro_font.mem | $(TARGET)
	yosys -p "read_verilog top.v; synth_gowin -no-rw-check -top top -json $@"

# Place and Route
$(TARGET)/top_pnr.json: $(TARGET)/top.json nextpnr_constraints.py | $(TARGET)
	nextpnr-himbaechel --json $< --freq 27 --write $@ --device $(DEVICE) --vopt family=$(FAMILY) --vopt cst=$(BOARD).cst --pre-place nextpnr_constraints.py

# Generate Bitstream
$(TARGET)/top.fs: $(TARGET)/top_pnr.json | $(TARGET)
	gowin_pack -d $(FAMILY) -o $@ $<

# Tests
$(TARGET)/text_mode_tb: taro/text_mode_tb.v taro/text_mode.v $(TARGET)/taro_font.mem | $(TARGET)
	iverilog -g2012 -s text_mode_tb -o $@ taro/text_mode_tb.v taro/text_mode.v

.PHONY: test
test: $(TARGET)/text_mode_tb
	vvp $(TARGET)/text_mode_tb

# Actions
.PHONY: load
load: $(TARGET)/top.fs
	openFPGALoader -b $(BOARD) $<

.PHONY: flash
flash: $(TARGET)/top.fs
	openFPGALoader -b $(BOARD) $< -f

.PHONY: serial
serial:
	picocom -b 115200 /dev/tty.usbserial-1101

.PHONY: clean
clean:
	rm -rf $(TARGET)
