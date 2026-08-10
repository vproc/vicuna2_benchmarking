cmake_minimum_required(VERSION 3.10)

project(etiss_crt0 C CXX ASM)

set(ETISS_LINKER "${CMAKE_CURRENT_SOURCE_DIR}/linker_verilator.ld" CACHE STRING "The ETISS linker")
set(ETISS_CRT_LIB ${CMAKE_CURRENT_BINARY_DIR} CACHE STRING "The ETISS crt0 library search path")

add_library(${PROJECT_NAME} STATIC crt0_verilator.S fixes.c trap_handler.c)

target_link_options(${PROJECT_NAME} PRIVATE "-T${ETISS_LINKER}")

