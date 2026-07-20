cmake_minimum_required(VERSION 3.10)
message(STATUS "CMake Version ${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION}.${CMAKE_PATCH_VERSION}")


##########################
# Required Variables at top level:
#   BENCHMARK_SUITE - select the benchmark suite to compile/run
#   COMPILER        - select the compiler to be used
#
# Each benchmark suite can declare their own specific variables
#
# FEATURES:
# - TRACE : enables .csv memory trace and .vcd signal trace output for benchmarks.  Due to large file sizes, only trace of last test run will be kept.  Will be located in /build/Testing
#
#
##########################

set(BENCHMARK_SUITE "NONE" CACHE STRING "Benchmark Suite to compile.  Name of the top level folder in /Benchmark_Sources")
set(COMPILER "NONE" CACHE STRING "GCC or LLVM")
set(FRAMEWORK "TFLM" CACHE STRING "Deployment framework used by benchmark suites that require one (TFLM or IREE)")
set_property(CACHE FRAMEWORK PROPERTY STRINGS TFLM IREE)


#####
# Default Paths to Subdirectories
#####

set(TOOLCHAIN_TOP ${CMAKE_CURRENT_SOURCE_DIR}/../toolchain) #Top level path to toolchain folder
set(VERILATOR_MODEL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../processor_models/verilator) #Top level path to verilator model files
set(GEM5_MODEL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../processor_models/gem5)#Top level path to gem5 model files
set(BUILD_DIR   ${CMAKE_CURRENT_SOURCE_DIR}/build) #Top level path to program build folder

#####
# Enable/Disable different simulators.  All enabled by default
#####

option(VERILATOR_SIM   "Enable Verilator simulation"                             ON)
option(SPIKE_SIM       "Enable spike simulation"                                 ON)
option(GEM5_SIM        "Enable gem5 simulation"                                  ON)
option(HYBRID_GEM5_SIM "Enable hybrid gem5/verilator simulation"                 ON)
option(ETISS_SIM       "Enable ETISS simulation"                                 ON)

#####
# Enable/Disable debugging features.  All disabled by default
#####

option(TRACE        "Enable trace outputs"                                      OFF)
option(COMMIT_LOG   "Enable register commit logs from Verilator + Spike"        OFF)

#####
# Select RISCV_ARCH and RISCV_ABI and Autovectorization flags based on selected features
#####

# Import Vector config

include(${CMAKE_CURRENT_SOURCE_DIR}/../processor_models/vector_config.cmake)
message("Selected SCALAR_CORE = ${SCALAR_CORE}")
set(ENV{VPROC_PIPELINES} ${VPROC_PIPELINES})
message("Selected VPROC_PIPELINES = ${VPROC_PIPELINES}")
message("Selected RISCV_ARCH = ${RISCV_ARCH}")
message("Selected VREG_W = ${VREG_W}")
set(MEM_W ${VMEM_W})
message("Selected MEM_W = ${MEM_W}")
set(MEM_PORTS ${VMEM_PORTS})
message("Selected MEM_PORTS = ${MEM_PORTS}")

set(MEM_LATENCY 1 CACHE STRING "Memory latency") #This should come from the vector config

#These control benchmark configurations specific to the selected RISCV_ARCH
option(RISCV_F "Use the RISC-V F Extension" OFF)
option(RISCV_ZFH "Use the RISC-V ZFH Extension" OFF)
option(RISCV_ZVE32X "Use the RISC-V Embedded V Extension" OFF)
option(RISCV_ZVE32F "Use the RISC-V Embedded V Float Extension" OFF)
option(RISCV_ZVHF "Use the RISC-V V Half Float Extension" OFF)



set(AUTOVEC_FLAGS "")

if(${RISCV_ARCH} STREQUAL "rv32im") 
    set(RISCV_ABI ilp32)
    set(RISCV_ARCH_COMP_STRING ${RISCV_ARCH})
    option(FH_OPS      "Use FP16 for intermediate operations (no conversion to float)"  OFF)

elseif(${RISCV_ARCH} STREQUAL "rv32imf")
    set(RISCV_ABI ilp32f)  
    set(RISCV_F ON)
    set(RISCV_ARCH_COMP_STRING ${RISCV_ARCH})
    option(FH_OPS      "Use FP16 for intermediate operations (no conversion to float)"  OFF)

elseif(${RISCV_ARCH} STREQUAL "rv32imf_zfh")
    set(RISCV_ABI ilp32f)  
    set(RISCV_F ON)
    set(RISCV_ZFH ON)
    set(RISCV_ARCH_COMP_STRING ${RISCV_ARCH})
    option(FH_OPS      "Use FP16 for intermediate operations (no conversion to float)"  ON)

elseif(${RISCV_ARCH} STREQUAL "rv32im_zve32x")
    set(RISCV_ABI ilp32) 
    set(RISCV_ZVE32X ON)
    set(AUTOVEC_FLAGS "")
    set(RISCV_ARCH_COMP_STRING ${RISCV_ARCH}_zvl${VREG_W}b)
    option(FH_OPS      "Use FP16 for intermediate operations (no conversion to float)"  OFF)

elseif(${RISCV_ARCH} STREQUAL "rv32imf_zve32f")
    set(RISCV_ABI ilp32f) 
    set(RISCV_ZVE32X ON)
    set(RISCV_ZVE32F ON)
    set(RISCV_F ON)
    set(RISCV_ARCH_COMP_STRING ${RISCV_ARCH}_zvl${VREG_W}b)
    #set(AUTOVEC_FLAGS "-fvectorize -fslp-vectorize -mllvm -scalable-vectorization=preferred -mllvm --riscv-v-vector-bits-min=${MIN_VLEN}")
    option(FH_OPS      "Use FP16 for intermediate operations (no conversion to float)"  OFF)
    
elseif(${RISCV_ARCH} STREQUAL "rv32imf_zfh_zve32f_zvfh")
    set(RISCV_ABI ilp32f) 
    set(RISCV_ZVE32X ON)
    set(RISCV_ZVE32F ON)
    set(RISCV_ZFH ON)
    set(RISCV_F ON)
    set(RISCV_ZVFH ON)
    set(RISCV_ARCH_COMP_STRING ${RISCV_ARCH}_zvl${VREG_W}b)
    #set(AUTOVEC_FLAGS "-fvectorize -fslp-vectorize -mllvm -scalable-vectorization=preferred -mllvm --riscv-v-vector-bits-min=${MIN_VLEN}")
    option(FH_OPS      "Use FP16 for intermediate operations (no conversion to float)"  ON) ##TODO: MOVE THIS TO BENCHMARKS TINYML
else()
    message(FATAL_ERROR "Unsupported RISCV_ARCH selected")
    
endif()

####
# Set build mode, Release by default
####
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE DEBUG)
endif()

if(PRINT)
  add_definitions(-DPRINT_OUTPUTS) ##Todo, this should be moved
endif()

# Tell CMake about our processor
set(CMAKE_SYSTEM_PROCESSOR ${RISCV_ARCH})
# The Generic system name is used for bare-metal targets (without OS) in CMake
set(CMAKE_SYSTEM_NAME Generic)

######################
## Setup the CMake Project
#####################

set(CMAKE_EXECUTABLE_SUFFIX_C .elf)
set(CMAKE_EXECUTABLE_SUFFIX_CXX .elf)
set(CMAKE_EXECUTABLE_SUFFIX_ASM .elf) 
set(CMAKE_EXECUTABLE_SUFFIX ".elf") #For some reason setting this works for ASM files but SUFFIX_ASM doesnt

######################
# Get current OS distribution for dependency downloads
######################
file(READ "/etc/os-release" OS_REL)
string(REGEX MATCH "Fedora|Ubuntu" DIST ${OS_REL})

if(DIST STREQUAL "Ubuntu")
    message(STATUS "Found Ubuntu")
elseif(DIST STREQUAL "Fedora")
    message(STATUS "Found Fedora")
else()
    message(WARNING "Found untested distribution. You might need to install submodule dependencies separately.")
endif()

include(${TOOLCHAIN_TOP}/CMake/toolchain_build.cmake) #include toolchain macros

message(STATUS "Selected FRAMEWORK = ${FRAMEWORK}")

#######
## Compiler Selection
#######
if(${COMPILER} STREQUAL "GCC")
    #build gcc multilib
    build_gcc_multilib()
    # Select Toolchain File

    option(AUTOVEC "Disable/Enable Autovectorization for GCC" ON)
    if (${AUTOVEC})
        set(AUTOVEC_FLAGS "-ftree-vectorize -fno-tree-slp-vectorize")
    else()
        set(AUTOVEC_FLAGS "-fno-tree-vectorize -fno-tree-slp-vectorize")
    endif()

    set(CMAKE_TOOLCHAIN_FILE "${TOOLCHAIN_TOP}/GCC/gcc_toolchain.cmake")

elseif(${COMPILER} STREQUAL "LLVM")
    build_llvm()
    set(CMAKE_TOOLCHAIN_FILE "${TOOLCHAIN_TOP}/llvm/llvm_toolchain.cmake")
else()
    message(FATAL_ERROR "UNSUPPORTED COMPILER SELECTED.  Select a valid compiler with -DCOMPILER=GCC/LLVM.")
endif()
project(Vicuna2_Benchmarking_Environment LANGUAGES C CXX ASM DESCRIPTION "Vicuna2 Benchmarking Environment")
include(CTest)

########
#Add Program Subdirectories
########

add_subdirectory(../benchmark_sources benchmark_sources)





