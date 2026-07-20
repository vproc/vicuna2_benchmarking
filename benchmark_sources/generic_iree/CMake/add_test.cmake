# Macro to add an IREE Benchmark test for Spike
macro(add_IreeBenchmark_Spike TEST_NAME TEST_DIR)
    # Build spike if it isnt present
    build_spike()

    set(TEST_TARGET ${TEST_NAME}_IREE_Spike)
    set(TEST_MLIR_SOURCE ${TEST_DIR}/${TEST_NAME}.mlir)
    set(TEST_VMFB ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.vmfb)
    set(TEST_C_HEADER ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.h)
    set(TEST_MAIN_SOURCE ${TEST_DIR}/main.c)

    # Find necessary tools
    find_program(IREE_COMPILE_TOOL iree-compile HINTS ${IREE_COMPILER_BIN_DIR} REQUIRED)
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
            -o ${TEST_VMFB}
        DEPENDS ${TEST_MLIR_SOURCE}
        COMMENT "Compiling ${TEST_NAME}.mlir -> ${TEST_NAME}.vmfb (${RISCV_ARCH})"
        VERBATIM
    )

    # Generate C header from VMFB
    add_custom_command(
        OUTPUT ${TEST_C_HEADER}
        COMMAND ${XXD_TOOL} -i ${TEST_VMFB} ${TEST_C_HEADER}
        COMMAND sed -i "s/_.*_${TEST_NAME}_vmfb/${TEST_NAME}_vmfb/g" ${TEST_C_HEADER}
        COMMAND sed -i "s/_.*_${TEST_NAME}_vmfb_len/${TEST_NAME}_vmfb_len/g" ${TEST_C_HEADER}
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

    target_sources(${TEST_TARGET} PUBLIC
        ${TEST_MAIN_SOURCE}
        ${CMAKE_CURRENT_SOURCE_DIR}/../framework/spike/crt0.S
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
        -T${CMAKE_CURRENT_SOURCE_DIR}/../framework/spike/lld_link.ld
    )

    add_custom_command(TARGET ${TEST_TARGET}
        POST_BUILD
        COMMAND ${CMAKE_OBJDUMP} -D ${TEST_TARGET}.elf > ${TEST_TARGET}_dump.txt
    )

    add_test(
        NAME ${TEST_TARGET}
        COMMAND ${TOOLCHAIN_TOP}/spike/bin/spike
            --isa=${RISCV_ARCH}_zvl${VREG_W}b
            ${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}.elf
        WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/../..
    )

    message(STATUS "Added IREE test: ${TEST_TARGET}")
endmacro()
