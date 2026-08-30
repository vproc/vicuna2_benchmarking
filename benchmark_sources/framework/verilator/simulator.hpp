#ifndef SIMULATOR_HPP
#define SIMULATOR_HPP

#include "uart.hpp"
#include <cstdint>

extern "C" {
void _exit(int status) {
    volatile char* exit_port = (volatile char*)0x00000408;
    *exit_port = (char)status;
}

void __attribute__((noinline)) address_match_start() { volatile int a = 1; }
void __attribute__((noinline)) address_match_end() { volatile int a = 1; }
}

class Simulator {
private:
  // Stats variables
  uint32_t start_cycles, start_instr;
  uint32_t end_cycles, end_instr;

  // Memory mapped address to terminate execution
  volatile int *const terminate_addr = (int *)0x00000408;

public:
  Simulator(){};

  // Function to start measurement
  // Verilator Simulation uses simulated CSRs
  inline void begin_measurement() {
    asm volatile("csrr %0,mcycle" : "=r"(start_cycles));
    asm volatile("csrr %0,minstret" : "=r"(start_instr));
    address_match_start();
  };

  // Function to end measurement
  // Verilator Simulation uses simulated CSRs
  inline void end_measurement() {
    address_match_end();
    asm volatile("csrr %0,mcycle" : "=r"(end_cycles));
    asm volatile("csrr %0,minstret" : "=r"(end_instr));
    uart_printf("Total Cycles:       %d\n", end_cycles - start_cycles);
    uart_printf("Total Instructions: %d\n\n", end_instr - start_instr);
  };

  // Termination success or failure function for this simulator
  void terminate(int code)
  {
    *terminate_addr = code; // Write return code to termination address
  };

  // Cleanup any allocatations
  ~Simulator(){};
};
#endif
