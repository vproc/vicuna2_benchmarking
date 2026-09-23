// baremetal_stubs.c
#include "iree/base/api.h"
#include "iree/base/threading/thread.h"
#include "iree/async/proactor.h"
#include "iree/async/notification.h"
#include "iree/async/util/proactor_thread_runner.h"

// Dummy bare-metal syscall functions to make IREE run in Spike enviroment without Verilator
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <stddef.h>
#include <stdint.h>

extern char _user_start;
extern char _stack_start;
#define __heap_start _user_start
#define __heap_end _stack_start
static char* heap_ptr = NULL;

void* _sbrk(ptrdiff_t incr) {
  if (heap_ptr == NULL) {
    heap_ptr = &__heap_start;
  }
  char* prev_heap = heap_ptr;
  if (heap_ptr + incr > &__heap_end) {
    errno = ENOMEM;
    return (void*)-1;
  }
  heap_ptr += incr;
  return (void*)prev_heap;
}

void* _sbrk_r(struct _reent* r, ptrdiff_t incr) {
  return _sbrk(incr);
}

void* sbrk(ptrdiff_t incr) {
  return _sbrk(incr);
}

void _exit_r(struct _reent* r, int status) {
  _exit(status);
}

int _write(int file, const char* ptr, int len) {
  return len;
}

int _write_r(struct _reent* r, int file, const char* ptr, int len) {
  return _write(file, ptr, len);
}

int _read(int file, char* ptr, int len) {
  return 0;
}

int _read_r(struct _reent* r, int file, char* ptr, int len) {
  return _read(file, ptr, len);
}

int _close(int file) { return -1; }
int _close_r(struct _reent* r, int file) { return -1; }

int _lseek(int file, int ptr, int dir) { return 0; }
int _lseek_r(struct _reent* r, int file, int ptr, int dir) { return 0; }

int _fstat(int file, struct stat* st) {
  if (st) {
    memset(st, 0, sizeof(*st));
    st->st_mode = S_IFCHR;
  }
  return 0;
}
int _fstat_r(struct _reent* r, int file, struct stat* st) {
  return _fstat(file, st);
}

int _isatty(int file) { return 1; }
int _isatty_r(struct _reent* r, int file) { return 1; }

int _kill(int pid, int sig) { errno = EINVAL; return -1; }
int _kill_r(struct _reent* r, int pid, int sig) { errno = EINVAL; return -1; }

int _getpid(void) { return 1; }
int _getpid_r(struct _reent* r) { return 1; }

// Prevent unaligned load traps from Newlib assembly optimizations when accessing string/binary data inside FlatBuffers.
int strncmp(const char* s1, const char* s2, size_t n) {
  while (n > 0) {
    unsigned char c1 = *(const unsigned char*)s1++;
    unsigned char c2 = *(const unsigned char*)s2++;
    if (c1 != c2) return (c1 < c2) ? -1 : 1;
    if (c1 == '\0') return 0;
    n--;
  }
  return 0;
}

int memcmp(const void* ptr1, const void* ptr2, size_t num) {
  const unsigned char* p1 = (const unsigned char*)ptr1;
  const unsigned char* p2 = (const unsigned char*)ptr2;
  for (size_t i = 0; i < num; i++) {
    if (p1[i] != p2[i]) return (p1[i] < p2[i]) ? -1 : 1;
  }
  return 0;
}

void* memcpy(void* dest, const void* src, size_t n) {
  unsigned char* d = (unsigned char*)dest;
  const unsigned char* s = (const unsigned char*)src;
  for (size_t i = 0; i < n; i++) {
    d[i] = s[i];
  }
  return dest;
}

void* memset(void* ptr, int value, size_t num) {
  unsigned char* p = (unsigned char*)ptr;
  for (size_t i = 0; i < num; i++) {
    p[i] = (unsigned char)value;
  }
  return ptr;
}

size_t strlen(const char* str) {
  const char* s = str;
  while (*s) s++;
  return (size_t)(s - str);
}

int strcmp(const char* s1, const char* s2) {
  while (*s1 && (*s1 == *s2)) {
    s1++;
    s2++;
  }
  return *(const unsigned char*)s1 - *(const unsigned char*)s2;
}

void* memmove(void* dest, const void* src, size_t n) {
  unsigned char* d = (unsigned char*)dest;
  const unsigned char* s = (const unsigned char*)src;
  if (d < s) {
    for (size_t i = 0; i < n; i++) d[i] = s[i];
  } else if (d > s) {
    for (size_t i = n; i > 0; i--) d[i - 1] = s[i - 1];
  }
  return dest;
}

void* memchr(const void* ptr, int value, size_t num) {
  const unsigned char* p = (const unsigned char*)ptr;
  for (size_t i = 0; i < num; i++) {
    if (p[i] == (unsigned char)value) return (void*)&p[i];
  }
  return NULL;
}

char* strcpy(char* dest, const char* src) {
  char* d = dest;
  while ((*d++ = *src++) != '\0');
  return dest;
}

char* strncpy(char* dest, const char* src, size_t n) {
  size_t i;
  for (i = 0; i < n && src[i] != '\0'; i++) {
    dest[i] = src[i];
  }
  for (; i < n; i++) {
    dest[i] = '\0';
  }
  return dest;
}


// Despite the fact that threading, synchronization, etc are disabled in the CMakeLists.txt file, IREE's initialization checks for a valid proactor and notification vtable.  We provide a dummy synchronous proactor and null runner factory to satisfy these dependencies.
iree_async_proactor_pool_runner_factory_t iree_async_proactor_pool_thread_runner_factory(void) {
  iree_async_proactor_pool_runner_factory_t f = {0};
  return f;
}

static void dummy_proactor_destroy(iree_async_proactor_t* proactor) {
  iree_allocator_free(proactor->allocator, proactor);
}

static iree_async_proactor_capabilities_t dummy_proactor_query_capabilities(iree_async_proactor_t* proactor) {
  return 0;
}

static iree_status_t dummy_proactor_submit(iree_async_proactor_t* proactor, iree_async_operation_list_t operations) {
  return iree_status_from_code(IREE_STATUS_UNIMPLEMENTED);
}

static iree_status_t dummy_proactor_poll(iree_async_proactor_t* proactor, iree_timeout_t timeout, iree_host_size_t* out_completed_count) {
  if (out_completed_count) *out_completed_count = 0;
  return iree_ok_status();
}

static void dummy_proactor_wake(iree_async_proactor_t* proactor) {}

static iree_status_t dummy_proactor_cancel(iree_async_proactor_t* proactor, iree_async_operation_t* operation) {
  return iree_status_from_code(IREE_STATUS_UNIMPLEMENTED);
}

static iree_status_t dummy_proactor_create_notification(
    iree_async_proactor_t* proactor, iree_async_notification_flags_t flags,
    iree_async_notification_t** out_notification) {
  iree_async_notification_t* n = NULL;
  IREE_RETURN_IF_ERROR(iree_allocator_malloc(proactor->allocator, sizeof(*n), (void**)&n));
  memset(n, 0, sizeof(*n));
  iree_atomic_ref_count_init(&n->ref_count);
  n->proactor = proactor;
  iree_atomic_store(&n->epoch, 0, iree_memory_order_relaxed);
  n->epoch_ptr = &n->epoch;
  *out_notification = n;
  return iree_ok_status();
}

static void dummy_proactor_destroy_notification(iree_async_proactor_t* proactor, iree_async_notification_t* notification) {
  iree_allocator_free(proactor->allocator, notification);
}

static void dummy_proactor_notification_signal(iree_async_proactor_t* proactor, iree_async_notification_t* notification, int32_t wake_count) {}

static bool dummy_proactor_notification_wait(iree_async_proactor_t* proactor, iree_async_notification_t* notification, uint32_t wait_token, iree_timeout_t timeout) {
  return true;
}

static const iree_async_proactor_vtable_t dummy_proactor_vtable = {
  .destroy = dummy_proactor_destroy,
  .query_capabilities = dummy_proactor_query_capabilities,
  .submit = dummy_proactor_submit,
  .poll = dummy_proactor_poll,
  .wake = dummy_proactor_wake,
  .cancel = dummy_proactor_cancel,
  .create_notification = dummy_proactor_create_notification,
  .destroy_notification = dummy_proactor_destroy_notification,
  .notification_signal = dummy_proactor_notification_signal,
  .notification_wait = dummy_proactor_notification_wait,
};

// POSIX proactor factory override for bare-metal RISC-V.
// Returns a dummy synchronous proactor instead of attempting POSIX epoll/pipe creation.
iree_status_t iree_async_proactor_create_posix(
    iree_async_proactor_options_t options, iree_allocator_t allocator,
    iree_async_proactor_t** out_proactor) {
  iree_async_proactor_t* p = NULL;
  IREE_RETURN_IF_ERROR(iree_allocator_malloc(allocator, sizeof(*p), (void**)&p));
  memset(p, 0, sizeof(*p));
  iree_async_proactor_initialize(&dummy_proactor_vtable, iree_make_cstring_view("dummy"), allocator, p);
  *out_proactor = p;
  return iree_ok_status();
}

iree_status_t iree_async_proactor_create_platform(
    iree_async_proactor_options_t options, iree_allocator_t allocator,
    iree_async_proactor_t** out_proactor) {
  return iree_async_proactor_create_posix(options, allocator, out_proactor);
}

// Thread creation stubs (unused in single-threaded local-sync execution).
iree_status_t iree_thread_create(iree_thread_entry_t entry, void* entry_arg,
                                 iree_thread_create_params_t params,
                                 iree_allocator_t allocator,
                                 iree_thread_t** out_thread) {
  if (out_thread) *out_thread = NULL;
  return iree_status_from_code(IREE_STATUS_UNIMPLEMENTED);
}

void iree_thread_release(iree_thread_t* thread) {}

