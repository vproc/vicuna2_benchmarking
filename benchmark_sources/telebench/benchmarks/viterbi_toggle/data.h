#ifndef VITERBI_BENCHMARK_DATA_H
#define VITERBI_BENCHMARK_DATA_H

#include <stdint.h>
#include "telebench/viterbi.h"

extern int16_t input_data[VITERBI_MAX_DATA_SIZE];

extern const int16_t
reference_output[VITERBI_OUTPUT_WORDS];

#endif
