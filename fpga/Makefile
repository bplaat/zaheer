BOARD=tangnano9k
FAMILY=GW1N-9C
DEVICE=GW1NR-LV9QN88PC6/I5

all: top.fs

# Boot firmware
boot/boot.bin: boot/boot.s
	nasm -f bin boot/boot.s -o boot/boot.bin

boot.mem: boot/boot.bin
	hexdump -v -e '1/1 "%02x\n"' boot/boot.bin > boot.mem

# Synthesis
top.json: top.v uart_tx.v boot.mem
	yosys -p "read_verilog top.v; synth_gowin -top top -json top.json"

# Place and Route
.INTERMEDIATE: top.json
top_pnr.json: top.json
	nextpnr-himbaechel --json top.json --freq 27 --write top_pnr.json --device ${DEVICE} --vopt family=${FAMILY} --vopt cst=${BOARD}.cst

# Generate Bitstream
.INTERMEDIATE: top_pnr.json
top.fs: top_pnr.json
	gowin_pack -d ${FAMILY} -o top.fs top_pnr.json

# Program Board
.PHONY: load
load: top.fs
	openFPGALoader -b ${BOARD} top.fs

.PHONY: flash
flash: top.fs
	openFPGALoader -b ${BOARD} top.fs -f
