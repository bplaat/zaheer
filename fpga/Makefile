BOARD=tangnano9k
FAMILY=GW1N-9C
DEVICE=GW1NR-LV9QN88PC6/I5

CC=cc
TARGET=target

all: $(TARGET)/top.fs

$(TARGET):
	mkdir -p $(TARGET)

# Assembler tool
$(TARGET)/asm: ../tools/asm.c | $(TARGET)
	$(CC) -Wall -Wextra -std=c99 -O2 -o $@ $<

# Boot firmware
$(TARGET)/boot.mem: boot/boot.s $(TARGET)/asm | $(TARGET)
	$(TARGET)/asm $< $@

# Synthesis
$(TARGET)/top.json: top.v cpu.v uart_tx.v uart_rx.v hdmi.v $(TARGET)/boot.mem | $(TARGET)
	yosys -p "read_verilog top.v; synth_gowin -top top -json $@"

# Place and Route
$(TARGET)/top_pnr.json: $(TARGET)/top.json | $(TARGET)
	nextpnr-himbaechel --json $< --freq 27 --write $@ --device $(DEVICE) --vopt family=$(FAMILY) --vopt cst=$(BOARD).cst

# Generate Bitstream
$(TARGET)/top.fs: $(TARGET)/top_pnr.json | $(TARGET)
	gowin_pack -d $(FAMILY) -o $@ $<

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
