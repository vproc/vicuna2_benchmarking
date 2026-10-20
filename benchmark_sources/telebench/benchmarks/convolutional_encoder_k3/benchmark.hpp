#ifndef BENCHMARK_HPP
#define BENCHMARK_HPP

#include <cstdint>

extern "C"
{
    #include "telebench/convolutional_encoder.h"
    #include "data.h"
}

class Benchmark
{
private:
    uint8_t output[OUTPUT_SIZE];

    uint8_t code_matrix[CONSTRAINT_LENGTH][NUMBER_CODE_VECTORS] =
    {
        {1, 1},
        {1, 0},
        {1, 1}
    };

public:

    Benchmark()
    {
        for (int i = 0; i < OUTPUT_SIZE; ++i)
        {
            output[i] = 0;
        }
    }

    inline int run_benchmark()
    {
        convolutionalEncode(
            input_data,
            DATA_SIZE,
            NUMBER_CODE_VECTORS,
            CONSTRAINT_LENGTH,
            code_matrix,
            output
        );

        return 0;
    }

    int validate_benchmark()
    {
        int fail_count = 0;

        for (int i = 0; i < OUTPUT_SIZE; ++i)
        {
            if (output[i] != reference_output[i])
            {
                ++fail_count;
            }
        }

        return fail_count;
    }

    ~Benchmark()
    {
    }
};

#endif
