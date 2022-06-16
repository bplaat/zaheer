# The Kora 16-bit Processor Project
The Kora processor is a new processor based on the Neva processor, but extremely expanded and better in every way.
The processor has a classic CISC instruction with some RISC features which is inspired by the x86, 68000, ARM and RISC-V instruction sets.

## The sub projects
Also included in this git repo are other smaller said projects that together with the Kora Processor make a complete computer system called the Mako Computer System running the Zuko Operating System:

- **The Kora 16-bit Processor**
    - A simple 16-bit CISC processor with RISC features
    - [Documentation](docs/kora-processor.md)

- **The Lola I/O chip**
    - A simple I/O chip with I<sup>2</sup>C, SPI micro-sd card and PS/2 support
    - [Documentation](docs/lola-io-chip.md)

- **The Taro Video Chip**
    - A simple video generator that outputs an 640x480 VGA signal
    - Various text and bitmap modes
    - [Documentation](docs/taro-video-chip.md)

- **The Mako Computer System**
    - A simple complete system with the Kora, Lola and Taro chips
    - And a 512 KiB RAM chip with some ports
    - [Documentation](docs/mako-computer-system.md)

- **The Zuko Operating System**
    - A simple MS-DOS like Operating System for the Mako Computer
    - [Documentation](docs/zuko-operating-system.md)

## Two different platforms
The ultimate goal is that this entire project will run on two different platforms:
- A Web Simulator version like [neva-processor.ml](https://neva-processor.ml/)
- A Altera Cyclone II FPGA dev board version with other hardwear on a broadboard

## Roadmap things to do
- Writing documentation about the sub projects
- Online window manager and editor platform
- Online Kora assembler
- Online Lola simulator
- Online Taro simulator
- Online Mako simulator: sd card, real time clock etc...
- Zuko basic Operating System
- A few demo programs for Zuko
- Repeat everything for real life hardware and FPGA 🎉

## License
Copyright &copy; 2020 - present [Bastiaan van der Plaat](https://bastiaan.ml/)

Licensed under the [MIT](LICENSE) license
