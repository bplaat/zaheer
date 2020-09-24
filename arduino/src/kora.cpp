#include "kora.hpp"
#include <stdint.h>
#include "memory.hpp"
#include "utils.hpp"

Kora::Kora(Memory &memory) : memory(memory) {}

void Kora::setFlags(uint16_t result) {
    // if (result > UINT16_MAX - data) {
    //             // carry
    //             // overflow
    //         }

    //         if (result == 0) {
    //             // zero
    //         }

    //         if ((result >> 14) == 1) {
    //             // sign
    //         }
}

void Kora::clock() {
    // Check if CPU is halted
    if (CHECK_BIT(registers[static_cast<int8_t>(Kora::Register::FLAGS)], static_cast<int8_t>(Kora::Flag::HALTED))) {
        return;
    }

    if (step == 0) {
        instructionWords[0] = memory.readWord(registers[static_cast<int8_t>(Kora::Register::IP)]);
        registers[static_cast<int8_t>(Kora::Register::IP)] += 2; // TODO: micro, small size
    }

    if (step == 2) {
        instructionWords[1] = memory.readWord(registers[static_cast<int8_t>(Kora::Register::IP)]);
        registers[static_cast<int8_t>(Kora::Register::IP)] += 2; // TODO: micro, small size
    }

    if (step == 3) {
        step = 0;

        Kora::Opcode opcode = static_cast<Kora::Opcode>(instructionWords[0] >> (16 - 5));
        Kora::Mode mode = static_cast<Kora::Mode>((instructionWords[0] >> (16 - 5 - 3)) & ((1 << 3) - 1));
        Kora::Register destination_register = static_cast<Kora::Register>((instructionWords[0] >> 4) & ((1 << 4) - 1));
        Kora::Condition condition = static_cast<Kora::Condition>(instructionWords[0] & ((1 << 4) - 1));
        if (mode == Kora::Mode::IMMEDIATE_MICRO || mode == Kora::Mode::REGISTER_MICRO) {
            condition = Kora::Condition::ALWAYS;
        }

        uint8_t immediate_micro = static_cast<uint8_t>(condition);
        uint8_t immediate_small = instructionWords[1] >> ((1 << 3) - 1);
        uint16_t immediate_normal = instructionWords[1];

        Kora::Register register_source_micro = static_cast<Kora::Register>(condition);
        Kora::Register register_source_small_and_normal = static_cast<Kora::Register>(instructionWords[1] >> 12);
        uint8_t register_displacement_small = (instructionWords[1] >> 8) & ((1 << 4) - 1);
        uint16_t register_displacement_normal = instructionWords[1] & ((1 << 12) - 1);

        // ############# CONDITION #############
        uint16_t flagRegister = registers[static_cast<int8_t>(Kora::Register::FLAGS)];

        if (condition == Kora::Condition::NEVER) {
            return;
        }

        if (condition == Kora::Condition::CARRY && !(
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::CARRY))
        )) {
            return;
        }

        if (condition == Kora::Condition::NOT_CARRY && !(
            !CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::CARRY))
        )) {
            return;
        }

        if (condition == Kora::Condition::ZERO && !(
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::ZERO))
        )) {
            return;
        }

        if (condition == Kora::Condition::NOT_ZERO && !(
            !CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::ZERO))
        )) {
            return;
        }

        if (condition == Kora::Condition::SIGN && !(
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::SIGN))
        )) {
            return;
        }

        if (condition == Kora::Condition::NOT_SIGN && !(
            !CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::SIGN))
        )) {
            return;
        }

        if (condition == Kora::Condition::OVERFLOW && !(
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::OVERFLOW))
        )) {
            return;
        }

        if (condition == Kora::Condition::NOT_OVERFLOW && !(
            !CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::OVERFLOW))
        )) {
            return;
        }

        if (condition == Kora::Condition::ABOVE && !(
            !CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::CARRY)) &&
            !CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::ZERO))
        )) {
            return;
        }

        if (condition == Kora::Condition::NOT_ABOVE && !(
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::CARRY)) ||
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::ZERO))
        )) {
            return;
        }

        if (condition == Kora::Condition::LESSER && !(
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::SIGN)) !=
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::OVERFLOW))
        )) {
            return;
        }

        if (condition == Kora::Condition::NOT_LESSER && !(
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::SIGN)) ==
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::OVERFLOW))
        )) {
            return;
        }

        if (condition == Kora::Condition::GREATER && !(
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::ZERO)) &&
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::SIGN)) ==
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::OVERFLOW))
        )) {
            return;
        }

        if (condition == Kora::Condition::NOT_GREATER && !(
            !CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::ZERO)) ||
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::SIGN)) !=
            CHECK_BIT(flagRegister, static_cast<uint8_t>(Kora::Flag::OVERFLOW))
        )) {
            return;
        }

        // ############# DATA #############
        uint16_t data;

        if (mode == Kora::Mode::IMMEDIATE_MICRO) {
            data = immediate_micro;
        }

        if (mode == Kora::Mode::IMMEDIATE_SMALL) {
            data = immediate_small;
        }

        if (mode == Kora::Mode::IMMEDIATE_NORMAL) {
            data = immediate_normal;
        }

        if (mode == Kora::Mode::IMMEDIATE_NORMAL_ADDRESS) {
            data = memory.readWord(immediate_normal);
        }

        if (mode == Kora::Mode::REGISTER_MICRO) {
            data = registers[static_cast<int8_t>(register_source_micro)];
        }

        if (mode == Kora::Mode::REGISTER_SMALL) {
            data = registers[static_cast<int8_t>(register_source_small_and_normal)] + register_displacement_small; // TODO sign
        }

        if (mode == Kora::Mode::REGISTER_NORMAL) {
            data = registers[static_cast<int8_t>(register_source_small_and_normal)] + register_displacement_normal; // TODO sign
        }

        if (mode == Kora::Mode::REGISTER_NORMAL_ADDRESS) {
            data = memory.readWord(registers[static_cast<int8_t>(register_source_small_and_normal)] + register_displacement_normal); // TODO sign
        }

        // ############# OPCODES #############

        // ##### LOAD / STORE INSTRUCTIONS #####

        // Load word
        if (opcode == Kora::Opcode::LW) {
            registers[static_cast<int8_t>(destination_register)] = data;
        }

        // Load byte signed
        if (opcode == Kora::Opcode::LB) {
            registers[static_cast<int8_t>(destination_register)] = data & 255; // TODO: sign
        }

        // Load byte unsigned
        if (opcode == Kora::Opcode::LBU) {
            registers[static_cast<int8_t>(destination_register)] = data & 255;
        }

        // Store word
        if (opcode == Kora::Opcode::SW) {
            memory.writeWord(data, registers[static_cast<int8_t>(destination_register)]);
        }

        // Store byte
        if (opcode == Kora::Opcode::SB) {
            memory.writeByte(data, registers[static_cast<int8_t>(destination_register)]);
        }

        // ##### ARITHMETIC INSTRUCTIONS #####

        // Add
        if (opcode == Kora::Opcode::ADD) {
            uint16_t result = registers[static_cast<int8_t>(destination_register)] + data;
            registers[static_cast<int8_t>(destination_register)] = result;
            setFlags(result);
        }

        // Add with carry
        if (opcode == Kora::Opcode::ADC) {
            uint16_t result = registers[static_cast<int8_t>(destination_register)] + data; // TODO: carry
            registers[static_cast<int8_t>(destination_register)] = result;
            setFlags(result);
        }

        // Subtract
        if (opcode == Kora::Opcode::SUB) {
            uint16_t result = registers[static_cast<int8_t>(destination_register)] + data; // TODO: carry
            registers[static_cast<int8_t>(destination_register)] = result;
            setFlags(result);
        }

        // Subtract with borrow
        if (opcode == Kora::Opcode::SBB) {
            uint16_t result = registers[static_cast<int8_t>(destination_register)] + data; // TODO: carry
            registers[static_cast<int8_t>(destination_register)] = result;
            setFlags(result);
        }

        // Negate
        if (opcode == Kora::Opcode::NEG) {
            uint16_t result = registers[static_cast<int8_t>(destination_register)] + data; // TODO: carry
            registers[static_cast<int8_t>(destination_register)] = result;
            setFlags(result);
        }

        // Compare
        if (opcode == Kora::Opcode::CMP) {
            uint16_t result = registers[static_cast<int8_t>(destination_register)] - data; // TODO: carry
            setFlags(result);
        }

        // ##### BITWISE INSTRUCTIONS #####

        // And
        if (opcode == Kora::Opcode::AND) {
            uint16_t result = registers[static_cast<int8_t>(destination_register)] & data;
            registers[static_cast<int8_t>(destination_register)] = result;
            setFlags(result);
        }

        // Or
        if (opcode == Kora::Opcode::OR) {
            uint16_t result = registers[static_cast<int8_t>(destination_register)] | data;
            registers[static_cast<int8_t>(destination_register)] = result;
            setFlags(result);
        }

        // Xor
        if (opcode == Kora::Opcode::XOR) {
            uint16_t result = registers[static_cast<int8_t>(destination_register)] ^ data;
            registers[static_cast<int8_t>(destination_register)] = result;
            setFlags(result);
        }

        // Not
        if (opcode == Kora::Opcode::NOT) {
            uint16_t result = ~data;
            registers[static_cast<int8_t>(destination_register)] = result;
            setFlags(result);
        }

        // Logical shift left
        if (opcode == Kora::Opcode::SHL) {
            uint16_t result = registers[static_cast<int8_t>(destination_register)] << (data & ((1 << 4) - 1));
            registers[static_cast<int8_t>(destination_register)] = result;
            setFlags(result);
        }

        // Logical shift right
        if (opcode == Kora::Opcode::SHR) {
            uint16_t result = registers[static_cast<int8_t>(destination_register)] >> (data & ((1 << 4) - 1));
            registers[static_cast<int8_t>(destination_register)] = result;
            setFlags(result);
        }

        // Arithmetic shift right
        if (opcode == Kora::Opcode::SAR) {
            uint16_t result = static_cast<int16_t>(registers[static_cast<int8_t>(destination_register)]) >> (data & ((1 << 4) - 1));
            registers[static_cast<int8_t>(destination_register)] = result;
            setFlags(result);
        }

        // ##### JUMP / STACK INSTRUCTIONS #####

        // Jump
        if (opcode == Kora::Opcode::JMP) {
            registers[static_cast<int8_t>(Kora::Register::ES)] = registers[static_cast<int8_t>(Kora::Register::CS)];
            registers[static_cast<int8_t>(Kora::Register::CS)] = registers[static_cast<int8_t>(destination_register)];
            registers[static_cast<int8_t>(Kora::Register::IP)] = data;
        }

        // Branch
        if (opcode == Kora::Opcode::BRA) {
            registers[static_cast<int8_t>(Kora::Register::ES)] = registers[static_cast<int8_t>(Kora::Register::CS)];
            registers[static_cast<int8_t>(Kora::Register::CS)] = registers[static_cast<int8_t>(destination_register)];
            registers[static_cast<int8_t>(Kora::Register::IP)] += data;
        }

        // Push
        if (opcode == Kora::Opcode::PUSH) {
            memory.writeWord(registers[static_cast<int8_t>(Kora::Register::SP)], data);
            registers[static_cast<int8_t>(Kora::Register::SP)] -= 2;
        }

        // Pop
        if (opcode == Kora::Opcode::POP) {
            registers[static_cast<int8_t>(Kora::Register::SP)] += 2;
            registers[static_cast<int8_t>(destination_register)] = memory.readWord(registers[static_cast<int8_t>(Kora::Register::SP)]);
        }

        // Call
        if (opcode == Kora::Opcode::CALL) {
            memory.writeWord(registers[static_cast<int8_t>(Kora::Register::SP)], registers[static_cast<int8_t>(Kora::Register::IP)]);
            registers[static_cast<int8_t>(Kora::Register::SP)] -= 2;

            registers[static_cast<int8_t>(Kora::Register::ES)] = registers[static_cast<int8_t>(Kora::Register::CS)];
            registers[static_cast<int8_t>(Kora::Register::CS)] = registers[static_cast<int8_t>(destination_register)];
            registers[static_cast<int8_t>(Kora::Register::IP)] = data;
        }

        // Branch call
        if (opcode == Kora::Opcode::BCALL) {
            memory.writeWord(registers[static_cast<int8_t>(Kora::Register::SP)], registers[static_cast<int8_t>(Kora::Register::IP)]);
            registers[static_cast<int8_t>(Kora::Register::SP)] -= 2;

            registers[static_cast<int8_t>(Kora::Register::ES)] = registers[static_cast<int8_t>(Kora::Register::CS)];
            registers[static_cast<int8_t>(Kora::Register::CS)] = registers[static_cast<int8_t>(destination_register)];
            registers[static_cast<int8_t>(Kora::Register::IP)] += data;
        }

        // Return
        if (opcode == Kora::Opcode::RET) {
            registers[static_cast<int8_t>(Kora::Register::ES)] = registers[static_cast<int8_t>(Kora::Register::CS)];
            registers[static_cast<int8_t>(Kora::Register::CS)] = registers[static_cast<int8_t>(destination_register)];
            registers[static_cast<int8_t>(Kora::Register::SP)] += data + 2; // TODO: check
            registers[static_cast<int8_t>(Kora::Register::IP)] = memory.readWord(registers[static_cast<int8_t>(Kora::Register::SP)]);
        }

        // ##### OTHER INSTRUCTIONS #####

        // CPUID
        if (opcode == Kora::Opcode::CPUID) {
            registers[static_cast<int8_t>(Kora::Register::A)] = PROCESSOR_MANUFACTER_ID;
            registers[static_cast<int8_t>(Kora::Register::B)] = PROCESSOR_ID;
            registers[static_cast<int8_t>(Kora::Register::C)] = (PROCESSOR_VERSION_HIGH << 8) | PROCESSOR_VERSION_LOW;
            registers[static_cast<int8_t>(Kora::Register::D)] = PROCESSOR_FEATURES;
            registers[static_cast<int8_t>(Kora::Register::E)] = PROCESSOR_MANUFACTER_TIMESTAMP & 65535;
            registers[static_cast<int8_t>(Kora::Register::F)] = PROCESSOR_MANUFACTER_TIMESTAMP >> 16;
        }
    }
}
