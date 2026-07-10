add_subdirectory(vicuna2_bsp vicuna2_bsp)
set(VICUNA_BSP_TOP ${CMAKE_CURRENT_SOURCE_DIR}/vicuna2_bsp/ PARENT_SCOPE)

add_subdirectory(etiss)
set(ETISS_CRT_TOP ${CMAKE_CURRENT_SOURCE_DIR}/etiss/ PARENT_SCOPE)

set(FRAMEWORK_TOP ${CMAKE_CURRENT_SOURCE_DIR}/ PARENT_SCOPE)

#Add header library for Verilator only simulation specific implementations
add_library(sim_Verilator INTERFACE)

target_include_directories(sim_Verilator INTERFACE
  ${CMAKE_CURRENT_SOURCE_DIR}/verilator
)

#Add header library for gem5 only simulation specific implementations
add_library(sim_gem5 INTERFACE)

target_include_directories(sim_gem5 INTERFACE
  ${CMAKE_CURRENT_SOURCE_DIR}/gem5
)

#Add library for hybrid simulation specific implementations
add_library(sim_hybrid INTERFACE)

target_include_directories(sim_hybrid INTERFACE
  ${CMAKE_CURRENT_SOURCE_DIR}/hybrid
)

#Add library for hybrid simulation specific implementations
add_library(sim_spike INTERFACE)

target_include_directories(sim_spike INTERFACE
  ${CMAKE_CURRENT_SOURCE_DIR}/spike
)

#Add library for ETISS simulation specific implementations
add_library(sim_etiss INTERFACE)

target_include_directories(sim_etiss INTERFACE
  ${CMAKE_CURRENT_SOURCE_DIR}/etiss
)

