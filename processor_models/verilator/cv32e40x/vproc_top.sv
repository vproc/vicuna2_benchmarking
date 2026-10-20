// Copyright TU Wien
// Licensed under the Solderpad Hardware License v2.1, see LICENSE.txt for details
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1


module vproc_top import vproc_pkg::*, obi_pkg::*; #(
        parameter int unsigned     ADDR_W        = 32,  // memory bus width in bits
        parameter int unsigned     MEM_W         = 32,  // memory bus width in bits
        parameter int unsigned     VMEM_W        = 32,  // vector memory interface width in bits
        parameter int unsigned     OBI_ID_WIDTH  = 8,   // vector memory interface width in bits
        parameter int unsigned     MEM_PORTS     = 1,
        parameter int unsigned     PORT_QUEUE_DEPTH = 2,
        parameter vreg_type        VREG_TYPE     = VREG_GENERIC,
        parameter mul_type         MUL_TYPE      = MUL_GENERIC
    )(
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,

    //////////////////////////////////////////
    //Main Core I DATA
    //////////////////////////////////////////
    output logic               mem_ireq_o,
    input  logic               mem_ignt_i,
    output logic [31:0]        mem_iaddr_o,
    output logic               mem_iid_o,
    input  logic               mem_irvalid_i,
    input  logic               mem_ierr_i,
    input  logic [32  -1:0]    mem_irdata_i,
    input  logic               mem_iid_i,

    //////////////////////////////////////////
    //Main Core D DATA
    //////////////////////////////////////////
    output logic               mem_req_o,
    output logic [31:0]        mem_addr_o,
    output logic               mem_we_o,
    output logic               mem_src_o,
    output logic [MEM_W/8-1:0] mem_be_o,
    output logic [MEM_W  -1:0] mem_wdata_o,
    input  logic               mem_rvalid_i,
    input  logic               mem_wvalid_i,
    input  logic               mem_err_i,
    input  logic               mem_src_i,
    input  logic [MEM_W  -1:0] mem_rdata_i,
    input  logic               mem_gnt_i,
    output logic               mem_id_o,
    input  logic               mem_id_i,

    //////////////////////////////////////////
    //Vector Core Data
    //////////////////////////////////////////
    output logic               vec_mem_req_o [MEM_PORTS-1:0],
    output logic [31:0]        vec_mem_addr_o [MEM_PORTS-1:0],
    output logic               vec_mem_we_o [MEM_PORTS-1:0],
    output logic [MEM_W/8-1:0] vec_mem_be_o [MEM_PORTS-1:0],
    output logic [MEM_W  -1:0] vec_mem_wdata_o [MEM_PORTS-1:0],
    input  logic               vec_mem_rvalid_i [MEM_PORTS-1:0],
    input  logic               vec_mem_err_i [MEM_PORTS-1:0],
    input  logic [MEM_W  -1:0] vec_mem_rdata_i [MEM_PORTS-1:0],
    input  logic               vec_mem_gnt_i [MEM_PORTS-1:0],
    output logic               vec_mem_id_o [MEM_PORTS-1:0],
    input  logic               vec_mem_id_i [MEM_PORTS-1:0],

    input logic                vec_mem_wvalid_i[MEM_PORTS-1:0], //UNUSED

    output logic               data_read_o,

    output logic [31:0]        pend_vreg_wr_map_o,

    output logic flush_o,
    output logic                            [           32-1:0] fetch_addr_o,
    output logic log_reg_w_o,
    output logic [           4:0] log_reg_w_addr_o,
    output logic [31:0] log_reg_w_data_o
              
    );
    if ((MEM_W & (MEM_W - 1)) != 0 || MEM_W < 32) begin
        $fatal(1, "The memory bus width MEM_W must be at least 32 and a power of two.  ",
                  "The current value of %d is invalid.", MEM_W);
    end

    ///////////////////////////////////////////////////////////////////////////
    // MAIN CORE INTEGRATION

    // Vector Unit Interface
    localparam X_NUM_RS = 3;
    localparam X_ID_WIDTH = 4;
    localparam X_RFR_WIDTH = 32;
    localparam X_RFW_WIDTH = 32;
    localparam X_MISA = 0;
    vproc_xif #(
        .X_NUM_RS    ( X_NUM_RS    ),
        .X_ID_WIDTH  ( X_ID_WIDTH  ),
        .X_MEM_WIDTH ( VMEM_W      ),
        .X_RFR_WIDTH ( X_RFR_WIDTH ),
        .X_RFW_WIDTH ( X_RFW_WIDTH ),
        .X_MISA      ( X_MISA      )
    ) vcore_xif ();

    localparam OBI_CFG = obi_default_cfg(ADDR_W, VMEM_W, OBI_ID_WIDTH, ObiMinimalOptionalConfig);
    OBI_BUS #(
        .OBI_CFG     ( OBI_CFG   )
    ) vcore_obi_bus [MEM_PORTS-1:0] ();

    
    `ifdef XIF_ON
    localparam bit X_EXT = 1'b1;
    `else
    localparam bit X_EXT = 1'b0;
    `endif

    localparam bit [VLSU_FLAGS_W-1:0] VLSU_FLAGS = (VLSU_FLAGS_W'(1) << VLSU_ALIGNED_UNITSTRIDE);

    localparam bit [BUF_FLAGS_W -1:0] BUF_FLAGS  = (BUF_FLAGS_W'(1) << BUF_DEQUEUE  ) |
                                                  (BUF_FLAGS_W'(1) << BUF_VREG_PEND);

    // eXtension Interface
    if_xif #(
        .X_NUM_RS    ( 3  ),
        .X_MEM_WIDTH ( 32 ),
        .X_RFR_WIDTH ( 32 ),
        .X_RFW_WIDTH ( 32 ),
        .X_MISA      ( 32'b00000000000000000000000000100000 )
    ) host_xif();

    cv32e40x_core #(
        .X_EXT               ( X_EXT         ),
        .X_NUM_RS            ( 3             )
    ) core (
        .clk_i               ( clk_i         ),
        .rst_ni              ( rst_ni        ),
        .scan_cg_en_i        ( 1'b0          ),
        .boot_addr_i         ( 32'h80000080  ),
        .dm_exception_addr_i ( '0            ),
        .dm_halt_addr_i      ( '0            ),
        .mhartid_i           ( '0            ),
        .mimpid_patch_i      ( '0            ),
        .mtvec_addr_i        ( 32'h00000000  ),
        .instr_req_o         ( mem_ireq_o    ),
        .instr_gnt_i         ( mem_ignt_i    ),
        .instr_rvalid_i      ( mem_irvalid_i ),
        .instr_addr_o        ( mem_iaddr_o   ),
        .instr_memtype_o     (               ),
        .instr_prot_o        (               ),
        .instr_dbg_o         (               ),
        .instr_rdata_i       ( mem_irdata_i  ),
        .instr_err_i         ( mem_ierr_i    ),
        .data_req_o          ( mem_req_o     ),
        .data_gnt_i          ( mem_gnt_i     ),     //TODO: Might need to block here for pending vector memory ops
        .data_rvalid_i       ( mem_rvalid_i | mem_wvalid_i ),
        .data_addr_o         ( mem_addr_o    ),
        .data_be_o           ( mem_be_o      ),
        .data_we_o           ( mem_we_o      ),
        .data_wdata_o        ( mem_wdata_o   ),
        .data_memtype_o      (               ),
        .data_prot_o         (               ),
        .data_dbg_o          (               ),
        .data_atop_o         (               ),
        .data_rdata_i        ( mem_rdata_i   ),
        .data_err_i          ( mem_err_i     ),
        .data_exokay_i       ( 1'b0          ),
        .mcycle_o            (               ),
        //Necessary XIF Ports
        .xif_issue_if        ( host_xif      ),
        .xif_commit_if       ( host_xif      ),
        .xif_result_if       ( host_xif      ),
        //Additional XIF Ports
        .xif_compressed_if   ( host_xif      ),
        .xif_mem_if          ( host_xif      ),
        .xif_mem_result_if   ( host_xif      ),

        .irq_i               ( '0            ),
        .clic_irq_i          ( '0            ),
        .clic_irq_id_i       ( '0            ),
        .clic_irq_level_i    ( '0            ),
        .clic_irq_priv_i     ( '0            ),
        .clic_irq_shv_i      ( '0            ),
        .fencei_flush_req_o  (               ),
        .fencei_flush_ack_i  ( 1'b0          ),
        .debug_req_i         ( 1'b0          ),
        .debug_havereset_o   (               ),
        .debug_running_o     (               ),
        .debug_halted_o      (               ),
        .fetch_enable_i      ( 1'b1          ),
        .core_sleep_o        (               )
    );

    ///////////////////////////////////////////////////////////////////////////
    // VECTOR CORE INTEGRATION

    vproc_core #(
        .XIF_ID_W           ( X_ID_WIDTH         ),
        .XIF_MEM_W          ( VMEM_W             ),
        .VREG_TYPE          ( VREG_TYPE          ),
        .MUL_TYPE           ( MUL_TYPE           ),
        .VLSU_FLAGS         ( VLSU_FLAGS         ),
        .BUF_FLAGS          ( BUF_FLAGS          ),
        .OBI_CFG            ( OBI_CFG            ),
        .PORT_QUEUE_DEPTH   ( PORT_QUEUE_DEPTH   ),
        .MEM_PORTS          ( MEM_PORTS          ),
        .DONT_CARE_ZERO     ( 1'b0               ),
        .ASYNC_RESET        ( 1'b0               )
    ) v_core (
        .clk_i              ( clk_i              ),
        .rst_ni             ( rst_ni             ),

        .xif_issue_if       ( vcore_xif          ),
        .xif_commit_if      ( vcore_xif          ),
        .xif_result_if      ( vcore_xif          ),
        .obi_bus            ( vcore_obi_bus      ),

        .pending_load_o     ( vect_pending_load  ),
        .pending_store_o    ( vect_pending_store ),

        .csr_vtype_o        ( csr_vtype          ),
        .csr_vl_o           ( csr_vl             ),
        .csr_vlenb_o        ( csr_vlenb          ),
        .csr_vstart_o       ( csr_vstart_rd      ),
        .csr_vstart_i       ( csr_vstart_wr      ),
        .csr_vstart_set_i   ( csr_vstart_wren    ),
        .csr_vxrm_o         ( csr_vxrm_rd        ),
        .csr_vxrm_i         ( csr_vxrm_wr        ),
        .csr_vxrm_set_i     ( csr_vxrm_wren      ),
        .csr_vxsat_o        ( csr_vxsat_rd       ),
        .csr_vxsat_i        ( csr_vxsat_wr       ),
        .csr_vxsat_set_i    ( csr_vxsat_wren     ),
        // `ifdef RISCV_ZVE32F
        // TODO: Reconnect FPU_SS
        // .fpr_wr_req_valid   ( fpr_wr_req_valid   ),
        // .fpr_wr_req_addr_o  ( fpr_wr_req_addr    ),
        // .fpr_res_valid      ( fpr_wr_resp_valid  ),
        // .float_round_mode_i ( float_round_mode   ),

        // .fpu_res_acc (fpu_ss_res_accepted),
        // .fpu_res_id (fpu_res_id),

        // `endif

        .pend_vreg_wr_map_o ( pend_vreg_wr_map_o )
    );

    /////
    //CONNECTING VPROC_XIF to HOST_XIF.
    /////

    assign vcore_xif.issue_valid         = host_xif.issue_valid;
    assign host_xif.issue_ready          = vcore_xif.issue_ready;
    assign vcore_xif.issue_req.instr     = host_xif.issue_req.instr;
    assign vcore_xif.issue_req.mode      = host_xif.issue_req.mode; 
    assign vcore_xif.issue_req.id        = host_xif.issue_req.id;
    assign vcore_xif.issue_req.rs        = host_xif.issue_req.rs;
    assign vcore_xif.issue_req.rs_valid  = host_xif.issue_req.rs_valid;
    assign host_xif.issue_resp.accept    = vcore_xif.issue_resp.accept;
    assign host_xif.issue_resp.writeback = vcore_xif.issue_resp.writeback;
    assign host_xif.issue_resp.dualwrite = vcore_xif.issue_resp.dualwrite;
    assign host_xif.issue_resp.dualread  = vcore_xif.issue_resp.dualread;
    assign host_xif.issue_resp.loadstore = vcore_xif.issue_resp.loadstore;
    assign host_xif.issue_resp.exc       = vcore_xif.issue_resp.exc;

    assign vcore_xif.commit_valid       = host_xif.commit_valid;
    assign vcore_xif.commit.id          = host_xif.commit.id;
    assign vcore_xif.commit.commit_kill = host_xif.commit.commit_kill;

    assign host_xif.result_valid   = vcore_xif.result_valid;
    assign vcore_xif.result_ready  = host_xif.result_ready;
    assign host_xif.result.id      = vcore_xif.result.id;
    assign host_xif.result.data    = vcore_xif.result.data;
    assign host_xif.result.rd      = vcore_xif.result.rd;
    assign host_xif.result.we      = vcore_xif.result.we;
    assign host_xif.result.exc     = vcore_xif.result.exc;
    assign host_xif.result.exccode = vcore_xif.result.exccode;
    assign host_xif.result.err     = vcore_xif.result.err;
    assign host_xif.result.dbg     = vcore_xif.result.dbg;

    ///////////
    //Connect Vector OBI bus to vproc_top ports
    // TODO: Currently only support for a single port
    ///////////

    //OBI Request
    assign vec_mem_req_o[0]     = vcore_obi_bus[0].req;
    assign vec_mem_addr_o[0]    = vcore_obi_bus[0].addr;
    assign vec_mem_we_o [0]     = vcore_obi_bus[0].we;
    assign vec_mem_be_o [0]     = vcore_obi_bus[0].be;
    assign vec_mem_wdata_o [0]  = vcore_obi_bus[0].wdata;
    assign vec_mem_id_o [0]     = vcore_obi_bus[0].aid;
    assign vcore_obi_bus[0].gnt = vec_mem_gnt_i[0];

    //OBI Response
    assign vcore_obi_bus[0].rvalid = vec_mem_rvalid_i[0];
    assign vcore_obi_bus[0].err    = vec_mem_err_i[0];
    assign vcore_obi_bus[0].rdata  = vec_mem_rdata_i[0];
    assign vcore_obi_bus[0].rid    = vec_mem_id_i[0];


endmodule
