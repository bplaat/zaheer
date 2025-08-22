LLVM_BIN := /opt/homebrew/opt/llvm/bin
CC := $(LLVM_BIN)/clang
OBJCOPY := $(LLVM_BIN)/llvm-objcopy
LD := /opt/homebrew/bin/ld.lld

all: boot.bin

start.o: start.s
	$(CC) --target=riscv32 -march=rv32i -mabi=ilp32 -c -o start.o start.s

main.o: main.c
	$(CC) --target=riscv32 -march=rv32i -mabi=ilp32 -Os -c -o main.o main.c

boot.elf: start.o main.o link.ld
	$(LD) -m elf32lriscv -T link.ld -o boot.elf start.o main.o

boot.bin: boot.elf
	$(OBJCOPY) -O binary boot.elf boot.bin
