#ifndef BENCHMARK_HPP
#define BENCHMARK_HPP

#include <cstdint>

extern "C"
{
    #include "telebench/bit_allocation.h"
    #include "data.h"
}

class Benchmark
{
private:
    int16_t output[NUMBER_OF_CARRIERS];

    int16_t water_level_in;
    int16_t water_level_out;

public:

    Benchmark()
    {
        for (int i = 0; i < NUMBER_OF_CARRIERS; ++i)
        {
            output[i] = 0;
        }

        // Original TeleBench starts with maximum carrier SNR.
        water_level_in = -32768;

        for (int i = 0; i < NUMBER_OF_CARRIERS; ++i)
        {
            if (carrier_snr[i] > water_level_in)
            {
                water_level_in = carrier_snr[i];
            }
        }

        // Original TeleBench clips allocation-map values to max 12 bits.
        for (int i = 0; i < ALLOCATION_MAP_SIZE; ++i)
        {
            if (allocation_map[i] > MAX_BITS_PER_CARRIER)
            {
                allocation_map[i] = MAX_BITS_PER_CARRIER;
            }
        }

        water_level_out = 0;
    }

    inline int run_benchmark()
    {
        fxpBitAllocation(
            carrier_snr,
            output,
            NUMBER_OF_CARRIERS,
            water_level_in,
            &water_level_out,
            allocation_map,
            BITS_PER_DMT_SYMBOL,
            0
        );

        return 0;
    }

    int validate_benchmark()
    {
        int fail_count = 0;

        for (int i = 0; i < NUMBER_OF_CARRIERS; ++i)
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
