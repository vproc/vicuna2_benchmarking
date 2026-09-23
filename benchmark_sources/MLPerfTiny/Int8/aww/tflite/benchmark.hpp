#ifndef AWW_INT8_BENCHMARK_HPP
#define AWW_INT8_BENCHMARK_HPP
#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "aww_int8_data/aww_int8_input_data.h"
#include "aww_int8_data/aww_int8_model_data.h"
#include "aww_int8_data/aww_int8_model_settings.h"
#include "aww_int8_data/aww_int8_output_data_ref.h"

#include "tensorflow/lite/micro/tflite_bridge/micro_error_reporter.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/schema/schema_generated.h"

//extern "C" {
//#include "runtime.h"
//#include "uart.h"
//}


//commit before array.h added - 6f2828619641503942f2bd69ddee006ff7823130

class Benchmark{
    private: 
        static constexpr size_t tensor_arena_size = 256 * 1024;
        alignas(16) uint8_t tensor_arena[tensor_arena_size];

        const tflite::Model *model;
    
    public:
    Benchmark(){};

    inline int run_benchmark(){
        tflite::MicroErrorReporter micro_error_reporter;
        tflite::ErrorReporter *error_reporter = &micro_error_reporter;

        model = tflite::GetModel(aww_int8_model_data);

        static tflite::MicroMutableOpResolver<6> resolver;
        resolver.AddFullyConnected();
        resolver.AddConv2D();
        resolver.AddDepthwiseConv2D();
        resolver.AddAveragePool2D();
        resolver.AddReshape();
        resolver.AddSoftmax();

        tflite::MicroInterpreter interpreter(model, resolver, tensor_arena, tensor_arena_size);

        if (interpreter.AllocateTensors() != kTfLiteOk)
        {
            TF_LITE_REPORT_ERROR(error_reporter, "ERROR: In AllocateTensors().");
            return -1;
        }

        Simulator simulator;
        simulator.begin_measurement();
        for (size_t i = 0; i < aww_int8_data_sample_cnt; i++)
        {
            memcpy(interpreter.input(0)->data.int8, (int8_t *)aww_int8_input_data[i], aww_int8_input_data_len[i]);

            if (interpreter.Invoke() != kTfLiteOk)
            {
                TF_LITE_REPORT_ERROR(error_reporter, "ERROR: In Invoke().");
                return -1;
            }
            

            int8_t top_index = 0;
            for (size_t j = 0; j < aww_int8_model_label_cnt; j++)
            {
                if (interpreter.output(0)->data.int8[j] > interpreter.output(0)->data.int8[top_index])
                {
                    top_index = j;
                }
            }

            if (top_index != aww_int8_output_data_ref[i])
            {
                //uart_printf("ERROR: at #%d, top_index %d aww_int8_output_data_ref %d \n", i, top_index, aww_int8_output_data_ref[i]);
                simulator.terminate(1); // see toycar/benchmark.hpp
                return -1;
            }
            else
            {
                //uart_printf("Sample #%d pass, top_index %d matches ref %d \n", i, top_index, aww_int8_output_data_ref[i]);
            }
        }
        simulator.end_measurement();
        simulator.terminate(0);
        return 0;
    }

   //Validate Output
    int validate_benchmark()
    {
        //Not used due to scoping issue
        return true;
    };
    //Cleanup any allocatations
    ~Benchmark(){
    };
};
#endif


