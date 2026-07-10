/*
 * Map vicuna specific functions to valid functions for gem5
 */
#ifndef UART_HPP
#define UART_HPP

#include <stdarg.h>
#include <stdio.h>
#include <stdint.h>

// void uart_putc(char c);
// char uart_getc(void);

// void uart_write(int n, const char *buf);
// void uart_read(int n, char *buf);

// int uart_puts(const char *str);
// void uart_gets(char *buf, int size);

//int uart_printf(const char* format, ...);
#define uart_printf printf

 #endif
