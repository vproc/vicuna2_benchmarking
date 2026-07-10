#Macro for all generic_cpp test sources.  Should be the same for all simulators and can be re-used
macro(generic_cpp_sources TEST_NAME TEST TEST_NUM)
    target_include_directories(${TEST_NAME} PUBLIC
        ${FRAMEWORK_TOP}/
        ${PROGRAMS_TOP}/${TEST}
        ${PROGRAMS_TOP}/${TEST}/test_data
    )

    target_sources(${TEST_NAME} PUBLIC
        ${FRAMEWORK_TOP}/main.cpp                                   # Framework
        ${PROGRAMS_TOP}/${TEST}/test_data/test_data_${TEST_NUM}.cpp # Benchmark
        ${PROGRAMS_TOP}/${TEST}/${TEST}.cpp                         # Benchmark
    )

endmacro()

macro(add_benchmark_Verilator TEST TEST_NUM) 
    
    set(TEST_NAME ${TEST}_${TEST_NUM})
    add_executable(${TEST_NAME})

    generic_cpp_sources(${TEST_NAME} ${TEST} ${TEST_NUM})

    #Set Linker
    target_link_options(${TEST_NAME} PRIVATE "-nostartfiles")

    target_link_options(${TEST_NAME} PRIVATE "-T${VICUNA_BSP_TOP}/lld_link.ld")


    #Link BSP
    target_link_libraries(${TEST_NAME} PUBLIC bsp_Vicuna UART_Vicuna sim_Verilator)

    add_custom_command(TARGET ${TEST_NAME}
                       POST_BUILD
                       COMMAND ${CMAKE_OBJCOPY} -O binary ${TEST_NAME}.elf ${TEST_NAME}.bin
                       COMMAND srec_cat ${TEST_NAME}.bin -binary -offset 0x0000 -byte-swap 4 -o ${TEST_NAME}.vmem -vmem
                       COMMAND rm -f prog_${TEST_NAME}.txt
                       COMMAND echo -n "${TEST_BUILD_DIR}/${TEST_NAME}.vmem" > prog_${TEST_NAME}.txt
                       COMMAND ${CMAKE_OBJDUMP} -D ${TEST_NAME}.elf > ${TEST_NAME}_dump.txt
                       )
    
    #VERY DANGEROUS TO USE TRACE
    if(TRACE)
        set(VCD_TRACE_ARGS "${TEST_BUILD_DIR}/test_${TEST_NAME}_sig.vcd")

    else()
        set(VCD_TRACE_ARGS "")
    endif()

    #Add Test
    add_test(NAME ${TEST_NAME} 
             COMMAND ./${VERILATOR_MODEL_DIR}/build/verilated_model ${TEST_BUILD_DIR}/prog_${TEST_NAME}.txt ${MEM_W} 4194304 ${MEM_LATENCY} 1 ${TEST_NAME} ${VREG_W} 0 ${VCD_TRACE_ARGS}#TODO: PASS ALL THESE ARGUMENTS IN FROM USER
             WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/../..)
             
    set_tests_properties(${TEST_NAME} PROPERTIES TIMEOUT 120) #TODO: Find a reasonable timeout for these tests

    message(STATUS "Successfully added ${TEST_NAME}")


endmacro()

macro(add_benchmark_Gem5 TEST TEST_NUM CONFIG_SCRIPT)
    #Check if Gem5 simulator has been built.  If not build it. TODO: Currently, if changes are made to the rtl/verilator model, the gem5 build must be manually deleted to rebuild. Should automatically detect if new model has been generated and rebuild gem5
    build_gem5()

    set(TEST_NAME ${TEST}_${TEST_NUM}_Gem5_${CONFIG_SCRIPT})

    add_executable(${TEST_NAME})

    generic_cpp_sources(${TEST_NAME} ${TEST} ${TEST_NUM})
    #Use default Linker TODO: use unified/standard one
    #target_link_options(${TEST_NAME} PRIVATE "-nostartfiles")
    #target_link_options(${TEST_NAME} PRIVATE "-T${VICUNA_BSP_TOP}/lld_link.ld")
    #Link tflm (for gem5 only build no bsp/) TODO: UART_VICUNA isnt needed, but include wants it
    target_link_libraries(${TEST_NAME} PRIVATE sim_gem5)

    add_custom_command(TARGET ${TEST_NAME}
                       POST_BUILD
                       COMMAND ${CMAKE_OBJDUMP} -D ${TEST_NAME}.elf > ${TEST_NAME}_dump.txt
                       )
    #Add Test # TODO: Current exit condition for gem5 is a segfault(from invalid uart write to be unified with other sim techniques) which reports test failed.  Improve exit conditions with gem5 API calls once generic testing structure is finished.
    add_test(NAME ${TEST_NAME} 
             COMMAND ${GEM5_MODEL_DIR}/gem5/build/ALL/gem5.opt ${GEM5_MODEL_DIR}/configuration_scripts/${CONFIG_SCRIPT}.py ${VREG_W} ${TEST_BUILD_DIR}/${TEST_NAME}.elf
             WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
             
    set_tests_properties(${TEST_NAME} PROPERTIES TIMEOUT 0) #TODO: Find a reasonable timeout for these tests

    message(STATUS "Successfully added ${TEST_NAME}")
endmacro()

macro(add_benchmark_etiss TEST TEST_NUM)
    # TODO: check if ETISS is built
    set(TEST_NAME ${TEST}_${TEST_NUM}_etiss)

    add_executable(${TEST_NAME})
    generic_cpp_sources(${TEST_NAME} ${TEST} ${TEST_NUM})

    add_dependencies(${TEST_NAME} etiss_crt0)
    target_link_libraries(${TEST_NAME} PRIVATE etiss_crt0 sim_etiss)

    add_custom_command(TARGET ${TEST_NAME}
        POST_BUILD
        COMMAND ${CMAKE_OBJDUMP} -D ${TEST_NAME}.elf > ${TEST_NAME}_dump.txt
    )

    if(CMAKE_CXX_COMPILER_ID MATCHES "(C|c?)lang")
        set(ETISS_LDFLAGS "-nostdlib -lc -lsemihost -lgcc -lstdc++ -L${ETISS_CRT_TOP} -T ${ETISS_CRT_TOP}/etiss.ld")
    else()
        set(ETISS_LDFLAGS "-L${ETISS_CRT_TOP} --specs=${ETISS_CRT_TOP}/etiss-semihost.specs -T ${ETISS_CRT_TOP}/etiss.ld")
    endif()

    # Set Linker
    target_link_options(${TEST_NAME} PRIVATE "${ETISS_LDFLAGS}")

    # TODO: ctest
endmacro()
