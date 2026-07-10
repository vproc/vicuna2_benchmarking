#####
# Add Generic C Programs to CTest
#####

# Add test addition macros
include(${CMAKE_CURRENT_SOURCE_DIR}/CMake/add_test.cmake)

######
#   CMAKE directory declarations for these tests
######
set(PROGRAMS_TOP ${CMAKE_CURRENT_SOURCE_DIR}/programs)
set(TEST_BUILD_DIR ${BUILD_DIR}/benchmark_sources/generic_cpp)                #TODO: Remove this dependency

######
# Add Tests
######

file(GLOB files "${CMAKE_CURRENT_SOURCE_DIR}/programs/matmul/test_data/*.cpp" )
foreach(item ${files})
    string(REPLACE ".cpp" "" test_num ${item})
    string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/programs/matmul/test_data/test_data_" "" test_num ${test_num})
    set(test_name "matmul")
    # add_benchmark_Verilator(${test_name} ${test_num})
    # add_benchmark_Gem5(${test_name} ${test_num} gem5_caches)
    add_benchmark_etiss(${test_name} ${test_num})
endforeach()

file(GLOB files "${CMAKE_CURRENT_SOURCE_DIR}/programs/add/test_data/*.cpp" )
foreach(item ${files})
    string(REPLACE ".cpp" "" test_num ${item})
    string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/programs/add/test_data/test_data_" "" test_num ${test_num})
    set(test_name "add")
    # add_benchmark_Verilator(${test_name} ${test_num})
    # add_benchmark_Gem5(${test_name} ${test_num} gem5_caches)
endforeach()

file(GLOB files "${CMAKE_CURRENT_SOURCE_DIR}/programs/mul/test_data/*.cpp" )
foreach(item ${files})
    string(REPLACE ".cpp" "" test_num ${item})
    string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/programs/mul/test_data/test_data_" "" test_num ${test_num})
    set(test_name "mul")
    # add_benchmark_Verilator(${test_name} ${test_num})
    # add_benchmark_Gem5(${test_name} ${test_num} gem5_caches)
endforeach()

file(GLOB files "${CMAKE_CURRENT_SOURCE_DIR}/programs/fir/test_data/*.cpp" )
foreach(item ${files})
    string(REPLACE ".cpp" "" test_num ${item})
    string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/programs/fir/test_data/test_data_" "" test_num ${test_num})
    set(test_name "fir")
    # add_benchmark_Verilator(${test_name} ${test_num})
    # add_benchmark_Gem5(${test_name} ${test_num} gem5_caches)
endforeach()
