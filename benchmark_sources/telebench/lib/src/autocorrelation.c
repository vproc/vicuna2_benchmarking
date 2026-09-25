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

#include "telebench/autocorrelation.h"

void fxpAutoCorrelation(
    int16_t *input_data,
    int16_t *autocorr_data,
    int16_t data_size,
    int16_t number_of_lags,
    int16_t scale)
{
    int i;
    int lag;
    int last_index;
    int32_t accumulator;

    for (lag = 0; lag < number_of_lags; lag++)
    {
        accumulator = 0;
        last_index = data_size - lag;

        for (i = 0; i < last_index; i++)
        {
            accumulator +=
                ((int32_t)input_data[i] *
                 (int32_t)input_data[i + lag]) >> scale;
        }

        autocorr_data[lag] =
            (int16_t)(accumulator >> 16);
    }
}
