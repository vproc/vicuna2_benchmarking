#ifndef AUTOCORRELATION_DATA_H
#define AUTOCORRELATION_DATA_H

#include <stdint.h>

#define DATA_SIZE       16
#define NUMBER_OF_LAGS   8
#define SCALE            4

extern int16_t input_data[DATA_SIZE];
extern const int16_t reference_output[NUMBER_OF_LAGS];

#endif
