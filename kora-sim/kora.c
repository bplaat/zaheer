// Kora Processor / Computer Simulator
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define DEBUG

// Bus
typedef struct Device Device;
struct Device {
    uint32_t addr;
    uint32_t size;
    uint8_t (*read)(Device *device, uint32_t addr);
    void (*write)(Device *device, uint32_t addr, uint8_t data);
    void *private_data;
    Device *next;
};

typedef struct Bus {
    Device *devices;
} Bus;

void bus_init(Bus *bus) { bus->devices = NULL; }

void bus_add_device(Bus *bus, Device *device) {
    device->next = bus->devices;
    bus->devices = device;
}

uint8_t bus_read(Bus *bus, uint32_t addr) {
    Device *device = bus->devices;
    while (device) {
        if (addr >= device->addr && addr < device->addr + device->size) {
            return device->read ? device->read(device, addr) : 0;
        }
        device = device->next;
    }
    return 0;
}

void bus_write(Bus *bus, uint32_t addr, uint8_t data) {
    Device *device = bus->devices;
    while (device) {
        if (addr >= device->addr && addr < device->addr + device->size) {
            if (device->write) {
                device->write(device, addr, data);
            }
            return;
        }
        device = device->next;
    }
}

// Memory device
uint8_t memory_device_read(Device *device, uint32_t addr) {
    return ((uint8_t *)device->private_data)[addr - device->addr];
}

void memory_device_write(Device *device, uint32_t addr, uint8_t data) {
    ((uint8_t *)device->private_data)[addr - device->addr] = data;
}

void memory_device_init(Device *device, void *memory, size_t size) {
    device->addr = 0;
    device->size = size;
    device->private_data = memory;
    device->read = &memory_device_read;
    device->write = &memory_device_write;
}

// Character device
uint8_t char_device_read(Device *device, uint32_t addr) { return getchar(); }

void char_device_write(Device *device, uint32_t addr, uint8_t data) {
    putchar((char)data);
#ifdef DEBUG
    putchar('\n');
#endif
}

void char_device_init(Device *device, uint32_t addr) {
    device->addr = addr;
    device->size = 1;
    device->read = &char_device_read;
    device->write = &char_device_write;
}

// Kora
typedef enum KoraReg {
    KORA_REG_T0,
    KORA_REG_T1,
    KORA_REG_T2,
    KORA_REG_T3,
    KORA_REG_S0,
    KORA_REG_S1,
    KORA_REG_S2,
    KORA_REG_S3,
    KORA_REG_A0,
    KORA_REG_A1,
    KORA_REG_A2,
    KORA_REG_A3,
    KORA_REG_BP,
    KORA_REG_SP,
    KORA_REG_RP,
    KORA_REG_FLAGS
} KoraReg;

typedef enum KoraFlag {
    KORA_FLAG_CARRY,
    KORA_FLAG_ZERO,
    KORA_FLAG_SIGN,
    KORA_FLAG_OVERFLOW,
    KORA_FLAG_HALT = 8
} KoraFlag;

typedef enum KoraCond {
    KORA_COND_ALWAYS,
    KORA_COND_CALL,
    KORA_COND_CARRY,
    KORA_COND_NOT_CARRY,
    KORA_COND_ZERO,
    KORA_COND_NOT_ZERO,
    KORA_COND_SIGN,
    KORA_COND_NOT_SIGN,
    KORA_COND_OVERFLOW,
    KORA_COND_NOT_OVERFLOW,
    KORA_COND_ABOVE,
    KORA_COND_NOT_ABOVE,
    KORA_COND_LESS,
    KORA_COND_NOT_LESS,
    KORA_COND_GREATER,
    KORA_COND_NOT_GREATER
} KoraCond;

typedef enum KoraOpcode {
    KORA_OP_MOV,
    KORA_OP_LW,
    KORA_OP_LH,
    KORA_OP_LHSX,
    KORA_OP_LB,
    KORA_OP_LBSX,
    KORA_OP_SW,
    KORA_OP_SH,
    KORA_OP_SB,

    KORA_OP_ADD,
    KORA_OP_ADC,
    KORA_OP_SUB,
    KORA_OP_SBB,
    KORA_OP_NEG,
    KORA_OP_CMP,

    KORA_OP_AND,
    KORA_OP_OR,
    KORA_OP_XOR,
    KORA_OP_NOT,
    KORA_OP_TEST,
    KORA_OP_SHL,
    KORA_OP_SHR,
    KORA_OP_SAR,

    KORA_OP_JMP
} KoraOpcode;

#ifdef DEBUG

static void kora_reg_strcat(char *buffer, uint8_t reg) {
    if (reg == KORA_REG_T0) strcat(buffer, "t0");
    if (reg == KORA_REG_T1) strcat(buffer, "t1");
    if (reg == KORA_REG_T2) strcat(buffer, "t2");
    if (reg == KORA_REG_T3) strcat(buffer, "t3");
    if (reg == KORA_REG_S0) strcat(buffer, "s0");
    if (reg == KORA_REG_S1) strcat(buffer, "s1");
    if (reg == KORA_REG_S2) strcat(buffer, "s2");
    if (reg == KORA_REG_S3) strcat(buffer, "s3");
    if (reg == KORA_REG_A0) strcat(buffer, "a0");
    if (reg == KORA_REG_A1) strcat(buffer, "a1");
    if (reg == KORA_REG_A2) strcat(buffer, "a2");
    if (reg == KORA_REG_A3) strcat(buffer, "a3");
    if (reg == KORA_REG_BP) strcat(buffer, "bp");
    if (reg == KORA_REG_SP) strcat(buffer, "sp");
    if (reg == KORA_REG_RP) strcat(buffer, "rp");
    if (reg == KORA_REG_FLAGS) strcat(buffer, "flags");
}

void kora_instruction_to_string(char *buffer, uint8_t *inst) {
    uint8_t opcode = inst[0] >> 2;
    uint8_t dest = inst[1] >> 4;
    if (opcode == KORA_OP_MOV) strcpy(buffer, "mov ");
    if (opcode == KORA_OP_LW) strcpy(buffer, "lw ");
    if (opcode == KORA_OP_LH) strcpy(buffer, "lh ");
    if (opcode == KORA_OP_LHSX) strcpy(buffer, "lhsx ");
    if (opcode == KORA_OP_LB) strcpy(buffer, "lb ");
    if (opcode == KORA_OP_LBSX) strcpy(buffer, "lbsx ");
    if (opcode == KORA_OP_SW) strcpy(buffer, "sw ");
    if (opcode == KORA_OP_SH) strcpy(buffer, "sh ");
    if (opcode == KORA_OP_SB) strcpy(buffer, "sb ");

    if (opcode == KORA_OP_ADD) strcpy(buffer, "add ");
    if (opcode == KORA_OP_ADC) strcpy(buffer, "adc ");
    if (opcode == KORA_OP_SUB) strcpy(buffer, "sub ");
    if (opcode == KORA_OP_SBB) strcpy(buffer, "sbb ");
    if (opcode == KORA_OP_NEG) strcpy(buffer, "neg ");
    if (opcode == KORA_OP_CMP) strcpy(buffer, "cmp ");

    if (opcode == KORA_OP_AND) strcpy(buffer, "and ");
    if (opcode == KORA_OP_OR) strcpy(buffer, "or ");
    if (opcode == KORA_OP_XOR) strcpy(buffer, "xor ");
    if (opcode == KORA_OP_NOT) strcpy(buffer, "not ");
    if (opcode == KORA_OP_TEST) strcpy(buffer, "test ");
    if (opcode == KORA_OP_SHL) strcpy(buffer, "shl ");
    if (opcode == KORA_OP_SHR) strcpy(buffer, "shr ");
    if (opcode == KORA_OP_SAR) strcpy(buffer, "sar ");

    if (opcode == KORA_OP_JMP) {
        if (dest == KORA_COND_ALWAYS) strcpy(buffer, "jmp ");
        if (dest == KORA_COND_CALL) strcpy(buffer, "call ");
        if (dest == KORA_COND_CARRY) strcpy(buffer, "jc ");
        if (dest == KORA_COND_NOT_CARRY) strcpy(buffer, "jnc ");
        if (dest == KORA_COND_ZERO) strcpy(buffer, "jz ");
        if (dest == KORA_COND_NOT_ZERO) strcpy(buffer, "jnz ");
        if (dest == KORA_COND_SIGN) strcpy(buffer, "js ");
        if (dest == KORA_COND_NOT_SIGN) strcpy(buffer, "jns ");
        if (dest == KORA_COND_OVERFLOW) strcpy(buffer, "jo ");
        if (dest == KORA_COND_NOT_OVERFLOW) strcpy(buffer, "jno ");
        if (dest == KORA_COND_ABOVE) strcpy(buffer, "ja ");
        if (dest == KORA_COND_NOT_ABOVE) strcpy(buffer, "jna ");
        if (dest == KORA_COND_LESS) strcpy(buffer, "jl ");
        if (dest == KORA_COND_NOT_LESS) strcpy(buffer, "jnl ");
        if (dest == KORA_COND_GREATER) strcpy(buffer, "jg ");
        if (dest == KORA_COND_NOT_GREATER) strcpy(buffer, "jng ");
    }

    if (opcode != KORA_OP_JMP) {
        kora_reg_strcat(buffer, dest);
        strcat(buffer, ", ");
    }

    char format_buffer[255];
    if (inst[0] & 1) {
        if ((inst[0] >> 1) & 1) {
            int32_t imm = (inst[1] & 15) | (inst[2] << 4) | (inst[3] << 12);
            if (opcode == KORA_OP_SHL || opcode == KORA_OP_SHR || opcode == KORA_OP_SAR) imm++;
            if (opcode == KORA_OP_JMP) {
                imm = ((imm ^ 524288) - 524288) << 1;
                if (imm > 0) strcat(buffer, "+");
            }
            sprintf(format_buffer, "%d", imm);
            strcat(buffer, format_buffer);
        } else {
            kora_reg_strcat(buffer, inst[1] & 15);
            int32_t disp = (int16_t)(inst[2] | (inst[3] << 8));
            if (disp > 0) {
                sprintf(format_buffer, " + %d", disp);
            } else {
                sprintf(format_buffer, " - %d", -disp);
            }
            strcat(buffer, format_buffer);
        }
    } else {
        if ((inst[0] >> 1) & 1) {
            int32_t imm = inst[1] & 15;
            if (opcode == KORA_OP_SHL || opcode == KORA_OP_SHR || opcode == KORA_OP_SAR) imm++;
            if (opcode == KORA_OP_JMP) {
                imm = ((imm ^ 8) - 8) << 1;
                if (imm > 0) strcat(buffer, "+");
            }
            sprintf(format_buffer, "%d", imm);
            strcat(buffer, format_buffer);
        } else {
            kora_reg_strcat(buffer, inst[1] & 15);
        }
    }
}

#endif

typedef struct Kora {
    Bus *bus;
    uint32_t ip;
    uint32_t regs[16];
    uint8_t inst[4];
    uint8_t step;
} Kora;

void kora_init(Kora *kora, Bus *bus) { kora->bus = bus; }

#ifdef DEBUG
void kora_print_state(Kora *kora) {
    char instruction[255];
    if (kora->inst[0] & 1) {
        sprintf(instruction, "%02x %02x %02x %02x", kora->inst[0], kora->inst[1], kora->inst[2], kora->inst[3]);
    } else {
        sprintf(instruction, "%02x %02x", kora->inst[0], kora->inst[1]);
    }
    char decompiled_instruction[255];
    kora_instruction_to_string(decompiled_instruction, &kora->inst[0]);
    printf(
        "ip=%08x, t0=%08x, t1=%08x, t2=%08x, t3=%08x, s0=%08x, s1=%08x, s2=%08x, s3=%08x | %s\n"
        "a0=%08x, a1=%08x, a2=%08x, a3=%08x, bp=%08x, sp=%08x, rp=%08x, "
        "flags=------%c----%c%c%c%c    | %s\n---\n",
        kora->ip, kora->regs[KORA_REG_T0], kora->regs[KORA_REG_T1], kora->regs[KORA_REG_T2], kora->regs[KORA_REG_T3],
        kora->regs[KORA_REG_S0], kora->regs[KORA_REG_S1], kora->regs[KORA_REG_S2], kora->regs[KORA_REG_S3], instruction,
        kora->regs[KORA_REG_A0], kora->regs[KORA_REG_A1], kora->regs[KORA_REG_A2], kora->regs[KORA_REG_A3],
        kora->regs[KORA_REG_BP], kora->regs[KORA_REG_SP], kora->regs[KORA_REG_RP],
        (kora->regs[KORA_REG_FLAGS] & (1 << KORA_FLAG_HALT)) != 0 ? 'H' : '-',
        (kora->regs[KORA_REG_FLAGS] & (1 << KORA_FLAG_OVERFLOW)) != 0 ? 'O' : '-',
        (kora->regs[KORA_REG_FLAGS] & (1 << KORA_FLAG_SIGN)) != 0 ? 'S' : '-',
        (kora->regs[KORA_REG_FLAGS] & (1 << KORA_FLAG_ZERO)) != 0 ? 'Z' : '-',
        (kora->regs[KORA_REG_FLAGS] & (1 << KORA_FLAG_CARRY)) != 0 ? 'C' : '-', decompiled_instruction);
}
#endif

void kora_clock(Kora *kora) {
    if (kora->step == 0) {
        kora->inst[0] = bus_read(kora->bus, kora->ip);
        kora->ip++;
        kora->step = 1;
        return;
    }
    if (kora->step == 1) {
        kora->inst[1] = bus_read(kora->bus, kora->ip);
        kora->ip++;
        kora->step = kora->inst[0] & 1 ? 2 : 4;
        return;
    }
    if (kora->step == 2) {
        kora->inst[2] = bus_read(kora->bus, kora->ip);
        kora->ip++;
        kora->step = 3;
        return;
    }
    if (kora->step == 3) {
        kora->inst[3] = bus_read(kora->bus, kora->ip);
        kora->ip++;
        kora->step = 4;
        return;
    }

    // Decode instruction
    uint8_t opcode = kora->inst[0] >> 2;
    uint8_t dest = kora->inst[1] >> 4;
    uint32_t data;
    if (kora->inst[0] & 1) {
        if ((kora->inst[0] >> 1) & 1) {
            data = (kora->inst[1] & 0xf) | (kora->inst[2] << 4) | (kora->inst[3] << 12);
            if (opcode == KORA_OP_SHL || opcode == KORA_OP_SHR || opcode == KORA_OP_SAR) {
                data++;
            }
            if (opcode == KORA_OP_JMP) {
                data = ((data ^ 524288) - 524288) << 1;
            }
        } else {
            int32_t disp = (int16_t)(kora->inst[2] | (kora->inst[3] << 8));
            data = kora->regs[kora->inst[1] & 0xf] + disp;
        }
    } else {
        if ((kora->inst[0] >> 1) & 1) {
            data = kora->inst[1] & 15;
            if (opcode == KORA_OP_SHL || opcode == KORA_OP_SHR || opcode == KORA_OP_SAR) {
                data++;
            }
            if (opcode == KORA_OP_JMP) {
                data = ((data ^ 8) - 8) << 1;
            }
        } else {
            data = kora->regs[kora->inst[1] & 0xf];
        }
    }

    if (kora->step == 4) {
        // Move, load and store instructions
        if (opcode == KORA_OP_MOV) {
            kora->regs[dest] = data;
        }
        if (opcode == KORA_OP_LW || opcode == KORA_OP_LH || opcode == KORA_OP_LHSX) {
            kora->regs[dest] = bus_read(kora->bus, data);
            kora->step = 5;
            return;
        }
        if (opcode == KORA_OP_LB) {
            kora->regs[dest] = bus_read(kora->bus, data);
        }
        if (opcode == KORA_OP_LBSX) {
            kora->regs[dest] = (int32_t)(int8_t)bus_read(kora->bus, data);
        }
        if (opcode == KORA_OP_SW || opcode == KORA_OP_SH) {
            bus_write(kora->bus, data, kora->regs[dest]);
            kora->step = 5;
            return;
        }
        if (opcode == KORA_OP_SB) {
            bus_write(kora->bus, data, kora->regs[dest]);
        }

        // Arithmetic instructions
        if (opcode >= KORA_OP_ADD && opcode <= KORA_OP_CMP) {
            bool carry_in = (kora->regs[KORA_REG_FLAGS] >> KORA_FLAG_CARRY) & 1;
            bool carry;
            uint32_t tmp;
            if (opcode == KORA_OP_ADD) carry = __builtin_add_overflow(kora->regs[dest], data, &kora->regs[dest]);
            if (opcode == KORA_OP_ADC)
                carry = __builtin_add_overflow(kora->regs[dest], data + carry_in, &kora->regs[dest]);
            if (opcode == KORA_OP_SUB) carry = __builtin_sub_overflow(kora->regs[dest], data, &kora->regs[dest]);
            if (opcode == KORA_OP_SBB)
                carry = __builtin_sub_overflow(kora->regs[dest], data + carry_in, &kora->regs[dest]);
            if (opcode == KORA_OP_NEG) carry = __builtin_sub_overflow(0, data, &kora->regs[dest]);
            if (opcode == KORA_OP_CMP) carry = __builtin_sub_overflow(kora->regs[dest], data, &tmp);
            uint32_t result = opcode == KORA_OP_CMP ? tmp : kora->regs[dest];
            bool sign = result >> 31;
            kora->regs[KORA_REG_FLAGS] = (carry << KORA_FLAG_CARRY) | ((result == 0) << KORA_FLAG_ZERO) |
                                         (sign << KORA_FLAG_SIGN) | ((carry_in != sign) << KORA_FLAG_OVERFLOW) |
                                         (kora->regs[KORA_REG_FLAGS] & 0xfffffff0);
        }

        // Bitwise instructions
        if (opcode >= KORA_OP_AND && opcode <= KORA_OP_SAR) {
            uint32_t tmp;
            if (opcode == KORA_OP_AND) kora->regs[dest] &= data;
            if (opcode == KORA_OP_OR) kora->regs[dest] |= data;
            if (opcode == KORA_OP_XOR) kora->regs[dest] ^= data;
            if (opcode == KORA_OP_NOT) kora->regs[dest] = ~data;
            if (opcode == KORA_OP_TEST) tmp = kora->regs[dest] & data;
            if (opcode == KORA_OP_SHL) kora->regs[dest] <<= data & 31;
            if (opcode == KORA_OP_SHR) kora->regs[dest] >>= data & 31;
            if (opcode == KORA_OP_SAR) kora->regs[dest] = (int32_t)kora->regs[dest] >> (int32_t)(data & 31);
            uint32_t result = opcode == KORA_OP_TEST ? tmp : kora->regs[dest];
            kora->regs[KORA_REG_FLAGS] = ((result == 0) << KORA_FLAG_ZERO) | ((result >> 31) << KORA_FLAG_SIGN) |
                                         (kora->regs[KORA_REG_FLAGS] & 0xfffffff0);
        }

        // Jump instructions
        if (opcode == KORA_OP_JMP) {
            uint32_t target = (kora->inst[0] >> 1) & 1 ? kora->ip + data : data;
            bool carry = (kora->regs[KORA_REG_FLAGS] & (1 << KORA_FLAG_CARRY)) != 0;
            bool zero = (kora->regs[KORA_REG_FLAGS] & (1 << KORA_FLAG_ZERO)) != 0;
            bool sign = (kora->regs[KORA_REG_FLAGS] & (1 << KORA_FLAG_SIGN)) != 0;
            bool overflow = (kora->regs[KORA_REG_FLAGS] & (1 << KORA_FLAG_OVERFLOW)) != 0;
            if (dest == KORA_COND_ALWAYS) kora->ip = target;
            if (dest == KORA_COND_CALL) {
                kora->regs[KORA_REG_RP] = kora->ip;
                kora->ip = target;
            }
            if (dest == KORA_COND_CARRY && carry) kora->ip = target;
            if (dest == KORA_COND_NOT_CARRY && !carry) kora->ip = target;
            if (dest == KORA_COND_ZERO && zero) kora->ip = target;
            if (dest == KORA_COND_NOT_ZERO && !zero) kora->ip = target;
            if (dest == KORA_COND_SIGN && sign) kora->ip = target;
            if (dest == KORA_COND_NOT_SIGN && !sign) kora->ip = target;
            if (dest == KORA_COND_OVERFLOW && overflow) kora->ip = target;
            if (dest == KORA_COND_NOT_OVERFLOW && !overflow) kora->ip = target;
            if (dest == KORA_COND_ABOVE && !carry && !zero) kora->ip = target;
            if (dest == KORA_COND_NOT_ABOVE && (carry || zero)) kora->ip = target;
            if (dest == KORA_COND_LESS && sign != overflow) kora->ip = target;
            if (dest == KORA_COND_NOT_LESS && sign == overflow) kora->ip = target;
            if (dest == KORA_COND_GREATER && zero && sign == overflow) kora->ip = target;
            if (dest == KORA_COND_NOT_GREATER && (!zero || sign != overflow)) kora->ip = target;
        }
        kora->step = 0;
#ifdef DEBUG
        kora_print_state(kora);
#endif
        return;
    }
    if (kora->step == 5) {
        if (opcode == KORA_OP_LW) {
            kora->regs[dest] = (bus_read(kora->bus, data + 1) << 8) | (kora->regs[dest] & 0xff);
            kora->step = 6;
            return;
        }
        if (opcode == KORA_OP_LH) {
            kora->regs[dest] = (bus_read(kora->bus, data + 1) << 8) | (kora->regs[dest] & 0xff);
            kora->step = 0;
#ifdef DEBUG
            kora_print_state(kora);
#endif
            return;
        }
        if (opcode == KORA_OP_LHSX) {
            kora->regs[dest] = (int32_t)(int16_t)((bus_read(kora->bus, data + 1) << 8) | (kora->regs[dest] & 0xff));
            kora->step = 0;
#ifdef DEBUG
            kora_print_state(kora);
#endif
            return;
        }
        if (opcode == KORA_OP_SW) {
            bus_write(kora->bus, data + 1, kora->regs[dest] >> 8);
            kora->step = 6;
            return;
        }
        if (opcode == KORA_OP_SH) {
            bus_write(kora->bus, data + 1, kora->regs[dest] >> 8);
            kora->step = 0;
#ifdef DEBUG
            kora_print_state(kora);
#endif
            return;
        }
    }
    if (kora->step == 6) {
        if (opcode == KORA_OP_LW) {
            kora->regs[dest] = (bus_read(kora->bus, data + 2) << 8) | (kora->regs[dest] & 0xffff);
            kora->step = 7;
            return;
        }
        if (opcode == KORA_OP_SW) {
            bus_write(kora->bus, data + 2, kora->regs[dest] >> 8);
            kora->step = 7;
            return;
        }
    }
    if (kora->step == 7) {
        if (opcode == KORA_OP_LW) {
            kora->regs[dest] = (bus_read(kora->bus, data + 3) << 8) | (kora->regs[dest] & 0xffffff);
            kora->step = 0;
#ifdef DEBUG
            kora_print_state(kora);
#endif
            return;
        }
        if (opcode == KORA_OP_SW) {
            bus_write(kora->bus, data + 3, kora->regs[dest] >> 8);
            kora->step = 0;
#ifdef DEBUG
            kora_print_state(kora);
#endif
            return;
        }
    }
}

#define INST_REG_REG(opcode, dest, src) (opcode << 2) | 0b00, (dest << 4) | src
#define INST_REG_REG_LARGE(opcode, dest, src, disp) \
    (opcode << 2) | 0b01, (dest << 4) | src, disp & 0xff, (disp >> 8) & 0xff
#define INST_REG_IMM(opcode, dest, imm) (opcode << 2) | 0b10, (dest << 4) | (imm & 15)
#define INST_REG_IMM_LARGE(opcode, dest, imm) \
    (opcode << 2) | 0b11, (dest << 4) | (imm & 15), (imm >> 4) & 255, (imm >> 12) & 255

int main(void) {
    // Bus
    Bus bus = {0};
    bus_init(&bus);

    // Memory device
    uint8_t memory[] = {
        INST_REG_IMM(KORA_OP_MOV, KORA_REG_T0, 0),
        INST_REG_IMM(KORA_OP_CMP, KORA_REG_T0, 8),
        INST_REG_IMM(KORA_OP_JMP, KORA_COND_ZERO, 2),
        INST_REG_IMM(KORA_OP_ADD, KORA_REG_T0, 1),
        INST_REG_IMM(KORA_OP_JMP, KORA_COND_ALWAYS, -4),

        INST_REG_IMM_LARGE(KORA_OP_MOV, KORA_REG_T0, 'H'),
        INST_REG_IMM_LARGE(KORA_OP_MOV, KORA_REG_A0, 0x1000),
        INST_REG_REG(KORA_OP_SB, KORA_REG_T0, KORA_REG_A0),
        INST_REG_IMM_LARGE(KORA_OP_MOV, KORA_REG_T0, 'o'),
        INST_REG_REG(KORA_OP_SB, KORA_REG_T0, KORA_REG_A0),
        INST_REG_IMM_LARGE(KORA_OP_MOV, KORA_REG_T0, 'i'),
        INST_REG_REG(KORA_OP_SB, KORA_REG_T0, KORA_REG_A0),

        INST_REG_IMM_LARGE(KORA_OP_OR, KORA_REG_FLAGS, 1 << KORA_FLAG_HALT),
    };
    Device memory_device = {0};
    memory_device_init(&memory_device, memory, sizeof(memory));
    bus_add_device(&bus, &memory_device);

    // Character device
    Device char_device = {0};
    char_device_init(&char_device, 0x1000);
    bus_add_device(&bus, &char_device);

    // Kora
    Kora kora = {0};
    kora_init(&kora, &bus);
    while ((kora.regs[KORA_REG_FLAGS] & (1 << KORA_FLAG_HALT)) == 0) {
        kora_clock(&kora);
    }
    return EXIT_SUCCESS;
}
