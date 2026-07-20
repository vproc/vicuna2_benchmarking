#ifndef BENCHMARK_TEMPLATE_HPP
#define BENCHMARK_TEMPLATE_HPP

#include "simulator.hpp"
// Note: test_config.h must be included before this file in the test's benchmark.hpp

#include "iree/base/api.h"
#include "iree/hal/api.h"
#include "iree/modules/hal/module.h"
#include "iree/runtime/api.h"
#include "iree/vm/api.h"
#include "iree/vm/bytecode/module.h"

#include <stdint.h>
#include <string.h>
#include <stdlib.h>

// Static Bump Allocator (No libc heap / no sbrk)
static uint8_t g_static_pool[STATIC_POOL_SIZE] __attribute__((section(".noinit"), aligned(64)));
static size_t g_pool_offset = 0;

static iree_status_t iree_static_bump_allocator_ctl(
    void* self, iree_allocator_command_t command, const void* params,
    void** inout_ptr) {
  switch (command) {
    case IREE_ALLOCATOR_COMMAND_MALLOC:
    case IREE_ALLOCATOR_COMMAND_REALLOC: {
      const iree_allocator_alloc_params_t* alloc_params =
          (const iree_allocator_alloc_params_t*)params;
      size_t size = (alloc_params->byte_length + 15) & ~((size_t)15);
      if (command == IREE_ALLOCATOR_COMMAND_REALLOC && *inout_ptr != NULL) {
        if (g_pool_offset + size > STATIC_POOL_SIZE) {
          return iree_make_status(IREE_STATUS_RESOURCE_EXHAUSTED,
                                  "Static pool exhausted on realloc");
        }
        void* new_ptr = &g_static_pool[g_pool_offset];
        g_pool_offset += size;
        memcpy(new_ptr, *inout_ptr, size);
        *inout_ptr = new_ptr;
        return iree_ok_status();
      }
      if (g_pool_offset + size > STATIC_POOL_SIZE) {
        return iree_make_status(
            IREE_STATUS_RESOURCE_EXHAUSTED,
            "Static pool exhausted on malloc (requested %zu, available %zu)",
            size, STATIC_POOL_SIZE - g_pool_offset);
      }
      *inout_ptr = &g_static_pool[g_pool_offset];
      g_pool_offset += size;
      return iree_ok_status();
    }
    case IREE_ALLOCATOR_COMMAND_CALLOC: {
      const iree_allocator_alloc_params_t* alloc_params =
          (const iree_allocator_alloc_params_t*)params;
      size_t size = (alloc_params->byte_length + 15) & ~((size_t)15);
      if (g_pool_offset + size > STATIC_POOL_SIZE) {
        return iree_make_status(IREE_STATUS_RESOURCE_EXHAUSTED,
                                "Static pool exhausted on calloc");
      }
      void* ptr = &g_static_pool[g_pool_offset];
      memset(ptr, 0, size);
      *inout_ptr = ptr;
      g_pool_offset += size;
      return iree_ok_status();
    }
    case IREE_ALLOCATOR_COMMAND_FREE: {
      return iree_ok_status();
    }
    default:
      return iree_make_status(IREE_STATUS_UNIMPLEMENTED);
  }
}

static iree_allocator_t get_static_allocator(void) {
  return (iree_allocator_t){
      .self = NULL,
      .ctl = iree_static_bump_allocator_ctl,
  };
}

// Override standard C library memory allocation functions
extern "C" {
    void* malloc(size_t size) {
        void* ptr = NULL;
        iree_allocator_alloc_params_t params = {.byte_length = size};
        iree_static_bump_allocator_ctl(NULL, IREE_ALLOCATOR_COMMAND_MALLOC, &params, &ptr);
        return ptr;
    }
    void* calloc(size_t num, size_t size) {
        void* ptr = NULL;
        iree_allocator_alloc_params_t params = {.byte_length = num * size};
        iree_static_bump_allocator_ctl(NULL, IREE_ALLOCATOR_COMMAND_CALLOC, &params, &ptr);
        return ptr;
    }
    void* realloc(void* ptr, size_t new_size) {
        void* new_ptr = ptr;
        iree_allocator_alloc_params_t params = {.byte_length = new_size};
        iree_static_bump_allocator_ctl(NULL, IREE_ALLOCATOR_COMMAND_REALLOC, &params, &new_ptr);
        return new_ptr;
    }
    void free(void* ptr) { (void)ptr; }
}

class Benchmark
{
    private:
    iree_runtime_instance_t* instance = nullptr;
    iree_runtime_session_t* session = nullptr;
    iree_runtime_call_t call;
    iree_allocator_t allocator;

    public:
    Benchmark() {
        allocator = get_static_allocator();

        iree_runtime_instance_options_t instance_options;
        iree_runtime_instance_options_initialize(&instance_options);
        iree_runtime_instance_options_use_all_available_drivers(&instance_options);

        iree_status_t status = iree_runtime_instance_create(&instance_options, allocator, &instance);
        if (!iree_status_is_ok(status)) return;

        iree_hal_device_t* device = nullptr;
        status = iree_runtime_instance_try_create_default_device(
            instance, iree_make_cstring_view("local-sync"), &device);
        if (!iree_status_is_ok(status)) return;

        iree_runtime_session_options_t session_options;
        iree_runtime_session_options_initialize(&session_options);
        status = iree_runtime_session_create_with_device(
            instance, &session_options, device, allocator, &session);
        iree_hal_device_release(device);
        if (!iree_status_is_ok(status)) return;

        iree_vm_module_t* module = nullptr;
        status = iree_vm_bytecode_module_create(
            iree_runtime_instance_vm_instance(instance), IREE_VM_BYTECODE_MODULE_FLAG_NONE,
            iree_make_const_byte_span(TEST_VMFB_DATA, TEST_VMFB_DATA_LEN),
            iree_allocator_null(), allocator, &module);
        if (!iree_status_is_ok(status)) return;

        status = iree_runtime_session_append_module(session, module);
        iree_vm_module_release(module);
        if (!iree_status_is_ok(status)) return;

        status = iree_runtime_call_initialize_by_name(
            session, iree_make_cstring_view(TEST_FUNCTION_NAME), &call);
    }

    inline int run_benchmark() {
        if (!instance || !session) return 1;

        iree_hal_allocator_t* device_allocator = iree_runtime_session_device_allocator(session);

        // Test-specific setup
        if (!TEST_INPUT_SETUP(allocator, device_allocator, session, &call)) {
            return 7;
        }
        
        // Run the test
        iree_status_t status = iree_runtime_call_invoke(&call, /*flags=*/0);
        if (!iree_status_is_ok(status)) {
            return 9;
        }
        return 0;
    }

    int validate_benchmark() {
        if (!instance || !session) return 1;

        iree_hal_buffer_view_t* ret0 = nullptr;
        iree_status_t status = iree_runtime_call_outputs_pop_front_buffer_view(&call, &ret0);
        if (!iree_status_is_ok(status) || !ret0) {
            return 10;
        }

        iree_hal_buffer_t* buffer = iree_hal_buffer_view_buffer(ret0);
        iree_hal_buffer_mapping_t mapping;
        int result = 0;

        if (iree_status_is_ok(iree_hal_buffer_map_range(
                buffer, IREE_HAL_MAPPING_MODE_SCOPED, IREE_HAL_MEMORY_ACCESS_READ,
                0, TEST_OUTPUT_SIZE, &mapping))) {

            const int8_t* out_ptr = (const int8_t*)mapping.contents.data;
            
            // Test-specific validation
            if (!TEST_OUTPUT_VALIDATE(out_ptr, TEST_OUTPUT_SIZE)) {
                result = 11; // Validation failed
            } else {
                result = 0; // Success
            }
            
            iree_hal_buffer_unmap_range(&mapping);
        } else {
            result = 98; // Map failed
        }

        iree_hal_buffer_view_release(ret0);
        return result;
    }

    ~Benchmark() {
        TEST_CLEANUP();
        iree_runtime_call_deinitialize(&call);
        if (session) iree_runtime_session_release(session);
        if (instance) iree_runtime_instance_release(instance);
    }
};

#endif // BENCHMARK_TEMPLATE_HPP
