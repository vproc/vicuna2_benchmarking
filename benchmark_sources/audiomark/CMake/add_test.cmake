#######
# Macro for adding a audiomark benchmark to CTest
#######
macro(add_Benchmark_Spike TEST)
    #Build spike if it isnt present
    build_spike()

    set(TEST_NAME ${TEST}_Spike)

    add_executable(${TEST_NAME})

    file(GLOB AUDIOMARK_SRCS "${AUDIOMARK_TOP}/tests/data/${TEST}_*.c")

    target_include_directories(${TEST_NAME} PRIVATE
        ${AUDIOMARK_TOP}/../benchmarks/${TEST}/
        ${AUDIOMARK_TOP}/src
    )

    target_sources(${TEST_NAME} PUBLIC
        ${FRAMEWORK_TOP}/main.cpp
        ${AUDIOMARK_TOP}/src/ee_${TEST}.c
        ${FRAMEWORK_TOP}/vicuna2_bsp/crt0.S
        ${AUDIOMARK_TOP}/../benchmarks/${TEST}/benchmark.hpp
        ${AUDIOMARK_SRCS}
    )

    #Set Linker
    target_link_options(${TEST_NAME} PRIVATE "-nostartfiles")

    target_link_options(${TEST_NAME} PRIVATE "-T${VICUNA_BSP_TOP}/lld_link.ld")
    #Link tflm and spike sim libraries
    target_link_libraries(${TEST_NAME} PRIVATE audiomark-riscv-lib sim_spike)

    add_custom_command(TARGET ${TEST_NAME}
        POST_BUILD
        COMMAND ${CMAKE_OBJDUMP} -D ${TEST_NAME}.elf > ${TEST_NAME}_dump.txt)

    #Optionally enable register commit log outputs for debugging
    set(SPIKE_COMMIT_LOG_ARGS "")
    if(${COMMIT_LOG})
        set(SPIKE_COMMIT_LOG_ARGS "--log-commits")
    endif()

    #Add Test
    add_test(NAME ${TEST_NAME}
        COMMAND ${TOOLCHAIN_TOP}/spike/bin/spike --isa=rv32imf_zicntr_zihpm_zfh_zve32f_zvfh_zvl${VREG_W}b ${SPIKE_COMMIT_LOG_ARGS} --log=${BINARY_DIR}/${TEST_NAME}_commit_log.txt ${BINARY_DIR}/${TEST_NAME}.elf
        WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/../..)

    set_tests_properties(${TEST_NAME} PROPERTIES TIMEOUT 5) #TODO: Find a reasonable timeout for these tests

    message(STATUS "Successfully added ${TEST_NAME}")

endmacro()
