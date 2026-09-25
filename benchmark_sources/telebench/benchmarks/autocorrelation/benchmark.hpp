#ifndef BENCHMARK_HPP
#define BENCHMARK_HPP

#include <cstdint>

extern "C"
{
    #include "telebench/autocorrelation.h"
    #include "data.h"
}

class Benchmark
{
private:
    int16_t output[NUMBER_OF_LAGS];

public:

    Benchmark()
    {
        for (int i = 0; i < NUMBER_OF_LAGS; ++i)
        {
            output[i] = 0;
        }
    }

    inline int run_benchmark()
    {
        fxpAutoCorrelation(
            input_data,
            output,
            DATA_SIZE,
            NUMBER_OF_LAGS,
            SCALE
        );

        return 0;
    }

    int validate_benchmark()
    {
        int fail_count = 0;

        for (int i = 0; i < NUMBER_OF_LAGS; ++i)
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
