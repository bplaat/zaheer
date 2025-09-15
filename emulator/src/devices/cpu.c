/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

#include "cpu.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void cpu_init(Cpu *cpu, Bus *bus) {
    memset(cpu->regs, 0, sizeof(cpu->regs));
    cpu->pc = 0;
    cpu->bus = bus;
    cpu->cycle_count = 0;
}

uint32_t cpu_fetch(Cpu *cpu) { return bus_read(cpu->bus, cpu->pc); }

void cpu_execute(Cpu *cpu, uint32_t instr) {
    uint32_t opcode = instr & 0x7F;
    uint32_t rd = (instr >> 7) & 0x1F;
    uint32_t rs1 = (instr >> 15) & 0x1F;
    uint32_t rs2 = (instr >> 20) & 0x1F;
    uint32_t funct3 = (instr >> 12) & 0x7;
    uint32_t funct7 = instr >> 25;

    // Sign-extended immediates
    int32_t i_imm = (int32_t)instr >> 20;
    uint32_t shamt = (instr >> 20) & 0x1F;
    int32_t s_imm = ((int32_t)((instr >> 25) << 5)) | ((instr >> 7) & 0x1F);
    s_imm = (s_imm << 20) >> 20;  // Sign extend
    int32_t b_imm = ((int32_t)(instr >> 31) << 12) | (((instr >> 7) & 1) << 11) | ((instr >> 25) & 0x3F) << 5 |
                    ((instr >> 8) & 0xF) << 1;
    b_imm = (b_imm << 19) >> 19;
    uint32_t u_imm = instr & 0xFFFFF000;
    int32_t j_imm = ((int32_t)(instr >> 31) << 20) | ((instr >> 12) & 0xFF) << 12 | ((instr >> 20) & 1) << 11 |
                    ((instr >> 21) & 0x3FF) << 1;
    j_imm = (j_imm << 11) >> 11;

    uint32_t rs1_val = cpu->regs[rs1];
    uint32_t rs2_val = cpu->regs[rs2];

    bool take_branch = false;
    uint32_t next_pc = cpu->pc + 4;

    switch (opcode) {
        case 0x37:  // LUI
            cpu->regs[rd] = u_imm;
            break;
        case 0x17:  // AUIPC
            cpu->regs[rd] = cpu->pc + u_imm;
            break;
        case 0x6F:  // JAL
            if (rd) cpu->regs[rd] = cpu->pc + 4;
            next_pc = cpu->pc + j_imm;
            break;
        case 0x67:  // JALR
            if (rd) cpu->regs[rd] = cpu->pc + 4;
            next_pc = (rs1_val + i_imm) & ~1;
            break;
        case 0x63:  // Branches
            switch (funct3) {
                case 0:
                    take_branch = (rs1_val == rs2_val);
                    break;  // BEQ
                case 1:
                    take_branch = (rs1_val != rs2_val);
                    break;  // BNE
                case 4:
                    take_branch = ((int32_t)rs1_val < (int32_t)rs2_val);
                    break;  // BLT
                case 5:
                    take_branch = ((int32_t)rs1_val >= (int32_t)rs2_val);
                    break;  // BGE
                case 6:
                    take_branch = (rs1_val < rs2_val);
                    break;  // BLTU
                case 7:
                    take_branch = (rs1_val >= rs2_val);
                    break;  // BGEU
            }
            if (take_branch) next_pc = cpu->pc + b_imm;
            break;
        case 0x03: {  // Loads
            uint32_t addr = rs1_val + i_imm;
            uint32_t word = bus_read(cpu->bus, addr & ~0x3);  // Word-aligned read
            uint32_t offset = addr & 0x3;                     // Byte offset within word
            switch (funct3) {
                case 0:  // LB
                    cpu->regs[rd] = (int8_t)((word >> (offset * 8)) & 0xFF);
                    break;
                case 1:  // LH
                    if (offset <= 2) {
                        cpu->regs[rd] = (int16_t)((word >> (offset * 8)) & 0xFFFF);
                    } else {
                        fprintf(stderr, "Unaligned LH at address 0x%08x\n", addr);
                        exit(1);
                    }
                    break;
                case 2:  // LW
                    if (offset == 0) {
                        cpu->regs[rd] = word;
                    } else {
                        fprintf(stderr, "Unaligned LW at address 0x%08x\n", addr);
                        exit(1);
                    }
                    break;
                case 4:  // LBU
                    cpu->regs[rd] = (word >> (offset * 8)) & 0xFF;
                    break;
                case 5:  // LHU
                    if (offset <= 2) {
                        cpu->regs[rd] = (word >> (offset * 8)) & 0xFFFF;
                    } else {
                        fprintf(stderr, "Unaligned LHU at address 0x%08x\n", addr);
                        exit(1);
                    }
                    break;
                default:
                    fprintf(stderr, "Invalid load funct3: %d\n", funct3);
                    exit(1);
            }
            break;
        }
        case 0x23: {  // Stores
            uint32_t addr = rs1_val + s_imm;
            uint32_t offset = addr & 0x3;                     // Byte offset within word
            uint32_t word = bus_read(cpu->bus, addr & ~0x3);  // Read current word
            (void)word;
            uint8_t wmask = 0;
            uint32_t val = rs2_val;
            switch (funct3) {
                case 0:  // SB
                    wmask = 1 << offset;
                    val = (rs2_val & 0xFF) << (offset * 8);
                    break;
                case 1:  // SH
                    if (offset <= 2) {
                        wmask = 0x3 << offset;
                        val = (rs2_val & 0xFFFF) << (offset * 8);
                    } else {
                        fprintf(stderr, "Unaligned SH at address 0x%08x\n", addr);
                        exit(1);
                    }
                    break;
                case 2:  // SW
                    if (offset == 0) {
                        wmask = 0xF;
                        val = rs2_val;
                    } else {
                        fprintf(stderr, "Unaligned SW at address 0x%08x\n", addr);
                        exit(1);
                    }
                    break;
                default:
                    fprintf(stderr, "Invalid store funct3: %d\n", funct3);
                    exit(1);
            }
            bus_write(cpu->bus, addr & ~0x3, val, wmask);
            break;
        }
        case 0x13:  // OP-IMM
            switch (funct3) {
                case 0:
                    cpu->regs[rd] = rs1_val + i_imm;
                    break;  // ADDI
                case 1:
                    cpu->regs[rd] = rs1_val << shamt;
                    break;  // SLLI
                case 2:
                    cpu->regs[rd] = ((int32_t)rs1_val < i_imm) ? 1 : 0;
                    break;  // SLTI
                case 3:
                    cpu->regs[rd] = (rs1_val < (uint32_t)i_imm) ? 1 : 0;
                    break;  // SLTIU
                case 4:
                    cpu->regs[rd] = rs1_val ^ i_imm;
                    break;  // XORI
                case 5:
                    if (funct7 == 0)
                        cpu->regs[rd] = rs1_val >> shamt;  // SRLI
                    else
                        cpu->regs[rd] = (uint32_t)((int32_t)rs1_val >> shamt);  // SRAI
                    break;
                case 6:
                    cpu->regs[rd] = rs1_val | i_imm;
                    break;  // ORI
                case 7:
                    cpu->regs[rd] = rs1_val & i_imm;
                    break;  // ANDI
            }
            break;
        case 0x33:  // OP
            switch (funct3) {
                case 0:
                    if (funct7 == 0)
                        cpu->regs[rd] = rs1_val + rs2_val;  // ADD
                    else
                        cpu->regs[rd] = rs1_val - rs2_val;  // SUB
                    break;
                case 1:
                    cpu->regs[rd] = rs1_val << rs2_val;
                    break;  // SLL
                case 2:
                    cpu->regs[rd] = ((int32_t)rs1_val < (int32_t)rs2_val) ? 1 : 0;
                    break;  // SLT
                case 3:
                    cpu->regs[rd] = (rs1_val < rs2_val) ? 1 : 0;
                    break;  // SLTU
                case 4:
                    cpu->regs[rd] = rs1_val ^ rs2_val;
                    break;  // XOR
                case 5:
                    if (funct7 == 0)
                        cpu->regs[rd] = rs1_val >> rs2_val;  // SRL
                    else
                        cpu->regs[rd] = (uint32_t)((int32_t)rs1_val >> (rs2_val & 0x1F));  // SRA
                    break;
                case 6:
                    cpu->regs[rd] = rs1_val | rs2_val;
                    break;  // OR
                case 7:
                    cpu->regs[rd] = rs1_val & rs2_val;
                    break;  // AND
            }
            break;
        case 0x0F:  // FENCE
            // NOP for emulator (memory ordering not simulated)
            if (funct3 == 0) {
            }  // FENCE
            else if (funct3 == 1) {
            }  // FENCE.I
            break;
        case 0x73: {  // SYSTEM
            uint32_t csr_addr = instr >> 20;
            uint32_t imm5 = rs1;  // For immediate CSR ops
            uint32_t csr_val = 0;
            if (funct3 == 0) {
                if (instr == 0x00000073) {  // ECALL
                    fprintf(stderr, "ECALL at PC 0x%08x\n", cpu->pc);
                    exit(0);
                } else if (instr == 0x00100073) {  // EBREAK
                    fprintf(stderr, "EBREAK at PC 0x%08x\n", cpu->pc);
                    exit(0);
                }
            } else {
                // CSR operations
                // Read current CSR value (only support cycle and cycleh)
                if (csr_addr == 0xC00) {  // cycle
                    csr_val = (uint32_t)cpu->cycle_count;
                } else if (csr_addr == 0xC80) {  // cycleh
                    csr_val = cpu->cycle_count >> 32;
                } else {
                    fprintf(stderr, "Unsupported CSR 0x%03x\n", csr_addr);
                    exit(1);
                }

                uint32_t new_val = csr_val;
                switch (funct3) {
                    case 1:  // CSRRW
                        new_val = rs1_val;
                        break;
                    case 2:  // CSRRS
                        new_val = csr_val | rs1_val;
                        break;
                    case 3:  // CSRRC
                        new_val = csr_val & ~rs1_val;
                        break;
                    case 5:  // CSRRWI
                        new_val = imm5;
                        break;
                    case 6:  // CSRRSI
                        new_val = csr_val | imm5;
                        break;
                    case 7:  // CSRRCI
                        new_val = csr_val & ~imm5;
                        break;
                }
                (void)new_val;

                // Write back if needed (but cycle is read-only, ignore writes)
                // For rdcycle, it's read-only, so no write

                cpu->regs[rd] = csr_val;
            }
            break;
        }
        default:
            fprintf(stderr, "Unknown opcode 0x%02x at PC 0x%08x\n", opcode, cpu->pc);
            exit(1);
    }

    cpu->pc = next_pc;
    cpu->regs[0] = 0;  // x0 hardwired to 0
}

void cpu_step(Cpu *cpu) {
    uint32_t instr = cpu_fetch(cpu);
    cpu_execute(cpu, instr);
    cpu->cycle_count++;
}
