/**
 *
 * Copyright (C) EEMBC(R) All Rights Reserved
 *
 * This software is licensed with an Acceptable Use Agreement under Apache 2.0.
 * Please refer to the license file (LICENSE.md) included with this code.
 *
 * Modified for integration into the Vicuna benchmarking framework.
 *
 */

#include "telebench/viterbi.h"

#define ENCBITS     5
#define NUMSTATES   (1 << ENCBITS)

#define EVENMULTIPLEOF8 \
    (1 - ((VITERBI_MAX_DATA_SIZE / 8) % 2))

typedef struct
{
    int16_t state;
    int16_t path_metric;
} StatePathMetricData;

static StatePathMetricData SPM1[NUMSTATES];
static StatePathMetricData SPM2[NUMSTATES];

static int16_t branch_metrics[NUMSTATES / 2];

static int16_t saved_path[
    NUMSTATES * (VITERBI_MAX_DATA_SIZE / 8 + 1)
];

static StatePathMetricData *buf_ptr[2] =
{
    SPM1,
    SPM2
};

static int buf_selector;

static const int16_t branch_word_mapping[] =
{
     16384,
     20480,
     24576,
     28672,
    -24576,
    -20480,
    -16384,
    -12288
};


static void FindMetrics(
    int16_t encoded_word,
    int16_t *branch_metric)
{
    int16_t pp;
    int16_t pm;
    int16_t mm;
    int16_t mp;

    int16_t p0_16;
    int16_t p1_16;

    int16_t bw0;
    int16_t bw1;

    bw0 = branch_word_mapping[
        (encoded_word & 0x38) >> 3
    ];

    bw1 = branch_word_mapping[
        encoded_word & 0x7
    ];

    p0_16 = (int16_t)(
        ((int32_t)bw0 * -16) >> 16
    );

    p1_16 = (int16_t)(
        ((int32_t)bw1 * -16) >> 16
    );

    pp =  p0_16 + p1_16;
    pm =  p0_16 - p1_16;
    mm = -p0_16 - p1_16;
    mp = -p0_16 + p1_16;

    *branch_metric++ = mm;
    *branch_metric++ = pm;
    *branch_metric++ = mp;
    *branch_metric++ = pp;

    *branch_metric++ = pp;
    *branch_metric++ = mp;
    *branch_metric++ = pm;
    *branch_metric++ = mm;

    *branch_metric++ = mp;
    *branch_metric++ = pp;
    *branch_metric++ = mm;
    *branch_metric++ = pm;

    *branch_metric++ = pm;
    *branch_metric++ = mm;
    *branch_metric++ = pp;
    *branch_metric++ = mp;
}


static void PreACS(
    int iterations,
    int16_t *branch_metric)
{
    int i;

    int16_t metric_in;
    int16_t metric1;
    int16_t metric2;

    StatePathMetricData *in =
        buf_ptr[buf_selector];

    StatePathMetricData *out =
        buf_ptr[1 - buf_selector];

    buf_selector ^= 1;

    for (i = 0; i < iterations; i++)
    {
        metric_in = *branch_metric++;

        metric1 =
            in->path_metric - metric_in;

        metric2 =
            in->path_metric + metric_in;

        out->path_metric = metric1;
        out->state = (int16_t)(in->state << 1);
        out++;

        out->path_metric = metric2;
        out->state =
            (int16_t)((in->state << 1) | 1);
        out++;

        in++;
    }
}


static void ACS(int16_t *branch_metric)
{
    int i;

    int16_t metric_in;
    int16_t metric1;
    int16_t metric2;

    StatePathMetricData *in1 =
        buf_ptr[buf_selector];

    StatePathMetricData *in2 =
        in1 + NUMSTATES / 2;

    StatePathMetricData *out =
        buf_ptr[1 - buf_selector];

    buf_selector ^= 1;

    for (i = 0; i < NUMSTATES / 2; i++)
    {
        metric_in = *branch_metric++;

        metric1 =
            in1->path_metric - metric_in;

        metric2 =
            in2->path_metric + metric_in;

        if (metric1 >= metric2)
        {
            out->path_metric = metric1;
            out->state =
                (int16_t)(in1->state << 1);
        }
        else
        {
            out->path_metric = metric2;
            out->state =
                (int16_t)(in2->state << 1);
        }

        out++;

        metric1 =
            in1->path_metric + metric_in;

        metric2 =
            in2->path_metric - metric_in;

        if (metric1 >= metric2)
        {
            out->path_metric = metric1;
            out->state =
                (int16_t)((in1->state << 1) | 1);
        }
        else
        {
            out->path_metric = metric2;
            out->state =
                (int16_t)((in2->state << 1) | 1);
        }

        out++;

        in1++;
        in2++;
    }
}


static void StorePaths(int16_t *path_ptr)
{
    int i;

    int16_t path_metric;

    StatePathMetricData *in =
        buf_ptr[buf_selector];

    for (i = 0; i < NUMSTATES; i++)
    {
        path_metric = in->state;

        *path_ptr++ =
            (int16_t)(path_metric >> 5);

        in->state =
            (int16_t)(path_metric & 0x1f);

        in++;
    }
}


static void TraceBack(
    int16_t *out,
    int16_t *in)
{
    int i;
    int offset = 0;

    volatile int16_t path_bits1;
    volatile int16_t path_bits2;

    out +=
        (VITERBI_MAX_DATA_SIZE / 8) / 2;

    *in =
        buf_ptr[buf_selector]->state;

    if (!EVENMULTIPLEOF8)
    {
        path_bits2 = *in;

        offset =
            (path_bits2 & 0xf8) >> 3;

        in -= NUMSTATES;

        *out-- =
            (int16_t)(path_bits2 << 8);
    }

    for (
        i = 0;
        i < ((VITERBI_MAX_DATA_SIZE / 8) / 2);
        i++)
    {
        path_bits1 =
            *(in + offset);

        offset =
            (path_bits1 & 0xf8) >> 3;

        in -= NUMSTATES;

        path_bits2 =
            *(in + offset);

        offset =
            (path_bits2 & 0xf8) >> 3;

        in -= NUMSTATES;

        *out-- =
            (int16_t)(
                (path_bits2 << 8) |
                path_bits1
            );
    }
}


void ViterbiDecoderIS136(
    int16_t *encoded_stream,
    int16_t *decoded_stream)
{
    int i;
    int iter;

    int16_t *path_ptr = saved_path;

    buf_selector = 0;

    SPM1[0].path_metric = 0x0ff;

    for (i = 1; i < NUMSTATES; i++)
    {
        SPM1[i].path_metric = 0;
    }

    iter = 1;

    for (i = 0; i < ENCBITS; i++)
    {
        FindMetrics(
            *encoded_stream++,
            branch_metrics
        );

        PreACS(
            iter,
            branch_metrics
        );

        iter *= 2;
    }

    for (
        i = 0;
        i < VITERBI_MAX_DATA_SIZE / 8 - 1;
        i++)
    {
        int j;

        for (j = 0; j < 8; j++)
        {
            FindMetrics(
                *encoded_stream++,
                branch_metrics
            );

            ACS(branch_metrics);
        }

        StorePaths(path_ptr);

        path_ptr += NUMSTATES;
    }

    for (i = 0; i < 8 - ENCBITS; i++)
    {
        FindMetrics(
            *encoded_stream++,
            branch_metrics
        );

        ACS(branch_metrics);
    }

    TraceBack(
        decoded_stream,
        path_ptr
    );
}
