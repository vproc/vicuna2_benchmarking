macro(add_muriscv_nn_test TEST)
    # very cursed testcase generator that copies the test case and replaces main with muriscv_nn_main, that we can integrate it into 
    # our own testing framework
    build_etiss()
    set(TEST_NAME ${TEST}_etiss)
    set(ETISS_CRT_LIB ${CMAKE_BINARY_DIR}/benchmark_sources/framework/etiss)

    # build unity
    include(FetchContent)
    set(FETCHCONTENT_QUIET FALSE)
    FetchContent_Declare(
    unity
    GIT_REPOSITORY https://github.com/ThrowTheSwitch/Unity
    GIT_TAG v2.5.2
    GIT_PROGRESS TRUE
    )
    add_definitions(-DUNITY_INCLUDE_CONFIG_H)
    FetchContent_MakeAvailable(unity)

    target_include_directories(unity PRIVATE $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/muriscv-nn/Tests/Utils>)
    # disable -Werror for unity, as it has some warnings that are not relevant to us
    get_target_property(_target_flags unity COMPILE_OPTIONS)
    list(REMOVE_ITEM _target_flags "-Werror")
    set_target_properties(unity PROPERTIES COMPILE_OPTIONS "-Wno-error {_target_flags} -Wno-error")
    if(CMAKE_CXX_COMPILER_ID MATCHES "(C|c?)lang")
        target_link_options(unity PRIVATE 
            "-nostdlib"
            "-lc"
            "-lsemihost"
            "-lgcc"
            "-lstdc++"
            "-T${ETISS_CRT_TOP}/etiss.ld"
        )
    endif()

    add_executable(${TEST_NAME})
    
    # read file and replace main with muriscv_nn_main
    file(READ ${CMAKE_CURRENT_SOURCE_DIR}/muriscv-nn/Tests/TestCases/${TEST}/${TEST}.c FILE_CONTENT)
    string(REPLACE "int main" "int muriscv_nn_main" FILE_CONTENT "${FILE_CONTENT}")
    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/TestCases/${TEST}/${TEST}.c "${FILE_CONTENT}")

    target_sources(${TEST_NAME} PUBLIC
        ${FRAMEWORK_TOP}/main.cpp
        ${CMAKE_CURRENT_BINARY_DIR}/TestCases/${TEST}/${TEST}.c
    )
    target_include_directories(${TEST_NAME} PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/muriscv-nn/Source/
        ${CMAKE_CURRENT_SOURCE_DIR}/muriscv-nn/Include/
        ${CMAKE_CURRENT_BINARY_DIR}/TestData/
        ${CMAKE_CURRENT_BINARY_DIR}/Utils/
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/muriscv-nn/Tests/Utils>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/muriscv-nn/Tests/TestData>
        ${FRAMEWORK_TOP}/etiss/
        ${CMAKE_CURRENT_SOURCE_DIR}/muriscv-nn-unittests/
    )
    
    target_link_libraries(${TEST_NAME} PUBLIC muriscvnn unity)
    

    add_dependencies(${TEST_NAME} etiss_crt0)
    target_link_libraries(${TEST_NAME} PRIVATE tflm etiss_crt0 sim_etiss)
    
    if(CMAKE_CXX_COMPILER_ID MATCHES "(C|c?)lang")
        target_link_options(${TEST_NAME} PRIVATE 
            "-nostdlib"
            "-lc"
            "-lsemihost"
            "-lgcc"
            "-lstdc++"
            "-L${ETISS_CRT_LIB}"
            "-T${ETISS_CRT_TOP}/etiss.ld"
        )
    else()
        target_link_options(${TEST_NAME} PRIVATE 
            "-L${ETISS_CRT_LIB}"
            "--specs=${ETISS_CRT_TOP}/etiss-semihost.specs"
            "-T${ETISS_CRT_TOP}/etiss.ld"
            "-nostartfiles"
        )
    endif()

    # put objdump in elf target
    add_custom_command(TARGET ${TEST_NAME}
    POST_BUILD
    COMMAND ${CMAKE_OBJDUMP} -D ${TEST_NAME}.elf > ${TEST_NAME}_dump.txt
    )

    message(${BINARY_DIR})
    add_test(NAME ${TEST_NAME} 
        COMMAND 
            ${TOOLCHAIN_TOP}/etiss_base/etiss_rvv/build/installed/bin/bare_etiss_processor 
            -i${FRAMEWORK_TOP}/etiss/etiss.ini 
            --vp.elf_file=${BINARY_DIR}/tflm/${TEST_NAME}.elf
            --arch.cpu=RV32IMACFDV_zvl${VREG_W}b
        WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
endmacro()

macro(prepare_muriscv_nn_tests)
    file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/muriscv-nn/Tests/TestData DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
    file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/muriscv-nn/Tests/Utils DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
endmacro()