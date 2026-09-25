#ifndef CONVOLUTIONAL_ENCODER_K4_DATA_H
#define CONVOLUTIONAL_ENCODER_K4_DATA_H

#include <stdint.h>

#define DATA_SIZE             512
#define NUMBER_CODE_VECTORS     2
#define CONSTRAINT_LENGTH       4
#define OUTPUT_SIZE (DATA_SIZE * NUMBER_CODE_VECTORS)

extern uint8_t input_data[DATA_SIZE];
extern const uint8_t reference_output[OUTPUT_SIZE];

#endif
