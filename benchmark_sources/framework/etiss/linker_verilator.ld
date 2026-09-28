/* Copyright TU Wien                                                               */
/* Licensed under the Solderpad Hardware License v2.1, see LICENSE.txt for details */
/* SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1                                */


OUTPUT_ARCH(riscv)
ENTRY(_start)

SEARCH_DIR(.)
__DYNAMIC = 0;

MEMORY
{
    boot : ORIGIN = 0x80000000, LENGTH = 0x00002000 /*   8 kB */
    ram  : ORIGIN = 0x80002000, LENGTH = 0x003FE000 /* 248 kB */
}

STACK_LEN = 0x4000; /* 16 kB */

SECTIONS
{
    .vectors : {
        *(.vectors)
    } >boot

    .text : {
        _stext = .;
        *(.text)
        *(.text.*)
        . = ALIGN(32);
        _etext  =  .;
        . = ALIGN(32);
        __CTOR_LIST__ = .;
        LONG((__CTOR_END__ - __CTOR_LIST__) / 4 - 2)
        *(.ctors)
        LONG(0)
        . = ALIGN(32);
        __CTOR_END__ = .;
        . = ALIGN(32);
        __DTOR_LIST__ = .;
        LONG((__DTOR_END__ - __DTOR_LIST__) / 4 - 2)
        *(.dtors)
        LONG(0)
        __DTOR_END__ = .;
        *(.lit)
        *(.shdata)
        . = ALIGN(32);
        _endtext = .;
        . = ALIGN(32);
        _ssetup = .;
        *(.setup)
        *(.setup.*)
        . = ALIGN(32);
         _esetup  =  .;
    } >ram

    .rodata : {
        . = ALIGN(4);
        *(.rodata);
        *(.rodata.*)
    } >ram

    .shbss : {
        . = ALIGN(4);
        *(.shbss)
    } >ram

    .data : {
        . = ALIGN(4);
        sdata = .;
        _sdata = .;
        *(.data);
        *(.data.*)
        edata = .;
        _edata = .;
    } >ram

    .bss (NOLOAD) : {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        _bss_end = .;
    } >ram

    _end = .;

    .user_align (NOLOAD) : {
        . = ALIGN(0x1000);
        _user_start = .;
    } >ram


    .stack ORIGIN(ram) + LENGTH(ram) - STACK_LEN (NOLOAD) : {
        . = ALIGN(16);
        _stack_start = .;
        . = . + STACK_LEN;
        . = ALIGN(16);
        stack = .;
        _stack = .;
        _stack_end = .;
    } >ram
}
