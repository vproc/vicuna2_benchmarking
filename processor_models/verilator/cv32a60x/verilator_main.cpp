// Copyright TU Wien
// Licensed under the Solderpad Hardware License v2.1, see LICENSE.txt for details
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1


#include <stdio.h>
#include <stdint.h>
#include <errno.h>
#include "Vvproc_top.h"

#include "verilator_support_cv32a60x.h"
#include "verilated.h"
#include "Vvproc_top_cva6_pipeline__Cz2.h"


int main(int argc, char **argv) {
    fprintf(stderr, "Starting Verilator Main()\n");
    
    int exit_code = 0;
    
    //////////////////////////
    //Check validity and parse input arguments
    //////////////////////////
    if (argc != 10 && argc != 12 && argc != 14) {
        fprintf(stderr, "ERROR: Correct Usage: %s PROG_PATHS_LIST MEM_PORTS MEM_W MEM_SZ MEM_LATENCY EXTRA_CYCLES TEST_NAME VREG_W NUM_TEST_CASES [--trace WAVEFORM_FILE] [--commit COMMIT_PATH]\n", argv[0]);
        return 1;
    }  

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
    //Verilated::commandArgs(argc, argv);

    FILE *fprogs = fopen(argv[1], "r");
    if (fprogs == NULL) {
        fprintf(stderr, "ERROR: opening `%s': %s\n", argv[1], strerror(errno));
        return 2;
    }

    //////////////////////////
    //Allocate memory latency buffers
    //////////////////////////

    bool *mem_rvalid_queue = (bool *)malloc(sizeof(bool) * mem_latency);
    unsigned char **mem_rdata_queue  = (unsigned char **)malloc(sizeof(unsigned char *) * mem_latency); //memory data port
    bool **mem_meta_queue   = (bool **)malloc(sizeof(bool *) * mem_latency); //memory metadata port

    bool *mem_wvalid_queue = (bool *)malloc(sizeof(bool) * mem_latency);


    for(int queue_pos = 0; queue_pos < mem_latency; queue_pos++)
    {
        mem_rdata_queue[queue_pos] = (unsigned char *)malloc(sizeof(unsigned char) * mem_w/8);
        mem_meta_queue[queue_pos] = (bool *)malloc(sizeof(bool) * 3); //2 metadata values (err, request source, iswrite)
    }
    //Ports for vector memory accesses
    bool **vec_mem_rvalid_queue = (bool **)malloc(sizeof(bool *) * mem_ports);
    unsigned char ***vec_mem_rdata_queue  = (unsigned char ***)malloc(sizeof(unsigned char **) * mem_ports); //memory data port
    bool ***vec_mem_meta_queue   = (bool ***)malloc(sizeof(bool **) * mem_ports); //memory metadata port
    bool **vec_mem_wvalid_queue = (bool **)malloc(sizeof(bool *) * mem_ports);

    for(int i = 0; i < mem_ports; i++){
        vec_mem_rvalid_queue[i] = (bool *)malloc(sizeof(bool) * mem_latency);
        vec_mem_rdata_queue[i]  = (unsigned char **)malloc(sizeof(unsigned char *) * mem_latency); //memory data port
        vec_mem_meta_queue[i]   = (bool **)malloc(sizeof(bool *) * mem_latency); //memory metadata port
        vec_mem_wvalid_queue[i] = (bool *)malloc(sizeof(bool) * mem_latency);
        for(int queue_pos = 0; queue_pos < mem_latency; queue_pos++)
        {
            vec_mem_rdata_queue[i][queue_pos] = (unsigned char *)malloc(sizeof(unsigned char) * mem_w/8);
            vec_mem_meta_queue[i][queue_pos] = (bool *)malloc(sizeof(bool) * 3); //2 metadata values (err, request source, iswrite)
        }
    }

    bool *mem_ivalid_queue = (bool *)malloc(sizeof(bool) * mem_latency);
    unsigned char **mem_idata_queue    = (unsigned char **)malloc(sizeof(unsigned char *) * mem_latency); //memory instruction port
    bool **mem_imeta_queue    = (bool **)malloc(sizeof(bool *) * mem_latency); //memory metadata port
    //even though known instruction interface width of 32 bits, malloc like this for compatability with memory management helper functions
    //same with metadata queue, known request source
    for(int queue_pos = 0; queue_pos < mem_latency; queue_pos++)
    {
        mem_idata_queue[queue_pos] = (unsigned char *)malloc(sizeof(unsigned char) * 32/8);
        mem_imeta_queue[queue_pos] = (bool *)malloc(sizeof(bool) * 2);
    }

    Vvproc_top *top = new Vvproc_top;

    //////////////////////////
    //Setup vcd trace file
    //////////////////////////
    VerilatedTrace_t *tfp = NULL;
    if (argc >= 12){
        if((strcmp(argv[10], "--trace")) == 0) {
            tfp = new VerilatedTrace_t;
            top->trace(tfp, 99);  // Trace 99 levels of hierarchy
            tfp->open(argv[11]);
        }
    }
    if (argc >= 14){
        if((strcmp(argv[12], "--trace")) == 0) {
            tfp = new VerilatedTrace_t;
            top->trace(tfp, 99);  // Trace 99 levels of hierarchy
            tfp->open(argv[13]);
        }
    }

    //////////////////////////
    //Init regfile logs
    //////////////////////////
    FILE *fxreglog = NULL;
    /*Log File for Scalar Registers*/
    if (argc >= 12){
        if((strcmp(argv[10], "--commit") == 0)) {
            std::string filename=(std::string(argv[11])+std::string(argv[7])+std::string("_xreg_commits_verilator.txt"));
            fxreglog = fopen(filename.c_str(), "w");
        }
    } 
    if (argc >= 14){
        if((strcmp(argv[12], "--commit") == 0)) {
            std::string filename=(std::string(argv[13])+std::string(argv[7])+std::string("_xreg_commits_verilator.txt"));
            fxreglog = fopen(filename.c_str(), "w");
        }
    }

    // /*Log File for Vector Registers.  Separate log because actual writes to VREGs might be out of order relative to the Xregs.  Should NOT be out of order relative to themselves.*/
    // filename=(std::string(argv[6])+std::string("_vreg_commits_verilator.txt"));
    // FILE *fvreglog = fopen(filename.c_str(), "w");

    // /*Log File for Scalar Floating Point Registers*/
    // filename=(std::string(argv[6])+std::string("_freg_commits_verilator.txt"));
    // FILE *ffreglog = fopen(filename.c_str(), "w");


    //////////////////////////
    //Read file containing program paths : TODO - Currently required for support of legacy tests (to get memory dump regions for verification).  Vector tests don't dump any memory to a file
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
    ref_path  = (char *)realloc(ref_path,  line_sz);
    dump_path = (char *)realloc(dump_path, line_sz);
    strcpy(ref_path,  "/dev/null");
    strcpy(dump_path, "/dev/null");

    int ref_start  = 0,
        ref_end    = 0,
        dump_start = 0,
        dump_end   = 0,
        items;
    items = sscanf(line, "%s %s %x %x %s %x %x", prog_path, ref_path, &ref_start, &ref_end, dump_path, &dump_start, &dump_end);
    if (items == 0 || items == EOF) {
        return -1;
    }

    unsigned char *mem = load_program(mem_sz, prog_path);

    
    //////////////////////////
    // Write Reference File (Legacy tests only)
    //////////////////////////

    dump_mem_region(ref_start, ref_end, mem, ref_path);

    //////////////////////////
    //Begin Program execution
    //////////////////////////
    for(int i = 0; i < mem_ports; i++){
        for (int j = 0; j < mem_latency; j++) {
            vec_mem_rvalid_queue[i][j] = 0;
        }
    }
    for (int i = 0; i < mem_latency; i++) {
        mem_rvalid_queue[i] = 0;
    }
    top->mem_rvalid_i = 0;
    top->mem_irvalid_i = 0;
    for(int i = 0; i < mem_ports; i++){
        top->vec_mem_rvalid_i[i] = 0;
    }

    top->xif_issue_accept_i = 0; //fix this port to 0, only needed for gem5
    top->xif_result_valid_i = 0;
    top->xif_result_id_i = 0;

    top->clk_i        = 0;
    top->rst_ni       = 0;
    for (int i = 0; i < 10; i++) {
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
    top->mem_ignt_i = 1;
    top->mem_gnt_i = 1;
    for(int i = 0; i < mem_ports; i++){
        top->vec_mem_rvalid_i[i] = 1;
    }
    char *endptr;
    int vreg_w = strtol(argv[7], &endptr, 10);
    
    int  cycles_begin_trace = 0;  //Traces begin at this cycle count.  TODO: expose to the command line
    int  cycles_end_trace =   0;    //Traces end at this cycle count.  TODO: expose to the command line

    // variables to keep track of vector tests successes/failures
    int v_test_success = 0;
    int v_test_failure = 0;
    
    bool dmem_req_limit = true;

    int num_outstanding_imem = 0;
    int num_outstanding_vmem = 0;
    int num_outstanding_dmem = 0;

    int num_read_req = 0;

    bool imem_busy = false;
    bool dmem_busy = false;
    bool* vmem_busy = (bool *)malloc(sizeof(bool) * mem_ports);
    for(int i = 0; i < mem_ports; i++){
        vmem_busy[i] = false;
    }

    //////////////////////////
    //Program Execution - Infinite loop with defined exit conditions
    //////////////////////////
    while (true) {

        //////////////////////////
        // Advance to next clock cycle
        //////////////////////////
        //advance_cycle_half(top, 0);

        top->eval();
        top->clk_i = 1;

        top->eval();
        //update_stats(top);
        //update_vcd(tfp, cycles_begin_trace, cycles_end_trace);

        //////////////////////////
        //Update Memory interfaces
        //////////////////////////


        // Update data memory interface signals
        for (int i = 0; i < mem_w/8; i++)
        {
            unsigned char* port = (unsigned char*)&(top->mem_rdata_i);
            port[i]  = mem_rdata_queue[mem_latency-1][i];
        }

        if (!mem_meta_queue[mem_latency-1][2]){
            top->mem_rvalid_i = mem_rvalid_queue[mem_latency-1];
            top->mem_wvalid_i = false;
        } else {
            top->mem_rvalid_i = false;
            top->mem_wvalid_i = mem_rvalid_queue[mem_latency-1];
        }
        top->mem_err_i   = mem_meta_queue[mem_latency-1][0];
        top->mem_src_i   = mem_meta_queue[mem_latency-1][1];

        // Update Vector memory interface signals
        for(int p = 0; p < mem_ports; p++){
            for (int i = 0; i < mem_w/8; i++) {
                unsigned char* port = (unsigned char*)&(top->vec_mem_rdata_i[p]);
                port[i]  = vec_mem_rdata_queue[p][mem_latency-1][i];
            }
            top->vec_mem_err_i[p]   = vec_mem_meta_queue[p][mem_latency-1][0];
            //top->vec_mem_src_i[p]   = vec_mem_meta_queue[p][mem_latency-1][1]; //eliminated
            top->vec_mem_rvalid_i[p] = vec_mem_rvalid_queue[p][mem_latency-1]; //Vector signalling over rvalid signal always
        }

        //////////
        //Next, advance fifo buffers by one cycle
        /////////
        
        for (int i = mem_latency-1; i > 0; i--) {
            for (int j = 0; j < mem_w/8; j++)
            {
                mem_rdata_queue[i][j] = mem_rdata_queue[i-1][j];
                vec_mem_rdata_queue[i][j] = vec_mem_rdata_queue[i-1][j];
            }
            mem_rvalid_queue[i] = mem_rvalid_queue[i-1];
            vec_mem_rvalid_queue[i] = vec_mem_rvalid_queue[i-1];
            for (int j = 0; j < 3; j++)
            {
                mem_meta_queue[i][j]   = mem_meta_queue[i-1][j];
                vec_mem_meta_queue[i][j]   = vec_mem_meta_queue[i-1][j];
            }
        }

        mem_rvalid_queue[0] = false;
        mem_meta_queue[0][0]   = false;
        mem_meta_queue[0][1]   = false;
        mem_meta_queue[0][2]   = false;
        for(int p = 0; p < mem_ports; p++){
            vec_mem_rvalid_queue[p][0]    = false;
            vec_mem_meta_queue[p][0][0]   = false;
            vec_mem_meta_queue[p][0][1]   = false;
            vec_mem_meta_queue[p][0][2]   = false;
        }

        // top->mem_gnt_i = !dmem_busy & top->mem_req_o;
        // top->mem_ignt_i = !imem_busy & top->mem_ireq_o;
        top->mem_gnt_i = !dmem_busy & top->mem_req_o;
        top->mem_ignt_i = !imem_busy & top->mem_ireq_o;

        for(int p = 0; p < mem_ports; p++){
            bool* port = (bool*)&(top->vec_mem_gnt_i);
            port[p] = !vmem_busy[p] & top->vec_mem_req_o[p];
        }

        update_mem_write(top, (top->mem_addr_o & 0xFFFFFFFC), (top->mem_req_o && top->mem_we_o && top->mem_gnt_i), (top->mem_src_o), mem_w, mem_latency, mem_sz, (unsigned char*)&(top->mem_wdata_o), (unsigned char*)&(top->mem_be_o), (bool*)&(top->mem_wvalid_i), mem_rvalid_queue, mem_meta_queue, mem);
        update_mem_load(top,  (top->mem_addr_o & 0xFFFFFFFC), (top->mem_req_o && !top->mem_we_o && top->mem_gnt_i), top->mem_we_o, (top->mem_src_o), mem_w, mem_latency, mem_sz, (unsigned char*)&(top->mem_rdata_i), (bool*)&(top->mem_rvalid_i), (bool*)&(top->mem_err_i), (bool*)&(top->mem_src_i), mem_rdata_queue, mem_rvalid_queue, mem_meta_queue, mem);
        for(int p = 0; p < mem_ports; p++){
            update_mem_write(top, (top->vec_mem_addr_o[p]), (top->vec_mem_req_o[p] && top->vec_mem_we_o[p] && top->vec_mem_gnt_i[p]), (top->vec_mem_src_o), mem_w, mem_latency, mem_sz, (unsigned char*)&(top->vec_mem_wdata_o[p]), (unsigned char*)&(top->vec_mem_be_o[p]), (bool*)&(top->vec_mem_wvalid_i[p]), vec_mem_rvalid_queue[p], vec_mem_meta_queue[p], mem);
            update_mem_load(top,  (top->vec_mem_addr_o[p]), (top->vec_mem_req_o[p] && !top->vec_mem_we_o[p] && top->vec_mem_gnt_i[p]), top->vec_mem_we_o[p], (top->vec_mem_src_o), mem_w, mem_latency, mem_sz, (unsigned char*)&(top->vec_mem_rdata_i[p]), (bool*)&(top->vec_mem_rvalid_i[p]), (bool*)&(top->vec_mem_err_i[p]), (bool*)&(top->vec_mem_src_i), vec_mem_rdata_queue[p], vec_mem_rvalid_queue[p], vec_mem_meta_queue[p], mem);
        }

        //Update instruction memory interface.  Never a write here.  Metadata field repurposed to store obi.id field, used internally for the index in the fetchbuffer.

        for (int i = 0; i < 32/8; i++)
        {
            unsigned char* port = (unsigned char*)&(top->mem_irdata_i);
            port[i]  = mem_idata_queue[mem_latency-1][i];
        }
        top->mem_irvalid_i = mem_ivalid_queue[mem_latency-1];
        top->mem_ierr_i   = mem_imeta_queue[mem_latency-1][0];
        top->mem_iid_i   = mem_imeta_queue[mem_latency-1][1];

        //Next, advance fifo buffers by one cycle
        for (int i = mem_latency-1; i > 0; i--) {
            for (int j = 0; j < 32/8; j++)
            {
                mem_idata_queue[i][j] = mem_idata_queue[i-1][j];
            }
            mem_ivalid_queue[i] = mem_ivalid_queue[i-1];
            for (int j = 0; j < 3; j++)
            {
                mem_imeta_queue[i][j]   = mem_imeta_queue[i-1][j];
            }
        }
        mem_ivalid_queue[0] = false;
        mem_imeta_queue[0][0]   = false; //never an error
        mem_imeta_queue[0][1]   = false;
        mem_imeta_queue[0][2]   = false;

        update_mem_load(top, (top->mem_iaddr_o), (top->mem_ireq_o && top->mem_ignt_i), false, (top->mem_iid_o), 32, mem_latency, mem_sz, (unsigned char*)&(top->mem_irdata_i), (bool*)&(top->mem_irvalid_i), (bool*)&(top->mem_ierr_i), (bool*)&(top->mem_iid_i), mem_idata_queue, mem_ivalid_queue, mem_imeta_queue, mem);
        top->eval();


        //Currently only two outstanding DMEM requests allowed
        if (top->mem_req_o && top->mem_gnt_i)
        {
            num_outstanding_dmem++;
                if (num_outstanding_dmem == 2)
                {
                    dmem_busy = true;
                }
        }
        if (top->mem_rvalid_i || top->mem_wvalid_i) {
            dmem_busy = false;
            num_outstanding_dmem--;

        }
         //Currently only two outstanding VMEM requests allowed per port
        for(int p = 0; p < mem_ports; p++){
            if (top->vec_mem_req_o[p] && top->vec_mem_gnt_i[p])
            {
                num_outstanding_vmem++;
                if (num_outstanding_vmem == 2)
                {
                    vmem_busy[p] = true;
                }
            }
            if (top->vec_mem_rvalid_i[p]) {
                vmem_busy[p] = false;
                num_outstanding_vmem--;
            }
        }
        //Currently only 2 outstanding IMEM requests allowed
        if (top->mem_ireq_o && top->mem_ignt_i)
        {
            num_outstanding_imem++;
            if (num_outstanding_imem == 2)
            {
                imem_busy = true; //only two outstanding request allowed
            }
        }
        if (top->mem_irvalid_i)
        {
            num_outstanding_imem--;
            imem_busy = false; 
        }

        top->eval();

        //Use memory mapped IO at address 0x408 to signal success or failure
        char w_port;
        if (check_memmapio(top->mem_addr_o, (top->mem_req_o && top->mem_we_o), 8, (unsigned char*)&(top->mem_wdata_o), 0x00000408u, &w_port)){
            if (w_port == 0)
            {
                fprintf(stderr, "SUCCESS: TEST PASS\n");
                exit_code = 0; //For benchmarks, only 1 test
                break;

            } else {
                fprintf(stderr, "ERROR: TEST FAILURE - FAILED OUTPUT VALIDATION - Exit Code: %u\n", (unsigned char)w_port);
                exit_code = 1;
                break; //For benchmarks, only 1 test
            }
        } 
        //Use memory mapped UART at address 0x400 to print outputs
        if (check_memmapio(top->mem_addr_o, (top->mem_req_o && top->mem_we_o), 8, (unsigned char*)&(top->mem_wdata_o), 0x00000400u, &w_port)){
            putc(w_port, stderr);
        }

        top->clk_i = 0;
        top->eval();
        update_stats(top);
        update_vcd(tfp, cycles_begin_trace, cycles_end_trace);

        //////////////////////////
        // Check/Write Register Commits
        //////////////////////////

        if (fxreglog != NULL && top->vproc_top->i_cva6_pipeline->we_gpr_commit_id)
        {
            fprintf(fxreglog, "x%d 0x%08x\n", top->vproc_top->i_cva6_pipeline->waddr_commit_id, top->vproc_top->i_cva6_pipeline->wdata_commit_id);
        }

        //////////////////////////
        // Check Exit Conditions
        //////////////////////////

        //A jump to address 0x70 is a failed test caused by an interrupt being called (all other interrupts also funnel here)
        if (check_PC(top, 0x000000070u) ) {
            fprintf(stderr, "ERROR: TEST FAILURE - Interrupt Called\n");
            exit_code = 1;
            break;
        }

        // 1000 cycles at the same address is a stall
        if (check_stall(top, 1000)){
            exit_code = 1;
            break;
        }

    }


    if (tfp != NULL)
    {
        tfp->close();
    }

    if (fxreglog != NULL)
    {
        fclose(fxreglog);
    }
    top->final();

    free(prog_path);
    free(ref_path);
    free(dump_path);
    free(line);
    free(mem);
    free(mem_rvalid_queue);
    free(vec_mem_rvalid_queue);

    for(int queue_pos = 0; queue_pos < mem_latency; queue_pos++)
    {
        free(mem_rdata_queue[queue_pos]);
        free(mem_idata_queue[queue_pos]);
        free(mem_meta_queue[queue_pos]);
        free(mem_imeta_queue[queue_pos]);

        
    }

    for(int p = 0; p < mem_ports; p++){
        for(int queue_pos = 0; queue_pos < mem_latency; queue_pos++){
            free(vec_mem_rdata_queue[p][queue_pos]);
            free(vec_mem_meta_queue[p][queue_pos]);
        }
        free(vec_mem_rdata_queue[p]);
        free(vec_mem_meta_queue[p]);
    }

    free(mem_rdata_queue);
    free(mem_idata_queue);
    free(mem_meta_queue);
    free(mem_imeta_queue);
    free(vec_mem_rdata_queue);
    free(vec_mem_meta_queue);
    free(vmem_busy);

    return exit_code;
}
