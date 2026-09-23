// Simple test to check out if IREE testing pipeline is working
// INPUT: {5, 3, 9, 7} + {1, 2, 3, 4}
// OUTPUT: {6, 5, 12, 11}

#include <stdint.h>
#include <string.h>
#include <stdio.h>

// Include VMFB compiled module
#include "add_vector.h"

// Test metadata
#define TEST_NAME "add_vector"
#define TEST_FUNCTION_NAME "module.vec_add_i8"
#define TEST_VMFB_DATA add_vector_vmfb
#define TEST_VMFB_DATA_LEN add_vector_vmfb_len

// Output configuration
#define TEST_OUTPUT_SIZE 4

// Memory pool size for IREE runtime
#define STATIC_POOL_SIZE (1024 * 1024)  // 1 MB static arena

// Test input data
static const int8_t g_test_input_0[4] = {5, 3, 9, 7};
static const int8_t g_test_input_1[4] = {1, 2, 3, 4};
static const int8_t g_test_expected[4] = {6, 5, 12, 11};

// Input setup macro
#define TEST_INPUT_SETUP(allocator, device_allocator, session, call) \
  ({                                                                   \
    int _setup_ok = 1;                                                \
    iree_hal_dim_t shape[1] = {4};                                   \
                                                                      \
    iree_hal_buffer_view_t* arg0 = NULL;                             \
    if (!iree_status_is_ok(iree_hal_buffer_view_allocate_buffer_copy(\
            iree_runtime_session_device(session), device_allocator,  \
            1, shape, IREE_HAL_ELEMENT_TYPE_SINT_8,                 \
            IREE_HAL_ENCODING_TYPE_DENSE_ROW_MAJOR,                 \
            (iree_hal_buffer_params_t){                              \
                .usage = IREE_HAL_BUFFER_USAGE_DEFAULT,             \
                .type = IREE_HAL_MEMORY_TYPE_DEVICE_LOCAL},         \
            iree_make_const_byte_span(g_test_input_0, 4), &arg0))) {\
      _setup_ok = 0;                                                 \
    } else {                                                          \
      iree_runtime_call_inputs_push_back_buffer_view(call, arg0);   \
      iree_hal_buffer_view_release(arg0);                           \
    }                                                                 \
                                                                      \
    iree_hal_buffer_view_t* arg1 = NULL;                             \
    if (_setup_ok && !iree_status_is_ok(                             \
            iree_hal_buffer_view_allocate_buffer_copy(               \
                iree_runtime_session_device(session),                \
                device_allocator, 1, shape,                          \
                IREE_HAL_ELEMENT_TYPE_SINT_8,                       \
                IREE_HAL_ENCODING_TYPE_DENSE_ROW_MAJOR,             \
                (iree_hal_buffer_params_t){                          \
                    .usage = IREE_HAL_BUFFER_USAGE_DEFAULT,         \
                    .type = IREE_HAL_MEMORY_TYPE_DEVICE_LOCAL},     \
                iree_make_const_byte_span(g_test_input_1, 4),       \
                &arg1))) {                                            \
      _setup_ok = 0;                                                 \
    } else if (_setup_ok) {                                          \
      iree_runtime_call_inputs_push_back_buffer_view(call, arg1);   \
      iree_hal_buffer_view_release(arg1);                           \
    }                                                                 \
    _setup_ok;                                                        \
  })

// Output validation macro (no printf - bare-metal can't output)
#define TEST_OUTPUT_VALIDATE(out_ptr, output_len)                    \
  ({                                                                   \
    int _match = 1;                                                   \
    for (int i = 0; i < 4; i++) {                                   \
      if (out_ptr[i] != g_test_expected[i]) {                        \
        _match = 0;                                                   \
        break;  /* Early exit on first mismatch */                   \
      }                                                               \
    }                                                                 \
    _match;                                                            \
  })

// Cleanup (empty for simple add_vector test)
#define TEST_CLEANUP() do { } while(0)
