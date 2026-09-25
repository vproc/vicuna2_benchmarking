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

#ifndef TELEBENCH_CONVOLUTIONAL_ENCODER_H
#define TELEBENCH_CONVOLUTIONAL_ENCODER_H

#include <stdint.h>

#define MAX_CODE_VECTORS 2
#define MAX_CONSTRAINT_LENGTH 8

#ifdef __cplusplus
extern "C" {
#endif

void convolutionalEncode(
    uint8_t *data_bits,
    int16_t data_byte_size,
    int16_t number_code_vectors,
    int16_t constraint_length,
    uint8_t (*code_matrix)[MAX_CODE_VECTORS],
    uint8_t *branch_words
);

#ifdef __cplusplus
}
#endif

#endif
