# Add test addition macros
include(${CMAKE_CURRENT_SOURCE_DIR}/CMake/add_test.cmake)




###########
# Add tests for the benchmark suite
###########



#Set location for build binaries
# set(BINARY_DIR ${BUILD_DIR}/benchmark_sources/MLPerfTiny/)

if(DEFINED FRAMEWORK AND ${FRAMEWORK} STREQUAL "TFLM")
    #Needed to run TensorFlow code with RISC-V toolchain.  These flags need to be defined at this level and at tflm library level TODO: investigate
    add_definitions(-DTF_LITE_USE_GLOBAL_MAX)
    add_definitions(-DTF_LITE_USE_GLOBAL_MIN)
    add_definitions(-DTF_LITE_STATIC_MEMORY)
    add_definitions(-DTF_LITE_USE_GLOBAL_CMATH_FUNCTIONS)
    if(NOT RISCV_F)
        add_definitions(-DTFLITE_EMULATE_FLOAT)                         #Might have issues with this for F extensions
    endif()
    add_definitions(-fno-rtti)          #Needed for GCC to resolve virtual delete function scope issue
    add_definitions(-fno-exceptions)    #Needed for GCC to resolve virtual delete function scope issue

    # Add tflm directory to build library
    add_subdirectory(tflm tflm)
    
    if(${ETISS_SIM})
    	add_Benchmark_etiss(toycar_int8 ${CMAKE_CURRENT_SOURCE_DIR}/Int8/toycar/ ${CMAKE_CURRENT_BINARY_DIR})
        if (DEFINED MURISCV_NN AND NOT ${MURISCV_NN})
            add_Benchmark_etiss(aww_int8 ${CMAKE_CURRENT_SOURCE_DIR}/Int8/aww/ ${CMAKE_CURRENT_BINARY_DIR})
        endif()
    endif()
    if(${VERILATOR_SIM})
    	add_Benchmark(toycar_int8 ${CMAKE_CURRENT_SOURCE_DIR}/Int8/toycar/ ${CMAKE_CURRENT_BINARY_DIR})
        add_Benchmark(aww_int8 ${CMAKE_CURRENT_SOURCE_DIR}/Int8/aww/ ${CMAKE_CURRENT_BINARY_DIR})
    endif()
    if (${GEM5_SIM})
    	add_Benchmark_Gem5(toycar_int8 ${CMAKE_CURRENT_SOURCE_DIR}/Int8/toycar/ ${CMAKE_CURRENT_BINARY_DIR} gem5_caches)
        add_Benchmark_Gem5(aww_int8 ${CMAKE_CURRENT_SOURCE_DIR}/Int8/aww/ ${CMAKE_CURRENT_BINARY_DIR})
    endif()
    if (${HYBRID_GEM5_SIM})
    	add_Benchmark_Hybrid(toycar_int8 ${CMAKE_CURRENT_SOURCE_DIR}/Int8/toycar/ ${CMAKE_CURRENT_BINARY_DIR} hybrid_caches)
    	add_Benchmark_Hybrid(toycar_int8 ${CMAKE_CURRENT_SOURCE_DIR}/Int8/toycar/ ${CMAKE_CURRENT_BINARY_DIR} hybrid_only)
    	add_Benchmark_Hybrid(aww_int8 ${CMAKE_CURRENT_SOURCE_DIR}/Int8/aww/ ${CMAKE_CURRENT_BINARY_DIR} hybrid_caches)
    	add_Benchmark_Hybrid(aww_int8 ${CMAKE_CURRENT_SOURCE_DIR}/Int8/aww/ ${CMAKE_CURRENT_BINARY_DIR} hybrid_only)
    endif()
    if(${SPIKE_SIM})
    	add_Benchmark_Spike(toycar_int8 ${CMAKE_CURRENT_SOURCE_DIR}/Int8/toycar/ ${CMAKE_CURRENT_BINARY_DIR})
        if (DEFINED MURISCV_NN AND NOT ${MURISCV_NN})
    	    add_Benchmark_Spike(aww_int8 ${CMAKE_CURRENT_SOURCE_DIR}/Int8/aww/ ${CMAKE_CURRENT_BINARY_DIR})
        endif()
    endif()
elseif(DEFINED FRAMEWORK AND ${FRAMEWORK} STREQUAL "IREE")
    message(FATAL_ERROR "WORK IN PROGRESS")
else()
    message(FATAL_ERROR "UNSUPPORTED DEPLOYMENT FRAMEWORK SELECTED.  SELECT A FRAMEWORK WITH -DFRAMEWORK=(TFLM/IREE)")
endif()
