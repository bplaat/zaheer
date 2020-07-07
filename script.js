(function () {
    // #################### ASSEMBLER CODE ####################

    // The assembler class
    class Assembler {
        constructor(text) {

        }

        assemble() {

        }
    }

    // #################### SIMULATOR CODE ####################

    // The processor class
    class Processor {

    }

    // The simulator class
    class Simulator {

    }

    // #################### UI CODE ####################

    // Disable CTRL+S key board shortcut for the pro hacker people that spam that key constant when to program...
    document.addEventListener('keydown', function (event) {
        if ((navigator.platform.match('Mac') ? event.metaKey : event.ctrlKey) && event.keyCode === 83) {
            event.preventDefault();
        }
    });

    // The code input field
    const codeInput = document.getElementById('code-input');

    const code = localStorage.getItem('code');
    if (code !== null) {
        codeInput.value = code;
    } else {
        codeInput.value = '';
    }

    codeInput.addEventListener('keydown', function (event) {
        // When you press backspace and your cursor is before 4 spaces delete them all at once
        if (event.keyCode === 8) {
            const start = this.selectionStart;
            const end = this.selectionEnd;

            if (start == end && this.value.substring(start - 4, start) == '    ') {
                event.preventDefault();
                this.value = this.value.substring(0, start - 4) + this.value.substring(start);
                this.selectionStart = this.selectionEnd = start - 4;
                localStorage.setItem('code', codeInput.value);
            }
        }

        // When you press tab place four spaces
        if (event.keyCode === 9) {
            event.preventDefault();
            const start = this.selectionStart;
            const end = this.selectionEnd;
            this.value = this.value.substring(0, start) + '    ' + this.value.substring(end);
            this.selectionStart = this.selectionEnd = start + 4;
            localStorage.setItem('code', codeInput.value);
        }

        // When you press enter go to next line with the indentation in spaces of the current line
        if (event.keyCode === 13) {
            event.preventDefault();
            const start = this.selectionStart;
            const end = this.selectionEnd;

            const line = this.value.substring(this.value.substring(0, start).lastIndexOf('\n') + 1);

            let spaces = 0;
            while (line.charAt(spaces) == ' ') {
                spaces++;
            }

            this.value = this.value.substring(0, start) + '\n' + ' '.repeat(spaces) + this.value.substring(end);
            this.selectionStart = this.selectionEnd = start + 1 + spaces;
            localStorage.setItem('code', codeInput.value);
        }
    });

    // When you change the code save it
    codeInput.addEventListener('input', function () {
        localStorage.setItem('code', codeInput.value);
    });

    // The machine output field
    const machineOutput = document.getElementById('machine-output');


    // const memory = new Uint8ClampedArray(2 ** 20);

    // const cpuid = {
    //     manufacturer: '~BPLAAT~',
    //     name: 'KORA',
    //     version: {
    //         high: 0,
    //         low: 1
    //     },
    //     features: 0b00000000
    // };

    // const registerNames = { z: 0, a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7,
    //     h: 8, ip: 9, sp: 10, bp: 11, cs: 12, ds: 13, ss: 14, flags: 15 };

    // const opcodes = {
    //     nop: 0x00, cpuid: 0x01, hlt: 0x02, load: 0x03, store: 0x04,
    //     add: 0x10, adc: 0x11, sub: 0x12, sbb: 0x13, cmp: 0x14, neg: 0x15
    // };

    // let registers;
    // let instructionBytes;

    // let step;

    // let opcode;
    // let addressMode;

    // let mode;
    // let size;
    // let condition;

    // let destinationRegister;
    // let sourceRegister;

    // function memory_read(segment, address) {
    //     return memory[(segment << 8) + address];
    // }

    // function reset () {
    //     registers = new Uint32Array(16);
    //     instructionBytes = new Uint8ClampedArray(7);

    //     step = 0;

    //     opcode = 0;
    //     addressMode = 0;

    //     mode = 0;
    //     size = 0;
    //     condition = 0;

    //     destinationRegister = 0;
    //     sourceRegister = 0;
    // }

    // function clock () {
    //     console.log('Clock', 'step =', step, 'ip =', registers[registerNames.ip]);

    //     // Fetch instruction
    //     if (step == 0) {
    //         step++;
    //         instructionBytes[0] = memory_read(registers[registerNames.cs], registers[registerNames.ip]++);
    //         opcode = instructionBytes[0] >> 1;
    //         addressMode = instructionBytes[0] & 1;
    //     }

    //     if (step == 1) {
    //         step++;
    //         instructionBytes[1] = memory_read(registers[registerNames.cs], registers[registerNames.ip]++);
    //         mode = instructionBytes[1] >> 6;
    //         size = (instructionBytes[1] >> 4) & 3;
    //         condition = instructionBytes[1] & 15;
    //     }

    //     if (step == 2) {
    //         step++;
    //         instructionBytes[2] = memory_read(registers[registerNames.cs], registers[registerNames.ip]++);
    //         destinationRegister = instructionBytes[2] >> 4
    //         sourceRegister = instructionBytes[2] & 15;
    //     }

    //     if ((mode == 1 || mode == 2 || mode == 3) && step == 3) {
    //         step++;
    //         instructionBytes[3] = memory_read(registers[registerNames.cs], registers[registerNames.ip]++);
    //     }

    //     if ((mode == 2 || mode == 3) && step == 4) {
    //         step++;
    //         instructionBytes[4] = memory_read(registers[registerNames.cs], registers[registerNames.ip]++);
    //     }

    //     if (mode == 3 && step == 5) {
    //         step++;
    //         instructionBytes[5] = memory_read(registers[registerNames.cs], registers[registerNames.ip]++);
    //     }

    //     if (mode == 3 && step == 6) {
    //         step++;
    //         instructionBytes[6] = memory_read(registers[registerNames.cs], registers[registerNames.ip]++);
    //     }

    //     // Execute instruction
    //     if ((mode == 0 && step == 3) || (mode == 1 && step == 4) || (mode == 2 && step == 5) || (mode == 3 && step == 7)) {
    //         step = 0;

    //         console.log('Execute!', instructionBytes);

    //         // Fetch byte or store
    //         if (addressMode) {

    //         }

    //         else {
    //             let data;

    //             if (mode == 0) {
    //                 data = registerNames[sourceRegister];
    //             }

    //             if (mode == 1) {
    //                 data = registerNames[sourceRegister] + instructionBytes[3];
    //             }

    //             if (mode == 2) {
    //                 data = registerNames[sourceRegister] + (instructionBytes[4] << 8) + instructionBytes[3];
    //             }

    //             if (mode == 3) {
    //                 data = registerNames[sourceRegister] + (instructionBytes[6] << 24) + (instructionBytes[5] << 16) + (instructionBytes[4] << 8) +  instructionBytes[3];
    //             }

    //             // Run instruction
    //             if (opcode == opcodes.nop) {
    //                 // Do nothing
    //             }

    //             if (opcode == opcodes.cpuid) {

    //             }

    //             if (opcode == opcodes.hlt) {

    //             }


    //             if (opcode == opcodes.load) {

    //             }

    //             if (opcode == opcodes.store) {

    //             }
    //         }
    //     }
    // }

    // reset();
    // clock();

    // function update () {
    //     clock();
    //     setTimeout(clock, 20);
    // }
    // update();
})();
