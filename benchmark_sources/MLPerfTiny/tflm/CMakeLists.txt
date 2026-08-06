####
# Include file with macros for adding tests
####
include(${CMAKE_CURRENT_SOURCE_DIR}/../CMake/add_test.cmake)

#
# Copyright (C) 2021-2024 Chair of Electronic Design Automation, TUM.
# Copyright (C) 2025-2026 TUWien.
#
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the License); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an AS IS BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

######
# Check if TFLM source tree has been generated.  If not, generate it.
# When using MURISCV-NN, a source tree needs to be generated with CMSIS kernels
######
if(MURISCV_NN)

  if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tflm_source_tree_cmsis")
      message("Tensorflow Source Tree not found for muRISCV-NN.  Generating now.")
      execute_process(COMMAND mkdir tflm_source_tree_cmsis
                      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
      execute_process(COMMAND python3 tensorflow/lite/micro/tools/project_generation/create_tflm_tree.py ../tflm_source_tree_cmsis --makefile_options="OPTIMIZED_KERNEL_DIR=cmsis_nn"
                      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tflite-micro)
  endif()

  set(TFLM_SOURCE_TREE_TOP ${CMAKE_CURRENT_SOURCE_DIR}/tflm_source_tree_cmsis)

else()

  if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tflm_source_tree")
      message("Tensorflow Source Tree not found.  Generating now.")
      execute_process(COMMAND mkdir tflm_source_tree
                      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
      execute_process(COMMAND python3 tensorflow/lite/micro/tools/project_generation/create_tflm_tree.py ../tflm_source_tree
                      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tflite-micro)
  endif()

  set(TFLM_SOURCE_TREE_TOP ${CMAKE_CURRENT_SOURCE_DIR}/tflm_source_tree)


endif()

######
# Build TFLM as a library
######


add_library(tflm STATIC)

# Needed to run TensorFlow code with RISC-V toolchain
add_definitions(-DTF_LITE_USE_GLOBAL_MAX)
add_definitions(-DTF_LITE_USE_GLOBAL_MIN)
add_definitions(-DTF_LITE_STATIC_MEMORY)
add_definitions(-DTF_LITE_USE_GLOBAL_CMATH_FUNCTIONS)
if(NOT RISCV_F)
    add_definitions(-DTFLITE_EMULATE_FLOAT)                         #Might have issues with this for F extensions
endif()
add_definitions(-fno-rtti)          #Needed for GCC to resolve virtual delete function scope issue
add_definitions(-fno-exceptions)    #Needed for GCC to resolve virtual delete function scope issue

if(RISCV_ZFH)
#Need to include custom tflm files for fp16 support
    if(FH_OPS)
        message("USING FP16 INTERMEDIATE OPS")
        set(FH_INCLUDE ${CMAKE_CURRENT_SOURCE_DIR}/FH_Support/16_bit_ops)
        
        set(FH_SUPPORT_SRCS
        ${FH_INCLUDE}/dequantize.h 
        ${FH_INCLUDE}/dequantize.cc
        ${FH_INCLUDE}/dequantize_common.cc
        ${FH_INCLUDE}/fully_connected.h
        ${FH_INCLUDE}/fully_connected.cc
        ${FH_INCLUDE}/fully_connected_common.cc
        
        ${FH_INCLUDE}/conv.h
        ${FH_INCLUDE}/conv.cc
        ${FH_INCLUDE}/conv_common.cc
        
        ${FH_INCLUDE}/depthwiseconv_float.h
        ${FH_INCLUDE}/depthwise_conv.cc
        ${FH_INCLUDE}/depthwise_conv_common.cc
        
        ${FH_INCLUDE}/pooling.h
        ${FH_INCLUDE}/pooling.cc
        ${FH_INCLUDE}/pooling_common.cc
        
        ${FH_INCLUDE}/reshape.cc
        ${FH_INCLUDE}/reshape_common.cc
        
        ${FH_INCLUDE}/softmax.h
        ${FH_INCLUDE}/softmax.cc
        ${FH_INCLUDE}/softmax_common.cc
        )
    else()
        message("USING FP32 INTERMEDIATE OPS WITH FP16 INPUTS")
        set(FH_INCLUDE ${CMAKE_CURRENT_SOURCE_DIR}/FH_Support/32_bit_ops)
        
        set(FH_SUPPORT_SRCS
        ${FH_INCLUDE}/dequantize.h 
        ${FH_INCLUDE}/dequantize.cc
        ${FH_INCLUDE}/dequantize_common.cc
        
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/fully_connected.h #Use original FC Kernel, using float
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/fully_connected.cc
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/fully_connected_common.cc
        
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/conv.h
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/conv.cc
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/conv_common.cc
        
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/depthwiseconv_float.h
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/depthwise_conv.cc
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/depthwise_conv_common.cc
        
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/pooling.h
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/pooling.cc
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/pooling_common.cc
        
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/reshape.cc
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/reshape_common.cc
        
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/softmax.h
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/softmax.cc
        ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/softmax_common.cc
        
        )
    
    
    
    
    endif()
else()
  if (NOT MURISCV_NN)
    message("Using TFLM Default Reference Operations and Kernels")
      set(FH_INCLUDE "")
      #No FH support, use original sources
      set(FH_SUPPORT_SRCS
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/dequantize.h 
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/dequantize.cc
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/dequantize_common.cc
      
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/fully_connected.h
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/fully_connected.cc
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/fully_connected_common.cc
      
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/conv.h
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/conv.cc
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/conv_common.cc
      
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/depthwiseconv_float.h
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/depthwise_conv.cc
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/depthwise_conv_common.cc
      
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/pooling.h
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/pooling.cc
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/pooling_common.cc
      
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/reshape.cc
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/reshape_common.cc
      
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/softmax.h
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/softmax.cc
      ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/softmax_common.cc
    )
  endif()
endif()


if(MURISCV_NN)
  set(TFLM_SRCS
    ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/cmsis_nn/fully_connected.cc
    ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/fully_connected_common.cc
  #   ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/cmsis_nn/mul.cc
  #   ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/cmsis_nn/add.cc
  # #  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/cmsis_nn/svdf.cc
  #   ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/cmsis_nn/conv.cc
  #   ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/cmsis_nn/depthwise_conv.cc
  #   ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/cmsis_nn/pooling.cc
  #   ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/cmsis_nn/softmax.cc
  )
  #add_definitions(-DUSE_PORTABLE_VEXT)
  add_definitions(-DCMSIS_NN)
else()
  set(TFLM_SRCS
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/fully_connected.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/mul.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/add.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/svdf.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/conv.cc
)
endif()

set(TFLM_SRCS
  ${TFLM_SRCS}
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/c/common.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/c/c_api_types.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/core/c/common.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/core/c/common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/c/builtin_op_data.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/builtin_ops.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/schema/schema_generated.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/compiler/mlir/lite/schema/schema_utils.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/schema/schema_utils.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/context_util.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_resource_variable.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/fake_micro_context.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/test_helpers.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/memory_planner/micro_memory_planner.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/memory_planner/linear_memory_planner.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/memory_planner/memory_plan_struct.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/memory_planner/linear_memory_planner.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/memory_planner/non_persistent_buffer_planner_shim.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/memory_planner/greedy_memory_planner.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/memory_planner/non_persistent_buffer_planner_shim.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/memory_planner/greedy_memory_planner.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/memory_helpers.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_allocator.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/system_setup.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/memory_helpers.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/mock_micro_graph.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/system_setup.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/flatbuffer_utils.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/fake_micro_context.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/recording_micro_allocator.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_utils.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_mutable_op_resolver.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/debug_log.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_profiler.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/test_helpers.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_resource_variable.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_context.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_profiler.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_utils.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_interpreter.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_allocation_info.cc
# ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_string.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/mock_micro_graph.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/compatibility.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/flatbuffer_utils.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/tflite_bridge/micro_error_reporter.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_time.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_allocation_info.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_interpreter_graph.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_interpreter_context.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/arena_allocator/single_arena_buffer_allocator.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/arena_allocator/single_arena_buffer_allocator.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/arena_allocator/persistent_arena_buffer_allocator.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/arena_allocator/ibuffer_allocator.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/arena_allocator/persistent_arena_buffer_allocator.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/arena_allocator/recording_single_arena_buffer_allocator.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/arena_allocator/recording_single_arena_buffer_allocator.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/arena_allocator/non_persistent_arena_buffer_allocator.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/arena_allocator/non_persistent_arena_buffer_allocator.h
#  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_string.h
#  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/all_ops_resolver.h
#  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_graph.cc
#  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/all_ops_resolver.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/recording_micro_interpreter.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_context.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_allocator.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/tflite_bridge/micro_error_reporter.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_interpreter.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_time.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/test_helper_custom_ops.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_graph.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/recording_micro_allocator.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/hard_swish.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/add_common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/detection_postprocess_flexbuffers_generated_data.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/lstm_eval.h
  #${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/dequantize.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/kernel_util.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/concatenation.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/space_to_batch_nd.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/resize_nearest_neighbor.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/softmax.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/pack.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/broadcast_args.cc
#  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/maximum_minimum.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/mul_common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/quantize.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/hard_swish_common.cc
  
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/cumsum.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/dequantize.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/prelu.h
#  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/pad.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/floor.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/split_v.cc
 # ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/svdf_common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/logistic.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/shape.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/micro_tensor_utils.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/conv_test.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/batch_to_space_nd.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/circular_buffer_flexbuffers_generated_data.h
#  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/micro_utils.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/kernel_runner.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/leaky_relu.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/sub.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/logistic.cc
#  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/unidirectional_sequence_lstm.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/floor_div.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/kernel_runner.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/hard_swish.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/ceil.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/strided_slice.cc

  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/logical.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/fully_connected.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/circular_buffer.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/micro_ops.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/kernel_util.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/assign_variable.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/sub_common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/reduce.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/unpack.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/ethosu.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/activations_common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/ethosu.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/conv.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/squared_difference.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/l2norm.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/l2_pool_2d.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/round.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/tanh.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/add_n.cc
  #${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/dequantize_common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/broadcast_to.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/circular_buffer.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/space_to_depth.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/add.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/quantize_common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/logical.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/split.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/if.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/expand_dims.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/logical_common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/lstm_eval.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/sub.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/prelu_common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/slice.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/gather.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/squeeze.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/floor_mod.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/depth_to_space.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/quantize.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/mul.h
  #${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/fully_connected_common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/gather_nd.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/reduce_common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/mirror_pad.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/activations.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/micro_tensor_utils.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/activations.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/fill.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/resize_bilinear.cc
 # ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/svdf.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/call_once.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/prelu.cc
  
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/lstm_shared.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/zeros_like.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/neg.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/elementwise.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/read_variable.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/div.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/while.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/exp.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/reduce.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/detection_postprocess.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/depthwise_conv.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/circular_buffer_common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/leaky_relu_common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/activation_utils.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/arg_min_max.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/comparisons.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/log_softmax.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/cast.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/leaky_relu.h
#  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/transpose_conv.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/pooling.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/elu.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/var_handle.cc
 # ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/unidirectional_sequence_lstm_test_config.h
#  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/transpose.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/kernels/logistic_common.cc
  
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/debug_log.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_op_resolver.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_op_resolver.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_arena_constants.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/test_helper_custom_ops.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_log.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/micro_log.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/tflite_bridge/flatbuffer_conversions_bridge.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/micro/tflite_bridge/flatbuffer_conversions_bridge.cc
 # ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/core/api/error_reporter.cc
 ${TFLM_SOURCE_TREE_TOP}/tensorflow/compiler/mlir/lite/core/api/error_reporter.cc
 ${TFLM_SOURCE_TREE_TOP}/tensorflow/compiler/mlir/lite/core/api/error_reporter.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/core/api/error_reporter.h
#  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/core/api/op_resolver.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/core/api/flatbuffer_conversions.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/core/api/tensor_utils.h
#  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/core/api/op_resolver.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/core/api/tensor_utils.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/core/api/flatbuffer_conversions.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/op_macros.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/kernel_util.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/kernel_util.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/tensor_ctypes.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/tensor_ctypes.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/strided_slice_logic.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/common.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/types.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/min.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/optimized/neon_check.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/portable_tensor.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/quantization_util.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/portable_tensor_utils_impl.h
  
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/slice.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/log_softmax.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/process_broadcast_shapes.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/broadcast_to.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/transpose.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/depthwiseconv_float.h
#  
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/prelu.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/logistic.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/comparisons.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/depthwiseconv_uint8.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/space_to_depth.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/ceil.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/sub.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/transpose_conv.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/depth_to_space.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/hard_swish.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/strided_slice.h
  #${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/fully_connected.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/floor_mod.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/batch_to_space_nd.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/binary_function.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/requantize.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/broadcast_args.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/concatenation.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/elu.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/add.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/pad.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/add_n.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/div.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/cumsum.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/exp.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/space_to_batch_nd.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/neg.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/batch_matmul.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/resize_nearest_neighbor.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/fill.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/quantize.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/mul.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/tanh.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/arg_min_max.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/portable_tensor_utils.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/l2normalization.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/round.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/reduce.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/portable_tensor_utils.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/floor_div.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/leaky_relu.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/resize_bilinear.h
  
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/integer_ops/logistic.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/integer_ops/mean.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/integer_ops/transpose_conv.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/integer_ops/fully_connected.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/integer_ops/conv.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/integer_ops/add.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/integer_ops/mul.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/integer_ops/tanh.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/integer_ops/l2normalization.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/integer_ops/depthwise_conv.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/integer_ops/pooling.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/maximum_minimum.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/floor.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/reference/lstm_cell.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/compatibility.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/runtime_shape.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/max.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/quantization_util.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/portable_tensor_utils.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/portable_tensor_utils.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/cppmath.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/internal/common.cc
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/kernels/padding.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/portable_type_to_tflitetype.h
  ${TFLM_SOURCE_TREE_TOP}/tensorflow/lite/builtin_op_data.h
)

set(TFLM_THIRD_PARTY_SRCS
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/util.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/vector.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/flexbuffers.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/struct.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/array.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/buffer_ref.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/default_allocator.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/verifier.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/buffer.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/vector_downward.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/flatbuffers.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/table.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/stl_emulation.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/base.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/flatbuffer_builder.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/string.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/allocator.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include/flatbuffers/detached_buffer.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/gemmlowp/internal/detect_platform.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/gemmlowp/fixedpoint/fixedpoint_neon.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/gemmlowp/fixedpoint/fixedpoint_sse.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/gemmlowp/fixedpoint/fixedpoint.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/kissfft/tools/kiss_fftr.c
  ${TFLM_SOURCE_TREE_TOP}/third_party/kissfft/tools/kiss_fftr.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/kissfft/_kiss_fft_guts.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/kissfft/kiss_fft.h
  ${TFLM_SOURCE_TREE_TOP}/third_party/kissfft/kiss_fft.c
  ${TFLM_SOURCE_TREE_TOP}/third_party/ruy/ruy/profiler/instrumentation.h
)

######
# include muRISC-V NN
######
if(MURISCV_NN)
  target_sources(tflm PRIVATE
  ${TFLM_SRCS}
  ${TFLM_THIRD_PARTY_SRCS}
  ${FH_SUPPORT_SRCS}
  )

  target_include_directories(tflm PUBLIC
  ${TFLM_SOURCE_TREE_TOP}
  ${TFLM_SOURCE_TREE_TOP}/third_party/ruy
  ${TFLM_SOURCE_TREE_TOP}/third_party/gemmlowp
  ${TFLM_SOURCE_TREE_TOP}/third_party/kissfft
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers
  ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include
  ${CMAKE_CURRENT_SOURCE_DIR}/muriscv-nn/Include
  ${CMAKE_CURRENT_SOURCE_DIR}/muriscv-nn/Include/CMSIS/NN/
  ${FH_INCLUDE}
  )

  target_link_libraries(tflm PRIVATE
  m
  stdc++
  UART_Vicuna
  muriscvnn
  )

  add_subdirectory(muriscv-nn/Source muriscv-nn)

  # Pass vector extension flags to muriscv-nn target
  if (DEFINED USE_VEXT AND USE_VEXT)
    target_compile_definitions(muriscvnn PRIVATE USE_VEXT)
    if (DEFINED USE_IME AND USE_IME)
      target_compile_definitions(muriscvnn PRIVATE USE_IME)
    endif()
  elseif(DEFINED USE_PEXT AND USE_PEXT)
    target_compile_definitions(muriscvnn PRIVATE USE_PEXT)
  endif()
  
  if (DEFINED MURISCV_NN_TEST AND NOT MURISCV_NN_TEST STREQUAL "OFF")
    # add muriscv-nn testcases only if etiss is used as the backend simulator
    if (${ETISS_SIM})
      include(${CMAKE_CURRENT_SOURCE_DIR}/CMake/add_muriscv_nn_test.cmake)
      prepare_muriscv_nn_tests()
      add_muriscv_nn_test(test_muriscv_nn_fully_connected_s8)
      add_muriscv_nn_test(test_muriscv_nn_fully_connected_s16)
    else()
      message(WARNING "muriscv-nn testcases are not added because ETISS is not used as the backend simulator")
    endif()

  endif()

else()

  target_sources(tflm PRIVATE
    ${TFLM_SRCS}
    ${TFLM_THIRD_PARTY_SRCS}
    ${FH_SUPPORT_SRCS}
  )

  target_include_directories(tflm PUBLIC
    ${TFLM_SOURCE_TREE_TOP}
    ${TFLM_SOURCE_TREE_TOP}/third_party/ruy
    ${TFLM_SOURCE_TREE_TOP}/third_party/gemmlowp
    ${TFLM_SOURCE_TREE_TOP}/third_party/kissfft
    ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers
    ${TFLM_SOURCE_TREE_TOP}/third_party/flatbuffers/include
    ${FH_INCLUDE}
  )

  target_link_libraries(tflm PRIVATE
    m
    stdc++
    UART_Vicuna
  )
endif()
