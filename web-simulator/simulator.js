// ########################################################################################
// #################################### KORA ASSEMBLER ####################################
// ########################################################################################

// TODO

// ########################################################################################
// ##################################### KORA SIMULATOR ###################################
// ########################################################################################

function bit (number, bit) {
    return (number >> bit) & 1;
}

class Memory {
    constructor({ bus, rom, ramSize }) {
        this.bus = bus;
        this.rom = rom;
        this.ram = new Uint16Array(ramSize / 2);
    }

    reset() {
        for (let i = 0; i < this.ram.length; i++) {
            this.ram[i] = 0;
        }
    }

    clock() {
        if (this.bus.address & 1) {
            console.error('Memory address \'' + this.bus.address.toString(16).padStart(6, '0') + '\' not word aligned!');
            return;
        }

        const wordAddress = this.bus.address >> 1;

        if (this.bus.reading) {
            if (this.bus.address < this.ram.length * 2) {
                this.bus.data = this.ram[wordAddress];
            }

            if (this.bus.address >= (1 << 24) - this.rom.length * 2) {
                this.bus.data = this.rom[(this.bus.address - ((1 << 24) - this.rom.length * 2)) / 2];
            }
        }
        else if (this.bus.writing) {
            if (this.bus.address < this.ram.length * 2) {
                if (bit(this.bus.byteEnable, 0) && bit(this.bus.byteEnable, 1)) {
                    this.ram[wordAddress] = this.bus.data;
                }
                else if (bit(this.bus.byteEnable, 0)) {
                    this.ram[wordAddress] = (this.ram[wordAddress] & 0xff00) | (this.bus.data & 0x00ff);
                }
                else if (bit(this.bus.byteEnable, 1)) {
                    this.ram[wordAddress] = (this.bus.data & 0xff00) | (this.ram[wordAddress] & 0x00ff);
                }
            }
        }
    }
}


class Bus {
    constructor({ rom, ramSize, outputElement }) {
        this.reading = false;
        this.writing = false;
        this.byteEnable = 0b00;
        this.address = 0;
        this.data = 0;

        this.memory = new Memory({ bus: this, rom, ramSize });
        this.kora = new Kora({ bus: this });

        this.outputElement = outputElement;
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
            this.outputElement.textContent += (this.reading ? 'r' : (this.writing ? 'w' : '-')) + ' ' +
                this.address.toString(16).padStart(6, '0') + ' ' +
                this.data.toString(16).padStart(4, '0') + '\n';

            const outputLines = this.outputElement.textContent.split('\n');
            this.outputElement.textContent = outputLines.slice(Math.max(0, outputLines.length - 16), outputLines.length).join('\n');
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
            if (displacement >> 11) {
                data = this.registers[source] - displacement;
            } else {
                data = this.registers[source] + displacement;
            }
        }

        // Check halt flag
        if (haltFlag) {
            return;
        }

        // Set zero and sign flags
        const setZeroSignFlags = (data, clearCarryOverflowFlags) => {
            // Clear carry flag
            if (clearCarryOverflowFlags) {
                this.registers[Kora.Registers.FLAGS] &= ~(1 << Kora.Flags.CARRY);
            }

            // Set zero flag
            if (this.registers[destination] == 0) {
                this.registers[Kora.Registers.FLAGS] |= 1 << Kora.Flags.ZERO;
            } else {
                this.registers[Kora.Registers.FLAGS] &= ~(1 << Kora.Flags.ZERO);
            }

            // Set sign flag
            if (bit(this.registers[destination], 15)) {
                this.registers[Kora.Registers.FLAGS] |= 1 << Kora.Flags.SIGN;
            } else {
                this.registers[Kora.Registers.FLAGS] &= ~(1 << Kora.Flags.SIGN);
            }

            // Clear overflow flag
            if (clearCarryOverflowFlags) {
                this.registers[Kora.Registers.FLAGS] &= ~(1 << Kora.Flags.OVERFOW);
            }
        };

        // Set overflow flag
        const setOverflowFlag = (oldCarryFlag) => {
            if (oldCarryFlag != bit(this.registers[Kora.Registers.FLAGS], Kora.Flags.SIGN)) {
                this.registers[Kora.Registers.FLAGS] |= 1 << Kora.Flags.OVERFOW;
            } else {
                this.registers[Kora.Registers.FLAGS] &= ~(1 << Kora.Flags.OVERFOW);
            }
        };

        // States
        if (this.state == Kora.State.FETCH) {
            console.log('# FETCH FIRST');
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
                this.state = Kora.State.EXECUTE_FIRST;
                this.clock();
                return;
            }

            // Normal instruction
            else {
                // Check condition
                console.log('# CONDITION CHECK');

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
                    console.log('# FETCH SECOND');
                    this.bus.reading = true;
                    this.bus.writing = false;
                    this.bus.address = (this.registers[Kora.Registers.CS] << 8) + this.registers[Kora.Registers.IP];
                    this.registers[Kora.Registers.IP] += 2;
                    this.state = Kora.State.PROCESS_SECOND;
                    return;
                }

                // Skip instruction fetch next word
                else {
                    this.registers[Kora.Registers.IP] += 2;
                    this.state = Kora.State.FETCH;
                    return this.clock();
                }
            }
        }

        if (this.state == Kora.State.PROCESS_SECOND) {
            this.instructionWords[1] = this.bus.data;

            // Execute instruction
            this.state = Kora.State.EXECUTE_FIRST;
            return this.clock();
        }

        if (this.state == Kora.State.EXECUTE_FIRST) {
            console.log('# EXECUTE FIRST');

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
                setZeroSignFlags(this.registers[destination], true);
            }

            if (opcode == Kora.Opcodes.LW) {
                this.bus.reading = true;
                this.bus.writing = false;
                this.bus.address = (this.registers[Kora.Registers.DS] << 8) + data;
                this.state = Kora.State.EXECUTE_SECOND;
                return;
            }

            if (opcode == Kora.Opcodes.LB) {
                this.bus.reading = true;
                this.bus.writing = false;
                this.bus.address = (this.registers[Kora.Registers.DS] << 8) + ((data >> 1) << 1);
                this.state = Kora.State.EXECUTE_SECOND;
                return;
            }

            if (opcode == Kora.Opcodes.LBU) {
                this.bus.reading = true;
                this.bus.writing = false;
                this.bus.address = (this.registers[Kora.Registers.DS] << 8) + ((data >> 1) << 1);
                this.state = Kora.State.EXECUTE_SECOND;
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
                this.bus.byteEnable = data & 1 ? 0b10 : 0b01;
                this.bus.address = (this.registers[Kora.Registers.DS] << 8) + ((data >> 1) << 1);
                if (data & 1) {
                    this.bus.data = (this.registers[destination] & 0x00ff) << 8;
                } else {
                    this.bus.data = this.registers[destination] & 0x00ff;
                }
                this.state = Kora.State.FETCH;
                return;
            }

            // ######################################
            // ##### Jump and call instructions #####
            // ######################################

            if (opcode == Kora.Opcodes.JMP) {
                this.registers[destination] = this.registers[Kora.Registers.IP];

                this.registers[Kora.Registers.IP] = data;
            }

            if (opcode == Kora.Opcodes.JMPR) {
                this.registers[destination] = this.registers[Kora.Registers.IP];

                if (!isRegister && !isNormal && bit(data, 3)) {
                    this.registers[Kora.Registers.IP] -= data;
                } else {
                    this.registers[Kora.Registers.IP] += data;
                }
            }

            if (opcode == Kora.Opcodes.JMPF) {
                this.registers[Kora.Registers.CS] = this.registers[destination];

                this.registers[Kora.Registers.IP] = data;
            }

            if (opcode == Kora.Opcodes.CALL) {
                // Push ip on the stack
                this.bus.reading = false;
                this.bus.writing = true;
                this.bus.byteEnable = 0b11;
                this.bus.address = (this.registers[Kora.Registers.SS] << 8) + this.registers[Kora.Registers.SP];
                this.registers[Kora.Registers.SP] -= 2;
                this.bus.data = this.registers[Kora.Registers.IP];

                this.registers[Kora.Registers.IP] = data;

                this.state = Kora.State.FETCH;
                return;
            }

            if (opcode == Kora.Opcodes.CALLR) {
                // Push ip on the stack
                this.bus.reading = false;
                this.bus.writing = true;
                this.bus.byteEnable = 0b11;
                this.bus.address = (this.registers[Kora.Registers.SS] << 8) + this.registers[Kora.Registers.SP];
                this.registers[Kora.Registers.SP] -= 2;
                this.bus.data = this.registers[Kora.Registers.IP];

                if (!isRegister && !isNormal && bit(data, 3)) {
                    this.registers[Kora.Registers.IP] -= data;
                } else {
                    this.registers[Kora.Registers.IP] += data;
                }

                this.state = Kora.State.FETCH;
                return;
            }

            if (opcode == Kora.Opcodes.CALLF) {
                // Push cs on the stack
                this.bus.reading = false;
                this.bus.writing = true;
                this.bus.byteEnable = 0b11;
                this.bus.address = (this.registers[Kora.Registers.SS] << 8) + this.registers[Kora.Registers.SP];
                this.registers[Kora.Registers.SP] -= 2;
                this.bus.data = this.registers[Kora.Registers.CS];

                this.registers[Kora.Registers.CS] = this.registers[destination];

                this.state = Kora.State.EXECUTE_SECOND;
                return;
            }

            if (opcode == Kora.Opcodes.RET) {
                // Pop ip off the stack
                this.bus.reading = true;
                this.bus.writing = false;
                this.bus.address = (this.registers[Kora.Registers.SS] << 8) + this.registers[Kora.Registers.SP] + 2;
                this.registers[Kora.Registers.SP] += 2 + data;
                this.state = Kora.State.EXECUTE_SECOND;
                return;
            }

            if (opcode == Kora.Opcodes.RETF) {
                // Pop ip off the stack
                this.bus.reading = true;
                this.bus.writing = false;
                this.bus.address = (this.registers[Kora.Registers.SS] << 8) + this.registers[Kora.Registers.SP] + 2;
                this.registers[Kora.Registers.SP] += 2;
                this.state = Kora.State.EXECUTE_SECOND;
                return;
            }

            // ######################################
            // ####### Arithmetic instructions #######
            // ######################################

            if (opcode == Kora.Opcodes.ADD) {
                this.registers[destination] += data;

                // Set carry flag
                if (this.registers[destination] + data > 0xffff) {
                    this.registers[Kora.Registers.FLAGS] |= 1 << Kora.Flags.CARRY;
                } else {
                    this.registers[Kora.Registers.FLAGS] &= ~(1 << Kora.Flags.CARRY);
                }

                setZeroSignFlags(this.registers[destination], false);

                setOverflowFlag(carryFlag);
            }

            if (opcode == Kora.Opcodes.ADC) {
                this.registers[destination] += data + carryFlag;

                // Set carry flag
                if (this.registers[destination] + (data + carryFlag) > 0xffff) {
                    this.registers[Kora.Registers.FLAGS] |= 1 << Kora.Flags.CARRY;
                } else {
                    this.registers[Kora.Registers.FLAGS] &= ~(1 << Kora.Flags.CARRY);
                }

                setZeroSignFlags(this.registers[destination], false);

                setOverflowFlag(carryFlag);
            }

            if (opcode == Kora.Opcodes.SUB) {
                this.registers[destination] -= data;

                // Set carry flag
                if (this.registers[destination] - data < 0) {
                    this.registers[Kora.Registers.FLAGS] |= 1 << Kora.Flags.CARRY;
                } else {
                    this.registers[Kora.Registers.FLAGS] &= ~(1 << Kora.Flags.CARRY);
                }

                setZeroSignFlags(this.registers[destination], false);

                setOverflowFlag(carryFlag);
            }

            if (opcode == Kora.Opcodes.SBB) {
                this.registers[destination] -= data + carryFlag;

                // Set carry flag
                if (this.registers[destination] - (data + carryFlag) < 0) {
                    this.registers[Kora.Registers.FLAGS] |= 1 << Kora.Flags.CARRY;
                } else {
                    this.registers[Kora.Registers.FLAGS] &= ~(1 << Kora.Flags.CARRY);
                }

                setZeroSignFlags(this.registers[destination], false);

                setOverflowFlag(carryFlag);
            }

            if (opcode == Kora.Opcodes.NEG) {
                this.registers[destination] = -data;

                // Set carry flag
                if (-data < 0) {
                    this.registers[Kora.Registers.FLAGS] |= 1 << Kora.Flags.CARRY;
                } else {
                    this.registers[Kora.Registers.FLAGS] &= ~(1 << Kora.Flags.CARRY);
                }

                setZeroSignFlags(this.registers[destination], false);

                setOverflowFlag(carryFlag);
            }

            if (opcode == Kora.Opcodes.CMP) {
                // Set carry flag
                if (this.registers[destination] - data < 0) {
                    this.registers[Kora.Registers.FLAGS] |= 1 << Kora.Flags.CARRY;
                } else {
                    this.registers[Kora.Registers.FLAGS] &= ~(1 << Kora.Flags.CARRY);
                }

                setZeroSignFlags(new Uint16Array([ this.registers[destination] - data ])[0], false);

                setOverflowFlag(carryFlag);
            }

            // ######################################
            // ######## Bitwise instructions ########
            // ######################################

            if (opcode == Kora.Opcodes.AND) {
                this.registers[destination] &= data;
                setZeroSignFlags(this.registers[destination], true);
            }

            if (opcode == Kora.Opcodes.OR) {
                this.registers[destination] |= data;
                setZeroSignFlags(this.registers[destination], true);
            }

            if (opcode == Kora.Opcodes.XOR) {
                this.registers[destination] ^= data;
                setZeroSignFlags(this.registers[destination], true);
            }

            if (opcode == Kora.Opcodes.NOT) {
                this.registers[destination] = ~data;
                setZeroSignFlags(this.registers[destination], true);
            }

            if (opcode == Kora.Opcodes.TEST) {
                setZeroSignFlags(new Uint16Array([ this.registers[destination] & data ])[0], true);
            }

            if (opcode == Kora.Opcodes.SHL) {
                this.registers[destination] <<= data & 16;
                setZeroSignFlags(this.registers[destination], true);
            }

            if (opcode == Kora.Opcodes.SHR) {
                this.registers[destination] >>= data & 16;
                setZeroSignFlags(this.registers[destination], true);
            }

            if (opcode == Kora.Opcodes.SAR) {
                this.registers[destination] >>= data & 16;

                const signBit = bit(this.registers[destination], 15);
                for (let i = 0; i < data & 16; i++) {
                    if (signBit) {
                        this.registers[destination] |= 1 << (15 - i);
                    } else {
                        this.registers[destination] &= ~(1 << (15 - i));
                    }
                }

                setZeroSignFlags(this.registers[destination], true);
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
                this.state = Kora.State.EXECUTE_SECOND;
                return;
            }

            // Fetch next instruction word
            this.state = Kora.State.FETCH;
            return this.clock();
        }

        if (this.state == Kora.State.EXECUTE_SECOND) {
            console.log('# EXECUTE SECOND');

            if (opcode == Kora.Opcodes.LW) {
                this.registers[destination] = this.bus.data;
                setZeroSignFlags(this.registers[destination], true);
            }

            if (opcode == Kora.Opcodes.LB) {
                if (data & 1) {
                    this.registers[destination] = this.bus.data >> 8;
                } else {
                    this.registers[destination] = this.bus.data & 0x00ff;
                }

                const signBit = bit(this.registers[destination], 7);
                for (let i = 8; i < 16; i++) {
                    if (signBit) {
                        this.registers[destination] |= 1 << i;
                    } else {
                        this.registers[destination] &= ~(1 << i);
                    }
                }

                setZeroSignFlags(this.registers[destination], true);
            }

            if (opcode == Kora.Opcodes.LBU) {
                if (data & 1) {
                    this.registers[destination] = this.bus.data >> 8;
                } else {
                    this.registers[destination] = this.bus.data & 0x00ff;
                }

                setZeroSignFlags(this.registers[destination], true);
            }

            if (this.state = Kora.State.CALL_FAR) {
                this.bus.reading = false;
                this.bus.writing = true;
                this.bus.byteEnable = 0b11;
                this.bus.address = (this.registers[Kora.Registers.SS] << 8) + this.registers[Kora.Registers.SP];
                this.registers[Kora.Registers.SP] -= 2;
                this.bus.data = this.registers[Kora.Registers.IP];

                this.registers[Kora.Registers.IP] = data;

                this.state = Kora.State.FETCH;
                return;
            }

            if (opcode == Kora.Opcodes.RET) {
                this.registers[Kora.Registers.IP] = this.bus.data;
            }

            if (opcode == Kora.Opcodes.RETF) {
                // Pop cs off the stack
                this.bus.reading = true;
                this.bus.writing = false;
                this.bus.address = (this.registers[Kora.Registers.SS] << 8) + this.registers[Kora.Registers.SP] + 2;
                this.registers[Kora.Registers.SP] += 2 + data;
                this.state = Kora.State.EXECUTE_SECOND;
                return;
            }

            if (opcode == Kora.Opcodes.POP) {
                this.registers[destination] = this.bus.data;
                setZeroSignFlags(this.registers[destination], true);
            }

            // Fetch next instruction word
            this.state = Kora.State.FETCH;
            return this.clock();
        }

        if (this.state = Kora.State.EXECUTE_THIRD) {
            console.log('# EXECUTE THIRD');

            if (opcode == Kora.Opcodes.RETF) {
                this.registers[Kora.Registers.CS] = this.bus.data;
            }

            // Fetch next instruction word
            this.state = Kora.State.FETCH;
            return this.clock();
        }
    }
}

Kora.State = {
    FETCH: 0,
    PROCESS_FIRST: 1,
    PROCESS_SECOND: 2,
    EXECUTE_FIRST: 3,
    EXECUTE_SECOND: 4,
    EXECUTE_THIRD: 5
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

// ########################################################################################
// ##################################### WINDOW MANAGER ###################################
// ########################################################################################

// Icons
const Icons = {
    MINIMIZE: '<svg class="icon" viewBox="0 0 24 24"><path fill="currentColor" d="M20,14H4V10H20" /></svg>',
    MAXIMIZE: '<svg class="icon" viewBox="0 0 24 24"><path fill="currentColor" d="M4,4H20V20H4V4M6,8V18H18V8H6Z" /></svg>',
    RESTORE: '<svg class="icon" viewBox="0 0 24 24"><path fill="currentColor" d="M4,8H8V4H20V16H16V20H4V8M16,8V14H18V6H10V8H16M6,12V18H14V12H6Z" /></svg>',
    CLOSE: '<svg class="icon" viewBox="0 0 24 24"><path fill="currentColor" d="M13.46,12L19,17.54V19H17.54L12,13.46L6.46,19H5V17.54L10.54,12L5,6.46V5H6.46L12,10.54L17.54,5H19V6.46L13.46,12Z" /></svg>'
};

// Windows
const windows = [];

window.addEventListener('mousemove', function (event) {
    if (Window._drag.enabled) {
        Window._drag.window.x = event.clientX - Window._drag.offset.x;
        Window._drag.window.y = event.clientY - Window._drag.offset.y;

        Window._drag.window._windowElement.style.top = Window._drag.window.y + 'px';
        Window._drag.window._windowElement.style.left = Window._drag.window.x + 'px';
    }
});

window.addEventListener('mouseup', function (event) {
    if (Window._drag.enabled) {
        Window._drag.enabled = false;
    }
});

// Window class
class Window {
    constructor ({
        title = 'Untitled', x = -1, y = -1, width = 640, height = 480,
        minimizable = true, maximizable = true, closable = true,
        onCreate, onClose = undefined
    }) {
        this.id = Window._idCounter++;
        this.title = title;
        if (x == -1) {
            x = (window.innerWidth - width) / 2;
        }
        this.x = x;
        if (y == -1) {
            y = (window.innerHeight - height) / 2;
        }
        this.y = y;
        this.width = width;
        this.height = height;
        this.minimizable = minimizable;
        this.maximizable = maximizable;
        this.closable = closable;
        this.closed = false;

        this.onCreate = onCreate;
        this.onClose = onClose;

        // Remove window focus
        if (Window._focusWindow != undefined) {
            Window._focusWindow._windowElement.classList.remove('window-has-focus');
            Window._previousFocusWindow = Window._focusWindow;
        }
        Window._focusWindow = this;

        // Create window element
        this._windowElement = document.createElement('div');
        this._windowElement.className = 'window window-has-focus';
        this._windowElement.style.top = this.y + 'px';
        this._windowElement.style.left = this.x + 'px';
        this._windowElement.style.width = this.width + 'px';
        this._windowElement.style.height = (this.height + Window.HEADER_HEIGHT) + 'px';
        this._windowElement.style.zIndex = Window._zIndexCounter++;
        this._windowElement.addEventListener('mousedown', (event) => {
            // When not in focus switch window focus
            if (!this._windowElement.classList.contains('window-has-focus')) {
                this.focus();
            }
        });
        Window._containerElement.appendChild(this._windowElement);

        // Create window header element
        this._windowHeaderElement = document.createElement('div');
        this._windowHeaderElement.className = 'window-header';
        this._windowHeaderElement.addEventListener('mousedown', (event) => {
            if (
                event.target.classList.contains('window-header-title') ||
                event.target.classList.contains('window-header-controls')
            ) {
                Window._drag.enabled = true;
                Window._drag.window = this;
                Window._drag.offset.x = event.clientX - this.x;
                Window._drag.offset.y = event.clientY - this.y;
            }
        });
        this._windowElement.appendChild(this._windowHeaderElement);

        const windowHeaderTitleElement = document.createElement('div');
        windowHeaderTitleElement.className = 'window-header-title';
        windowHeaderTitleElement.textContent = title;
        this._windowHeaderElement.appendChild(windowHeaderTitleElement);

        const windowHeaderControlsElement = document.createElement('div');
        windowHeaderControlsElement.className = 'window-header-controls';
        this._windowHeaderElement.appendChild(windowHeaderControlsElement);

        const windowHeaderMinimizeButtonElement = document.createElement('button');
        windowHeaderMinimizeButtonElement.className = 'window-header-button';
        if (!minimizable) windowHeaderCloseButtonElement.disabled = true;
        windowHeaderMinimizeButtonElement.innerHTML = Icons.MINIMIZE;
        windowHeaderControlsElement.appendChild(windowHeaderMinimizeButtonElement);

        const windowHeaderMaximizeButtonElement = document.createElement('button');
        windowHeaderMaximizeButtonElement.className = 'window-header-button';
        if (!maximizable) windowHeaderCloseButtonElement.disabled = true;
        windowHeaderMaximizeButtonElement.innerHTML = Icons.MAXIMIZE;
        windowHeaderControlsElement.appendChild(windowHeaderMaximizeButtonElement);

        const windowHeaderCloseButtonElement = document.createElement('button');
        windowHeaderCloseButtonElement.className = 'window-header-button';
        if (!closable) windowHeaderCloseButtonElement.disabled = true;
        windowHeaderCloseButtonElement.innerHTML = Icons.CLOSE;
        windowHeaderCloseButtonElement.addEventListener('click', () => {
            this.close();
        });
        windowHeaderControlsElement.appendChild(windowHeaderCloseButtonElement);

        // Create window body element
        this._windowBodyElement = document.createElement('div');
        this._windowBodyElement.className = 'window-body';
        this._windowElement.appendChild(this._windowBodyElement);

        onCreate.bind(this)(this._windowBodyElement);

        // Add window to the windows
        windows.push(this);
    }

    focus () {
        // Remove focus from previous window
        Window._focusWindow._windowElement.classList.remove('window-has-focus');
        Window._previousFocusWindow = Window._focusWindow;

        // Add focus to this window
        Window._focusWindow = this;
        this._windowElement.classList.add('window-has-focus');
        this._windowElement.style.zIndex = Window._zIndexCounter++;
    }

    close () {
        // Set window is closed
        this.closed = true;

        // Run close listener
        if (this.onClose != undefined) {
            this.onClose.bind(this)();
        }

        // Remove window instance
        for (let i = 0; i < windows.length; i++) {
            if (windows[i].id == this.id) {
                windows.splice(i);
                break;
            }
        }

        // Remove window element
        Window._containerElement.removeChild(this._windowElement);

        // Set previous window focus
        if (Window._previousFocusWindow != undefined) {
            Window._previousFocusWindow.focus();
        }
    }
}

Window.HEADER_HEIGHT = 49;

Window._containerElement = document.getElementById('window-manager');
Window._focusWindow = undefined;
Window._previousFocusWindow = undefined;
Window._idCounter = 0;
Window._zIndexCounter = 0;
Window._drag = {
    enabled: false,
    window: undefined,
    offset: {
        x: undefined,
        y: undefined
    }
};

// Launcher window
let launcherWindow = undefined;
function openLauncher() {
    if (launcherWindow == undefined || launcherWindow.closed) {
        launcherWindow = new Window({
            title: 'Kora Launcher',
            closable: false,

            onCreate: function (body) {
                body.innerHTML = '<div class="container">' +
                    '<h2>Welcome to the Kora Web Environment!</h2>' +
                    '<p>You can open diffrent tools to create and test programs for the Kora processor platform</p>' +
                    '<p><button onclick="openAssembler()">Open Kora Assembler</button></p>' +
                    '<p><button onclick="openSimulator()">Open Kora Simulator</button></p>' +
                    '</div>';
            }
        });
    } else {
        launcherWindow.focus();
    }
}

// Assembler window
let assemblerWindow = undefined;
function openAssembler() {
    if (assemblerWindow == undefined || assemblerWindow.closed) {
        assemblerWindow = new Window({
            title: 'Kora Assembler',
            width: 800,
            height: 600,

            onCreate: function (body) {
                body.innerHTML = '<div class="container">' +
                    '<h2>Kora Assembler</h2>' +
                    '</div>';
            }
        });
    } else {
        assemblerWindow.focus();
    }
}

// Simulator window
let simulatorWindow = undefined;
function openSimulator() {
    if (simulatorWindow == undefined || simulatorWindow.closed) {
        simulatorWindow = new Window({
            title: 'Kora Simulator',
            width: 800,
            height: 600,

            onCreate: function (body) {
                body.innerHTML = '<div class="container">' +
                    '<h2>Kora Simulator</h2>' +
                    '<pre></pre>' +
                    '</div>';

                // Create ROM the hard way
                const rom = new Uint16Array((1 * 256) / 2);

                let p = 0;

                // mov a, 4
                rom[p++] = (Kora.Opcodes.MOV << 10) | (Kora.Mode.IMMEDIATE_NORMAL << 8) | (Kora.Registers.A << 4) | (Kora.Conditions.ALWAYS);
                rom[p++] = -2;

                // mov byte [1], a -> sb a, 1
                rom[p++] = (Kora.Opcodes.SB << 10) | (Kora.Mode.IMMEDIATE_SHORT << 8) | (Kora.Registers.A << 4) | (1);

                // mov b, byte [1] -> lbu a, 1
                rom[p++] = (Kora.Opcodes.LBU << 10) | (Kora.Mode.IMMEDIATE_SHORT << 8) | (Kora.Registers.B << 4) | (1);

                // subc b, 5
                rom[p++] = (Kora.Opcodes.SUB << 10) | (Kora.Mode.IMMEDIATE_NORMAL << 8) | (Kora.Registers.B << 4) | (Kora.Conditions.CARRY);
                rom[p++] = 5;

                // mov c, 9
                rom[p++] = (Kora.Opcodes.MOV << 10) | (Kora.Mode.IMMEDIATE_SHORT << 8) | (Kora.Registers.C << 4) | (9);

                // halt -> or flags, 1 << 8
                rom[p++] = (Kora.Opcodes.OR << 10) | (Kora.Mode.IMMEDIATE_NORMAL << 8) | (Kora.Registers.FLAGS << 4) | (Kora.Conditions.ALWAYS);
                rom[p++] = 1 << Kora.Flags.HALT;

                const bus = new Bus({ rom, ramSize: 6 * 512, outputElement: body.children[0].children[1] });

                bus.reset();

                bus.clock();

                this.clockInterval = setInterval(function () {
                    bus.clock();
                }, 1000 / 10);
            },

            onClose: function () {
                if (this.clockInterval != undefined) {
                    clearInterval(this.clockInterval);
                }
            }
        });
    } else {
        simulatorWindow.focus();
    }
}

openLauncher();
