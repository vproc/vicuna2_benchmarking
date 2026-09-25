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


#include "telebench/convolutional_encoder.h"

void convolutionalEncode(
    uint8_t *data_bits,
    int16_t data_byte_size,
    int16_t number_code_vectors,
    int16_t constraint_length,
    uint8_t (*code_matrix)[MAX_CODE_VECTORS],
    uint8_t *branch_words)
{
    int16_t sr_index;
    int16_t bw_index;
    int16_t data_index;
    int16_t cv_index;

    uint8_t shift_register[MAX_CONSTRAINT_LENGTH];

    for (sr_index = 0; sr_index < constraint_length; sr_index++)
    {
        shift_register[sr_index] = 0;
    }

    bw_index = 0;

    for (data_index = 0; data_index < data_byte_size; data_index++)
    {
        for (sr_index = constraint_length - 1;
             sr_index > 0;
             sr_index--)
        {
            shift_register[sr_index] =
                shift_register[sr_index - 1];
        }

        shift_register[0] = data_bits[data_index];

        for (cv_index = 0;
             cv_index < number_code_vectors;
             cv_index++)
        {
            branch_words[bw_index] = 0;

            for (sr_index = 0;
                 sr_index < constraint_length;
                 sr_index++)
            {
                if (code_matrix[sr_index][cv_index])
                {
                    branch_words[bw_index] ^=
                        shift_register[sr_index];
                }
            }

            bw_index++;
        }
    }
}
