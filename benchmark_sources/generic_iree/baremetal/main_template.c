/*
 * Generic IREE Bare-Metal Test Template
 * 
 * This template is used to generate test_main.c files from test-specific config.
 * Each test provides:
 *   - TEST_NAME: string identifier
 *   - TEST_VMFB_HEADER: C header from compiled VMFB
 *   - TEST_FUNCTION_NAME: IREE function to call
 *   - TEST_NUM_ITERATIONS: number of test iterations
 *   - TEST_INPUT_SETUP(allocator, device_allocator, session): setup test inputs
 *   - TEST_OUTPUT_VALIDATE(out_ptr, output_len): validate output
 *   - TEST_CLEANUP: cleanup test-specific data
 */

#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#include "iree/base/api.h"
#include "iree/hal/api.h"
#include "iree/modules/hal/module.h"
#include "iree/runtime/api.h"
#include "iree/vm/api.h"
#include "iree/vm/bytecode/module.h"


// Simple IREE allocator implementation
#define STATIC_POOL_SIZE (1024 * 1024)  // 1 MB static arena
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
void* malloc(size_t size) {
  void* ptr = NULL;
  iree_allocator_alloc_params_t params = {.byte_length = size};
  iree_static_bump_allocator_ctl(NULL, IREE_ALLOCATOR_COMMAND_MALLOC, &params,
                                 &ptr);
  return ptr;
}
void* calloc(size_t num, size_t size) {
  void* ptr = NULL;
  iree_allocator_alloc_params_t params = {.byte_length = num * size};
  iree_static_bump_allocator_ctl(NULL, IREE_ALLOCATOR_COMMAND_CALLOC, &params,
                                 &ptr);
  return ptr;
}
void* realloc(void* ptr, size_t new_size) {
  void* new_ptr = ptr;
  iree_allocator_alloc_params_t params = {.byte_length = new_size};
  iree_static_bump_allocator_ctl(NULL, IREE_ALLOCATOR_COMMAND_REALLOC, &params,
                                 &new_ptr);
  return new_ptr;
}
void free(void* ptr) { (void)ptr; }

// Global output variables
volatile int g_execution_success = 0;

// Main entry point
// Return codes:
//   0: Success
//   1-10: IREE initialization or runtime execution error
//   11: Output verification mismatch
int main(void) {
  iree_allocator_t allocator = get_static_allocator();

  iree_runtime_instance_options_t instance_options;
  iree_runtime_instance_options_initialize(&instance_options);
  iree_runtime_instance_options_use_all_available_drivers(&instance_options);

  iree_runtime_instance_t* instance = NULL;
  if (!iree_status_is_ok(
          iree_runtime_instance_create(&instance_options, allocator, &instance))) {
    _exit(1);
  }

  iree_hal_device_t* device = NULL;
  if (!iree_status_is_ok(iree_runtime_instance_try_create_default_device(
          instance, iree_make_cstring_view("local-sync"), &device))) {
    iree_runtime_instance_release(instance);
    _exit(2);
  }

  iree_runtime_session_options_t session_options;
  iree_runtime_session_options_initialize(&session_options);
  iree_runtime_session_t* session = NULL;
  if (!iree_status_is_ok(iree_runtime_session_create_with_device(
          instance, &session_options, device, allocator, &session))) {
    iree_hal_device_release(device);
    iree_runtime_instance_release(instance);
    _exit(3);
  }
  iree_hal_device_release(device);

  // Load VMFB module (provided by test_config.h)
  iree_vm_module_t* module = NULL;
  if (!iree_status_is_ok(iree_vm_bytecode_module_create(
          iree_runtime_instance_vm_instance(instance), IREE_VM_BYTECODE_MODULE_FLAG_NONE,
          iree_make_const_byte_span(TEST_VMFB_DATA, TEST_VMFB_DATA_LEN),
          iree_allocator_null(), allocator, &module))) {
    iree_runtime_session_release(session);
    iree_runtime_instance_release(instance);
    _exit(4);
  }

  if (!iree_status_is_ok(iree_runtime_session_append_module(session, module))) {
    iree_vm_module_release(module);
    iree_runtime_session_release(session);
    iree_runtime_instance_release(instance);
    _exit(5);
  }
  iree_vm_module_release(module);

  // Initialize call (test-specific function name from test_config.h)
  iree_runtime_call_t call;
  if (!iree_status_is_ok(iree_runtime_call_initialize_by_name(
          session, iree_make_cstring_view(TEST_FUNCTION_NAME), &call))) {
    iree_runtime_session_release(session);
    iree_runtime_instance_release(instance);
    _exit(6);
  }

  iree_hal_allocator_t* device_allocator =
      iree_runtime_session_device_allocator(session);

  // Checkpoint static bump pool offset for each iteration
  size_t checkpoint_offset = g_pool_offset;
  int all_passed = 1;

  // Test-specific setup (from test_config.h)
  if (!TEST_INPUT_SETUP(allocator, device_allocator, session, &call)) {
    iree_runtime_call_deinitialize(&call);
    iree_runtime_session_release(session);
    iree_runtime_instance_release(instance);
    _exit(7);
  }

  // Invoke IREE function
  if (!iree_status_is_ok(iree_runtime_call_invoke(&call, /*flags=*/0))) {
    iree_runtime_call_deinitialize(&call);
    iree_runtime_session_release(session);
    iree_runtime_instance_release(instance);
    _exit(9);
  }

  // Extract output
  iree_hal_buffer_view_t* ret0 = NULL;
  if (!iree_status_is_ok(
          iree_runtime_call_outputs_pop_front_buffer_view(&call, &ret0)) ||
      !ret0) {
    iree_runtime_call_deinitialize(&call);
    iree_runtime_session_release(session);
    iree_runtime_instance_release(instance);
    _exit(10);
  }

  iree_hal_buffer_t* buffer = iree_hal_buffer_view_buffer(ret0);
  iree_hal_buffer_mapping_t mapping;
  if (iree_status_is_ok(iree_hal_buffer_map_range(
          buffer, IREE_HAL_MAPPING_MODE_SCOPED, IREE_HAL_MEMORY_ACCESS_READ,
          0, TEST_OUTPUT_SIZE, &mapping))) {
    const int8_t* out_ptr = (const int8_t*)mapping.contents.data;
    
    // Test-specific validation (from test_config.h)
    if (!TEST_OUTPUT_VALIDATE(out_ptr, TEST_OUTPUT_SIZE)) {
      all_passed = 0;
    }
    
    iree_hal_buffer_unmap_range(&mapping);
    
    // Return exit code based on validation
    if (all_passed) {
      _exit(0);  // Success
    } else {
      _exit(11);  // Validation failed
    }
  } else {
    iree_hal_buffer_view_release(ret0);
    iree_runtime_call_deinitialize(&call);
    iree_runtime_session_release(session);
    iree_runtime_instance_release(instance);
    return 98;  // Buffer map failed
  }
  iree_hal_buffer_view_release(ret0);

  // Test-specific cleanup
  TEST_CLEANUP();

  iree_runtime_call_deinitialize(&call);
  iree_runtime_session_release(session);
  iree_runtime_instance_release(instance);

  g_execution_success = all_passed;
  exit(g_execution_success ? 0 : 11);  // Signal exit to Spike via tohost HTIF
  return 0;  // Unreachable
}
