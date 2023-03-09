// Work in progress!!! Not complete!!!

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef enum KoraReg {
    KORA_REG_T0,    // tmp0, return
    KORA_REG_T1,    //
    KORA_REG_T2,    //
    KORA_REG_T3,    //
    KORA_REG_T4,    //
    KORA_REG_S0,    // saved0
    KORA_REG_S1,    //
    KORA_REG_S2,    //
    KORA_REG_S3,    //
    KORA_REG_A0,    // arg0
    KORA_REG_A1,    //
    KORA_REG_A2,    //
    KORA_REG_A3,    //
    KORA_REG_BP,    // base pointer
    KORA_REG_SP,    // stack pointer
    KORA_REG_FLAGS  // flags
} KoraReg;

typedef enum KoraFlag {
    KORA_FLAG_ZERO,
    KORA_FLAG_SIGN,
    KORA_FLAG_CARRY,
    KORA_FLAG_OVERFLOW,
    KORA_FLAG_HALT = 8
} KoraFlag;

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

    KORA_OP_JMP,
    KORA_OP_JZ,
    KORA_OP_JNZ,
    KORA_OP_JS,
    KORA_OP_JNS,
    KORA_OP_JC,
    KORA_OP_JNC,
    KORA_OP_JO,
    KORA_OP_JNO,
    KORA_OP_JA,
    KORA_OP_JNA,
    KORA_OP_JB,
    KORA_OP_JNB,
    KORA_OP_JL,
    KORA_OP_JNL,
    KORA_OP_JG,
    KORA_OP_JNG,

    KORA_OP_PUSH,
    KORA_OP_POP,
    KORA_OP_CALL,
    KORA_OP_RET
} KoraOpcode;

typedef struct Kora {
    uint32_t ip;
    uint32_t regs[16];
    uint8_t inst[4];
    uint8_t step;
} Kora;

void kora_init(Kora *k) { k->ip = 0xffff0000; }

uint8_t kora_read(Kora *k, uint32_t addr) { return 0; }

void kora_write(Kora *k, uint32_t addr, uint8_t data) { return 0; }

#define arth_flags()                                                                                              \
    bool sign = k->regs[dest] >> 15;                                                                              \
    k->regs[KORA_REG_FLAGS] = ((k->regs[dest] == 0) << KORA_FLAG_ZERO) | (sign << KORA_FLAG_SIGN) | (carry << KORA_FLAG_CARRY) | \
               ((carry_in != sign) << KORA_FLAG_OVERFLOW) | (k->regs[KORA_REG_FLAGS] & 0xfff0);

#define bit_flags() \
    k->regs[KORA_REG_FLAGS] =      \
        ((k->regs[dest] == 0) << KORA_FLAG_ZERO) | ((k->regs[dest] >> 15) << KORA_FLAG_SIGN) | (k->regs[KORA_REG_FLAGS] & 0xfffc);

void kora_clock(Kora *k) {
    if (k->step == 0) {
        k->inst[0] = kora_read(k, k->ip++);
        k->step = 1;
    }
    if (k->step == 1) {
        k->inst[1] = kora_read(k, k->ip++);
        k->step = k->inst[0] & 1 ? 4 : 2;
    }
    if (k->step == 2) {
        k->inst[2] = kora_read(k, k->ip++);
        k->step = 3;
    }
    if (k->step == 3) {
        k->inst[3] = kora_read(k, k->ip++);
        k->step = 4;
    }
    if (k->step == 4) {
        uint16_t data;
        if (k->inst[0] & 1) {
            if ((k->inst[0] >> 1) & 1) {
                data = k->regs[k->inst[2] >> 4];
            } else {
                data = k->inst[2] | (k->inst[3] << 8);
            }
        } else {
            if ((k->inst[0] >> 1) & 1) {
                data = k->regs[k->inst[1] & 0xf];
            } else {
                data = k->inst[1] & 0xf;
            }
        }

        uint8_t dest = k->inst[1] >> 4;
        uint8_t opcode = k->inst[0] >> 2;

        // Move, load and store instructions
        if (opcode == KORA_OP_MOV) {
            k->regs[dest] = data;
        }
        if (opcode == KORA_OP_LW) {
            k->regs[dest] = kora_read(k, data) | (kora_read(k, data + 1) << 8) | (kora_read(k, data + 2) << 16) |
                            (kora_read(k, data + 3) << 24);
        }
        if (opcode == KORA_OP_LH) {
            k->regs[dest] = kora_read(k, data) | (kora_read(k, data + 1) << 8);
        }
        if (opcode == KORA_OP_LHSX) {
            k->regs[dest] = (int32_t)(int16_t)(kora_read(k, data) | (kora_read(k, data + 1) << 8));
        }
        if (opcode == KORA_OP_LB) {
            k->regs[dest] = kora_read(k, data);
        }
        if (opcode == KORA_OP_LBSX) {
            k->regs[dest] = (int16_t)(int8_t)kora_read(k, data);
        }
        if (opcode == KORA_OP_SW) {
            kora_write(k, data, k->regs[dest]);
            kora_write(k, data + 1, k->regs[dest] >> 8);
            kora_write(k, data + 2, k->regs[dest] >> 16);
            kora_write(k, data + 3, k->regs[dest] >> 24);
        }
        if (opcode == KORA_OP_SW) {
            kora_write(k, data, k->regs[dest]);
            kora_write(k, data + 1, k->regs[dest] >> 8);
        }
        if (opcode == KORA_OP_SB) {
            kora_write(k, data, k->regs[dest]);
        }

        // Arithmetic instructions
        if (opcode == KORA_OP_ADD) {
            bool carry_in = (k->regs[KORA_REG_FLAGS] >> KORA_FLAG_CARRY) & 1;
            bool carry = __builtin_add_overflow(k->regs[dest], data, &k->regs[dest]);
            arth_flags();
        }
        if (opcode == KORA_OP_ADC) {
            bool carry_in = (k->regs[KORA_REG_FLAGS] >> KORA_FLAG_CARRY) & 1;
            bool carry = __builtin_add_overflow(k->regs[dest], data + carry_in, &k->regs[dest]);
            arth_flags();
        }
        if (opcode == KORA_OP_SUB) {
            bool carry_in = (k->regs[KORA_REG_FLAGS] >> KORA_FLAG_CARRY) & 1;
            bool carry = __builtin_sub_overflow(k->regs[dest], data, &k->regs[dest]);
            arth_flags();
        }
        if (opcode == KORA_OP_SBB) {
            bool carry_in = (k->regs[KORA_REG_FLAGS] >> KORA_FLAG_CARRY) & 1;
            bool carry = __builtin_sub_overflow(k->regs[dest], data + carry_in, &k->regs[dest]);
            arth_flags();
        }
        if (opcode == KORA_OP_NEG) {
            bool carry_in = (k->regs[KORA_REG_FLAGS] >> KORA_FLAG_CARRY) & 1;
            bool carry = __builtin_sub_overflow(0, data, &k->regs[dest]);
            arth_flags();
        }
        if (opcode == KORA_OP_CMP) {
            bool carry_in = (k->regs[KORA_REG_FLAGS] >> KORA_FLAG_CARRY) & 1;
            uint16_t tmp;
            bool carry = __builtin_sub_overflow(k->regs[dest], data, &tmp);
            bool sign = tmp >> 15;
            k->regs[KORA_REG_FLAGS] = ((tmp == 0) << KORA_FLAG_ZERO) | (sign << KORA_FLAG_SIGN) | (carry << KORA_FLAG_CARRY) |
                       ((carry_in != sign) << KORA_FLAG_OVERFLOW) | (k->regs[KORA_REG_FLAGS] & 0xfff0);
        }

        // Bitwise instructions
        if (opcode == KORA_OP_AND) {
            k->regs[dest] &= data;
            bit_flags();
        }
        if (opcode == KORA_OP_OR) {
            k->regs[dest] |= data;
            bit_flags();
        }
        if (opcode == KORA_OP_XOR) {
            k->regs[dest] ^= data;
            bit_flags();
        }
        if (opcode == KORA_OP_NOT) {
            k->regs[dest] = ~data;
            bit_flags();
        }
        if (opcode == KORA_OP_TEST) {
            uint16_t tmp = k->regs[dest] & data;
            k->regs[KORA_REG_FLAGS] = ((tmp == 0) << KORA_FLAG_ZERO) | ((tmp >> 15) << KORA_FLAG_SIGN) | (k->regs[KORA_REG_FLAGS] & 0xfffc);
        }
        if (opcode == KORA_OP_SHL) {
            k->regs[dest] <<= data & 15;
            bit_flags();
        }
        if (opcode == KORA_OP_SHR) {
            k->regs[dest] >>= data & 15;
            bit_flags();
        }
        if (opcode == KORA_OP_SAR) {
            k->regs[dest] >>= data & 15;  // TODO sign ex
            bit_flags();
        }

        // Stack and jump instructions
        if (opcode == KORA_OP_PUSH) {
            kora_write(k, (k->regs[KORA_REG_SS] << 8) + k->regs[KORA_REG_SP]--, data);
            kora_write(k, (k->regs[KORA_REG_SS] << 8) + k->regs[KORA_REG_SP]--, data >> 8);
        }
        if (opcode == KORA_OP_POP) {
            k->regs[dest] = (kora_load(k, (k->regs[KORA_REG_SS] << 8) + ++k->regs[KORA_REG_SP]) << 8) |
                            kora_load(k, (k->regs[KORA_REG_SS] << 8) + ++k->regs[KORA_REG_SP]);
        }
        if (opcode == KORA_OP_JMP) {
            if (dest != KORA_REG_SP) k->cs = k->regs[dest];
            k->ip = data;
        }
        if (opcode == KORA_OP_CALL) {
            kora_write(k, (k->regs[KORA_REG_SS] << 8) + k->regs[KORA_REG_SP]--, k->ip);
            kora_write(k, (k->regs[KORA_REG_SS] << 8) + k->regs[KORA_REG_SP]--, k->ip >> 8);
            k->ip = data;
        }
        if (opcode == KORA_OP_RET) {
            k->ip = (kora_load(k, (k->regs[KORA_REG_SS] << 8) + ++k->regs[KORA_REG_SP]) << 8) |
                    kora_load(k, (k->regs[KORA_REG_SS] << 8) + ++k->regs[KORA_REG_SP]);
            k->regs[KORA_REG_SP] += data;
        }

        k->step = 0;
    }
}

int main(void) {
    Kora kora = {0};
    kora_init(&kora);

    while ((kora.flags & KORA_FLAG_HALT) == 0) {
        kora_clock(&kora);
    }

    return EXIT_SUCCESS;
}
