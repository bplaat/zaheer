function bit (number, bit) {
    return (number >> bit) % 2 != 0;
}

class Memory {
    constructor({ bus, rom, ramSize }) {
        this.rom = rom;
        this.ram = new Uint16Array(ramSize / 2);
    }

    reset() {
        for (let i = 0; i < this.ram.length; i++) {
            this.ram[i] = 0;
        }
    }

    clock() {
        if (bus.reading) {
            if (bus.address < this.ram.length * 2) {
                bus.data = this.ram[bus.address / 2];
            }

            if (bus.address >= (1 << 24) - this.rom.length * 2) {
                bus.data = this.rom[(bus.address - ((1 << 24) - this.rom.length * 2)) / 2];
            }
        }
        else if (bus.writing) {
            if (bus.address < this.ram.length * 2) {
                if (bit(bus.byteEnable, 0) && bit(bus.byteEnable, 1)) {
                    this.ram[bus.address / 2] = bus.data;
                }
                else if (bit(bus.byteEnable, 0)) {
                    this.ram[bus.address / 2] = (this.ram[bus.address / 2] & 0xff00) | (bus.data & 0x00ff);
                }
                else if (bit(bus.byteEnable, 1)) {
                    this.ram[bus.address / 2] = (bus.data & 0xff00) | (this.ram[bus.address / 2] & 0x00ff);
                }
            }
        }
    }
}

const busOutputLabel = document.getElementById('bus-output-label');

class Bus {
    constructor() {
        const rom = new Uint16Array((1 * 256) / 2);

        let p = 0;

        // mov a, 4
        rom[p++] = (Kora.Opcodes.MOV << 10) | (Kora.Mode.IMMEDIATE_SHORT << 8) | (Kora.Registers.A << 4) | (4);

        // mov word [0], a -> sw a, 0
        rom[p++] = (Kora.Opcodes.SW << 10) | (Kora.Mode.IMMEDIATE_SHORT << 8) | (Kora.Registers.A << 4) | (0);

        // mov b, word [0] -> lw a, 0
        rom[p++] = (Kora.Opcodes.LW << 10) | (Kora.Mode.IMMEDIATE_SHORT << 8) | (Kora.Registers.B << 4) | (0);

        // subc b, 5
        rom[p++] = (Kora.Opcodes.SUB << 10) | (Kora.Mode.IMMEDIATE_NORMAL << 8) | (Kora.Registers.B << 4) | (Kora.Conditions.CARRY);
        rom[p++] = 5;

        // mov c, 9
        rom[p++] = (Kora.Opcodes.MOV << 10) | (Kora.Mode.IMMEDIATE_SHORT << 8) | (Kora.Registers.C << 4) | (9);

        // halt -> or flags, 1 << 8
        rom[p++] = (Kora.Opcodes.OR << 10) | (Kora.Mode.IMMEDIATE_NORMAL << 8) | (Kora.Registers.FLAGS << 4) | (Kora.Conditions.ALWAYS);
        rom[p++] = 1 << Kora.Flags.HALT;

        this.reading = false;
        this.writing = false;
        this.byteEnable = 0b00;
        this.address = 0;
        this.data = 0;

        this.memory = new Memory({ bus: this, rom, ramSize: 6 * 512});
        this.kora = new Kora({ bus: this });
    }

    reset() {
        this.memory.reset();
        this.kora.reset();
    }

    clock() {
        this.memory.clock();
        this.kora.clock();

        console.log('Kora registers: ' + this.kora.registers.join(' '));

        const haltFlag = bit(this.kora.registers[Kora.Registers.FLAGS], Kora.Flags.HALT);
        if (!haltFlag) {
            busOutputLabel.textContent += (this.reading ? 'r' : (this.writing ? 'w' : '-')) + ' ' +
                this.address.toString(16).padStart(6, '0') + ' ' +
                this.data.toString(16).padStart(4, '0') + '\n';

            const outputLines = busOutputLabel.textContent.split('\n');
            busOutputLabel.textContent = outputLines.slice(Math.max(0, outputLines.length - 40), outputLines.length).join('\n');
        }
    }
}

class Kora {
    constructor ({ bus }) {
        this.bus = bus;

        this.state = Kora.State.FETCH;
        this.registers = new Uint16Array(18);
        this.instructionWords = new Uint16Array(2);

        this.cpuid = {
            manufacterId: 0x2807, // Bastiaan van der Plaat
            processorId: 0xB0EF, // Kora Processor
            processorVersion: 0x0001, // Version 0.1
            processorFeatures: 0b0000000000000000, // No extra features
            processorManufacterDate: Date.now() / 1000 // Current time
        };
    }

    reset () {
        this.state = Kora.State.FETCH;

        for (let i = 0; i < this.registers.length; i++) {
            this.registers[i] = 0;
        }
        this.registers[Kora.Registers.CS] = 0xffff;

        for (let i = 0; i < this.instructionWords.length; i++) {
            this.instructionWords[i] = 0;
        }
    }

    clock () {
        // Reset read/write
        this.bus.reading = false;
        this.bus.writing = false;

        // Read flags bits
        const carryFlag = bit(this.registers[Kora.Registers.FLAGS], Kora.Flags.CARRY);
        const zeroFlag = bit(this.registers[Kora.Registers.FLAGS], Kora.Flags.ZERO);
        const signFlag = bit(this.registers[Kora.Registers.FLAGS], Kora.Flags.SIGN);
        const overflowFlag = bit(this.registers[Kora.Registers.FLAGS], Kora.Flags.OVERFOW);
        const haltFlag = bit(this.registers[Kora.Registers.FLAGS], Kora.Flags.HALT);

        // Parse instruction
        const opcode = this.instructionWords[0] >> (8 + 2);
        const isRegister = bit(this.instructionWords[0], 9);
        const isNormal = bit(this.instructionWords[0], 8);
        const destination = (this.instructionWords[0] >> 4) & 15;
        const condition = this.instructionWords[0] & 15;

        // Do mode data fetch
        let data;

        // Immediate small mode
        if (!isRegister && !isNormal) {
            data = condition;
        }

        // Immediate normal mode
        if (!isRegister && isNormal) {
            data = this.instructionWords[1];
        }

        // Register small mode
        if (isRegister && !isNormal) {
            data = this.registers[condition];
        }

        // Register normal mode
        if (isRegister && isNormal) {
            const source = this.instructionWords[1] >> 12;
            const displacement = this.instructionWords[1] & 4095;
            if ((displacement >> 11) == 1) {
                data = this.registers[source] - displacement;
            } else {
                data = this.registers[source] + displacement;
            }
        }

        // Check halt flag
        if (haltFlag) {
            return;
        }

        if (this.state == Kora.State.FETCH) {
            console.log('# FETCH');
            this.bus.reading = true;
            this.bus.writing = false;
            this.bus.address = (this.registers[Kora.Registers.CS] << 8) + this.registers[Kora.Registers.IP];
            this.registers[Kora.Registers.IP] += 2;
            this.state = Kora.State.PROCESS_FIRST;
            return;
        }

        if (this.state == Kora.State.PROCESS_FIRST) {
            this.instructionWords[0] = this.bus.data;

            // Small instruction
            const isNormal = bit(this.instructionWords[0], 8);
            if (!isNormal) {
                this.state = Kora.State.EXECUTE;
                this.clock();
                return;
            }

            // Normal instruction
            else {
                // Check condition
                console.log('# CONDITION');

                const condition = this.instructionWords[0] & 15;
                let passed;

                if (condition == Kora.Conditions.ALWAYS) {
                    passed = true;
                }

                if (condition == Kora.Conditions.CARRY) {
                    passed = carryFlag;
                }
                if (condition == Kora.Conditions.NOT_CARRY) {
                    passed = !carryFlag;
                }

                if (condition == Kora.Conditions.ZERO) {
                    passed = zeroFlag;
                }
                if (condition == Kora.Conditions.NOT_ZERO) {
                    passed = !zeroFlag;
                }

                if (condition == Kora.Conditions.SIGN) {
                    passed = signFlag;
                }
                if (condition == Kora.Conditions.NOT_SIGN) {
                    passed = !signFlag;
                }

                if (condition == Kora.Conditions.OVERFLOW) {
                    passed = overflowFlag;
                }
                if (condition == Kora.Conditions.NOT_OVERFLOW) {
                    passed = !overflowFlag;
                }

                if (condition == Kora.Conditions.ABOVE) {
                    passed = !carryFlag && !zeroFlag;
                }
                if (condition == Kora.Conditions.NOT_ABOVE) {
                    passed = carryFlag || zeroFlag;
                }

                if (condition == Kora.Conditions.LESSER) {
                    passed = signFlag != overflowFlag;
                }
                if (condition == Kora.Conditions.NOT_LESSER) {
                    passed = signFlag == overflowFlag;
                }

                if (condition == Kora.Conditions.GREATER) {
                    passed = zeroFlag && (signFlag == overflowFlag);
                }
                if (condition == Kora.Conditions.NOT_GREATER) {
                    passed = !zeroFlag || (signFlag != overflowFlag);
                }

                // Fetch next word
                if (passed) {
                    console.log('# FETCH');
                    this.bus.reading = true;
                    this.bus.writing = false;
                    this.bus.address = (this.registers[Kora.Registers.CS] << 8) + this.registers[Kora.Registers.IP];
                    this.registers[Kora.Registers.IP] += 2;
                    this.state = Kora.State.PROCESS_SECOND;
                    return;
                }

                // Skip instruction fetch next word
                else {
                    console.log('# SKIP FETCH');
                    this.bus.reading = true;
                    this.bus.writing = false;
                    this.bus.address = (this.registers[Kora.Registers.CS] << 8) + this.registers[Kora.Registers.IP] + 2;
                    this.registers[Kora.Registers.IP] += 2 + 2;
                    this.state = Kora.State.PROCESS_FIRST;
                    return;
                }
            }
        }

        if (this.state == Kora.State.PROCESS_SECOND) {
            this.instructionWords[1] = this.bus.data;
            this.state = Kora.State.EXECUTE;
            this.clock();
            return;
        }

        if (this.state == Kora.State.EXECUTE) {
            console.log('# EXECUTE');

            // #######################################
            // ########## Special instructions #######
            // #######################################

            if (opcode == Kora.Opcodes.NOP) {
                // Do nothing
            }

            if (opcode == Kora.Opcodes.CPUID) {
                this.registers[Kora.Registers.A0] = this.cpuid.manufacterId;
                this.registers[Kora.Registers.A1] = this.cpuid.processorId;
                this.registers[Kora.Registers.A2] = this.cpuid.processorVersion;
                this.registers[Kora.Registers.A3] = this.cpuid.processorFeatures;
                this.registers[Kora.Registers.T1] = this.cpuid.processorManufacterDate >> 16;
                this.registers[Kora.Registers.T2] = this.cpuid.processorManufacterDate & 0xffff;
            }

            // #######################################
            // ## Move, load and store instructions ##
            // #######################################

            if (opcode == Kora.Opcodes.MOV) {
                this.registers[destination] = data;
            }

            if (opcode == Kora.Opcodes.LW) {
                this.bus.reading = true;
                this.bus.writing = false;
                this.bus.address = (this.registers[Kora.Registers.DS] << 8) + data;
                this.state = Kora.State.WRITEBACK;
                return;
            }

            if (opcode == Kora.Opcodes.LB) {
                this.bus.reading = true;
                this.bus.writing = false;
                this.bus.address = (this.registers[Kora.Registers.DS] << 8) + ((data >> 1) << 1);
                this.state = Kora.State.WRITEBACK;
                return;
            }

            if (opcode == Kora.Opcodes.LBU) {
                this.bus.reading = true;
                this.bus.writing = false;
                this.bus.address = (this.registers[Kora.Registers.DS] << 8) + ((data >> 1) << 1);
                this.state = Kora.State.WRITEBACK;
                return;
            }

            if (opcode == Kora.Opcodes.SW) {
                this.bus.reading = false;
                this.bus.writing = true;
                this.bus.byteEnable = 0b11;
                this.bus.address = (this.registers[Kora.Registers.DS] << 8) + data;
                this.bus.data = this.registers[destination];
                this.state = Kora.State.FETCH;
                return;
            }

            if (opcode == Kora.Opcodes.SB) {
                this.bus.reading = false;
                this.bus.writing = true;
                this.bus.byteEnable = data % 2 == 1 ? 0b10 : 0b01;
                this.bus.address = (this.registers[Kora.Registers.DS] << 8) + ((data >> 1) << 1);
                this.bus.data = this.registers[destination];
                this.state = Kora.State.FETCH;
                return;
            }

            // ######################################
            // ##### Jump and call instructions #####
            // ######################################

            if (opcode == Kora.Opcodes.JMP) {
                // TODO
            }

            if (opcode == Kora.Opcodes.JMPR) {
                // TODO
            }

            if (opcode == Kora.Opcodes.JMPF) {
                // TODO
            }

            if (opcode == Kora.Opcodes.CALL) {
                // TODO
            }

            if (opcode == Kora.Opcodes.CALLR) {
                // TODO
            }

            if (opcode == Kora.Opcodes.CALLF) {
                // TODO
            }

            if (opcode == Kora.Opcodes.RET) {
                // TODO
            }

            if (opcode == Kora.Opcodes.RETF) {
                // TODO
            }

            // ######################################
            // ####### Arithmetic instructions #######
            // ######################################

            if (opcode == Kora.Opcodes.ADD) {
                this.registers[destination] += data;
                // set flags
            }

            if (opcode == Kora.Opcodes.ADC) {
                this.registers[destination] += data + carryFlag;
                // set flags
            }

            if (opcode == Kora.Opcodes.SUB) {
                this.registers[destination] -= data;
                // set flags
            }

            if (opcode == Kora.Opcodes.SBB) {
                this.registers[destination] -= data + carryFlag;
                // set flags
            }

            if (opcode == Kora.Opcodes.NEG) {
                this.registers[destination] = -data;
                // set flags
            }

            if (opcode == Kora.Opcodes.CMP) {
                // set flags
            }

            // ######################################
            // ######## Bitwise instructions ########
            // ######################################

            if (opcode == Kora.Opcodes.AND) {
                this.registers[destination] &= data;
                // set flags
            }

            if (opcode == Kora.Opcodes.OR) {
                this.registers[destination] |= data;
                // set flags
            }

            if (opcode == Kora.Opcodes.XOR) {
                this.registers[destination] ^= data;
                // set flags
            }

            if (opcode == Kora.Opcodes.NOT) {
                this.registers[destination] = ~data;
                // set flags
            }

            if (opcode == Kora.Opcodes.TEST) {
                // set flags
            }

            if (opcode == Kora.Opcodes.SHL) {
                this.registers[destination] <<= data & 16;
                // set flags
            }

            if (opcode == Kora.Opcodes.SHR) {
                this.registers[destination] >>= data & 16;
                // set flags
            }

            if (opcode == Kora.Opcodes.SAR) {
                this.registers[destination] >>>= data & 16;
                // set flags
            }

            // ######################################
            // ######### Stack instructions #########
            // ######################################

            if (opcode == Kora.Opcodes.PUSH) {
                this.bus.reading = false;
                this.bus.writing = true;
                this.bus.byteEnable = 0b11;
                this.bus.address = (this.registers[Kora.Registers.SS] << 8) + this.registers[Kora.Registers.SP];
                this.registers[Kora.Registers.SP] -= 2;
                this.bus.data = data;
                this.state = Kora.State.FETCH;
                return;
            }

            if (opcode == Kora.Opcodes.POP) {
                this.bus.reading = true;
                this.bus.writing = false;
                this.bus.address = (this.registers[Kora.Registers.SS] << 8) + this.registers[Kora.Registers.SP] + 2;
                this.registers[Kora.Registers.SP] += 2;
                this.state = Kora.State.WRITEBACK;
                return;
            }

            // Fetch next first word
            console.log('# FETCH');
            this.bus.reading = true;
            this.bus.writing = false;
            this.bus.address = (this.registers[Kora.Registers.CS] << 8) + this.registers[Kora.Registers.IP];
            this.registers[Kora.Registers.IP] += 2;
            this.state = Kora.State.PROCESS_FIRST;
            return;
        }

        if (this.state == Kora.State.WRITEBACK) {
            console.log('# WRITEBACK');

            if (opcode == Kora.Opcodes.LW) {
                this.registers[destination] = this.bus.data;
            }

            if (opcode == Kora.Opcodes.LB) {
                this.registers[destination] = (bit(this.bus.data, 7) << 15) | (this.bus.data & 0x80);
            }

            if (opcode == Kora.Opcodes.LBU) {
                this.registers[destination] = this.bus.data & 0x00ff;
            }

            if (opcode == Kora.Opcodes.POP) {
                this.registers[destination] = this.bus.data;
            }

            // Fetch next instruction
            console.log('# FETCH');
            this.bus.reading = true;
            this.bus.writing = false;
            this.bus.address = (this.registers[Kora.Registers.CS] << 8) + this.registers[Kora.Registers.IP];
            this.registers[Kora.Registers.IP] += 2;
            this.state = Kora.State.PROCESS_FIRST;
            return;
        }
    }
}

Kora.State = {
    FETCH: 0,
    PROCESS_FIRST: 1,
    PROCESS_SECOND: 2,
    EXECUTE: 3,
    WRITEBACK: 4
};

Kora.Registers = {
    A: 0, T0: 0,
    B: 1, T1: 1,
    C: 2, T2: 2,
    D: 3, S0: 3,
    E: 4, S1: 4,
    F: 5, S2: 5,
    G: 6, A0: 6,
    H: 7, A1: 7,
    I: 8, A2: 8,
    J: 9, A3: 9,
    K: 10, BP: 10,
    L: 11, RP: 11,

    DS: 12,
    SS: 13,
    SP: 14,
    FLAGS: 15,

    CS: 16,
    IP: 17
};

Kora.Flags = {
    CARRY: 0,
    ZERO: 1,
    SIGN: 2,
    OVERFOW: 3,

    HALT: 8
};

Kora.Conditions = {
    ALWAYS: 0,

    CARRY: 1,
    NOT_CARRY: 2,

    ZERO: 3,
    NOT_ZERO: 4,

    SIGN: 5,
    NOT_SIGN: 6,

    OVERFLOW: 7,
    NOT_OVERFLOW: 8,

    ABOVE: 9,
    NOT_ABOVE: 10,

    LOWER: 11,
    NOT_LOWER: 12,

    GREATER: 13,
    NOT_GREATER: 14
};

Kora.Mode = {
    IMMEDIATE_SHORT: 0,
    IMMEDIATE_NORMAL: 1,
    REGISTER_SHORT: 2,
    REGISTER_NORMAL: 3
};

Kora.Opcodes = {
    NOP: 0,
    CPUID: 1,

    MOV: 2,
    LW: 3,
    LB: 4,
    LBU: 5,
    SW: 6,
    SB: 7,

    JMP: 8,
    JMPR: 9,
    JMPF: 10,
    CALL: 11,
    CALLR: 12,
    CALLF: 13,
    RET: 14,
    RETF: 15,

    ADD: 16,
    ADC: 17,
    SUB: 18,
    SBB: 19,
    NEG: 20,
    CMP: 21,

    AND: 22,
    OR: 23,
    XOR: 24,
    NOT: 25,
    TEST: 26,
    SHL: 27,
    SHR: 28,
    SAR: 29,

    PUSH: 30,
    POP: 31
};

const bus = new Bus();

bus.reset();

bus.clock();

setInterval(function () {
    bus.clock();
}, 500);
