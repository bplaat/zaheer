#pragma once

#include <stdint.h>
#include "memory.hpp"
#include "compile_time.hpp"

// Undef Arduino / AVR defines :D
#undef SP
#undef ADC

class Kora {
    public:
        static const uint16_t PROCESSOR_MANUFACTER_ID = 0x219f;
        static const uint16_t PROCESSOR_ID = 0xca3f;
        static const uint8_t PROCESSOR_VERSION_HIGH = 0;
        static const uint8_t PROCESSOR_VERSION_LOW = 1;
        static const uint16_t PROCESSOR_FEATURES = 0b0000000000000000;
        static const uint32_t PROCESSOR_MANUFACTER_TIMESTAMP = UNIX_TIMESTAMP;

        enum class Opcode {
            NOP = 0,

            LW = 1,
            LB = 2,
            LBU = 3,
            SW = 4,
            SB = 5,

            ADD = 6,
            ADC = 7,
            SUB = 8,
            SBB = 9,
            NEG = 10,
            CMP = 11,

            AND = 12,
            OR = 13,
            XOR = 14,
            NOT = 15,
            SHL = 16,
            SHR = 17,
            SAR = 18,

            JMP = 19,
            BRA = 20,
            PUSH = 21,
            POP = 22,
            CALL = 23,
            BCALL = 24,
            RET = 25,

            CPUID = 26
        };

        enum class Mode {
            IMMEDIATE_MICRO = 0,
            IMMEDIATE_SMALL = 1,
            IMMEDIATE_NORMAL = 2,
            IMMEDIATE_NORMAL_ADDRESS = 3,

            REGISTER_MICRO = 4,
            REGISTER_SMALL = 5,
            REGISTER_NORMAL = 6,
            REGISTER_NORMAL_ADDRESS = 7
        };

        enum class Register {
            A = 0,
            B = 1,
            C = 2,
            D = 3,
            E = 4,
            F = 5,
            G = 6,
            H = 7,
            IP = 8,
            SP = 9,
            BP = 10,
            CS = 11,
            DS = 12,
            SS = 13,
            ES = 14,
            FLAGS = 15
        };

        enum class Flag {
            CARRY = 0,
            ZERO = 1,
            SIGN = 2,
            OVERFLOW = 3,
            HALTED = 8
        };

        enum class Condition {
            ALWAYS = 0,
            NEVER = 1,
            CARRY = 2,
            NOT_CARRY = 3,
            ZERO = 4,
            NOT_ZERO = 5,
            SIGN = 6,
            NOT_SIGN = 7,
            OVERFLOW = 8,
            NOT_OVERFLOW = 9,
            ABOVE = 10,
            NOT_ABOVE = 11,
            LESSER = 12,
            NOT_LESSER = 13,
            GREATER = 14,
            NOT_GREATER = 15
        };

        Memory &memory;
        uint16_t registers[16];
        uint16_t instructionWords[2];
        uint8_t step = 0;

        Kora(Memory &memory);

        void clock();

    private:
        void setFlags(uint16_t result);
};
