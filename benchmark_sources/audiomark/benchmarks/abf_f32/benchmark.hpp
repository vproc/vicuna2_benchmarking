#ifndef BENCHMARK_HPP
#define BENCHMARK_HPP 

#include <cstdint>
//BSP includes
//#include "uart.hpp"
//Includes for benchmark

extern "C"
{
   #include "ee_abf_f32.h"
}
#define TEST_NBUFFERS 104U
#define NSAMPLES      256U
#define NFRAMEBYTES   512U

extern const int16_t p_channel1[TEST_NBUFFERS][NSAMPLES];
extern const int16_t p_channel2[TEST_NBUFFERS][NSAMPLES];
extern const int16_t p_expected[TEST_NBUFFERS][NSAMPLES];

class Benchmark
{
    private:
    /*
    * Private Helper Functions and variables
    */

    /* Noise to signal ratio */
    #define NSRM50DB 0.003162f

    int16_t p_left[NSAMPLES];
    int16_t p_right[NSAMPLES];
    int16_t p_output[NSAMPLES];

    xdais_buffer_t xdais[3];

    int8_t inst_array_static[8192];  //Statically decare this array due to malloc issues

    // Used deep inside audiomark core
    char *spxGlobalHeapPtr;
    char *spxGlobalHeapEnd;

    bool      err           = false;
    uint32_t  memreq        = 0;
    uint32_t *p_req         = &memreq;
    void     *inst          = &inst_array_static;
    uint32_t  parameters[1] = { 0 };
    uint32_t  A             = 0;
    uint32_t  B             = 0;
    float     ratio         = 0.0f;

    public:
    /*
    * Required Functions for test framework
    */
    //
    Benchmark(){
        // filter initialization
        //ee_abf_f32(NODE_MEMREQ, (void **)&p_req, NULL, NULL);
        //inst = vicuna_malloc(memreq);

        SETUP_XDAIS(xdais[0], p_left, NFRAMEBYTES);
        SETUP_XDAIS(xdais[1], p_right, NFRAMEBYTES);
        SETUP_XDAIS(xdais[2], p_output, NFRAMEBYTES);

        ee_abf_f32(NODE_RESET, (void **)&inst, xdais, NULL);

        memcpy(p_left, &p_channel1[0], NFRAMEBYTES);    //Currently only running first testcase
        memcpy(p_right, &p_channel2[0], NFRAMEBYTES);
    };

    //Call code to be benchmarked
    inline int run_benchmark()
    {
        int err = ee_abf_f32(NODE_RESET, (void **)&inst, xdais, NULL);
        return err; //cannot fail internally

    };

    //Validate Output
    int validate_benchmark()
    {
        for (unsigned j = 0; j < NSAMPLES; ++j)
        {
            A += abs(p_output[j]);
            B += abs(p_output[j] - p_expected[0][j]); //Currently only running first testcase

#ifdef DEBUG_EXACT_BITS
            if (p_output[j] == p_expected[i][j])
            {
                err = true;
                printf("S[%03d]B[%03d]L[%-5d]R[%-5d]O[%-5d]E[%-5d] ... FAIL\n",
                       i,
                       j,
                       p_left[j],
                       p_right[j],
                       p_output[j],
                       p_expected[i][j]);
            }
#endif
        }

        ratio = (float)B / (float)A;
        if (ratio > NSRM50DB)
        {
            err = true;
            //printf("ABF FAIL: Frame #%d exceeded -50 dB Noise-to-Signal ratio\n", i);
        }

        return err;
    };
    //Cleanup any allocatations
    ~Benchmark(){
    };
};
#endif
