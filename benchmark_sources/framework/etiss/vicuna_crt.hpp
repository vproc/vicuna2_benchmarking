/*
 * Map vicuna specific functions to valid functions for gem5
 */

#ifndef _VICUNA_CRT_H
#define _VICUNA_CRT_H

#ifdef __cplusplus
//extern "C" {
#endif

#include <stdlib.h>

#define vicuna_malloc malloc 
#define vicuna_free free 

#ifdef __cplusplus
//}
#endif

#endif /* _VICUNA_CRT_H */
