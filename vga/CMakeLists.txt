cmake_minimum_required(VERSION 3.13)

include(pico_sdk_import.cmake)

project(kora)

pico_sdk_init()

add_executable(kora)

pico_generate_pio_header(kora ${CMAKE_CURRENT_LIST_DIR}/hsync.pio)
pico_generate_pio_header(kora ${CMAKE_CURRENT_LIST_DIR}/vsync.pio)
pico_generate_pio_header(kora ${CMAKE_CURRENT_LIST_DIR}/rgb.pio)
target_sources(kora PRIVATE vga.c)

target_link_libraries(kora PRIVATE pico_stdlib hardware_pio hardware_dma)
pico_add_extra_outputs(kora)
