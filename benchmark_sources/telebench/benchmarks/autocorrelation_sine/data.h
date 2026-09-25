#ifndef AUTOCORRELATION_SINE_DATA_H
#define AUTOCORRELATION_SINE_DATA_H

#include <stdint.h>

#define DATA_SIZE        1024
#define NUMBER_OF_LAGS   16
#define SCALE             10

extern int16_t input_data[DATA_SIZE];
extern const int16_t reference_output[NUMBER_OF_LAGS];

#endif
