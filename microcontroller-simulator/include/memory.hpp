#pragma once

#include <stdint.h>
#include <SD.h>

struct Bank {
    uint32_t address;
    uint16_t usage;
    uint8_t *memory;
};

class Memory {
    public:
        uint32_t size;
        uint16_t realSize;
        uint16_t bankSize;
        File memoryFile;

        Bank *banks;
        uint8_t banksLength;

        Memory(uint32_t size, uint16_t realSize, uint16_t bankSize);

        void begin();

        uint16_t readWord(uint32_t address);

        uint8_t readByte(uint32_t address);

        void readBuffer(uint32_t address, uint8_t *buffer, uint16_t size);

        void writeWord(uint32_t address, uint16_t word);

        void writeByte(uint32_t address, uint8_t byte);

        void writeBuffer(uint32_t address, uint8_t *buffer, uint16_t size);

    private:
        Bank *loadBank(uint32_t address);
};
