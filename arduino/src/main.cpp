#include <Arduino.h>
#include <SPI.h>
#include <SD.h>
#include "memory.hpp"
#include "kora.hpp"

#define SS_PIN 10

#define MEMORY_SIZE (uint32_t)(640) * 1024
#define MEMORY_REAL_SIZE 2 * 512
#define MEMORY_BANK_SIZE 256

#define BOOT_ADDRESS 0x0200
const char PROGMEM boot_file_name[] = "/BOOT.BIN";
#define BOOT_FILE_SIZE 512

Memory memory(MEMORY_SIZE, MEMORY_REAL_SIZE, MEMORY_BANK_SIZE);
Kora kora(memory);

bool running = false;

void setup() {
    // Init serial
    Serial.begin(9600);
    Serial.print(F("[INFO] Kora simulator v"));
    Serial.print(Kora::PROCESSOR_VERSION_HIGH);
    Serial.print(F("."));
    Serial.print(Kora::PROCESSOR_VERSION_LOW);
    Serial.println(F(" starting..."));

    // Init SD card
    Serial.println(F("[INFO] Beginning SD card..."));
    SD.begin(SS_PIN);

    // Init memory
    Serial.println(F("[INFO] Beginning memory..."));
    memory.begin();

    // Check if boot file exists
    if (!SD.exists((char *)boot_file_name)) {
        Serial.println(F("[ERROR] Can't find the '/boot.bin' bootloader file!"));
        return;
    }

    // Load boot sector in parts to memory
    Serial.println(F("[INFO] Reading bootloader..."));
    File bootFile = SD.open(boot_file_name, FILE_READ);
    const uint8_t bootFileParts = 4;
    uint8_t bootFileBuffer[BOOT_FILE_SIZE / bootFileParts];
    for (int8_t i = 0; i < bootFileParts; i++) {
        bootFile.read(&bootFileBuffer, BOOT_FILE_SIZE / bootFileParts);
        memory.writeBuffer(BOOT_ADDRESS + i * (BOOT_FILE_SIZE / bootFileParts), bootFileBuffer, BOOT_FILE_SIZE / bootFileParts);
    }
    bootFile.close();

    // Set Kora CPU entrypoint to boot sector
    Serial.println(F("[INFO] Kora running bootloader..."));
    kora.registers[static_cast<int8_t>(Kora::Register::IP)] = BOOT_ADDRESS;
    running = true;
}

void loop() {
    if (running) {
        // Do kora clock cycle
        kora.clock();
    }
}
