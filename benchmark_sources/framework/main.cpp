#include "simulator.hpp"
#include "benchmark.hpp"

//Includes two separate headers
// - "benchmark.hpp" contains benchmark specific functions.  Class defined for each benchmark.
// - "simulator.hpp" contains simulator specific functions.  Class defined for each simulator framework.


int main() 
{ 
    //Declare Benchmark and Simulator
    Benchmark benchmark;
    Simulator simulator;

    //Run benchmark
    simulator.begin_measurement();
    int code = benchmark.run_benchmark();
    simulator.end_measurement();
    if (code != 0) {
        return code;
    }
    code = benchmark.validate_benchmark();
    simulator.terminate(code);
    return code;

} 
