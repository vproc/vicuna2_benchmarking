# Macro to add an IREE Benchmark test for Spike
macro(add_IreeBenchmark_Spike TEST_NAME TEST_DIR)
    # Build spike if it isnt present
    build_spike()

    set(TEST_TARGET ${TEST_NAME}_IREE_Spike)
    set(TEST_MLIR_SOURCE ${TEST_DIR}/${TEST_NAME}.mlir)
    set(TEST_VMFB ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.vmfb)
    set(TEST_C_HEADER ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.h)
    set(TEST_MAIN_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/../framework/main.cpp)

    # Find necessary tools
    find_program(IREE_COMPILE_TOOL iree-compile HINTS ${IREE_HOST_BIN_DIR} REQUIRED)
    find_program(XXD_TOOL xxd REQUIRED)

    # Generate IREE LLVM features based on RISCV_ARCH
    set(IREE_LLVM_FEATURES "")
    string(REGEX MATCH "m" HAS_M ${RISCV_ARCH})
    string(REGEX MATCH "f" HAS_F ${RISCV_ARCH})
    string(REGEX MATCH "zve32x" HAS_ZVE32X ${RISCV_ARCH})
    string(REGEX MATCH "zve32f" HAS_ZVE32F ${RISCV_ARCH})

    if(HAS_M)
        set(IREE_LLVM_FEATURES "${IREE_LLVM_FEATURES},+m")
    endif()
    if(HAS_F)
        set(IREE_LLVM_FEATURES "${IREE_LLVM_FEATURES},+f")
    endif()
    if(HAS_ZVE32X)
        set(IREE_LLVM_FEATURES "${IREE_LLVM_FEATURES},+zve32x")
    endif()
    if(HAS_ZVE32F)
        set(IREE_LLVM_FEATURES "${IREE_LLVM_FEATURES},+zve32f")
    endif()

    if(HAS_ZVE32X OR HAS_ZVE32F)
        set(IREE_LLVM_FEATURES "${IREE_LLVM_FEATURES},+zvl${VREG_W}b")
    endif()

    string(REGEX REPLACE "^," "" IREE_LLVM_FEATURES "${IREE_LLVM_FEATURES}")

    # Compile MLIR -> VMFB
    add_custom_command(
        OUTPUT ${TEST_VMFB}
        COMMAND ${IREE_COMPILE_TOOL}
            ${TEST_MLIR_SOURCE}
            --iree-hal-target-device=local
            --iree-hal-local-target-device-backends=llvm-cpu
            --iree-llvmcpu-target-triple=riscv32-unknown-elf
            --iree-llvmcpu-target-abi=${RISCV_ABI}
            --iree-llvmcpu-target-cpu-features=${IREE_LLVM_FEATURES}
            --iree-consteval-jit-target-device=local
            -o ${TEST_VMFB}
        DEPENDS ${TEST_MLIR_SOURCE}
        COMMENT "Compiling ${TEST_NAME}.mlir -> ${TEST_NAME}.vmfb (${RISCV_ARCH})"
        VERBATIM
    )

    # Generate C header from VMFB
    add_custom_command(
        OUTPUT ${TEST_C_HEADER}
        COMMAND ${XXD_TOOL} -i -n ${TEST_NAME}_vmfb ${TEST_VMFB} ${TEST_C_HEADER}
        DEPENDS ${TEST_VMFB}
        COMMENT "Generating ${TEST_NAME}.h from ${TEST_NAME}.vmfb"
        VERBATIM
    )

    # Create executable
    add_executable(${TEST_TARGET})

    target_include_directories(${TEST_TARGET} PRIVATE
        ${TEST_DIR}
        ${CMAKE_CURRENT_BINARY_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/iree/iree-source/runtime/src
        ${CMAKE_CURRENT_SOURCE_DIR}/iree/iree-build-rv32-runtime/runtime/src
        ${CMAKE_CURRENT_SOURCE_DIR}/iree/iree-source/third_party/flatcc/include
    )

    target_compile_definitions(${TEST_TARGET} PRIVATE
        IREE_PLATFORM_GENERIC=1
        IREE_FILE_IO_ENABLE=0
        IREE_DEVICE_SIZE_T=uint32_t
        PRIdsz=PRIu32
        IREE_SOCKETS_ENABLE=0
        "IREE_TIME_NOW_FN={ return 0\\; }"
    )

    target_compile_options(${TEST_TARGET} PRIVATE -fno-builtin)
    target_compile_features(${TEST_TARGET} PRIVATE cxx_std_14)

    target_sources(${TEST_TARGET} PUBLIC
        ${TEST_MAIN_SOURCE}
        ${FRAMEWORK_TOP}/vicuna2_bsp/crt0.S 
        ${CMAKE_CURRENT_SOURCE_DIR}/baremetal/baremetal_stubs.c
    )

    set_source_files_properties(${TEST_MAIN_SOURCE} PROPERTIES
        OBJECT_DEPENDS "${TEST_C_HEADER};${TEST_VMFB}"
    )

    target_link_libraries(${TEST_TARGET} PRIVATE
        sim_spike
        -Wl,--start-group
        iree_runtime_unified
        iree_base_base
        flatcc_parsing
        flatcc_runtime
        -Wl,--end-group
        m
    )

    target_link_options(${TEST_TARGET} PRIVATE
        -nostartfiles
        -T${CMAKE_CURRENT_SOURCE_DIR}/../framework/vicuna2_bsp/lld_link.ld
    )

    add_custom_command(TARGET ${TEST_TARGET}
        POST_BUILD
        COMMAND ${CMAKE_OBJDUMP} -D ${TEST_TARGET}.elf > ${TEST_TARGET}_dump.txt
    )

    if(COMMIT_LOG) 
        set(SPIKE_COMMIT_LOG_ARGS "--log-commits" "--log=${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}_commit_log.txt")
    else()
        set(SPIKE_COMMIT_LOG_ARGS "")
    endif()

    add_test(
        NAME ${TEST_TARGET}
        COMMAND ${TOOLCHAIN_TOP}/spike/bin/spike
            --isa=${RISCV_ARCH}_zvl${VREG_W}b
            ${SPIKE_COMMIT_LOG_ARGS}
            ${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}.elf
        WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/../..
    )

    message(STATUS "Added IREE test: ${TEST_TARGET}")
endmacro()

macro(add_IreeBenchmark_Verilator TEST_NAME TEST_DIR)
    # Check if verilator model is built
    if(NOT EXISTS "${VERILATOR_MODEL_DIR}/build/verilated_model")
        message(FATAL_ERROR "Verilator Model executable not present!  Build it and try again.")
    endif()

    set(TEST_TARGET ${TEST_NAME}_IREE_Verilator)
    set(TEST_MLIR_SOURCE ${TEST_DIR}/${TEST_NAME}.mlir)
    set(TEST_VMFB ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.vmfb)
    set(TEST_C_HEADER ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.h)
    set(TEST_MAIN_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/../framework/main.cpp)

    # Find necessary tools
    find_program(IREE_COMPILE_TOOL iree-compile HINTS ${IREE_HOST_BIN_DIR} REQUIRED)
    find_program(XXD_TOOL xxd REQUIRED)

    # Generate IREE LLVM features based on RISCV_ARCH
    set(IREE_LLVM_FEATURES "")
    string(REGEX MATCH "m" HAS_M ${RISCV_ARCH})
    string(REGEX MATCH "f" HAS_F ${RISCV_ARCH})
    string(REGEX MATCH "zve32x" HAS_ZVE32X ${RISCV_ARCH})
    string(REGEX MATCH "zve32f" HAS_ZVE32F ${RISCV_ARCH})

    if(HAS_M)
        set(IREE_LLVM_FEATURES "${IREE_LLVM_FEATURES},+m")
    endif()
    if(HAS_F)
        set(IREE_LLVM_FEATURES "${IREE_LLVM_FEATURES},+f")
    endif()
    if(HAS_ZVE32X)
        set(IREE_LLVM_FEATURES "${IREE_LLVM_FEATURES},+zve32x")
    endif()
    if(HAS_ZVE32F)
        set(IREE_LLVM_FEATURES "${IREE_LLVM_FEATURES},+zve32f")
    endif()

    if(HAS_ZVE32X OR HAS_ZVE32F)
        set(IREE_LLVM_FEATURES "${IREE_LLVM_FEATURES},+zvl${VREG_W}b")
    endif()

    string(REGEX REPLACE "^," "" IREE_LLVM_FEATURES "${IREE_LLVM_FEATURES}")

    # Compile MLIR -> VMFB
    add_custom_command(
        OUTPUT ${TEST_VMFB}
        COMMAND ${IREE_COMPILE_TOOL}
            ${TEST_MLIR_SOURCE}
            --iree-hal-target-device=local
            --iree-hal-local-target-device-backends=llvm-cpu
            --iree-llvmcpu-target-triple=riscv32-unknown-elf
            --iree-llvmcpu-target-abi=${RISCV_ABI}
            --iree-llvmcpu-target-cpu-features=${IREE_LLVM_FEATURES}
            --iree-consteval-jit-target-device=local
            -o ${TEST_VMFB}
        DEPENDS ${TEST_MLIR_SOURCE}
        COMMENT "Compiling ${TEST_NAME}.mlir -> ${TEST_NAME}.vmfb (${RISCV_ARCH})"
        VERBATIM
    )

    # Generate C header from VMFB
    add_custom_command(
        OUTPUT ${TEST_C_HEADER}
        COMMAND ${XXD_TOOL} -i -n ${TEST_NAME}_vmfb ${TEST_VMFB} ${TEST_C_HEADER}
        DEPENDS ${TEST_VMFB}
        COMMENT "Generating ${TEST_NAME}.h from ${TEST_NAME}.vmfb"
        VERBATIM
    )

    # Create executable
    add_executable(${TEST_TARGET})

    target_include_directories(${TEST_TARGET} PRIVATE
        ${TEST_DIR}
        ${CMAKE_CURRENT_BINARY_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/iree/iree-source/runtime/src
        ${CMAKE_CURRENT_SOURCE_DIR}/iree/iree-build-rv32-runtime/runtime/src
        ${CMAKE_CURRENT_SOURCE_DIR}/iree/iree-source/third_party/flatcc/include
        ${CMAKE_CURRENT_SOURCE_DIR}/../framework
    )

    target_compile_definitions(${TEST_TARGET} PRIVATE
        IREE_PLATFORM_GENERIC=1
        IREE_FILE_IO_ENABLE=0
        IREE_DEVICE_SIZE_T=uint32_t
        PRIdsz=PRIu32
        IREE_SOCKETS_ENABLE=0
        "IREE_TIME_NOW_FN={ return 0\\; }"
    )

    target_compile_options(${TEST_TARGET} PRIVATE -fno-builtin)
    target_compile_features(${TEST_TARGET} PRIVATE cxx_std_14)

    target_sources(${TEST_TARGET} PUBLIC
        ${TEST_MAIN_SOURCE}
        ${CMAKE_CURRENT_SOURCE_DIR}/baremetal/baremetal_stubs.c
    )

    set_source_files_properties(${TEST_MAIN_SOURCE} PROPERTIES
        OBJECT_DEPENDS "${TEST_C_HEADER};${TEST_VMFB}"
    )

    target_link_options(${TEST_TARGET} PRIVATE "-nostartfiles")
    if (${COMPILER} STREQUAL "LLVM")
        target_compile_options(${TEST_TARGET} PRIVATE "-fno-use-cxa-atexit")
    endif()
    
    target_link_options(${TEST_TARGET} PRIVATE "-T${VICUNA_BSP_TOP}/lld_link.ld")

    target_link_libraries(${TEST_TARGET} PRIVATE
        bsp_Vicuna 
        UART_Vicuna 
        sim_Verilator
        -Wl,--start-group
        iree_runtime_unified
        iree_base_base
        flatcc_parsing
        flatcc_runtime
        -Wl,--end-group
        m
    )

    add_custom_command(TARGET ${TEST_TARGET}
                       POST_BUILD
                       COMMAND ${CMAKE_OBJCOPY} -O binary ${TEST_TARGET}.elf ${TEST_TARGET}.bin
                       COMMAND srec_cat ${TEST_TARGET}.bin -binary -offset 0x0000 -byte-swap 4 -o ${TEST_TARGET}.vmem -vmem
                       COMMAND rm -f prog_${TEST_TARGET}.txt
                       COMMAND echo -n "${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}.vmem ${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}_unused.txt " > prog_${TEST_TARGET}.txt
                       COMMAND readelf -s ${TEST_TARGET}.elf | sed '2,13 s/ //1' | grep vref_start | cut -d " " -f 6 | tr [=["\n"]=] " " >> prog_${TEST_TARGET}.txt
                       COMMAND readelf -s ${TEST_TARGET}.elf | sed '2,13 s/ //1' | grep vref_end | cut -d " " -f 6 | tr [=["\n"]=] " " >> prog_${TEST_TARGET}.txt
                       COMMAND echo -n "${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}_vicuna_sim_out.txt " >> prog_${TEST_TARGET}.txt
                       COMMAND readelf -s ${TEST_TARGET}.elf | sed '2,13 s/ //1' | grep vdata_start | cut -d " " -f 6 | tr [=["\n"]=] " " >> prog_${TEST_TARGET}.txt
                       COMMAND readelf -s ${TEST_TARGET}.elf | sed '2,13 s/ //1' | grep vdata_end | cut -d " " -f 6 | tr [=["\n"]=] " " >> prog_${TEST_TARGET}.txt
                       COMMAND ${CMAKE_OBJDUMP} -D ${TEST_TARGET}.elf > ${TEST_TARGET}_dump.txt
                       )

    if(TRACE)
        set(VCD_TRACE_FLAG "--trace")
        set(VCD_TRACE_ARG "${CMAKE_CURRENT_BINARY_DIR}/test_${TEST_NAME}_Verilator_sig.vcd")
    else()
        set(VCD_TRACE_FLAG "")
        set(VCD_TRACE_ARG "")
    endif()

     if(COMMIT_LOG)
        set(COMMIT_FLAG "--commit")
        set(COMMIT_ARG "${CMAKE_CURRENT_BINARY_DIR}/")
    else()
        set(COMMIT_FLAG "")
        set(COMMIT_ARG "")
    endif()

    add_test(
        NAME ${TEST_TARGET}
        COMMAND ./${VERILATOR_MODEL_DIR}/build/verilated_model ${CMAKE_CURRENT_BINARY_DIR}/prog_${TEST_TARGET}.txt ${MEM_PORTS} ${MEM_W} 8388608 ${MEM_LATENCY} 1 toycar ${VREG_W} 0 ${VCD_TRACE_FLAG} ${VCD_TRACE_ARG} ${COMMIT_FLAG} ${COMMIT_ARG}
        WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/../..
    )

    message(STATUS "Added IREE test: ${TEST_TARGET}")
endmacro()
