/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <stdint.h>

#include "../bus.h"

typedef struct {
    uint32_t regs[32];  // x0-x31, x0 is always 0
    uint32_t pc;
    uint64_t cycle_count;  // For rdcycle/rdcycleh
    Bus *bus;
} Cpu;

void cpu_init(Cpu *cpu, Bus *bus);

uint32_t cpu_fetch(Cpu *cpu);

void cpu_execute(Cpu *cpu, uint32_t instr);

void cpu_step(Cpu *cpu);
