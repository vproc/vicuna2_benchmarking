#ifndef SIMULATOR_HPP
#define SIMULATOR_HPP 

#include <cstdint>


#include <cstdint>

extern "C" {
void _exit(int status) {
    uint32_t tohost_val = (status << 1) | 1;
    __asm__ volatile("mv t0, %0" : : "r"(tohost_val));
    __asm__ volatile("la t1, tohost");
    __asm__ volatile("auipc t2, 0x0");
    __asm__ volatile("sw t0, 0(t1)");
    __asm__ volatile("jalr x0, 4(t2)");
}
}
class Simulator
{
    private:

    // Stats variables
    uint32_t start_cycles, start_instr;
    uint32_t end_cycles, end_instr;

    public:

    Simulator(){};

    //Function to start measurement TODO: Spike output for instructions executed
    inline void begin_measurement()
    {
    };

    //Function to end measurement
    inline void end_measurement()
    {

    };

    //Termination success or failure function for this simulator
    int terminate(int return_code)
    {
        _exit(return_code);
        return return_code;
    }

    //Cleanup any allocatations
    ~Simulator(){};
};
#endif
