BOARD=tangnano9k
FAMILY=GW1N-9C
DEVICE=GW1NR-LV9QN88PC6/I5

all: top.fs

# Boot firmware
boot/boot.bin: boot/start.s boot/main.c
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o boot/start.o boot/start.s
	riscv64-unknown-elf-gcc -Os -march=rv32i -mabi=ilp32 -c -o boot/main.o boot/main.c
	riscv64-unknown-elf-ld -m elf32lriscv -T boot/link.ld -o boot/boot.elf boot/start.o boot/main.o
	riscv64-unknown-elf-objcopy -O binary boot/boot.elf boot/boot.bin

boot.mem: boot/boot.bin
	hexdump -v -e '1/4 "%08x" "\n"' boot/boot.bin > boot.mem

# Synthesis
top.json: top.v uart_tx.v memory.v cpu.v boot.mem
	yosys -p "read_verilog top.v; synth_gowin -top top -json top.json"

# Place and Route
.INTERMEDIATE: top.json
top_pnr.json: top.json
	nextpnr-himbaechel --json top.json --freq 27 --write top_pnr.json --device ${DEVICE} --vopt family=${FAMILY} --vopt cst=${BOARD}.cst

# Generate Bitstream
.INTERMEDIATE: top_pnr.json
top.fs: top_pnr.json
	gowin_pack -d ${FAMILY} -o top.fs top_pnr.json

# Actions
.PHONY: load
load: top.fs
	openFPGALoader -b ${BOARD} top.fs

.PHONY: flash
flash: top.fs
	openFPGALoader -b ${BOARD} top.fs -f

.PHONY: serial
serial:
	picocom -b 115200 /dev/tty.usbserial-11101

.PHONY: boot
boot: boot/boot.bin
	riscv64-unknown-elf-objdump -D boot/boot.elf
	riscv64-unknown-elf-objdump -b binary -m riscv:rv32 -D --disassemble-zeroes boot/boot.bin
