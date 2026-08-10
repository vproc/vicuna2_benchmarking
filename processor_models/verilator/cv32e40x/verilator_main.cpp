// Copyright TU Wien
// Licensed under the Solderpad Hardware License v2.1, see LICENSE.txt for
// details SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include "Vvproc_top.h"
#include <bits/getopt_core.h>
#include <cstdio>
#include <errno.h>
#include <getopt.h>
#include <stdint.h>
#include <stdio.h>

#include "verilated.h"
#include "verilator_support_cv32e40x.h"

int main(int argc, char **argv) {
  fprintf(stderr, "Starting Verilator Main()\n");

  int exit_code = 0;

  // Parse program arguments
  if (argc < 10) {
    fprintf(
        stderr,
        "ERROR: Correct Usage: %s PROG_PATHS_LIST MEM_PORTS MEM_W MEM_SZ "
        "MEM_LATENCY EXTRA_CYCLES TEST_NAME VREG_W NUM_TEST_CASES [--trace|-t "
        "WAVEFORM_FILE] [--commit|-c COMMIT_PATH] [--itrace|-i <filepath>]\n",
        argv[0]);
    return 1;
  }

  Vvproc_top *top = new Vvproc_top;
  VerilatedTrace_t *tfp = NULL;
  FILE *fxreglog = NULL;
  auto const program_name = argv[0];

  std::fprintf(stderr, "More args\n");
  static struct option long_options[] = {{"itrace", required_argument, 0, 'i'},
                                         {"trace", required_argument, 0, 't'},
                                         {"commit", required_argument, 0, 'c'},
                                         {0, 0, 0, 0}};

  int opt;
  int option_index = 0;

  while ((opt = getopt_long(argc, argv, "i:c:t:", long_options,
                            &option_index)) != -1) {
    switch (opt) {
    case 'i':
      // Enable instruction tracing
      std::fprintf(stderr, "Enable instruction tracing to %s\n", optarg);
      enable_inst_trace(optarg);
      break;
    case 'c':
      // Init regfile logs
      // TODO: Log commits based on paths for cv32e40x
      {
        std::string filename = (std::string(optarg) + std::string(argv[7]) +
                                std::string("_xreg_commits_verilator.txt"));
        fxreglog = fopen(filename.c_str(), "w");
      }
      break;
    case 't':
      // Setup vcd trace file
      tfp = new VerilatedTrace_t;
      top->trace(tfp, 99); // Trace 99 levels of hierarchy
      tfp->open(optarg);
    default:
      fprintf(stderr,
              "Usage: %s [9 required args...] [--itrace|-i <filepath>] "
              "[--commit|-c <filepath>]\n",
              program_name);
      exit(EXIT_FAILURE);
    }
  }

  // TODO: will be changed anyway
  argv += optind - 1;

  int mem_ports, mem_w, mem_sz, mem_latency, extra_cycles, num_cases;
  {
    char *endptr;
    mem_ports = strtol(argv[2], &endptr, 10);
    if (mem_ports == 0 || *endptr != 0) {
      fprintf(stderr, "ERROR: invalid MEM_PORTS argument\n");
      return 1;
    }
    mem_w = strtol(argv[3], &endptr, 10);
    if (mem_w == 0 || *endptr != 0) {
      fprintf(stderr, "ERROR: invalid MEM_W argument\n");
      return 1;
    }
    mem_sz = strtol(argv[4], &endptr, 10);
    if (mem_sz == 0 || *endptr != 0) {
      fprintf(stderr, "ERROR: invalid MEM_SZ argument\n");
      return 1;
    }
    mem_latency = strtol(argv[5], &endptr, 10);
    if (*endptr != 0) {
      fprintf(stderr, "ERROR: invalid MEM_LATENCY argument\n");
      return 1;
    }
    extra_cycles = strtol(argv[6], &endptr, 10);
    if (*endptr != 0) {
      fprintf(stderr, "ERROR: invalid EXTRA_CYCLES argument\n");
      return 1;
    }
    num_cases = strtol(argv[9], &endptr, 10);
    if (*endptr != 0) {
      fprintf(stderr, "ERROR: invalid NUM_TEST_CASES argument\n");
      return 1;
    }
  }

  Verilated::traceEverOn(true);
  // Verilated::commandArgs(argc, argv);

  FILE *fprogs = fopen(argv[1], "r");
  if (fprogs == NULL) {
    fprintf(stderr, "ERROR: opening `%s': %s\n", argv[1], strerror(errno));
    return 2;
  }

  //////////////////////////
  // Allocate memory latency buffers
  //////////////////////////
  bool *mem_rvalid_queue[mem_ports];
  unsigned char **mem_rdata_queue[mem_ports];
  bool *mem_err_queue[mem_ports];

  for (int i = 0; i < mem_ports; i++) {
    mem_rvalid_queue[i] = (bool *)malloc(sizeof(bool) * mem_latency);
    mem_rdata_queue[i] =
        (unsigned char **)malloc(sizeof(unsigned char *) * mem_latency);
    mem_err_queue[i] = (bool *)malloc(sizeof(bool) * mem_latency);

    for (int queue_pos = 0; queue_pos < mem_latency; queue_pos++) {
      mem_rdata_queue[i][queue_pos] =
          (unsigned char *)malloc(sizeof(unsigned char) * mem_w / 8);
    }
  }

  bool *mem_ivalid_queue = (bool *)malloc(sizeof(bool) * mem_latency);
  unsigned char **mem_idata_queue = (unsigned char **)malloc(
      sizeof(unsigned char *) * mem_latency); // memory instruction port
  bool *mem_ierr_queue = (bool *)malloc(sizeof(bool) * mem_latency);
  // even though known instruction interface width of 32 bits, malloc like this
  // for compatability with memory management helper functions
  for (int queue_pos = 0; queue_pos < mem_latency; queue_pos++) {
    mem_idata_queue[queue_pos] =
        (unsigned char *)malloc(sizeof(unsigned char) * mem_w / 8);
  }

  //////////////////////////
  // Read file containing program paths : TODO - Currently required for support
  // of legacy tests (to get memory dump regions for verification).  Vector
  // tests don't dump any memory to a file
  //////////////////////////

  char *line = NULL, *prog_path = NULL, *ref_path = NULL, *dump_path = NULL;
  size_t line_sz = 0;
  getline(&line, &line_sz, fprogs);
  // allocate sufficient storage space for the four paths (length of the
  // line, or at least 32 bytes)
  if (line_sz < 32) {
    line_sz = 32;
  }
  prog_path = (char *)realloc(prog_path, line_sz);
  ref_path = (char *)realloc(ref_path, line_sz);
  dump_path = (char *)realloc(dump_path, line_sz);
  strcpy(ref_path, "/dev/null");
  strcpy(dump_path, "/dev/null");

  int ref_start = 0, ref_end = 0, dump_start = 0, dump_end = 0, items;
  items = sscanf(line, "%s %s %x %x %s %x %x", prog_path, ref_path, &ref_start,
                 &ref_end, dump_path, &dump_start, &dump_end);
  if (items == 0 || items == EOF) {
    return -1;
  }

  unsigned char *mem = load_program(mem_sz, prog_path);

  //////////////////////////
  // Write Reference File (Legacy tests only)
  //////////////////////////

  dump_mem_region(ref_start, ref_end, mem, ref_path);

  //////////////////////////
  // Begin Program execution
  //////////////////////////

  int i;
  for (int j = 0; j < mem_ports; j++) {
    for (i = 0; i < mem_latency; i++) {
      mem_rvalid_queue[j][i] = 0;
    }
    top->mem_rvalid_i[j] = 0;
  }
  top->mem_irvalid_i = 0;
  top->clk_i = 0;
  top->rst_ni = 0;
  for (i = 0; i < 10; i++) {
    top->clk_i = 0;
    top->eval();
    update_stats(top);
    update_vcd(tfp, 0, 0);

    top->clk_i = 1;
    top->eval();
    update_stats(top);
    update_vcd(tfp, 0, 0);
  }
  top->rst_ni = 1;
  top->eval();
  update_stats(top);
  update_vcd(tfp, 0, 0);

  char *endptr;
  int vreg_w = strtol(argv[8], &endptr, 10);

  int cycles_begin_trace =
      0; // Traces begin at this cycle count.  TODO: expose to the command line
  int cycles_end_trace =
      0; // Traces end at thsi cycle count.  TODO: expose to the command line

  // variables to keep track of vector tests successes/failures
  int v_test_success = 0;
  int v_test_failure = 0;

  //////////////////////////
  // Program Execution - Infinite loop with defined exit conditions
  //////////////////////////
  while (true) {

    //////////////////////////
    // Advance to next clock cycle
    //////////////////////////
    // advance_cycle_half(top, 0);

    top->clk_i = 1;
    top->eval();
    update_stats(top);
    update_vcd(tfp, cycles_begin_trace, cycles_end_trace);

    //////////////////////////
    // Update Memory interfaces
    //////////////////////////
    for (int i = 0; i < mem_ports; i++) {
      // Update write interface
      // Update read interface TODO - STALL IF (top->mem_req_o &&
      // !top->mem_we_o).  Original Vicuna also did not contain this condition
      // TODO: MEM_REQ_VALID NEEDS TO BE SIGNALLED for writes
      update_mem_load(
          top->mem_addr_o[i], (top->mem_req_o[i] && !top->mem_we_o[i]), mem_w,
          mem_latency, mem_sz, (unsigned char *)&(top->mem_rdata_i[i]),
          (bool *)&(top->mem_rvalid_i[i]), (bool *)&(top->mem_err_i[i]),
          mem_rdata_queue[i], mem_rvalid_queue[i], mem_err_queue[i], mem);
      update_mem_write(
          top->mem_addr_o[i], (top->mem_req_o[i] && top->mem_we_o[i]), mem_w,
          mem_latency, mem_sz, (unsigned char *)&(top->mem_wdata_o[i]),
          (unsigned char *)&(top->mem_be_o[i]), mem_rvalid_queue[i],
          mem_err_queue[i], mem);
    }

    // Update instruction memory interface
    update_mem_load(top->mem_iaddr_o, top->mem_ireq_o, mem_w, mem_latency,
                    mem_sz, (unsigned char *)&(top->mem_irdata_i),
                    (bool *)&(top->mem_irvalid_i), (bool *)&(top->mem_ierr_i),
                    mem_idata_queue, mem_ivalid_queue, mem_ierr_queue, mem);

    top->eval();
    update_stats(top);
    update_vcd(tfp, cycles_begin_trace, cycles_end_trace);

    //////////////////////////
    // Check Memory Mapped IO
    //////////////////////////

    // Use memory mapped IO at address 0x408 to signal success or failure
    char w_port;
    if (check_memmapio(
            top->mem_addr_o[0], (top->mem_req_o[0] && top->mem_we_o[0]), 8,
            (unsigned char *)&(top->mem_wdata_o[0]), 0x00000408u, &w_port)) {
      if (w_port == 0) {
        fprintf(stderr, "SUCCESS: TEST PASS\n");
        exit_code = 0; // For benchmarks, only 1 test
        break;

      } else {
        fprintf(stderr, "ERROR: TEST FAILURE - FAILED OUTPUT VALIDATION\n");
        exit_code = 1;
        break; // For benchmarks, only 1 test
      }
    }
    // Use memory mapped UART at address 0x400 to print outputs
    if (check_memmapio(
            top->mem_addr_o[0], (top->mem_req_o[0] && top->mem_we_o[0]), 8,
            (unsigned char *)&(top->mem_wdata_o[0]), 0x00000400u, &w_port)) {
      putc(w_port, stderr);
    }

    //////////////////////////
    // Check/Write Register Commits
    //////////////////////////

    // if (fxreglog != NULL &&
    // top->vproc_top->i_cva6_pipeline->we_gpr_commit_id)
    // {
    //     fprintf(fxreglog, "x%d 0x%08x\n",
    //     top->vproc_top->i_cva6_pipeline->waddr_commit_id,
    //     top->vproc_top->i_cva6_pipeline->wdata_commit_id);
    // }

    //////////////////////////
    // Advance to next clock cycle
    //////////////////////////
    // advance_cycle_half(top, 1);
    top->clk_i = 0;
    top->eval();
    update_stats(top);
    update_vcd(tfp, cycles_begin_trace, cycles_end_trace);

    //////////////////////////
    // Check Exit Conditions
    //////////////////////////

    // A jump to address 0x70 is a failed test caused by an interrupt being
    // called (all other interrupts also funnel here)
    if (check_PC(top, 0x000000070u)) {
      fprintf(stderr, "ERROR: TEST FAILURE - Interrupt Called\n");
      exit_code = 1;
      break;
    }

    if (check_stall(top, 10000)) {
      exit_code = 1;
      break;
    }

    //////////
    // Outputs + Statistics
    //////////

    // update_xreg_commit(top, fxreglog);
    // update_freg_commit(top, ffreglog);
    // update_vreg_commit(top, vreg_w, fvreglog);
  }

#if defined(TRACE_VCD) || defined(TRACE_FST)
  if (tfp != NULL) {
    tfp->close();
  }
#endif
  top->final();
  free(prog_path);
  free(ref_path);
  free(dump_path);
  free(line);
  free(mem);
  for (int i = 0; i < mem_ports; i++) {
    free(mem_rvalid_queue[i]);
    for (int queue_pos = 0; queue_pos < mem_latency; queue_pos++) {
      free(mem_rdata_queue[i][queue_pos]);
    }
    free(mem_rdata_queue[i]);
    free(mem_err_queue[i]);
  }

  for (int queue_pos = 0; queue_pos < mem_latency; queue_pos++) {
    free(mem_idata_queue[queue_pos]);
  }
  free(mem_idata_queue);

  fclose(fprogs);
  if (tfp != NULL) {
    tfp->close();
  }

  if (fxreglog != NULL) {
    fclose(fxreglog);
  }
  // fclose(fvreglog);
  // fclose(ffreglog);

  return exit_code;
}
