  /*                             Copyright (c) 2017 SiFive Inc. All rights reserved.

  This                           copyrighted material is made available to anyone wishing to use,
  modify,                        copy, or redistribute it subject to the terms and conditions
  of                             the FreeBSD License. This program is distributed in the hope that
  it                             will be useful, but WITHOUT ANY WARRANTY expressed or implied,
  including                      the implied warranties of MERCHANTABILITY or FITNESS FOR
  A                              PARTICULAR PURPOSE. A copy of this license is available at
http:
  //www.opensource.org/licenses.

  */

# modified for use in ETISS

#ifndef __SIZEOF_POINTER__
#error pointer size unknown
#endif

#if __SIZEOF_POINTER__ == 4
#define LREG lw
#define SREG sw
#define REGBYTES 4
#elif __SIZEOF_POINTER__ == 8
#define LREG ld
#define SREG sd
#define REGBYTES 8
#else
#error __SIZEOF_POINTER__ neither 4 nor 8
#endif

# #ifndef SIMULATION_RUNS
# #define SIMULATION_RUNS 1
# #endif
  .text

  .global                        _start
_start:

# Enable RVV
  csrr                           a0, mstatus
  li                             a1, 0x00002200                                                    #Init FS bits to enable F-EXT and VS bits to enable V-EXT
  or                             a0, a0, a1
  csrw                           mstatus, a0

# setup "Machine Trap-Vector Base-Address"
# mode is 0 -> all exceptions go to same code
  la                             t0, _trap_vector
  csrw                           mtvec, t0

# Initialize global pointer
  .option                        push
  .option                        norelax
  la                             gp, __global_pointer$
  .option                        pop

# Initialize the stack pointer
  la                             sp, __stack

# Clear the bss segment
# memset(void* str, int c, size_t n);
# memset(__bss_start, 0, __bss_start - _end);
  la                             a0, __bss_start
  li                             a1, 0
  la                             a2, _end
  sub                            a2, a2, a0
  call                           memset

# Register global termination functions
# to be called upon exit
  la                             a0, __libc_fini_array
  call                           atexit

# Run global initialization functions
  call                           __libc_init_array

# load simulation runs count.
# li s11, SIMULATION_RUNS

simulation_loop:

# beqz s11, end_simulation_loop

# call user code
# main(int argc, char *argv[]);
# main(0, 0);
# load argc and argv (TODO)
  li                             a0, 0
  li                             a1, 0
  li                             a2, 0                                                             # set envp = NULL just in case
  call                           main

# addi s11, s11, -1

# bnez s11, simulation_loop

# end_simulation_loop:
  tail                           exit

  .p2align                       2                                                                 # align on 4-byte boundary
_trap_vector:
  addi                           sp, sp, -32*REGBYTES

  SREG                           x1, 1*REGBYTES(sp)
  SREG                           x2, 2*REGBYTES(sp)
  SREG                           x3, 3*REGBYTES(sp)
  SREG                           x4, 4*REGBYTES(sp)
  SREG                           x5, 5*REGBYTES(sp)
  SREG                           x6, 6*REGBYTES(sp)
  SREG                           x7, 7*REGBYTES(sp)
  SREG                           x8, 8*REGBYTES(sp)
  SREG                           x9, 9*REGBYTES(sp)
  SREG                           x10, 10*REGBYTES(sp)
  SREG                           x11, 11*REGBYTES(sp)
  SREG                           x12, 12*REGBYTES(sp)
  SREG                           x13, 13*REGBYTES(sp)
  SREG                           x14, 14*REGBYTES(sp)
  SREG                           x15, 15*REGBYTES(sp)
  SREG                           x16, 16*REGBYTES(sp)
  SREG                           x17, 17*REGBYTES(sp)
  SREG                           x18, 18*REGBYTES(sp)
  SREG                           x19, 19*REGBYTES(sp)
  SREG                           x20, 20*REGBYTES(sp)
  SREG                           x21, 21*REGBYTES(sp)
  SREG                           x22, 22*REGBYTES(sp)
  SREG                           x23, 23*REGBYTES(sp)
  SREG                           x24, 24*REGBYTES(sp)
  SREG                           x25, 25*REGBYTES(sp)
  SREG                           x26, 26*REGBYTES(sp)
  SREG                           x27, 27*REGBYTES(sp)
  SREG                           x28, 28*REGBYTES(sp)
  SREG                           x29, 29*REGBYTES(sp)
  SREG                           x30, 30*REGBYTES(sp)
  SREG                           x31, 31*REGBYTES(sp)

# void _trap_handler_c(unsigned long mcause, unsigned long mepc)
  csrr                           a0, mcause
  csrr                           a1, mepc
  call                           _trap_handler_c

  LREG                           x1, 1*REGBYTES(sp)
  LREG                           x2, 2*REGBYTES(sp)
  LREG                           x3, 3*REGBYTES(sp)
  LREG                           x4, 4*REGBYTES(sp)
  LREG                           x5, 5*REGBYTES(sp)
  LREG                           x6, 6*REGBYTES(sp)
  LREG                           x7, 7*REGBYTES(sp)
  LREG                           x8, 8*REGBYTES(sp)
  LREG                           x9, 9*REGBYTES(sp)
  LREG                           x10, 10*REGBYTES(sp)
  LREG                           x11, 11*REGBYTES(sp)
  LREG                           x12, 12*REGBYTES(sp)
  LREG                           x13, 13*REGBYTES(sp)
  LREG                           x14, 14*REGBYTES(sp)
  LREG                           x15, 15*REGBYTES(sp)
  LREG                           x16, 16*REGBYTES(sp)
  LREG                           x17, 17*REGBYTES(sp)
  LREG                           x18, 18*REGBYTES(sp)
  LREG                           x19, 19*REGBYTES(sp)
  LREG                           x20, 20*REGBYTES(sp)
  LREG                           x21, 21*REGBYTES(sp)
  LREG                           x22, 22*REGBYTES(sp)
  LREG                           x23, 23*REGBYTES(sp)
  LREG                           x24, 24*REGBYTES(sp)
  LREG                           x25, 25*REGBYTES(sp)
  LREG                           x26, 26*REGBYTES(sp)
  LREG                           x27, 27*REGBYTES(sp)
  LREG                           x28, 28*REGBYTES(sp)
  LREG                           x29, 29*REGBYTES(sp)
  LREG                           x30, 30*REGBYTES(sp)
  LREG                           x31, 31*REGBYTES(sp)

  addi                           sp, sp, 32*REGBYTES
  mret
