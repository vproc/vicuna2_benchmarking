# generic_iree - Generic IREE/MLIR Test Suite

message(STATUS "Setting up generic_iree IREE/MLIR test suite")

# Configure IREE runtime for bare-metal tests
add_subdirectory(iree iree)

# Verify IREE runtime is available after configuration
if(NOT TARGET iree::runtime::unified)
    message(FATAL_ERROR "IREE runtime not available after iree subdirectory configuration")
endif()

# Directories
set(GENERIC_IREE_BAREMETAL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/baremetal)
set(GENERIC_IREE_TESTS_DIR ${CMAKE_CURRENT_SOURCE_DIR}/tests)

message(STATUS "Baremetal infrastructure dir: ${GENERIC_IREE_BAREMETAL_DIR}")

# Build spike simulator if needed
build_spike()

# Set IREE compiler tools directory (where iree-compile lives)

# Include IREE test macro
include(CMake/add_test.cmake)

# Add tests
add_IreeBenchmark_Spike(add_vector ${CMAKE_CURRENT_SOURCE_DIR}/tests/add_vector)

message(STATUS "generic_iree test suite configured successfully")
