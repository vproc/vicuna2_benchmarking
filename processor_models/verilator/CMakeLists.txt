cmake_minimum_required(VERSION 3.10)
message(STATUS "CMake Version ${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION}.${CMAKE_PATCH_VERSION}")

###This file is used to build the verilated models of CV32E40X and Vicuna###

########################
# Arguments
#
# RV_ARCH : select the processor architecture configuration to verilate
# TRACE   : If defined, enable vcd trace outputs.  WARNING: Traces can be very large (GBs)
# TRACE_FULL   : If defined, trace outputs of ENTIRE model WARNING: Traces can be very VERY large (GBs) (requires TRACE=ON)
# CACHE :   Enable a cache configuration


#####################
# Setup the CMake Project
####################

project(Verilated-Builds LANGUAGES C CXX DESCRIPTION "Environment for Verilating Models")


set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Using C and C++ 11
set(CMAKE_C_STANDARD 14)
set(CMAKE_CXX_STANDARD 14)

option(TRACE "Enable minimal VCD trace outputs" OFF)
option(TRACE_FULL "Enable FULL VCD trace outputs" OFF) #TODO: prevent this option from being cached, force user to always manually enable it

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

#####################
# Check if verilator has been built and include tool.   If not, build it
####################
set(TOOLCHAIN_TOP ${CMAKE_CURRENT_SOURCE_DIR}/../../toolchain) #Top level path to toolchain folder
include(${TOOLCHAIN_TOP}/CMake/toolchain_build.cmake) #include toolchain macros

build_verilator()

find_package(verilator HINTS ${CMAKE_CURRENT_SOURCE_DIR}/../../toolchain/verilator)

########
## Import RTL configuration from here instead of command line.
## File shared with program compliation.
########
include(${CMAKE_CURRENT_SOURCE_DIR}/../vector_config.cmake)
message("Selected SCALAR_CORE = ${SCALAR_CORE}")
set(ENV{VPROC_PIPELINES} ${VPROC_PIPELINES})
message("Selected VPROC_PIPELINES = ${VPROC_PIPELINES}")
message("Selected RISCV_ARCH = ${RISCV_ARCH}")
set(ENV{VREG_W} ${VREG_W})
message("Selected VREG_W = ${VREG_W}")
set(MEM_W ${VMEM_W})
message("Selected MEM_W = ${MEM_W}")
set(MEM_PORTS ${VMEM_PORTS})
message("Selected MEM_PORTS = ${MEM_PORTS}")

set(MEM_SZ 4194304)

######################
# Extension Flags
######################

if(${RISCV_ARCH} STREQUAL "rv32im") #Build only scalar core
    set(XIF_FLAG "" )
    set(RISCV_F "" )
    set(RISCV_ZFH "" )
    set(RISCV_ZVE32X "" )
    set(RISCV_ZVE32F "" )
    set(RISCV_ZVFH "" )

elseif(${RISCV_ARCH} STREQUAL "rv32imf") #Build scalar core with FPU on the Xif interface
    set(XIF_FLAG "-DXIF_ON" )
    set(RISCV_F "-DRISCV_F" )
    set(RISCV_ZFH "" )
    set(RISCV_ZVE32X "" )
    set(RISCV_ZVE32F "" )
    set(RISCV_ZVFH "" )
    #C++ Flags
    add_definitions(-DRISCV_F)

elseif(${RISCV_ARCH} STREQUAL "rv32imf_zfh") #Build scalar core with FPU on the Xif interface with half-float support
    set(XIF_FLAG "-DXIF_ON" )
    set(RISCV_F "-DRISCV_F" )
    set(RISCV_ZFH "-DRISCV_ZFH" )
    set(RISCV_ZVE32X "" )
    set(RISCV_ZVE32F "" )
    set(RISCV_ZVFH "" )
    #C++ Flags
    add_definitions(-DRISCV_F)
    add_definitions(-DRISCV_ZFH)

elseif(${RISCV_ARCH} STREQUAL "rv32im_zve32x") #Build scalar core with Vicuna on the Xif interface
    set(XIF_FLAG "-DXIF_ON" )
    set(RISCV_F "" )
    set(RISCV_ZFH "" )
    set(RISCV_ZVE32X "-DRISCV_ZVE32X" )
    set(RISCV_ZVE32F "" )
    set(RISCV_ZVFH "" )
    #C++ Flags
    add_definitions(-DRISCV_ZVE32X)

elseif(${RISCV_ARCH} STREQUAL "rv32imf_zve32f") #Build scalar core with Vicuna and FPU on the Xif interface
    set(XIF_FLAG "-DXIF_ON" )
    set(RISCV_F "-DRISCV_F" )
    set(RISCV_ZFH "" )
    set(RISCV_ZVE32X "-DRISCV_ZVE32X" )
    set(RISCV_ZVE32F "-DRISCV_ZVE32F" )
    set(RISCV_ZVFH "" )
    #C++ Flags
    add_definitions(-DRISCV_F)
    add_definitions(-DRISCV_ZVE32X)
    add_definitions(-DRISCV_ZVE32F)

elseif(${RISCV_ARCH} STREQUAL "rv32imf_zfh_zve32f_zvfh") #Build scalar core with Vicuna (+floating point + half precision float) and FPU on the Xif interface
    set(XIF_FLAG "-DXIF_ON" )
    set(RISCV_F "-DRISCV_F" )
    set(RISCV_ZFH "-DRISCV_ZFH" )
    set(RISCV_ZVE32X "-DRISCV_ZVE32X" )
    set(RISCV_ZVE32F "-DRISCV_ZVE32F" )
    set(RISCV_ZVFH "-DRISCV_ZVFH" )
    #C++ Flags
    add_definitions(-DRISCV_F)
    add_definitions(-DRISCV_ZFH)
    add_definitions(-DRISCV_ZVE32X)
    add_definitions(-DRISCV_ZVE32F)
    add_definitions(-DRISCV_ZVFH)

else()
    message(FATAL_ERROR "Unsupported RISCV_ARCH selected")

endif()

######################
# Sources/Include Directories
######################

add_subdirectory(../../rtl/ rtl)


######################
# Flags
######################
### TRACE FLAGS

#if(TRACE)
   add_definitions(-DTRACE_VCD)
   set(TRACE TRACE)
    
#    if(TRACE_FULL)
#        set(TRACE_FLAG  ) #no --trace-depth flag defaults to entire model
#    else()
#        set(TRACE_FLAG --trace-depth 2)
#    endif()
#endif()

### Experimental Features flags
#if(OLD_VICUNA)
set(VICUNA_MODE -DOLD_VICUNA)
#endif()

#This always needs to be set
set(READ_MODE -DFORCE_ALIGNED_READS)
#if(FORCE_ALIGNED_READS)
    #set(READ_MODE -DFORCE_ALIGNED_READS)
#endif()

#CV32A60X sends Issue and Commit signals at the same time, change operating mode
if(${SCALAR_CORE} STREQUAL "cv32a60x")
    set(COMMIT_AND_ISSUE -DCOMMIT_AND_ISSUE)
endif()

######################
# Run Verilator to create model
######################

#Create the verilated model 
add_executable(verilated_model)

target_sources(verilated_model PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/${SCALAR_CORE}/verilator_support_${SCALAR_CORE}.h
    ${CMAKE_CURRENT_SOURCE_DIR}/${SCALAR_CORE}/verilator_support_${SCALAR_CORE}.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/${SCALAR_CORE}/verilator_main.cpp)

if ( ${SCALAR_CORE} STREQUAL "cv32e40x" )
    verilate(verilated_model SOURCES  ${DESIGN_SRC_OBI} ${CV32E40X_SOURCE} ${VICUNA_FPU_SRCS} ${VICUNA_SRCS} ${FPU_SS_SOURCE} ${CMAKE_CURRENT_SOURCE_DIR}/${SCALAR_CORE}/vproc_top.sv
                INCLUDE_DIRS  ${INCLUDE_OBI} ${CV32E40X_INCLUDE} ${VICUNA_FPU_INCS} ${VICUNA_INCS} ${FPU_SS_INCLUDE} ${CMAKE_CURRENT_SOURCE_DIR}
                TOP_MODULE vproc_top 
                PREFIX Vvproc_top
                ${TRACE}                                    
                VERILATOR_ARGS -cc -exe ${CMAKE_CURRENT_SOURCE_DIR}/${SCALAR_CORE}/verilator_main.cpp --unroll-count 1024
                                -Wno-WIDTH -Wno-PINMISSING -Wno-UNOPTFLAT   
                                -Wno-UNSIGNED -Wno-IMPLICIT -Wno-LITENDIAN -Wno-CASEINCOMPLETE
                                -Wno-SYMRSVDWORD -Wno-BLKANDNBLK -Wno-BLKSEQ -Wno-SYNCASYNCNET
                                -Wno-COMBDLY 
                                -Wno-WIDTHCONCAT
                                -Wno-ENUMVALUE 
                                -Wno-SELRANGE -Wno-LATCH #These might be caused from not connecting everything properly
                                -Wno-IMPLICITSTATIC      
                                #+define+COREV_ASSERT_OFF       #Fixes UVM error with CV32E40X (Needed when not using -DVPROC_SVA)
                                ${TRACE_FLAG} 
                                --assert -DVPROC_SVA
                                -GMEM_W=${MEM_W} -GVMEM_W=${VMEM_W} -GMEM_PORTS=${MEM_PORTS}
                                ${VICUNA_MODE}
                                ${READ_MODE}
                                ${XIF_FLAG}
                                ${RISCV_F}
                                ${RISCV_ZFH}
                                ${RISCV_ZVE32X}
                                ${RISCV_ZVE32F}
                                ${RISCV_ZVFH}
                                -CFLAGS "-std=gnu++14 -O2")

elseif( ${SCALAR_CORE} STREQUAL "cv32a60x" ) #TODO: Verify/Test support for floating point vector systems with this core.  Currently, only Zve32x tested.
    verilate(verilated_model SOURCES ${DESIGN_SRC_OBI} ${CV32A60X_SOURCE} ${VICUNA_SRCS} ${CMAKE_CURRENT_SOURCE_DIR}/${SCALAR_CORE}/vproc_top.sv
                INCLUDE_DIRS ${INCLUDE_OBI} ${CV32A60X_INCLUDE} ${VICUNA_INCS} ${CMAKE_CURRENT_SOURCE_DIR}
                TOP_MODULE vproc_top 
                PREFIX Vvproc_top
                ${TRACE}                                    
                VERILATOR_ARGS -cc -exe ${CMAKE_CURRENT_SOURCE_DIR}/${SCALAR_CORE}/verilator_main.cpp --unroll-count 1024
                                -Wno-WIDTH -Wno-PINMISSING -Wno-UNOPTFLAT   
                                -Wno-UNSIGNED -Wno-IMPLICIT -Wno-LITENDIAN -Wno-CASEINCOMPLETE
                                -Wno-SYMRSVDWORD -Wno-BLKANDNBLK -Wno-BLKSEQ -Wno-SYNCASYNCNET
                                -Wno-COMBDLY 
                                -Wno-WIDTHCONCAT
                                -Wno-ENUMVALUE 
                                -Wno-SELRANGE -Wno-LATCH #These might be caused from not connecting everything properly
                                -Wno-IMPLICITSTATIC      
                                #+define+COREV_ASSERT_OFF       #Fixes UVM error with CV32E40X (Needed when not using -DVPROC_SVA)
                                #--clk clk_i
                                ${TRACE_FLAG} 
                                --assert -DVPROC_SVA
                                -GMEM_W=${MEM_W} -GVMEM_W=${VMEM_W} -GMEM_PORTS=${MEM_PORTS}
                                ${VICUNA_MODE}
                                ${READ_MODE}
                                ${XIF_FLAG}
                                ${RISCV_F}
                                ${RISCV_ZFH}
                                ${RISCV_ZVE32X}
                                ${RISCV_ZVE32F}
                                ${RISCV_ZVFH}
                                ${COMMIT_AND_ISSUE}
                                -CFLAGS "-std=gnu++14 -O2")



        # Compile verilator model as a shared library for linking with gem5.  This prevents a rebuild of gem5 every time the model changes.  Currently only supported for CVA6
        add_library(verilated_model_lib SHARED)

        file(GLOB VERILATOR_FILES "${CMAKE_CURRENT_SOURCE_DIR}/build/CMakeFiles/verilated_model.dir/Vvproc_top.dir/*.cpp" )
        target_sources(verilated_model_lib PUBLIC
        ${TOOLCHAIN_TOP}/verilator/include/verilated.cpp
        ${TOOLCHAIN_TOP}/verilator/include/verilated_vcd_c.cpp
        ${TOOLCHAIN_TOP}/verilator/include/verilated_threads.cpp
        ${VERILATOR_FILES}
        )

        target_include_directories(verilated_model_lib PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/build/CMakeFiles/verilated_model.dir/Vvproc_top.dir/
        ${TOOLCHAIN_TOP}/verilator/include/gtkwave/
        ${TOOLCHAIN_TOP}/verilator/include/vltstd/
        ${TOOLCHAIN_TOP}/verilator/include/
        )


else()
    message(FATAL_ERROR "Unsupported Scalar Core Selected")
endif()



