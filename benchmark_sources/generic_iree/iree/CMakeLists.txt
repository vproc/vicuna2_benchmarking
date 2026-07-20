# IREE runtime setup for generic_iree tests and MLPerfTiny tests compiled with IREE flag

message(STATUS "Configuring IREE runtime for generic_iree...")

# Configuration for bare-metal RISC-V32 MLIR execution
set(IREE_BUILD_COMPILER OFF CACHE BOOL "" FORCE)
set(IREE_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(IREE_BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)
set(IREE_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(IREE_BUILD_SAMPLES OFF CACHE BOOL "" FORCE)
set(IREE_BUILD_PYTHON_BINDINGS OFF CACHE BOOL "" FORCE)
set(IREE_BUILD_TRACY OFF CACHE BOOL "" FORCE)
set(IREE_BUILD_TOOLS OFF CACHE BOOL "" FORCE)

# Bare-metal specific configurations
set(IREE_ENABLE_THREADING OFF CACHE BOOL "" FORCE)
set(IREE_ENABLE_POSIX OFF CACHE BOOL "" FORCE)
set(IREE_ENABLE_RUNTIME_TRACING OFF CACHE BOOL "" FORCE)
set(IREE_ENABLE_WERROR_FLAG OFF CACHE BOOL "" FORCE)
set(IREE_SYNCHRONIZATION_DISABLE_UNSAFE ON CACHE BOOL "" FORCE)
set(IREE_CSPRNG_USE_STUB ON CACHE BOOL "" FORCE)
set(IREE_SOCKETS_ENABLE OFF CACHE BOOL "" FORCE)
set(IREE_HAL_DRIVER_DEFAULTS OFF CACHE BOOL "" FORCE)
set(IREE_HAL_DRIVER_LOCAL_SYNC ON CACHE BOOL "" FORCE)
set(IREE_HAL_DRIVER_LOCAL_TASK OFF CACHE BOOL "" FORCE)
set(IREE_HAL_DRIVER_NULL OFF CACHE BOOL "" FORCE)
set(IREE_HAL_DRIVER_VULKAN OFF CACHE BOOL "" FORCE)
set(IREE_HAL_EXECUTABLE_LOADER_DEFAULTS OFF CACHE BOOL "" FORCE)
set(IREE_HAL_EXECUTABLE_LOADER_EMBEDDED_ELF ON CACHE BOOL "" FORCE)
set(IREE_HAL_EXECUTABLE_PLUGIN_DEFAULTS OFF CACHE BOOL "" FORCE)
set(IREE_HAL_EXECUTABLE_PLUGIN_EMBEDDED_ELF ON CACHE BOOL "" FORCE)

# Fetch compiler from host
# TODO: add an optin for compile the compiler as well as runtime
set(IREE_HOST_BIN_DIR "/home/efectn/iree-prod-test/iree-build-compiler/tools" CACHE STRING "" FORCE)

# Bare-metal platform defines
add_compile_definitions(
    IREE_PLATFORM_GENERIC=1
    IREE_FILE_IO_ENABLE=0
    IREE_DEVICE_SIZE_T=uint32_t
    PRIdsz=PRIu32
    IREE_SOCKETS_ENABLE=0
)

# Suppress warnings stemmed from IREE source code
string(APPEND CMAKE_C_FLAGS " -Wno-type-limits -Wno-unused-parameter -Wno-missing-field-initializers -Wno-ignored-qualifiers -Wno-cast-function-type")
string(APPEND CMAKE_CXX_FLAGS " -Wno-type-limits -Wno-unused-parameter -Wno-missing-field-initializers -Wno-ignored-qualifiers -Wno-cast-function-type")

# Remove -Werror to allow warnings
string(REPLACE " -Werror" "" CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
string(REPLACE " -Werror" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
string(REPLACE " -Werror" "" CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS}")

# IREE_TIME_NOW_FN stuff
string(APPEND CMAKE_C_FLAGS " -DIREE_TIME_NOW_FN=\\{return\\ 0\\;\\}")
string(APPEND CMAKE_CXX_FLAGS " -DIREE_TIME_NOW_FN=\\{return\\ 0\\;\\}")
string(APPEND CMAKE_ASM_FLAGS " -DIREE_TIME_NOW_FN=\\{return\\ 0\\;\\}")

# Math library
string(APPEND CMAKE_EXE_LINKER_FLAGS " -lm")

# Apply IREE patches if not already applied
set(IREE_PATCH_DIR "${CMAKE_CURRENT_SOURCE_DIR}/iree-patches")
set(IREE_PATCH_STAMP "${CMAKE_CURRENT_SOURCE_DIR}/iree-source/.patches_applied")

if(NOT EXISTS "${IREE_PATCH_STAMP}")
    message(STATUS "Applying IREE patches from ${IREE_PATCH_DIR}")
    file(GLOB IREE_PATCHES "${IREE_PATCH_DIR}/*.patch")
    
    # Sort patches to ensure they are applied in order
    list(SORT IREE_PATCHES)
    
    foreach(PATCH_FILE IN LISTS IREE_PATCHES)
        message(STATUS "Applying patch: ${PATCH_FILE}")
        execute_process(
            COMMAND git apply "${PATCH_FILE}"
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/iree-source"
            RESULT_VARIABLE PATCH_RESULT
        )
        if(NOT PATCH_RESULT EQUAL 0)
            message(FATAL_ERROR "Failed to apply patch: ${PATCH_FILE}")
        endif()
    endforeach()
    
    file(TOUCH "${IREE_PATCH_STAMP}")
endif()

# Add IREE runtime source as subdirectory
set(_MLPERFTINY_IREE_PREV_SYSTEM_PROCESSOR ${CMAKE_SYSTEM_PROCESSOR})
set(CMAKE_SYSTEM_PROCESSOR riscv32)
add_subdirectory(iree-source iree-source EXCLUDE_FROM_ALL)
set(CMAKE_SYSTEM_PROCESSOR ${_MLPERFTINY_IREE_PREV_SYSTEM_PROCESSOR})
unset(_MLPERFTINY_IREE_PREV_SYSTEM_PROCESSOR)

# Create unified runtime target
if(TARGET iree::runtime::unified)
    message(STATUS "IREE runtime::unified available for generic_iree")
else()
    message(WARNING "IREE runtime::unified not found")
endif()

message(STATUS "IREE runtime configured for generic_iree")
