#######
# Macros for adding a tinyml benchmark to CTest
#######
include(${TOOLCHAIN_TOP}/CMake/toolchain_build.cmake) #include toolchain macros

macro(add_Benchmark TEST SOURCE_DIR TEST_BUILD_DIR)

    # Check if verilator model is built  TODO: Implement check to confirm params are the same?
    if(NOT EXISTS "${VERILATOR_MODEL_DIR}/build/verilated_model")
        message(FATAL_ERROR "Verilator Model executable not present!  Build it and try again.")
    endif()

    set(TEST_NAME ${TEST}_Verilator)

    add_executable(${TEST_NAME})

    target_include_directories(${TEST_NAME} PRIVATE
        ${SOURCE_DIR}
        ${SOURCE_DIR}/model_data
        ${FRAMEWORK_TOP}/
    )

    target_sources(${TEST_NAME} PUBLIC
        ${FRAMEWORK_TOP}/main.cpp  
        ${SOURCE_DIR}/${TEST}_data/${TEST}_input_data.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_input_data.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_data.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_data.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_settings.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_settings.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_output_data_ref.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_output_data_ref.h
    )
    #Set Linker
    target_link_options(${TEST_NAME} PRIVATE "-nostartfiles")
    if (${COMPILER} STREQUAL "LLVM")
        target_compile_options(${TEST_NAME} PRIVATE "-fno-use-cxa-atexit")  #-fno-use-cxa-atexit needed for hidden symbol `__dso_handle' error for llvm
    endif()
    target_link_options(${TEST_NAME} PRIVATE "-T${VICUNA_BSP_TOP}/lld_link.ld")


    #Link BSP
    target_link_libraries(${TEST_NAME} PRIVATE bsp_Vicuna UART_Vicuna tflm sim_Verilator)

    add_custom_command(TARGET ${TEST_NAME}
                       POST_BUILD
                       COMMAND ${CMAKE_OBJCOPY} -O binary ${TEST_NAME}.elf ${TEST_NAME}.bin
                       COMMAND srec_cat ${TEST_NAME}.bin -binary -offset 0x0000 -byte-swap 4 -o ${TEST_NAME}.vmem -vmem
                       COMMAND rm -f prog_${TEST_NAME}.txt
                       COMMAND echo -n "${TEST_BUILD_DIR}/${TEST_NAME}.vmem ${TEST_BUILD_DIR}/${TEST_NAME}_unused.txt " > prog_${TEST_NAME}.txt
                       COMMAND readelf -s ${TEST_NAME}.elf | sed '2,13 s/ //1' | grep vref_start | cut -d " " -f 6 | tr [=["\n"]=] " " >> prog_${TEST_NAME}.txt
                       COMMAND readelf -s ${TEST_NAME}.elf | sed '2,13 s/ //1' | grep vref_end | cut -d " " -f 6 | tr [=["\n"]=] " " >> prog_${TEST_NAME}.txt
                       COMMAND echo -n "${TEST_BUILD_DIR}/${TEST_NAME}_vicuna_sim_out.txt " >> prog_${TEST_NAME}.txt
                       COMMAND readelf -s ${TEST_NAME}.elf | sed '2,13 s/ //1' | grep vdata_start | cut -d " " -f 6 | tr [=["\n"]=] " " >> prog_${TEST_NAME}.txt
                       COMMAND readelf -s ${TEST_NAME}.elf | sed '2,13 s/ //1' | grep vdata_end | cut -d " " -f 6 | tr [=["\n"]=] " " >> prog_${TEST_NAME}.txt
                       COMMAND ${CMAKE_OBJDUMP} -D ${TEST_NAME}.elf > ${TEST_NAME}_dump.txt
                       )
    #VERY DANGEROUS TO USE TRACE
    if(TRACE)
        set(VCD_TRACE_FLAG "--trace")
        set(VCD_TRACE_ARG "${TEST_BUILD_DIR}/test_${TEST_NAME}_sig.vcd")
    else()
        set(VCD_TRACE_FLAG "")
        set(VCD_TRACE_ARG "")
    endif()

     if(COMMIT_LOG)
        set(COMMIT_FLAG "--commit")
        set(COMMIT_ARG "${TEST_BUILD_DIR}/")
    else()
        set(COMMIT_FLAG "")
        set(COMMIT_ARG "")
    endif()

    #Add Test
    add_test(NAME ${TEST_NAME} 
             COMMAND ./${VERILATOR_MODEL_DIR}/build/verilated_model ${TEST_BUILD_DIR}/prog_${TEST_NAME}.txt ${MEM_PORTS} ${MEM_W} 4194304 ${MEM_LATENCY} 1 ${TEST_NAME} ${VREG_W} 0 ${VCD_TRACE_FLAG} ${VCD_TRACE_ARG} ${COMMIT_FLAG} ${COMMIT_ARG}#TODO: PASS ALL THESE ARGUMENTS IN FROM USER
             WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/../..)
             
    set_tests_properties(${TEST_NAME} PROPERTIES TIMEOUT  1000) #TODO: Find a reasonable timeout for these tests

    message(STATUS "Successfully added ${TEST_NAME}")

endmacro()

macro(add_Benchmark_Gem5 TEST SOURCE_DIR BINARY_DIR CONFIG_SCRIPT)
    #Check if Gem5 simulator has been built.  If not build it. TODO: Currently, if changes are made to the rtl/verilator model, the gem5 build must be manually deleted to rebuild. Should automatically detect if new model has been generated and rebuild gem5
    build_gem5()

    set(TEST_NAME ${TEST}_Gem5_${CONFIG_SCRIPT})

    add_executable(${TEST_NAME})

    target_include_directories(${TEST_NAME} PRIVATE
        ${SOURCE_DIR}
        ${SOURCE_DIR}/model_data
        ${FRAMEWORK_TOP}/
    )

    target_sources(${TEST_NAME} PUBLIC
        ${FRAMEWORK_TOP}/main.cpp  
        ${SOURCE_DIR}/${TEST}_data/${TEST}_input_data.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_input_data.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_data.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_data.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_settings.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_settings.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_output_data_ref.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_output_data_ref.h
    )
    #Use default Linker TODO: use unified/standard one
    #target_link_options(${TEST_NAME} PRIVATE "-nostartfiles")
    #target_link_options(${TEST_NAME} PRIVATE "-T${VICUNA_BSP_TOP}/lld_link.ld")
    #Link tflm (for gem5 only build no bsp/) TODO: UART_VICUNA isnt needed, but include wants it
    target_link_libraries(${TEST_NAME} PRIVATE tflm sim_gem5)

    add_custom_command(TARGET ${TEST_NAME}
                       POST_BUILD
                       COMMAND ${CMAKE_OBJDUMP} -D ${TEST_NAME}.elf > ${TEST_NAME}_dump.txt
                       )
    #Add Test # TODO: Current exit condition for gem5 is a segfault(from invalid uart write to be unified with other sim techniques) which reports test failed.  Improve exit conditions with gem5 API calls once generic testing structure is finished.
    add_test(NAME ${TEST_NAME} 
             COMMAND ${GEM5_MODEL_DIR}/gem5/build/ALL/gem5.opt ${GEM5_MODEL_DIR}/configuration_scripts/${CONFIG_SCRIPT}.py ${VREG_W} ${BINARY_DIR}/${TEST_NAME}.elf
             WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
             
    set_tests_properties(${TEST_NAME} PROPERTIES TIMEOUT 0) #TODO: Find a reasonable timeout for these tests

    message(STATUS "Successfully added ${TEST_NAME}")
endmacro()

macro(add_Benchmark_Hybrid TEST SOURCE_DIR TEST_BUILD_DIR CONFIG_SCRIPT)
    #Check if Gem5 simulator has been built.  If not build it. TODO: Currently, if changes are made to the rtl/verilator model, the gem5 build must be manually deleted to rebuild
    build_gem5()

    set(TEST_NAME ${TEST}_Hybrid_${CONFIG_SCRIPT})

    add_executable(${TEST_NAME})

    target_include_directories(${TEST_NAME} PRIVATE
        ${SOURCE_DIR}
        ${SOURCE_DIR}/model_data
        ${FRAMEWORK_TOP}/
    )

    target_sources(${TEST_NAME} PUBLIC
        ${FRAMEWORK_TOP}/main.cpp
        ${SOURCE_DIR}/${TEST}_data/${TEST}_input_data.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_input_data.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_data.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_data.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_settings.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_settings.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_output_data_ref.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_output_data_ref.h
    )
    #Set Linker
    target_link_options(${TEST_NAME} PRIVATE "-nostartfiles")
    #target_link_options(${TEST_NAME} PRIVATE "-nostdlib")

    target_link_options(${TEST_NAME} PRIVATE "-T${VICUNA_BSP_TOP}/lld_link.ld")


    #Link BSP
    target_link_libraries(${TEST_NAME} PRIVATE bsp_Vicuna UART_Vicuna tflm sim_hybrid)

    add_custom_command(TARGET ${TEST_NAME}
                       POST_BUILD
                       COMMAND ${CMAKE_OBJDUMP} -D ${TEST_NAME}.elf > ${TEST_NAME}_dump.txt
                       )

    #Hybrid Sim allows trace outputs, should be able to enable it here
    # set(INST_TRACE_ARGS "${BUILD_DIR}/Testing/inst_trace.txt")

    # if(TRACE)
    #     set(MEM_TRACE_ARGS "${BUILD_DIR}/Testing/last_test_mem.csv")
    #     set(VCD_TRACE_ARGS "${BUILD_DIR}/Testing/last_test_sig.vcd")

    # else()
    #     set(MEM_TRACE_ARGS "")
    #     set(VCD_TRACE_ARGS "")
    # endif()
                       
	              
  #Add Test
        add_test(NAME ${TEST_NAME} 
             COMMAND ${GEM5_MODEL_DIR}/gem5/build/ALL/gem5.opt ${GEM5_MODEL_DIR}/configuration_scripts/${CONFIG_SCRIPT}.py ${BINARY_DIR}/${TEST_NAME}.elf ${MEM_W}
             WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})

    set_tests_properties(${TEST_NAME} PROPERTIES TIMEOUT 60) #TODO: Find a reasonable timeout for these tests

    message(STATUS "Successfully added ${TEST_NAME}")

endmacro()

macro(add_Benchmark_Spike TEST SOURCE_DIR TEST_BUILD_DIR)
    #Build spike if it isnt present
    build_spike()

    set(TEST_NAME ${TEST}_Spike)
    
    add_executable(${TEST_NAME})

    target_include_directories(${TEST_NAME} PRIVATE
        ${SOURCE_DIR}
        ${SOURCE_DIR}/model_data
        ${FRAMEWORK_TOP}/
    )

    target_sources(${TEST_NAME} PUBLIC
        ${FRAMEWORK_TOP}/main.cpp
        ${FRAMEWORK_TOP}/vicuna2_bsp/crt0.S    
        ${SOURCE_DIR}/${TEST}_data/${TEST}_input_data.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_input_data.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_data.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_data.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_settings.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_settings.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_output_data_ref.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_output_data_ref.h
    )

#     #Set Linker
    target_link_options(${TEST_NAME} PRIVATE "-nostartfiles")

    target_link_options(${TEST_NAME} PRIVATE "-T${FRAMEWORK_TOP}/vicuna2_bsp/lld_link.ld") #Spike address space starts at 0x80000000, needs different linker script
    if (${COMPILER} STREQUAL "LLVM")
        target_compile_options(${TEST_NAME} PRIVATE "-fno-use-cxa-atexit")  #-fno-use-cxa-atexit needed for hidden symbol `__dso_handle' error for llvm
    endif()
    #Link tflm and spike sim libraries
    target_link_libraries(${TEST_NAME} PRIVATE tflm sim_spike)   

    add_custom_command(TARGET ${TEST_NAME}
                       POST_BUILD
                       COMMAND ${CMAKE_OBJDUMP} -D ${TEST_NAME}.elf > ${TEST_NAME}_dump.txt)    
	              

    #Add Test
     add_test(NAME ${TEST_NAME} 
              COMMAND ${TOOLCHAIN_TOP}/spike/bin/spike --isa=rv32imf_zicntr_zihpm_zfh_zve32f_zvfh_zvl${VREG_W}b ${TEST_BUILD_DIR}/${TEST_NAME}.elf 
              WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/../..)
             
    set_tests_properties(${TEST_NAME} PROPERTIES TIMEOUT 0) #TODO: Find a reasonable timeout for these tests

    message(STATUS "Successfully added ${TEST_NAME}")

endmacro()
 
macro(add_benchmark_etiss TEST SOURCE_DIR)
    build_etiss()
    set(TEST_NAME ${TEST}_etiss)
    set(ETISS_CRT_LIB ${CMAKE_BINARY_DIR}/benchmark_sources/framework/etiss)

    add_executable(${TEST_NAME})
    target_include_directories(${TEST_NAME} PRIVATE
        ${SOURCE_DIR}
        ${SOURCE_DIR}/model_data
        ${FRAMEWORK_TOP}/
    )
    target_sources(${TEST_NAME} PUBLIC
        ${FRAMEWORK_TOP}/main.cpp
        ${SOURCE_DIR}/${TEST}_data/${TEST}_input_data.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_input_data.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_data.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_data.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_settings.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_settings.h
        ${SOURCE_DIR}/${TEST}_data/${TEST}_output_data_ref.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_output_data_ref.h
    )


    add_dependencies(${TEST_NAME} etiss_crt0)
    target_link_libraries(${TEST_NAME} PRIVATE tflm etiss_crt0 sim_etiss)
    
    
    target_link_options(${TEST_NAME} PRIVATE 
        "-L${ETISS_CRT_LIB}"
        "--specs=${ETISS_CRT_TOP}/etiss-semihost.specs"
        "-T${ETISS_CRT_TOP}/etiss.ld"
        "-nostartfiles"
    )

    # put objdump in elf target
    add_custom_command(TARGET ${TEST_NAME}
    POST_BUILD
    COMMAND ${CMAKE_OBJDUMP} -D ${TEST_NAME}.elf > ${TEST_NAME}_dump.txt
    )

    add_test(NAME ${TEST_NAME} 
        COMMAND 
            ${TOOLCHAIN_TOP}/etiss_base/etiss_rvv/build/installed/bin/bare_etiss_processor 
            -i${FRAMEWORK_TOP}/etiss/etiss.ini 
            --vp.elf_file=${BINARY_DIR}/${TEST_NAME}.elf
        WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
endmacro()

macro(add_Benchmark_IREE_Spike TEST SOURCE_DIR TEST_BUILD_DIR)
    #Build spike if it isnt present
    build_spike()

    set(TEST_NAME ${TEST}_IREE_Spike)
    
    # Allow external override of TOSA_CONVERTER_PATH
    set(TOSA_CONVERTER_PATH "/home/efectn/iree-prod-test/demo-simple-mlir/tensorflow_model/myenv/bin" CACHE PATH "Path to the directory containing tosa-converter-for-tflite")

    set(PREGENERATED_MLIR "${SOURCE_DIR}/${TEST}_data/${TEST}_model.mlir")
    set(TEST_MLIR_SOURCE ${CMAKE_CURRENT_BINARY_DIR}/${TEST}_model.mlir)
    set(TEST_VMFB ${CMAKE_CURRENT_BINARY_DIR}/${TEST}_model.vmfb)
    set(TEST_C_HEADER ${CMAKE_CURRENT_BINARY_DIR}/${TEST}_model.c)

    if(EXISTS "${PREGENERATED_MLIR}")
        message(STATUS "Found pre-generated MLIR model at ${PREGENERATED_MLIR}, skipping TFLite extraction and TOSA conversion.")
        
        # Copy the pregenerated MLIR to the build directory so the pipeline can continue smoothly
        add_custom_command(
            OUTPUT ${TEST_MLIR_SOURCE}
            COMMAND ${CMAKE_COMMAND} -E copy ${PREGENERATED_MLIR} ${TEST_MLIR_SOURCE}
            DEPENDS ${PREGENERATED_MLIR}
            COMMENT "Copying pre-generated MLIR model to build directory"
            VERBATIM
        )
    else()
        message(STATUS "Pre-generated MLIR model not found at ${PREGENERATED_MLIR}. Setting up TFLite to MLIR conversion pipeline.")
        # Locate TFLite to MLIR converter (tosa-converter-for-tflite)
        find_program(TOSA_CONVERTER tosa-converter-for-tflite
                     HINTS ${TOSA_CONVERTER_PATH}
                     REQUIRED)
        find_package(Python3 REQUIRED)

        set(TEST_TFLITE_SOURCE ${CMAKE_CURRENT_BINARY_DIR}/${TEST}_model.tflite)

        # 1. Extract TFLite from model_data.cc
        add_custom_command(
            OUTPUT ${TEST_TFLITE_SOURCE}
            COMMAND Python3::Interpreter ${CMAKE_CURRENT_SOURCE_DIR}/CMake/extract_tflite.py
                ${SOURCE_DIR}/${TEST}_data/${TEST}_model_data.cc
                ${TEST_TFLITE_SOURCE}
            DEPENDS ${SOURCE_DIR}/${TEST}_data/${TEST}_model_data.cc ${CMAKE_CURRENT_SOURCE_DIR}/CMake/extract_tflite.py
            COMMENT "Extracting ${TEST}_model.tflite from model_data.cc"
            VERBATIM
        )

        # 2. Convert TFLite to MLIR
        add_custom_command(
            OUTPUT ${TEST_MLIR_SOURCE}
            COMMAND ${TOSA_CONVERTER} ${TEST_TFLITE_SOURCE} --text -o ${TEST_MLIR_SOURCE}
            DEPENDS ${TEST_TFLITE_SOURCE}
            COMMENT "Converting ${TEST}_model.tflite -> ${TEST}_model.mlir via TOSA"
            VERBATIM
        )
    endif()

    # Locate IREE compiler
    find_program(IREE_COMPILE_TOOL iree-compile HINTS ${IREE_COMPILER_BIN_DIR} REQUIRED)
    find_program(XXD_TOOL xxd REQUIRED)

    # 3. Compile MLIR to VMFB
    string(REGEX MATCH "m" HAS_M ${RISCV_ARCH})
    string(REGEX MATCH "f" HAS_F ${RISCV_ARCH})
    string(REGEX MATCH "zve32x" HAS_ZVE32X ${RISCV_ARCH})
    string(REGEX MATCH "zve32f" HAS_ZVE32F ${RISCV_ARCH})

    # Generate IREE LLVM features based on RISCV_ARCH
    set(IREE_LLVM_FEATURES "")

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

    # 2. Compile MLIR to VMFB
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
        COMMENT "Compiling ${TEST}_model.mlir -> ${TEST}_model.vmfb"
        VERBATIM
    )

    # 4. Generate C array from VMFB
    add_custom_command(
        OUTPUT ${TEST_C_HEADER}
        COMMAND ${XXD_TOOL} -i ${TEST_VMFB} ${TEST_C_HEADER}
        COMMAND sed -i "s/_.*_${TEST}_model_vmfb/iree_model_vmfb/g" ${TEST_C_HEADER}
        COMMAND sed -i "s/_.*_${TEST}_model_vmfb_len/iree_model_vmfb_len/g" ${TEST_C_HEADER}
        DEPENDS ${TEST_VMFB}
        COMMENT "Generating ${TEST}_model.c from ${TEST}_model.vmfb"
        VERBATIM
    )

    add_executable(${TEST_NAME})

    target_include_directories(${TEST_NAME} PRIVATE
        ${SOURCE_DIR}
        ${SOURCE_DIR}/${TEST}_data
        ${FRAMEWORK_TOP}/
        ${CMAKE_CURRENT_BINARY_DIR}
    )

    set(IREE_WRAPPER_SOURCE ${FRAMEWORK_TOP}/main.cpp)

    target_sources(${TEST_NAME} PUBLIC
        ${IREE_WRAPPER_SOURCE}
        ${TEST_C_HEADER}
        ${FRAMEWORK_TOP}/spike/crt0.S
        ${CMAKE_CURRENT_SOURCE_DIR}/../generic_iree/baremetal/baremetal_stubs.c
        ${SOURCE_DIR}/${TEST}_data/${TEST}_input_data.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_model_settings.cc
        ${SOURCE_DIR}/${TEST}_data/${TEST}_output_data_ref.cc
    )

    set_source_files_properties(${IREE_WRAPPER_SOURCE} PROPERTIES
        OBJECT_DEPENDS "${TEST_C_HEADER};${TEST_VMFB}"
    )

    # Define IREE_RUNTIME_ENABLED to trigger IREE-specific conditional compilation in benchmark headers.
    target_compile_definitions(${TEST_NAME} PRIVATE 
        IREE_RUNTIME_ENABLED=1
        IREE_PLATFORM_GENERIC=1
        IREE_FILE_IO_ENABLE=0
        IREE_DEVICE_SIZE_T=uint32_t
        PRIdsz=PRIu32
        IREE_SOCKETS_ENABLE=0
        "IREE_TIME_NOW_FN={ return 0\\; }"
    )

    target_compile_features(${TEST_NAME} PRIVATE cxx_std_14)
    target_compile_options(${TEST_NAME} PRIVATE -fno-builtin)

    # Set Linker
    target_link_options(${TEST_NAME} PRIVATE "-nostartfiles")
    target_link_options(${TEST_NAME} PRIVATE "-T${FRAMEWORK_TOP}/spike/lld_link.ld")
    
    if (${COMPILER} STREQUAL "LLVM")
        target_compile_options(${TEST_NAME} PRIVATE "-fno-use-cxa-atexit")
    endif()
    
    # Link IREE runtime and spike sim libraries
    target_link_libraries(${TEST_NAME} PRIVATE 
        sim_spike
        -Wl,--start-group
        iree_runtime_unified
        iree_base_base
        flatcc_parsing
        flatcc_runtime
        -Wl,--end-group
        m
    )   

    add_custom_command(TARGET ${TEST_NAME}
                       POST_BUILD
                       COMMAND ${CMAKE_OBJDUMP} -D ${TEST_NAME}.elf > ${TEST_NAME}_dump.txt)    

    # Add Test
    add_test(NAME ${TEST_NAME} 
             COMMAND ${TOOLCHAIN_TOP}/spike/bin/spike --isa=${RISCV_ARCH}_zvl${VREG_W}b ${TEST_BUILD_DIR}/${TEST_NAME}.elf 
             WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/../..)
             
    set_tests_properties(${TEST_NAME} PROPERTIES TIMEOUT 0)

    message(STATUS "Successfully added ${TEST_NAME}")

 endmacro()
