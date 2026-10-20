###########
# Add benchmark test macros
###########
include(${CMAKE_CURRENT_SOURCE_DIR}/CMake/add_test.cmake)


# Paths
set(TELEBENCH_TOP ${CMAKE_CURRENT_SOURCE_DIR})
set(TELEBENCH_LIB_PATH ${CMAKE_CURRENT_SOURCE_DIR}/lib)


# Common TeleBench library
add_library(telebench-lib STATIC)

set_target_properties(telebench-lib PROPERTIES
    LINKER_LANGUAGE C
)

target_sources(telebench-lib PRIVATE
    ${TELEBENCH_LIB_PATH}/src/autocorrelation.c
    ${TELEBENCH_LIB_PATH}/src/convolutional_encoder.c
    ${TELEBENCH_LIB_PATH}/src/bit_allocation.c
    ${TELEBENCH_LIB_PATH}/src/viterbi.c
)

target_include_directories(telebench-lib PUBLIC
    ${TELEBENCH_LIB_PATH}/include
)


# Add benchmarks
set(BINARY_DIR ${BUILD_DIR}/benchmark_sources/telebench/)

file(GLOB folders "${CMAKE_CURRENT_SOURCE_DIR}/benchmarks/*")

foreach(item ${folders})

    if(EXISTS "${item}/benchmark.hpp")

        string(REPLACE
            "${CMAKE_CURRENT_SOURCE_DIR}/benchmarks/"
            ""
            bm
            ${item}
        )

        if(${SPIKE_SIM})
            add_Benchmark_Spike(${bm})
        endif()

    endif()

endforeach()
