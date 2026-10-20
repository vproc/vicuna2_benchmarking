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

#include "telebench/bit_allocation.h"

void fxpBitAllocation(
    int16_t *carrier_snr_db,
    int16_t *carrier_bit_allocation,
    uint16_t number_of_carriers,
    int16_t water_level_db_in,
    int16_t *water_level_db_out,
    int16_t *allocation_map,
    uint16_t bits_per_dmt_symbol,
    size_t loop_cnt)
{
    uint16_t total_bits;
    uint16_t carrier_bits;
    int16_t carrier;
    int32_t delta_db;
    int16_t water_level_db;

    (void)loop_cnt;

    water_level_db = water_level_db_in;

    do
    {
        total_bits = 0;

        for (carrier = 0; carrier < number_of_carriers; carrier++)
        {
            delta_db = carrier_snr_db[carrier] - water_level_db;

            if (delta_db < 0)
            {
                carrier_bits = 0;
            }
            else
            {
                if (delta_db > 32767)
                {
                    carrier_bits = MAX_BITS_PER_CARRIER;
                }
                else
                {
                    carrier_bits = allocation_map[delta_db >> 6];
                }

                if ((carrier_bits + total_bits) > bits_per_dmt_symbol)
                {
                    carrier_bits = bits_per_dmt_symbol - total_bits;
                }
            }

            carrier_bit_allocation[carrier] = carrier_bits;
            total_bits += carrier_bits;
        }

        water_level_db +=
            (int32_t)STEP_SIZE * 3 *
            ((int16_t)total_bits - (int16_t)bits_per_dmt_symbol)
            / (int16_t)number_of_carriers;

    } while (total_bits != bits_per_dmt_symbol);

    *water_level_db_out = water_level_db;
}
