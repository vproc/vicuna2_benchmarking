#######
# TeleBench benchmark test macros

include(${TOOLCHAIN_TOP}/CMake/toolchain_build.cmake)


# Spike
macro(add_Benchmark_Spike TEST)

    # Build Spike if it is not already present
    build_spike()

    set(TEST_NAME ${TEST}_Spike)

    add_executable(${TEST_NAME})


    # Headers
    target_include_directories(${TEST_NAME} PRIVATE

        # benchmark.hpp and data.h
        ${TELEBENCH_TOP}/benchmarks/${TEST}

        # telebench/autocorrelation.h
        ${TELEBENCH_LIB_PATH}/include

        # framework headers
        ${FRAMEWORK_TOP}
    )


    # Benchmark-specific C sources
    file(GLOB BENCH_SRCS
        "${TELEBENCH_TOP}/benchmarks/${TEST}/*.c"
    )


    # Executable sources
    target_sources(${TEST_NAME} PRIVATE

        # Generic benchmark runner
        ${FRAMEWORK_TOP}/main.cpp

        # Bare-metal startup code
        ${FRAMEWORK_TOP}/vicuna2_bsp/crt0.S

        # Benchmark adapter
        ${TELEBENCH_TOP}/benchmarks/${TEST}/benchmark.hpp

        # input.c, reference.c, etc.
        ${BENCH_SRCS}
    )


    # Linker setup
    target_link_options(${TEST_NAME} PRIVATE
        "-nostartfiles"
    )

    target_link_options(${TEST_NAME} PRIVATE
        "-T${FRAMEWORK_TOP}/vicuna2_bsp/lld_link.ld"
    )


    # Libraries
    target_link_libraries(${TEST_NAME} PRIVATE
        telebench-lib
        sim_spike
    )


    # Generate disassembly
    add_custom_command(
        TARGET ${TEST_NAME}
        POST_BUILD
        COMMAND ${CMAKE_OBJDUMP}
                -D ${TEST_NAME}.elf
                > ${TEST_NAME}_dump.txt
    )


    # CTest
    add_test(
        NAME ${TEST_NAME}

        COMMAND
            ${TOOLCHAIN_TOP}/spike/bin/spike

            --isa=rv32imf_zicntr_zihpm_zfh_zve32f_zvfh_zvl${VREG_W}b

            ${BUILD_DIR}/benchmark_sources/telebench/${TEST_NAME}.elf

        WORKING_DIRECTORY
            ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/../..
    )


    set_tests_properties(
        ${TEST_NAME}
        PROPERTIES TIMEOUT 5
    )


    message(STATUS "Successfully added ${TEST_NAME}")

endmacro()
