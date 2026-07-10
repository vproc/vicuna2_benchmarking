/*
// Copyright 2017 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// This file was modified by the Chair of Electronic Design Automation, TUM
*/

ENTRY(_start)
SEARCH_DIR(.)

MEMORY
{
  ROM  (rx) : ORIGIN = 0x00000000, LENGTH = 0x00400000
  RAM  (rw) : ORIGIN = 0x00400000, LENGTH = 0x00100000
}

/* minimum sizes for heap and stack. It will be checked that they can fit on the RAM */
__heap_size      = 0x1000; /* 4 KiB */
__stack_size     = 0x1000; /* 4 KiB */


SECTIONS
{
  /* ================ ROM ================ */

  .text : {
    *(.text .text.* )
  }  > ROM

  .rodata : {
    *(.rodata .rodata.*)
  } > ROM
  .srodata : {
    *(.srodata .srodata.*)
  } > ROM



  /* ================ RAM ================ */

  .init_array : {
    PROVIDE_HIDDEN (__init_array_start = .);
    KEEP (*(.init_array .init_array.*))
    PROVIDE_HIDDEN (__init_array_end = .);
  } > RAM
  .fini_array : {
    PROVIDE_HIDDEN (__fini_array_start = .);
    KEEP (*(.fini_array .fini_array.*))
    PROVIDE_HIDDEN (__fini_array_end = .);
  } > RAM

  .gcc_except_table : {
    *(.gcc_except_table .gcc_except_table.*)
  } > RAM

  .eh_frame : {
    KEEP (*(.eh_frame))
  } > RAM

  __data_start = .;
  .data : {
      *(.data .data.*)
  } > RAM
  __sdata_start = .;
  .sdata : {
      *(.sdata .sdata.*)
  } > RAM

  __bss_start = .;
  .sbss : {
      *(.sbss .sbss.*)
  } > RAM
  .bss : {
      *(.bss .bss.*)
  } > RAM
  _end = .;

  /* do not place anything after this address, because the heap starts here! */

  /* point the global pointer so it can access sdata, sbss, data and bss */
  __global_pointer$ = MIN(__sdata_start + 0x800, MAX(__data_start + 0x800, _end - 0x800));

  /* stack pointer starts at the top of the ram */
  __stack = ORIGIN(RAM) + LENGTH(RAM);
  .stack : {
    ASSERT ((__stack > (_end + __heap_size + __stack_size)), "Error: RAM too small for heap and stack");
  }
}
