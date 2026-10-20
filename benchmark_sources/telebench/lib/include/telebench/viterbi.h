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

#ifndef TELEBENCH_VITERBI_H
#define TELEBENCH_VITERBI_H

#include <stdint.h>

#define VITERBI_MAX_DATA_SIZE 344
#define VITERBI_OUTPUT_WORDS (VITERBI_MAX_DATA_SIZE / 16 + 1)

#ifdef __cplusplus
extern "C" {
#endif

void ViterbiDecoderIS136(
    int16_t *encoded_stream,
    int16_t *decoded_stream
);

#ifdef __cplusplus
}
#endif

#endif
