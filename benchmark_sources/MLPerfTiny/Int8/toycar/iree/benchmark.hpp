#pragma once

#include "toycar_int8_input_data.h"
#include "toycar_int8_output_data_ref.h"
#include <stdlib.h> // For abs()

extern "C" {
    extern const unsigned char iree_model_vmfb[];
    extern const unsigned int iree_model_vmfb_len;
}

#define TEST_NAME "toycar_int8"
#define TEST_FUNCTION_NAME "module.main"
#define TEST_VMFB_DATA iree_model_vmfb
#define TEST_VMFB_DATA_LEN iree_model_vmfb_len
#define TEST_OUTPUT_SIZE toycar_int8_input_data_len[0]
#define STATIC_POOL_SIZE (5 * 1024 * 1024)

#define TEST_INPUT_SETUP(allocator, device_allocator, session, call) \
  ({ \
    int _setup_ok = 1; \
    iree_hal_dim_t shape[2] = {1, (iree_hal_dim_t)toycar_int8_input_data_len[0]}; \
    iree_hal_buffer_view_t* arg0 = nullptr; \
    iree_status_t status = iree_hal_buffer_view_allocate_buffer_copy( \
        iree_runtime_session_device(session), device_allocator, 2, shape, \
        IREE_HAL_ELEMENT_TYPE_SINT_8, IREE_HAL_ENCODING_TYPE_DENSE_ROW_MAJOR, \
        (iree_hal_buffer_params_t){.usage = IREE_HAL_BUFFER_USAGE_DEFAULT, \
                                   .type = IREE_HAL_MEMORY_TYPE_DEVICE_LOCAL}, \
        iree_make_const_byte_span(toycar_int8_input_data[0], toycar_int8_input_data_len[0]), &arg0); \
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
    int32_t sum = 0; \
    for (size_t j = 0; j < toycar_int8_input_data_len[0]; j++) { \
        int32_t diff1 = (int8_t)toycar_int8_input_data[0][j] - out_ptr[j]; \
        sum += (diff1 * diff1); \
    } \
    sum /= toycar_int8_input_data_len[0]; \
    int32_t diff = abs(sum - (int32_t)toycar_int8_output_data_ref[0]); \
    (diff <= 1); \
  })

#define TEST_CLEANUP() do {} while(0)

#include "../../../../generic_iree/baremetal/benchmark_template.hpp"
