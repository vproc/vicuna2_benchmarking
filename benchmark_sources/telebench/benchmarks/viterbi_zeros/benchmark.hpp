#ifndef BENCHMARK_HPP
#define BENCHMARK_HPP

#include <cstdint>

extern "C"
{
    #include "telebench/viterbi.h"
    #include "data.h"
}

class Benchmark
{
private:
    int16_t output[VITERBI_OUTPUT_WORDS];

public:

    Benchmark()
    {
        for (int i = 0;
             i < VITERBI_OUTPUT_WORDS;
             ++i)
        {
            output[i] = 0;
        }
    }

    inline int run_benchmark()
    {
        ViterbiDecoderIS136(
            input_data,
            output
        );

        return 0;
    }

    int validate_benchmark()
    {
        int fail_count = 0;

        for (int i = 0;
             i < VITERBI_OUTPUT_WORDS;
             ++i)
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
