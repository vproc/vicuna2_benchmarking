#ifndef BIT_ALLOCATION_DATA6_DATA_H
#define BIT_ALLOCATION_DATA6_DATA_H

#include <stdint.h>
#include "telebench/bit_allocation.h"

#define NUMBER_OF_CARRIERS   100
#define BITS_PER_DMT_SYMBOL  500

extern int16_t carrier_snr[NUMBER_OF_CARRIERS];
extern const int16_t reference_output[NUMBER_OF_CARRIERS];
extern int16_t allocation_map[ALLOCATION_MAP_SIZE];

#endif
