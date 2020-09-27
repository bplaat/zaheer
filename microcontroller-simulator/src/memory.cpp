#include "memory.hpp"
#include <SD.h>

Memory::Memory(uint32_t size, uint16_t realSize, uint16_t bankSize)
    : size(size), realSize(realSize), bankSize(bankSize)
{
    banks = new Bank[realSize / bankSize];
}

void Memory::begin() {
    // Open memory file
    memoryFile = SD.open("/MEMORY.BIN", FILE_WRITE);

    // Clear / Create the memory file
    uint8_t zeroBuffer[bankSize];
    for (uint16_t i = 0; i < bankSize; i++) {
        zeroBuffer[i] = 0;
    }

    memoryFile.seek(0);
    for (uint32_t i = 0; i < size / bankSize; i++) {
        memoryFile.write(zeroBuffer, bankSize);
    }
    memoryFile.flush();
}

Bank *Memory::loadBank(uint32_t address) {
    // Calculate bank start address
    uint32_t bankAddress = (address / bankSize) * bankSize;

    // Check if bank already is loaded
    for (uint8_t i = 0; i < banksLength; i++) {
        if (address >= banks[i].address && address < banks[i].address + bankSize) {
            // Increment bank usage
            if (banks[i].usage < UINT16_MAX) {
                banks[i].usage++;
            }

            // Decrement other banks usage
            for (uint8_t j = 0; j < banksLength; j++) {
                if (j != i && banks[j].usage > 0) {
                    banks[j].usage--;
                }
            }

            // Return already loaded bank
            return &banks[i];
        }
    }

    // Check to add bank
    if (banksLength * bankSize <= realSize) {
        // Create bank
        int8_t newbankIndex = banksLength++;
        banks[newbankIndex].address = bankAddress;
        banks[newbankIndex].usage = 1;

        // Decrement other banks usage
        for (uint8_t j = 0; j < banksLength; j++) {
            if (j != newbankIndex && banks[j].usage > 0) {
                banks[j].usage--;
            }
        }

        // Read new bank and return
        banks[newbankIndex].memory = new uint8_t[bankSize];
        memoryFile.seek(bankAddress);
        memoryFile.read(banks[newbankIndex].memory, bankSize);
        return &banks[newbankIndex];
    }

    // Find lowest bank
    int8_t lowestBankIndex = 0;
    for (uint8_t i = 0; i < banksLength; i++) {
        if (banks[i].usage < banks[lowestBankIndex].usage) {
            lowestBankIndex = i;
        }
    }

    // Write lowest bank
    memoryFile.seek(banks[lowestBankIndex].address);
    memoryFile.write(banks[lowestBankIndex].memory, bankSize);
    memoryFile.flush();

    // Set new bank info
    banks[lowestBankIndex].address = bankAddress;
    banks[lowestBankIndex].usage = 1;

    // Decrement other banks
    for (uint8_t j = 0; j < banksLength; j++) {
        if (j != lowestBankIndex && banks[j].usage > 0) {
            banks[j].usage--;
        }
    }

    // Read new bank and return
    memoryFile.seek(bankAddress);
    memoryFile.read(banks[lowestBankIndex].memory, bankSize);
    return &banks[lowestBankIndex];
}

uint16_t Memory::readWord(uint32_t address) {
    Bank *bank = loadBank(address);
    uint8_t lowByte = bank->memory[address % bankSize];
    bank = loadBank(address + 1);
    return lowByte | (bank->memory[(address + 1) % bankSize] << 8);
}

uint8_t Memory::readByte(uint32_t address) {
    Bank *bank = loadBank(address);
    return bank->memory[address % bankSize];
}

void Memory::readBuffer(uint32_t address, uint8_t *buffer, uint16_t size) {
    for (uint16_t i = 0; i < size; i++) {
        Bank *bank = loadBank(address + i);
        buffer[i] = bank->memory[address % bankSize];
    }
}

void Memory::writeWord(uint32_t address, uint16_t word) {
    Bank *bank = loadBank(address);
    bank->memory[address % bankSize] = word & 255;
    bank = loadBank(address + 1);
    bank->memory[(address + 1) % bankSize] = word >> 8;
}

void Memory::writeByte(uint32_t address, uint8_t byte) {
    Bank *bank = loadBank(address);
    bank->memory[address % bankSize] = byte;
}

void Memory::writeBuffer(uint32_t address, uint8_t *buffer, uint16_t size) {
    for (uint16_t i = 0; i < size; i++) {
        Bank *bank = loadBank(address + i);
        bank->memory[address % bankSize] = buffer[i];
    }
}
