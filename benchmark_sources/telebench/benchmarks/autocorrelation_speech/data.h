#ifndef AUTOCORRELATION_SPEECH_DATA_H
#define AUTOCORRELATION_SPEECH_DATA_H

#include <stdint.h>

#define DATA_SIZE        500
#define NUMBER_OF_LAGS   32
#define SCALE              9

extern int16_t input_data[DATA_SIZE];
extern const int16_t reference_output[NUMBER_OF_LAGS];

#endif
