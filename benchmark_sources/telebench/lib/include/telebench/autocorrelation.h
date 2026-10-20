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

#ifndef TELEBENCH_AUTOCORRELATION_H
#define TELEBENCH_AUTOCORRELATION_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void fxpAutoCorrelation(
    int16_t *input_data,
    int16_t *autocorr_data,
    int16_t data_size,
    int16_t number_of_lags,
    int16_t scale
);

#ifdef __cplusplus
}
#endif

#endif
