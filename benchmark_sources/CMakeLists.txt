########
# Add framework directory including bsps, support files, and simulator specific functions.
add_subdirectory(framework framework)
########

#Select benchmark suite build directory.  Since each benchmark suite uses a different compiler setup, only one can be active at a time.
if(NOT BENCHMARK_SUITE)
    message(FATAL_ERROR "No Benchmark Suite selected.  Select a valid suite with -DBENCHMARK_SUITE=(name)")
endif()

if(${BENCHMARK_SUITE} STREQUAL "generic_cpp")
    add_subdirectory(generic_cpp generic_cpp)
elseif(${BENCHMARK_SUITE} STREQUAL "generic_iree")
    # generic_iree requires FRAMEWORK=IREE
    if(NOT ${FRAMEWORK} STREQUAL "IREE")
        message(FATAL_ERROR "generic_iree suite requires FRAMEWORK=IREE")
    endif()
    add_subdirectory(generic_iree generic_iree)
elseif(${BENCHMARK_SUITE} STREQUAL "MLPerfTiny")
    add_subdirectory(MLPerfTiny MLPerfTiny)
elseif(${BENCHMARK_SUITE} STREQUAL "embench_dsp")
    add_subdirectory(embench_dsp embench_dsp)
elseif(${BENCHMARK_SUITE} STREQUAL "embench_iot")
    add_subdirectory(embench_iot embench_iot)
elseif(${BENCHMARK_SUITE} STREQUAL "audiomark")
    add_subdirectory(audiomark audiomark)
else()
    message(FATAL_ERROR "Unsupported Benchmark Suite selected.  Select a valid suite with -DBENCHMARK_SUITE=(name)")
endif()



