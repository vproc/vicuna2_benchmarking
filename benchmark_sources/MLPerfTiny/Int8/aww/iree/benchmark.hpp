#pragma once

#include "aww_int8_input_data.h"
#include "aww_int8_model_settings.h"
#include "aww_int8_output_data_ref.h"
#include <stdint.h>

extern "C" {
extern const unsigned char iree_model_vmfb[];
extern const unsigned int iree_model_vmfb_len;
}

#define TEST_NAME "aww_int8"
#define TEST_FUNCTION_NAME "module.main"
#define TEST_VMFB_DATA iree_model_vmfb
#define TEST_VMFB_DATA_LEN iree_model_vmfb_len
#define TEST_OUTPUT_SIZE aww_int8_model_label_cnt
#define STATIC_POOL_SIZE (4 * 1024 * 1024)

#define TEST_INPUT_SETUP(allocator, device_allocator, session, call) \
  ({ \
    int _setup_ok = 1; \
    iree_hal_dim_t shape[4] = {1, 49, 10, 1}; \
    iree_hal_buffer_view_t* arg0 = nullptr; \
    iree_status_t status = iree_hal_buffer_view_allocate_buffer_copy( \
        iree_runtime_session_device(session), \
        device_allocator, 4, shape, \
        IREE_HAL_ELEMENT_TYPE_SINT_8, IREE_HAL_ENCODING_TYPE_DENSE_ROW_MAJOR, \
        (iree_hal_buffer_params_t){.usage = IREE_HAL_BUFFER_USAGE_DEFAULT, \
                                   .type = IREE_HAL_MEMORY_TYPE_DEVICE_LOCAL}, \
        iree_make_const_byte_span(aww_int8_input_data[0], \
                                  aww_int8_input_data_len[0]), \
        &arg0); \
    if (!iree_status_is_ok(status)) { \
        _setup_ok = 0; \
    } else { \
        iree_runtime_call_inputs_push_back_buffer_view(call, arg0); \
        iree_hal_buffer_view_release(arg0); \
    } \
    _setup_ok; \
  })

#define TEST_OUTPUT_VALIDATE(out_ptr, out_size) \
  ({ \
    uint8_t top_index = 0; \
    for (size_t i = 1; i < aww_int8_model_label_cnt; ++i) { \
      if (out_ptr[i] > out_ptr[top_index]) top_index = static_cast<uint8_t>(i); \
    } \
    (top_index == aww_int8_output_data_ref[0]); \
  })

#define TEST_CLEANUP() do {} while(0)

#include "../../../../generic_iree/baremetal/benchmark_template.hpp"
