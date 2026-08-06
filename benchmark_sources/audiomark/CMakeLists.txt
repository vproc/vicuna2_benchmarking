 
###########
# Add test addition macros
###########
include(${CMAKE_CURRENT_SOURCE_DIR}/CMake/add_test.cmake)

set(AUDIOMARK_TOP ${CMAKE_CURRENT_SOURCE_DIR}/audiomark)


###########
# Include audiomark RISCV port as library
# TODO: Include the optimized fp32 kernel library
###########
set(PORT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/audiomark/ports/riscv/)
include(${PORT_DIR}/port.cmake)

add_library(audiomark-riscv-lib STATIC)
set_target_properties(audiomark-riscv-lib PROPERTIES LINKER_LANGUAGE C)

set(TH_SOURCE
	# This is essentially an include needed in th_api.c
	${AUDIOMARK_TOP}/src/ee_nn_tables.c
	${AUDIOMARK_TOP}/src/ee_abf_f32_tables.c)

target_sources(audiomark-riscv-lib PUBLIC ${PORT_SOURCE} ${TH_SOURCE})

target_include_directories(audiomark-riscv-lib PUBLIC
                                ${AUDIOMARK_TOP}/src
                                ${PORT_DIR}
                                ${PORT_DIR}/src/
                                ${PORT_DIR}/src/dsp/)

target_compile_definitions(audiomark-riscv-lib PUBLIC -DUSE_RISCV_DSP)

###########
# Add tests for the benchmark suite
###########

#Set location for build binaries
set(BINARY_DIR ${BUILD_DIR}/benchmark_sources/audiomark)

add_Benchmark_Spike(abf_f32)

