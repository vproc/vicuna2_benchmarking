/**
 *
 * Copyright (C) EEMBC(R) All Rights Reserved
 *
 * This software is licensed with an Acceptable Use Agreement under Apache 2.0.
 * Please refer to the license file (LICENSE.md) included with this code.
 *
 * Modified for integration into the Vicuna benchmarking framework.
 *
 */

#ifndef TELEBENCH_BIT_ALLOCATION_H
#define TELEBENCH_BIT_ALLOCATION_H

#include <stdint.h>
#include <stddef.h>

#define STEP_SIZE               51
#define MAX_BITS_PER_CARRIER    12
#define ALLOCATION_MAP_SIZE     512

#ifdef __cplusplus
extern "C" {
#endif

void fxpBitAllocation(
    int16_t *carrier_snr_db,
    int16_t *carrier_bit_allocation,
    uint16_t number_of_carriers,
    int16_t water_level_db_in,
    int16_t *water_level_db_out,
    int16_t *allocation_map,
    uint16_t bits_per_dmt_symbol,
    size_t loop_cnt
);

#ifdef __cplusplus
}
#endif

#endif
