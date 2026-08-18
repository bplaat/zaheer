# Zaheer Computer Platform

A work-in-progress computer desktop GUI platform running on cheap FPGAs

## Getting Started

- Install [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) and add it to `PATH`.
- Run commands from the repository root.

## Make Commands

- `make` or `make build` - build the FPGA bitstream at `target/top.fs`.
- `make test` - run the assembler, UART, text-mode, timing, and TMDS tests.
- `make load` - load the bitstream onto the FPGA until power-off.
- `make flash` - write the bitstream to persistent FPGA flash.
- `make serial` - open the configured serial port at 115200 baud.
- `make clean` - remove generated files in `target/`.

## License

Copyright © 2020-2026 [Bastiaan van der Plaat](https://github.com/bplaat)

Licensed under the [MIT](LICENSE) license.
