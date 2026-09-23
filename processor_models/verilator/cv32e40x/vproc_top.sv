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
        input  logic               clk_i,
        input  logic               rst_ni,

        output logic               mem_req_o    [MEM_PORTS-1:0],
        output logic [31:0]        mem_addr_o   [MEM_PORTS-1:0],
        output logic               mem_we_o     [MEM_PORTS-1:0],
        output logic [MEM_W/8-1:0] mem_be_o     [MEM_PORTS-1:0],
        output logic [MEM_W  -1:0] mem_wdata_o  [MEM_PORTS-1:0],
        output logic               mem_aid_o    [MEM_PORTS-1:0],
        input  logic               mem_rvalid_i [MEM_PORTS-1:0],
        input  logic               mem_err_i    [MEM_PORTS-1:0],
        input  logic [MEM_W  -1:0] mem_rdata_i  [MEM_PORTS-1:0],
        input  logic               mem_rid_i    [MEM_PORTS-1:0],

        output logic [31:0]        pend_vreg_wr_map_o,

        output logic               mem_ireq_o,
        output logic [31:0]        mem_iaddr_o,
        input  logic               mem_irvalid_i,
        input  logic               mem_ierr_i,
        input  logic [MEM_W-1:0]   mem_irdata_i
              
    );
    if ((MEM_W & (MEM_W - 1)) != 0 || MEM_W < 32) begin
        $fatal(1, "The memory bus width MEM_W must be at least 32 and a power of two.  ",
                  "The current value of %d is invalid.", MEM_W);
    end

    // Reset synchronizer (sync reset is used for Vicuna by default, async reset for the core)
    logic [3:0] rst_sync_qn;
    logic sync_rst_n;
    always_ff @(posedge clk_i) begin
        rst_sync_qn[0] <= rst_ni;
        for (int i = 1; i < 4; i++) begin
            rst_sync_qn[i] <= rst_sync_qn[i-1];
        end
    end
    assign sync_rst_n = rst_sync_qn[3];

    ///////////////////////////////////////////////////////////////////////////
    // MAIN CORE INTEGRATION

    // Instruction fetch interface
    logic        instr_req;
    logic [31:0] instr_addr;
    logic        instr_gnt;
    logic        instr_rvalid;
    logic        instr_err;
    logic [31:0] instr_rdata;

    // Data load & store interface
    logic        sdata_req;
    logic [31:0] sdata_addr;
    logic        sdata_we;
    logic  [3:0] sdata_be;
    logic [31:0] sdata_wdata;
    logic        sdata_gnt;
    logic        sdata_rvalid;
    logic        sdata_err;
    logic [31:0] sdata_rdata;

   

    ///////////////////////////Top level xif interface, some signals used for the memory units

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

    logic        vect_pending_load;
    logic        vect_pending_store;

    //signals for calculating the avg VL.  Defined here in case vcore is not instantiated
    logic        vcore_result_valid /* verilator public */;
    logic        vcore_result_ready /* verilator public */;
    assign vcore_result_valid = vcore_xif.result_valid;
    assign vcore_result_ready = vcore_xif.result_ready;
    logic [31:0] csr_vtype_o /* verilator public */;
    logic [31:0] csr_vl_o /* verilator public */;
    logic [31:0] csr_vlen_b_o /* verilator public */;

    // CSR register interface for Vector Unit
    localparam int unsigned VECT_CSR_CNT = 7;
    logic [11:0] vect_csr_addr [VECT_CSR_CNT];
    logic [31:0] vect_csr_rdata[VECT_CSR_CNT];
    logic        vect_csr_we   [VECT_CSR_CNT];
    logic [31:0] vect_csr_wdata[VECT_CSR_CNT];
    assign vect_csr_addr = '{
        12'h008, // vstart
        12'h009, // vxsat
        12'h00A, // vxrm
        12'h00F, // vcsr
        12'hC20, // vl
        12'hC21, // vtype
        12'hC22  // vlenb
    };


    //localparam bit USE_XIF_MEM = VMEM_W == 32;
    localparam bit USE_XIF_MEM = '0; // Force Vicuna to always use direct memory port and not XIF interface (brings system closer to updated XIF compliance)


    
    `ifdef XIF_ON
    localparam bit X_EXT = 1'b1;
    `else
    localparam bit X_EXT = 1'b0;
    `endif

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
        .instr_req_o         ( instr_req     ),
        .instr_gnt_i         ( instr_gnt     ),
        .instr_rvalid_i      ( instr_rvalid  ),
        .instr_addr_o        ( instr_addr    ),
        .instr_memtype_o     (               ),
        .instr_prot_o        (               ),
        .instr_dbg_o         (               ),
        .instr_rdata_i       ( instr_rdata   ),
        .instr_err_i         ( instr_err     ),
        .data_req_o          ( sdata_req     ),
        .data_gnt_i          ( sdata_gnt     ),
        .data_rvalid_i       ( sdata_rvalid  ),
        .data_addr_o         ( sdata_addr    ),
        .data_be_o           ( sdata_be      ),
        .data_we_o           ( sdata_we      ),
        .data_wdata_o        ( sdata_wdata   ),
        .data_memtype_o      (               ),
        .data_prot_o         (               ),
        .data_dbg_o          (               ),
        .data_atop_o         (               ),
        .data_rdata_i        ( sdata_rdata   ),
        .data_err_i          ( sdata_err     ),
        .data_exokay_i       ( 1'b0          ),
        .mcycle_o            (               ),
        .xif_compressed_if   ( host_xif      ),
        .xif_issue_if        ( host_xif      ),
        .xif_commit_if       ( host_xif      ),
        .xif_mem_if          ( host_xif      ),
        .xif_mem_result_if   ( host_xif      ),
        .xif_result_if       ( host_xif      ),
        //.xif_result_id       ( host_xif.result.id     ),
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

`ifndef RISCV_F
    //CONNECTING VPROC_XIF to HOST_XIF.
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

    if (USE_XIF_MEM) begin
        assign host_xif.mem_valid         = vcore_xif.mem_valid;
        assign vcore_xif.mem_ready        = host_xif.mem_ready;             
        assign host_xif.mem_req.id        = vcore_xif.mem_req.id;           
        assign host_xif.mem_req.addr      = vcore_xif.mem_req.addr;         
        assign host_xif.mem_req.mode      = vcore_xif.mem_req.mode;         
        assign host_xif.mem_req.we        = vcore_xif.mem_req.we;           
        assign host_xif.mem_req.size      = vcore_xif.mem_req.size;         
        assign host_xif.mem_req.be        = vcore_xif.mem_req.be;           
        assign host_xif.mem_req.attr      = vcore_xif.mem_req.attr;         
        assign host_xif.mem_req.wdata     = vcore_xif.mem_req.wdata;        
        assign host_xif.mem_req.last      = vcore_xif.mem_req.last;         
        assign host_xif.mem_req.spec      = vcore_xif.mem_req.spec;         
        assign vcore_xif.mem_resp.exc     = host_xif.mem_resp.exc;          
        assign vcore_xif.mem_resp.exccode = host_xif.mem_resp.exccode;      
        assign vcore_xif.mem_resp.dbg     = host_xif.mem_resp.dbg;          
        assign vcore_xif.mem_result_valid = host_xif.mem_result_valid;      
        assign vcore_xif.mem_result.id    = host_xif.mem_result.id;         
        assign vcore_xif.mem_result.rdata = host_xif.mem_result.rdata;      
        assign vcore_xif.mem_result.err   = host_xif.mem_result.err;        
        assign vcore_xif.mem_result.dbg   = host_xif.mem_result.dbg;        
    end
`endif

    assign vect_csr_we    = '{default:'0};
    assign vect_csr_wdata = '{default:'0};


    ///////////////////////////////////////////////////////////////////////////
    // VECTOR CORE INTEGRATION

    // Vector CSR read/write conversion
    logic [31:0] csr_vtype;
    assign csr_vtype_o = csr_vtype;
    logic [31:0] csr_vl;
    assign csr_vl_o = csr_vl;
    logic [31:0] csr_vlenb;
    assign csr_vlen_b_o = csr_vlenb;
    logic [31:0] csr_vstart_rd;
    logic [31:0] csr_vstart_wr;
    logic        csr_vstart_wren;
    logic        csr_vxsat_rd;
    logic        csr_vxsat_wr;
    logic        csr_vxsat_wren;
    logic [1:0]  csr_vxrm_rd;
    logic [1:0]  csr_vxrm_wr;
    logic        csr_vxrm_wren;
    assign vect_csr_rdata[0] = csr_vstart_rd;
    assign vect_csr_rdata[1] = {31'b0, csr_vxsat_rd};
    assign vect_csr_rdata[2] = {30'b0, csr_vxrm_rd};
    assign vect_csr_rdata[3] = {29'b0, csr_vxrm_rd, csr_vxsat_rd};
    assign vect_csr_rdata[4] = csr_vl;
    assign vect_csr_rdata[5] = csr_vtype;
    assign vect_csr_rdata[6] = csr_vlenb;
    assign csr_vstart_wr     = vect_csr_wdata[0];
    assign csr_vstart_wren   = vect_csr_we[0];
    assign csr_vxsat_wr      = vect_csr_we[1] ? vect_csr_wdata[1][0]   : vect_csr_wdata[3][0];
    assign csr_vxsat_wren    = vect_csr_we[1] | vect_csr_we[3];
    assign csr_vxrm_wr       = vect_csr_we[2] ? vect_csr_wdata[2][1:0] : vect_csr_wdata[3][2:1];
    assign csr_vxrm_wren     = vect_csr_we[2] | vect_csr_we[3];


    // Data read/write for Vector Unit
    logic                vdata_gnt      [MEM_PORTS-1:0];
    logic                vdata_rvalid   [MEM_PORTS-1:0];
    logic                vdata_err      [MEM_PORTS-1:0];
    logic [VMEM_W-1:0]   vdata_rdata    [MEM_PORTS-1:0];
    logic                vdata_req      [MEM_PORTS-1:0];
    logic [31:0]         vdata_addr     [MEM_PORTS-1:0];
    logic                vdata_we       [MEM_PORTS-1:0];
    logic [VMEM_W/8-1:0] vdata_be       [MEM_PORTS-1:0];
    logic [VMEM_W-1:0]   vdata_wdata    [MEM_PORTS-1:0];
    logic [OBI_ID_WIDTH-1:0] vdata_req_id [MEM_PORTS-1:0];
    logic [OBI_ID_WIDTH-1:0] vdata_res_id [MEM_PORTS-1:0];

    // Allow for vector loads/stores to be misaligned with respect to VMEM_W
    `ifdef FORCE_ALIGNED_READS // not needed anymore since scratch is aligning already
    localparam bit [VLSU_FLAGS_W-1:0] VLSU_FLAGS = (VLSU_FLAGS_W'(0) << VLSU_ALIGNED_UNITSTRIDE);
    `else
    localparam bit [VLSU_FLAGS_W-1:0] VLSU_FLAGS = (VLSU_FLAGS_W'(0) << VLSU_ALIGNED_UNITSTRIDE);
    `endif

    localparam bit [BUF_FLAGS_W -1:0] BUF_FLAGS  = (BUF_FLAGS_W'(1) << BUF_DEQUEUE  ) |
                                                   (BUF_FLAGS_W'(1) << BUF_VREG_PEND);
`ifdef RISCV_ZVE32X
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
        .rst_ni             ( sync_rst_n         ),

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
        `ifdef RISCV_ZVE32F
        .fpr_wr_req_valid   ( fpr_wr_req_valid   ),
        .fpr_wr_req_addr_o  ( fpr_wr_req_addr    ),
        .fpr_res_valid      ( fpr_wr_resp_valid  ),
        .float_round_mode_i ( float_round_mode   ),

        .fpu_res_acc (fpu_ss_res_accepted),
        .fpu_res_id (fpu_res_id),

        `endif

        .pend_vreg_wr_map_o ( pend_vreg_wr_map_o )
    );

    // TODO: wire id signal from/to aoptional/roptional field from lsu
    if (USE_XIF_MEM) begin 
        assign vcore_xif.mem_valid        = vcore_obi_bus[0].req;
        assign vcore_obi_bus[0].gnt       = vcore_xif.mem_ready;
        //assign vcore_xif.mem_req.id       = vcore_obi_bus[0].aid;
        assign vcore_xif.mem_req.addr     = vcore_obi_bus[0].addr;
        assign vcore_xif.mem_req.mode     = '0;
        assign vcore_xif.mem_req.we       = vcore_obi_bus[0].we;
        //assign vcore_xif.mem_req.size; //TODO: get size
        assign vcore_xif.mem_req.be       = vcore_obi_bus[0].be;
        assign vcore_xif.mem_req.attr     = '0;
        assign vcore_xif.mem_req.wdata    = vcore_obi_bus[0].wdata;
        //assign vcore_xif.mem_req.last; //TODO: get last
        assign vcore_xif.mem_req.spec     = '0;
        assign vcore_obi_bus[0].rvalid    = vcore_xif.mem_result_valid;
        //assign vcore_obi_bus[0].rid       = vcore_xif.mem_result.id;
        assign vcore_obi_bus[0].rdata     = vcore_xif.mem_result.rdata;
        assign vcore_obi_bus[0].err       = vcore_xif.mem_result.err;        
    end



`endif

`ifdef RISCV_F
    
    `ifdef RISCV_ZFH
    
        parameter C_XF16 = 1'b1;
        
        parameter fpnew_pkg::fpu_features_t FEATURES = '{
                                                Width:         fpu_ss_pkg::C_FLEN,
                                                EnableVectors: fpu_ss_pkg::C_XFVEC,
                                                EnableNanBox:  1'b0,
                                                FpFmtMask:     {
                                                    fpu_ss_pkg::C_RVF, fpu_ss_pkg::C_RVD, C_XF16, fpu_ss_pkg::C_XF8, fpu_ss_pkg::C_XF16ALT
                                                }, IntFmtMask: {
                                                    fpu_ss_pkg::C_XFVEC && fpu_ss_pkg::C_XF8, fpu_ss_pkg::C_XFVEC && (C_XF16 || fpu_ss_pkg::C_XF16ALT), 1'b1, 1'b0
                                                }};
        
        
    `else
    
        parameter C_XF16 = 1'b0;
        
        parameter fpnew_pkg::fpu_features_t FEATURES = fpu_ss_pkg::FPU_FEATURES;
    
    `endif

    `ifdef RISCV_ZVE32F
    // Interface for Vicuna Arbiter for access to the FP Regfile
    logic [31:0] fp_scoreboard;
    logic [ 4:0] fp_raddr;
    logic [31:0] fp_rdata; 

    logic fpr_wr_req_valid;
    logic [4:0] fpr_wr_req_addr;

    logic fpr_wr_resp_valid;

    fpnew_pkg::roundmode_e float_round_mode;

    `endif


     if_xif #(
        .X_NUM_RS    ( 3  ),
        .X_MEM_WIDTH ( 32 ),
        .X_RFR_WIDTH ( 32 ),
        .X_RFW_WIDTH ( 32 ),
        .X_MISA      ( 32'b00000000000000000000000000100000 )
    ) fpu_ss_xif();

    fpu_ss #(
    .PULP_ZFINX           ( 0 ),
    .INPUT_BUFFER_DEPTH   ( 1 ), //Needs to be set to 1 otherwise locks up.
    .OUT_OF_ORDER         ( 0 ),
    .FORWARDING           ( 0 ),
    .FPU_FEATURES         ( FEATURES ),
    .FPU_IMPLEMENTATION   ( fpu_ss_pkg::FPU_IMPLEMENTATION )
    ) fpu_ss_i (
        // clock and reset
        .clk_i                (clk_i),
        .rst_ni               (sync_rst_n),

        `ifdef RISCV_ZVE32F
        // Interface for Vicuna Arbiter for access to the FP Regfile
        .vicuna_rd_scoreboard_o(fp_scoreboard),
        .vicuna_raddr_i(fp_raddr),
        .vicuna_rdata_o(fp_rdata),

        .vicuna_fpr_wr_req_valid(fpr_wr_req_valid),
        .vicuna_fpr_wr_req_addr_i(fpr_wr_req_addr),

        .vicuna_fpr_res_valid(fpr_wr_resp_valid),
        .vicuna_fpr_res_addr_i(vcore_xif.result.rd),
        .vicuna_fpr_wb_data_i(vcore_xif.result.data),
        .float_round_mode_o ( float_round_mode ),  

        `endif

        // Compressed Interface (Not currently used)
        .x_compressed_valid_i (),
        .x_compressed_ready_o (),
        .x_compressed_req_i   (),
        .x_compressed_resp_o  (),

        // Issue Interface
        .x_issue_valid_i      ( fpu_ss_xif.issue_valid ),
        .x_issue_ready_o      ( fpu_ss_xif.issue_ready ),
        .x_issue_req_i        ( fpu_ss_xif.issue_req ),
        .x_issue_resp_o       ( fpu_ss_xif.issue_resp ),

        // Commit Interface
        .x_commit_valid_i     ( fpu_ss_xif.commit_valid ),
        .x_commit_i           ( fpu_ss_xif.commit ),

        // Memory Request/Response Interface
        .x_mem_valid_o        ( fpu_ss_xif.mem_valid ),
        .x_mem_ready_i        ( fpu_ss_xif.mem_ready ),
        .x_mem_req_o          ( fpu_ss_xif.mem_req ),
        .x_mem_resp_i         ( fpu_ss_xif.mem_resp ),

        // Memory Result Interface
        .x_mem_result_valid_i ( fpu_ss_xif.mem_result_valid ),
        .x_mem_result_i       ( fpu_ss_xif.mem_result ),



        // Result Interface
        .x_result_valid_o     ( fpu_ss_xif.result_valid ),
        .x_result_ready_i     ( fpu_ss_xif.result_ready ),
        .x_result_o           ( fpu_ss_xif.result )
    );


    //CONNECTING FPU_SS to HOST_XIF.
    `ifndef RISCV_ZVE32X

    assign fpu_ss_xif.issue_valid        = host_xif.issue_valid;            
    assign host_xif.issue_ready          = fpu_ss_xif.issue_ready;          
    assign fpu_ss_xif.issue_req.instr    = host_xif.issue_req.instr;        
    assign fpu_ss_xif.issue_req.mode     = host_xif.issue_req.mode;         
    assign fpu_ss_xif.issue_req.id       = host_xif.issue_req.id;           
    assign fpu_ss_xif.issue_req.rs       = host_xif.issue_req.rs;           
    assign fpu_ss_xif.issue_req.rs_valid = host_xif.issue_req.rs_valid;     
    assign host_xif.issue_resp.accept    = fpu_ss_xif.issue_resp.accept;        
    assign host_xif.issue_resp.writeback = fpu_ss_xif.issue_resp.writeback;     
    assign host_xif.issue_resp.dualwrite = fpu_ss_xif.issue_resp.dualwrite;     
    assign host_xif.issue_resp.dualread  = fpu_ss_xif.issue_resp.dualread;      
    assign host_xif.issue_resp.loadstore = fpu_ss_xif.issue_resp.loadstore;      
    assign host_xif.issue_resp.exc       = fpu_ss_xif.issue_resp.exc;       

    assign fpu_ss_xif.commit_valid       = host_xif.commit_valid;           
    assign fpu_ss_xif.commit.id          = host_xif.commit.id;              
    assign fpu_ss_xif.commit.commit_kill = host_xif.commit.commit_kill;     

    assign host_xif.result_valid   = fpu_ss_xif.result_valid;
    assign fpu_ss_xif.result_ready = host_xif.result_ready;                 
    assign host_xif.result.id      = fpu_ss_xif.result.id;                  
    assign host_xif.result.data    = fpu_ss_xif.result.data;                  
    assign host_xif.result.rd      = fpu_ss_xif.result.rd;                  
    assign host_xif.result.we      = fpu_ss_xif.result.we;                  
    assign host_xif.result.exc     = fpu_ss_xif.result.exc;                 
    assign host_xif.result.exccode = fpu_ss_xif.result.exccode;             
    assign host_xif.result.err     = fpu_ss_xif.result.err;                 
    assign host_xif.result.dbg     = fpu_ss_xif.result.dbg;                 

    
    assign host_xif.mem_valid          = fpu_ss_xif.mem_valid;
    assign fpu_ss_xif.mem_ready        = host_xif.mem_ready;             
    assign host_xif.mem_req.id         = fpu_ss_xif.mem_req.id;          
    assign host_xif.mem_req.addr       = fpu_ss_xif.mem_req.addr;        
    assign host_xif.mem_req.mode       = fpu_ss_xif.mem_req.mode;        
    assign host_xif.mem_req.we         = fpu_ss_xif.mem_req.we;          
    assign host_xif.mem_req.size       = fpu_ss_xif.mem_req.size;        
    assign host_xif.mem_req.be         = fpu_ss_xif.mem_req.be;          
    assign host_xif.mem_req.attr       = fpu_ss_xif.mem_req.attr;        
    assign host_xif.mem_req.wdata      = fpu_ss_xif.mem_req.wdata;       
    assign host_xif.mem_req.last       = fpu_ss_xif.mem_req.last;        
    assign host_xif.mem_req.spec       = fpu_ss_xif.mem_req.spec;        
    assign fpu_ss_xif.mem_resp.exc     = host_xif.mem_resp.exc;          
    assign fpu_ss_xif.mem_resp.exccode = host_xif.mem_resp.exccode;      
    assign fpu_ss_xif.mem_resp.dbg     = host_xif.mem_resp.dbg;          
    assign fpu_ss_xif.mem_result_valid = host_xif.mem_result_valid;      
    assign fpu_ss_xif.mem_result.id    = host_xif.mem_result.id;         
    assign fpu_ss_xif.mem_result.rdata = host_xif.mem_result.rdata;      
    assign fpu_ss_xif.mem_result.err   = host_xif.mem_result.err;        
    assign fpu_ss_xif.mem_result.dbg   = host_xif.mem_result.dbg;        
    
    `endif

`endif


//If both Vicuna and FPU_SS are used, connect with arbitration
//All signals from the host can be broadcast to all units on the interface
`ifdef RISCV_ZVE32X
    `ifdef RISCV_F

    assign fpu_ss_xif.issue_valid        = host_xif.issue_valid & host_xif.issue_ready;            //Valid signal only high when host signal is valid and both units are ready.
    assign vcore_xif.issue_valid         = host_xif.issue_valid & host_xif.issue_ready;            //Prevents vector unit from accepting offload when core is stalled by FPU
    assign host_xif.issue_ready          = fpu_ss_xif.issue_ready & vcore_xif.issue_ready ;               // Arbitrate: only ready when both units are ready to accept
    assign fpu_ss_xif.issue_req.instr    = host_xif.issue_req.instr;        //Broadcast from host
    assign vcore_xif.issue_req.instr    = host_xif.issue_req.instr;        //Broadcast from host
    assign fpu_ss_xif.issue_req.mode     = host_xif.issue_req.mode;         //Broadcast from host
    assign vcore_xif.issue_req.mode     = host_xif.issue_req.mode;         //Broadcast from host
    assign fpu_ss_xif.issue_req.id       = host_xif.issue_req.id;           //Broadcast from host
    assign vcore_xif.issue_req.id       = host_xif.issue_req.id;           //Broadcast from host

    
    assign fpu_ss_xif.issue_req.rs       = host_xif.issue_req.rs;           //Broadcast from host
    assign fpu_ss_xif.issue_req.rs_valid = host_xif.issue_req.rs_valid;     //Broadcast from host
    `ifdef RISCV_ZVE32F
    //when Zve32f is enabled, rs may be an int value from CV32E40X or a float value from FPU_SS
    always_comb begin
        //Offloaded instruction needs no scalar float value
        vcore_xif.issue_req.rs = host_xif.issue_req.rs;
        vcore_xif.issue_req.rs_valid = host_xif.issue_req.rs_valid;
        //Offloaded instruction is a vector instruction and involves a scalar floating point value as input
        //OPCODE Vector and OPFVF
        fp_raddr = '0;
        if (host_xif.issue_req.instr[6:0] == 7'h57 & host_xif.issue_req.instr[14:12] == 3'b101) begin
            fp_raddr = host_xif.issue_req.instr[19:15]; //fpr address is rs1 in this case
            vcore_xif.issue_req.rs = {'0, fp_rdata};//rs1 is replaced with the floating point value
            vcore_xif.issue_req.rs_valid = (host_xif.issue_req.rs_valid & (~fp_scoreboard[host_xif.issue_req.instr[19:15]])); //only valid if fp reg is valid on the scoreboard    
        end
    end

    `else
    assign vcore_xif.issue_req.rs       = host_xif.issue_req.rs;           //Broadcast from host
    assign vcore_xif.issue_req.rs_valid = host_xif.issue_req.rs_valid;     //Broadcast from host
    `endif

    assign host_xif.issue_resp.accept    = fpu_ss_xif.issue_resp.accept | vcore_xif.issue_resp.accept;         // Arbitrate: each unit outputs 0 if not responding.  correct output is OR of both  
    assign host_xif.issue_resp.writeback = fpu_ss_xif.issue_resp.writeback | vcore_xif.issue_resp.writeback;      
    assign host_xif.issue_resp.dualwrite = fpu_ss_xif.issue_resp.dualwrite | vcore_xif.issue_resp.dualwrite;      
    assign host_xif.issue_resp.dualread  = fpu_ss_xif.issue_resp.dualread | vcore_xif.issue_resp.dualread;       
    assign host_xif.issue_resp.loadstore = fpu_ss_xif.issue_resp.loadstore | vcore_xif.issue_resp.loadstore;      
    assign host_xif.issue_resp.exc       = fpu_ss_xif.issue_resp.exc | vcore_xif.issue_resp.exc;   

    //Commit Interface: cannot broadcast commit valid, only send to unit that accepted the request
    logic [15:0] coproc_issued_d;
    logic [15:0] coproc_issued_q;
    always_ff @(posedge clk_i) begin
        if(~rst_ni) begin
            coproc_issued_q <= '0;    
        end else begin
            coproc_issued_q <= coproc_issued_d;
        end
    end  
    always_comb begin
        coproc_issued_d = coproc_issued_q;
        //if vproc accepts, write 0.  if fpu_ss accepts, write 1
        if (vcore_xif.issue_resp.accept & host_xif.issue_valid) begin
            coproc_issued_d[host_xif.issue_req.id] = 1'b0; 
        end else if (fpu_ss_xif.issue_resp.accept & host_xif.issue_valid) begin
            coproc_issued_d[host_xif.issue_req.id] = 1'b1;
        end

        //Commit signal is only sent to the unit that accepted the request
        if (coproc_issued_q[host_xif.commit.id]) begin
            fpu_ss_xif.commit_valid = host_xif.commit_valid;            
            fpu_ss_xif.commit.id    = host_xif.commit.id;               
            fpu_ss_xif.commit.commit_kill = host_xif.commit.commit_kill; 
            vcore_xif.commit_valid = 1'b0;  
            vcore_xif.commit.id    = '0;   
            vcore_xif.commit.commit_kill = 1'b0;
        end else begin
            vcore_xif.commit_valid = host_xif.commit_valid;            
            vcore_xif.commit.id    = host_xif.commit.id;               
            vcore_xif.commit.commit_kill = host_xif.commit.commit_kill;  
            fpu_ss_xif.commit_valid = 1'b0;   
            fpu_ss_xif.commit.id    = '0;
            fpu_ss_xif.commit.commit_kill = 1'b0; 
        end

    end     

    assign host_xif.result_valid   = fpu_ss_xif.result_valid | vcore_xif.result_valid;                    // Arbitrate: Valid when either unit has valid data.  Core will be waiting for one result at a time
    assign fpu_ss_xif.result_ready = host_xif.result_ready;                 //Broadcast from host
    assign vcore_xif.result_ready = host_xif.result_ready;                 //Broadcast from host
    assign host_xif.result.id      = fpu_ss_xif.result.id | vcore_xif.result.id; 

    //vector unit needs to know when instructions offloaded to the fpu_ss are finished
    logic fpu_ss_res_accepted;
    logic [16-1:0] fpu_ss_id; //TODO Parametrize this with XIF_ID_W

    assign fpu_ss_res_accepted = fpu_ss_xif.result_valid & host_xif.result_ready;
    assign fpu_ss_id = fpu_ss_xif.result.id;
     
    
    //In the event that a vector instruction writes to the fp regfile, need to extract the reg address and data to send to the fpregfile
    //Also need to prevent writing to any registers in the main core.
    always_comb begin
        host_xif.result.data    = fpu_ss_xif.result.data | vcore_xif.result.data;                       
        host_xif.result.rd      = fpu_ss_xif.result.rd | vcore_xif.result.rd;                       
        host_xif.result.we      = fpu_ss_xif.result.we | vcore_xif.result.we;
        if (fpr_wr_resp_valid) begin
            host_xif.result.data    = '0;                       
            host_xif.result.rd      = '0;                   
            host_xif.result.we      = '0;
        end

    end                                                                                                 
    


    assign host_xif.result.exc     = fpu_ss_xif.result.exc | vcore_xif.result.exc;                      
    assign host_xif.result.exccode = fpu_ss_xif.result.exccode | vcore_xif.result.exccode;                  
    assign host_xif.result.err     = fpu_ss_xif.result.err | vcore_xif.result.err;                    
    assign host_xif.result.dbg     = fpu_ss_xif.result.dbg | fpu_ss_xif.result.dbg;   

    if (USE_XIF_MEM) begin
        assign host_xif.mem_valid          = fpu_ss_xif.mem_valid | vcore_xif.mem_valid;                // Arbitrate: 1 if issuing req, 0 otherwise. output is OR
        assign fpu_ss_xif.mem_ready        = host_xif.mem_ready;             //Broadcast from host
        assign vcore_xif.mem_ready        = host_xif.mem_ready;             //Broadcast from host
        always_comb begin
            if (fpu_ss_xif.mem_valid) begin
                host_xif.mem_req.id         = fpu_ss_xif.mem_req.id;               // Arbitrate : value only valid when mem_valid is high.  Correct output is (mem_valid & mem_req) | (mem_valid & mem_req)
                host_xif.mem_req.addr       = fpu_ss_xif.mem_req.addr;             
                host_xif.mem_req.mode       = fpu_ss_xif.mem_req.mode;             
                host_xif.mem_req.we         = fpu_ss_xif.mem_req.we;               
                host_xif.mem_req.size       = fpu_ss_xif.mem_req.size;             
                host_xif.mem_req.be         = fpu_ss_xif.mem_req.be;               
                host_xif.mem_req.attr       = fpu_ss_xif.mem_req.attr;             
                host_xif.mem_req.wdata      = fpu_ss_xif.mem_req.wdata;            
                host_xif.mem_req.last       = fpu_ss_xif.mem_req.last;             
                host_xif.mem_req.spec       = fpu_ss_xif.mem_req.spec;   
            end else begin
                host_xif.mem_req.id         = vcore_xif.mem_req.id;               // Arbitrate : value only valid when mem_valid is high.  Correct output is (mem_valid & mem_req) | (mem_valid & mem_req)
                host_xif.mem_req.addr       = vcore_xif.mem_req.addr;             
                host_xif.mem_req.mode       = vcore_xif.mem_req.mode;             
                host_xif.mem_req.we         = vcore_xif.mem_req.we;               
                host_xif.mem_req.size       = vcore_xif.mem_req.size;             
                host_xif.mem_req.be         = vcore_xif.mem_req.be;               
                host_xif.mem_req.attr       = vcore_xif.mem_req.attr;             
                host_xif.mem_req.wdata      = vcore_xif.mem_req.wdata;            
                host_xif.mem_req.last       = vcore_xif.mem_req.last;             
                host_xif.mem_req.spec       = vcore_xif.mem_req.spec; 
            end          

        end

        //For arbitration of mem_result_valid, keep track of which offloaded instruction IDs are sent to which unit on the Xif interface.  Unintended behaviour from FPU_SS when this signal is broadcast
        logic [X_ID_WIDTH-1:0] mem_req_d;
        logic [X_ID_WIDTH-1:0] mem_req_q;

        always_comb begin
            mem_req_d = mem_req_q;
            if (vcore_xif.issue_resp.accept) begin          //if sent to vicuna, set to 0
                mem_req_d[host_xif.issue_req.id] = 1'b0;
            end
            if (fpu_ss_xif.issue_resp.accept) begin         //if sent to fpu_ss, set to 1
                mem_req_d[host_xif.issue_req.id] = 1'b1;
            end
        end

        always_ff @(posedge clk_i, negedge rst_ni) begin
            if (~rst_ni) begin
                mem_req_q   <= '0;
            end else begin
                mem_req_q   <= mem_req_d;
            end
        end

        always_comb begin
            if (mem_req_q[host_xif.mem_result.id]) begin //Mem_result is for FPU_SS
                fpu_ss_xif.mem_result_valid = host_xif.mem_result_valid;
                vcore_xif.mem_result_valid    = 1'b0;
            end else begin                              //Mem_result is for Vicuna
                fpu_ss_xif.mem_result_valid = 1'b0;
                vcore_xif.mem_result_valid    = host_xif.mem_result_valid;
            end
        end
        assign fpu_ss_xif.mem_result.id    = host_xif.mem_result.id;         //Broadcast from host
        assign vcore_xif.mem_result.id    = host_xif.mem_result.id;         //Broadcast from host
        assign fpu_ss_xif.mem_result.rdata = host_xif.mem_result.rdata;      //Broadcast from host
        assign vcore_xif.mem_result.rdata = host_xif.mem_result.rdata;      //Broadcast from host
        assign fpu_ss_xif.mem_result.err   = host_xif.mem_result.err;        //Broadcast from host
        assign vcore_xif.mem_result.err   = host_xif.mem_result.err;        //Broadcast from host
        assign fpu_ss_xif.mem_result.dbg   = host_xif.mem_result.dbg;        //Broadcast from host
        assign vcore_xif.mem_result.dbg   = host_xif.mem_result.dbg;        //Broadcast from host

    end else begin

        //If Vicuna is not on the XIF interface, just connect FPU_SS
        assign host_xif.mem_valid          = fpu_ss_xif.mem_valid;
        assign fpu_ss_xif.mem_ready        = host_xif.mem_ready;             
        assign host_xif.mem_req.id         = fpu_ss_xif.mem_req.id;          
        assign host_xif.mem_req.addr       = fpu_ss_xif.mem_req.addr;        
        assign host_xif.mem_req.mode       = fpu_ss_xif.mem_req.mode;        
        assign host_xif.mem_req.we         = fpu_ss_xif.mem_req.we;          
        assign host_xif.mem_req.size       = fpu_ss_xif.mem_req.size;        
        assign host_xif.mem_req.be         = fpu_ss_xif.mem_req.be;          
        assign host_xif.mem_req.attr       = fpu_ss_xif.mem_req.attr;        
        assign host_xif.mem_req.wdata      = fpu_ss_xif.mem_req.wdata;       
        assign host_xif.mem_req.last       = fpu_ss_xif.mem_req.last;        
        assign host_xif.mem_req.spec       = fpu_ss_xif.mem_req.spec;        
        assign fpu_ss_xif.mem_resp.exc     = host_xif.mem_resp.exc;          
        assign fpu_ss_xif.mem_resp.exccode = host_xif.mem_resp.exccode;      
        assign fpu_ss_xif.mem_resp.dbg     = host_xif.mem_resp.dbg;          
        assign fpu_ss_xif.mem_result_valid = host_xif.mem_result_valid;      
        assign fpu_ss_xif.mem_result.id    = host_xif.mem_result.id;         
        assign fpu_ss_xif.mem_result.rdata = host_xif.mem_result.rdata;      
        assign fpu_ss_xif.mem_result.err   = host_xif.mem_result.err;        
        assign fpu_ss_xif.mem_result.dbg   = host_xif.mem_result.dbg;   

    end

    `endif
`endif

    // Extract vector unit memory signals from extension interface
    if (USE_XIF_MEM) begin
        assign vdata_req                  = '0;
        assign vdata_addr                 = '0;
        assign vdata_we                   = '0;
        assign vdata_be                   = '0;
        assign vdata_wdata                = '0;
        assign vdata_req_id               = '0;
    end else begin
        for(genvar i = 0; i < MEM_PORTS; i++) begin
            assign vdata_req[i]                  = vcore_obi_bus[i].req;
            assign vcore_obi_bus[i].gnt          = vdata_gnt[i];
            assign vdata_addr[i]                 = vcore_obi_bus[i].addr;
            assign vdata_we[i]                   = vcore_obi_bus[i].we;
            assign vdata_be[i]                   = vcore_obi_bus[i].be;
            assign vdata_wdata[i]                = vcore_obi_bus[i].wdata;
            assign vdata_req_id[i]               = vcore_obi_bus[i].aid;
            assign vcore_obi_bus[i].rvalid       = vdata_rvalid[i];
            assign vcore_obi_bus[i].rid          = vdata_res_id[i];
            assign vcore_obi_bus[i].rdata        = vdata_rdata[i];
            assign vcore_obi_bus[i].err          = vdata_err[i];
        end
    end

    // Data arbiter for main core and vector unit
    logic                sdata_hold;
    logic                data_req       [MEM_PORTS-1:0];
    logic [31:0]         data_addr      [MEM_PORTS-1:0];
    logic                data_we        [MEM_PORTS-1:0];
    logic [VMEM_W/8-1:0] data_be        [MEM_PORTS-1:0];
    logic [VMEM_W  -1:0] data_wdata     [MEM_PORTS-1:0];
    logic                data_gnt       [MEM_PORTS-1:0];
    logic                data_rvalid    [MEM_PORTS-1:0];
    logic                data_err       [MEM_PORTS-1:0];
    logic [VMEM_W  -1:0] data_rdata     [MEM_PORTS-1:0];
    logic [OBI_ID_WIDTH-1:0] data_req_id [MEM_PORTS-1:0];
    logic [OBI_ID_WIDTH-1:0] data_res_id [MEM_PORTS-1:0];
    logic                sdata_waiting;
    logic                vdata_waiting;
    logic [31:0]         sdata_wait_addr;
    assign sdata_hold = ~USE_XIF_MEM & (vdata_req[0] | (vect_pending_load & sdata_we));
    always_comb begin
        data_req[0]   = vdata_req[0] | (sdata_req & ~sdata_hold);
        data_addr[0]  = sdata_addr;
        data_we[0]    = sdata_we;
        // TODO: data_req_id[0] = ; for cva core
        
        `ifdef FORCE_ALIGNED_READS
        data_addr[0]  =  {sdata_addr[31:$clog2(VMEM_W/8)], {$clog2(VMEM_W/8){1'b0}}};
        data_be[0]    = {{(VMEM_W-32){1'b0}}, sdata_be} << (sdata_addr[$clog2(VMEM_W/8)-1:0] & {{$clog2(VMEM_W/32){1'b1}}, 2'b00});
        data_wdata[0] = '0;
        for (int i = 0; i < VMEM_W / 32; i++) begin
            data_wdata[0][32*i +: 32] = sdata_wdata;
        end
        `else
        data_be[0]    = {{(VMEM_W-32){1'b0}}, sdata_be};
        data_wdata[0] = {{(VMEM_W-32){1'b0}}, sdata_wdata};
        `endif
        
        if (vdata_req[0]) begin
            data_addr[0]     = vdata_addr[0];
            data_we[0]       = vdata_we[0];
            data_be[0]       = vdata_be[0];
            data_wdata[0]    = vdata_wdata[0];
            data_req_id[0]   = vdata_req_id[0];
        end
        for(int i = 1; i < MEM_PORTS; i++) begin
            data_req[i]      = vdata_req[i];
            data_addr[i]     = vdata_addr[i];
            data_we[i]       = vdata_we[i];
            data_be[i]       = vdata_be[i];
            data_wdata[i]    = vdata_wdata[i];
            data_req_id[i]   = vdata_req_id[i];
        end
    end
    assign sdata_gnt = data_gnt[0] & sdata_req & ~sdata_hold;
    for(genvar i = 0; i < MEM_PORTS; i++) begin
        assign vdata_gnt[i] = data_gnt[i] & vdata_req[i];
    end

    vproc_queue #(
        .WIDTH        ( $bits(instr_wait_addr)                                        ),
        .DEPTH        ( 2                                                             ), // cv32 is configured to send out max 2 requests as default
        .FLOW         ( 1'b1                                                          )
    ) i_wait_id_queue (
        .clk_i        ( clk_i                                                         ),
        .async_rst_ni ( rst_ni                                                        ),
        .sync_rst_ni  ( 1'b1                                                          ), // sync_rst_n
        .enq_ready_o  (                                                               ),
        .enq_valid_i  ( imem_gnt                                                      ),
        .enq_data_i   ( instr_addr                                                    ),
        .deq_ready_i  ( imem_rvalid                                                   ),
        .deq_valid_o  (                                                               ),
        .deq_data_o   ( instr_wait_addr                                               ),
        .flags_any_o  (                                                               ),
        .flags_all_o  (                                                               )
    );

    vproc_queue #(
        .WIDTH        ( $bits(sdata_wait_addr)                                        ),
        .DEPTH        ( 2                                                             ), // cv32 is configured to send out max 2 requests as default
        .FLOW         ( 1'b1                                                          )
    ) s_wait_id_queue (
        .clk_i        ( clk_i                                                         ),
        .async_rst_ni ( rst_ni                                                        ),
        .sync_rst_ni  ( sync_rst_n                                                    ),
        .enq_ready_o  (                                                               ),
        .enq_valid_i  ( sdata_gnt                                                     ),
        .enq_data_i   ( sdata_addr                                                    ),
        .deq_ready_i  ( sdata_rvalid                                                  ),
        .deq_valid_o  ( sdata_waiting                                                 ),
        .deq_data_o   ( sdata_wait_addr                                               ),
        .flags_any_o  (                                                               ),
        .flags_all_o  (                                                               )
    );

    vproc_queue #(
        .WIDTH        ( 1                                            	 	          ),
        .DEPTH        ( PORT_QUEUE_DEPTH                                              ),
        .FLOW         ( 1'b1                                                          )
    ) v_wait_id_queue (
        .clk_i        ( clk_i                                                         ),
        .async_rst_ni ( 1                                                             ),
        .sync_rst_ni  ( sync_rst_n                                                    ),
        .enq_ready_o  (                                                               ),
        .enq_valid_i  ( vdata_gnt[0]                                                  ),
        .enq_data_i   (                                                               ),
        .deq_ready_i  ( vdata_rvalid[0]                                              ),
        .deq_valid_o  ( vdata_waiting                                                 ),
        .deq_data_o   (                                                               ),
        .flags_any_o  (                                                               ),
        .flags_all_o  (                                                               )
    );

    assign sdata_rvalid = sdata_waiting & data_rvalid[0];
    assign sdata_err    = data_err[0];
    
    
    assign vdata_rvalid[0] = vdata_waiting & data_rvalid[0];
    assign vdata_err[0]    = data_err[0];
    for(genvar i = 1; i < MEM_PORTS; i++) begin
        assign vdata_rvalid[i] = data_rvalid[i];
        assign vdata_err[i]    = data_err[i];
    end

    `ifdef FORCE_ALIGNED_READS
    assign sdata_rdata  = data_rdata[0][(sdata_wait_addr[$clog2(VMEM_W)-1:0] & {3'b000, {($clog2(VMEM_W/8)-2){1'b1}}, 2'b00})*8 +: 32];
    `else
    assign sdata_rdata  = data_rdata[0][31:0];
    `endif
    assign vdata_rdata  = data_rdata;
    assign vdata_res_id = data_res_id;

    // Memory Interface signals I-DATA
    logic             imem_req;
    logic             imem_gnt;
    logic [31:0]      imem_addr;
    logic             imem_rvalid;
    logic [MEM_W-1:0] imem_rdata;
    logic             imem_err;
    logic             i_miss /* verilator public */;
    logic             i_hit  /* verilator public */;
    logic [31:0]      instr_wait_addr;

    always_comb begin
        imem_req  = instr_req;
        instr_gnt = imem_gnt;
        instr_rvalid = imem_rvalid;
        instr_err    = imem_err;

        `ifdef FORCE_ALIGNED_READS
        imem_addr  =  {instr_addr[31:$clog2(VMEM_W/8)], {$clog2(VMEM_W/8){1'b0}}};
        instr_rdata  = imem_rdata[(instr_wait_addr[$clog2(VMEM_W)-1:0] & {3'b000, {($clog2(VMEM_W/8)-2){1'b1}}, 2'b00})*8 +: 32];
        `else
        imem_addr = instr_addr;
        instr_rdata  = imem_rdata[31:0];
        `endif
    end


    // Memory Interface signals D-DATA
    logic               dmem_req    [MEM_PORTS-1:0];
    logic               dmem_gnt    [MEM_PORTS-1:0];
    logic [31:0]        dmem_addr   [MEM_PORTS-1:0];
    logic               dmem_we     [MEM_PORTS-1:0];
    logic [MEM_W/8-1:0] dmem_be     [MEM_PORTS-1:0];
    logic [MEM_W  -1:0] dmem_wdata  [MEM_PORTS-1:0];
    logic               dmem_rvalid [MEM_PORTS-1:0];
    logic               dmem_wvalid [MEM_PORTS-1:0];
    logic [MEM_W  -1:0] dmem_rdata  [MEM_PORTS-1:0];
    logic               dmem_err    [MEM_PORTS-1:0];
    logic               dmem_aid    [MEM_PORTS-1:0];
    logic               dmem_rid    [MEM_PORTS-1:0];
    logic               d_miss /* verilator public */;
    logic               d_hit  /* verilator public */;

    for(genvar i = 0; i < MEM_PORTS; i++) begin
        assign dmem_req[i]    = data_req[i];
        assign dmem_addr[i]   = data_addr[i];
        assign dmem_we[i]     = data_we[i] && mem_req_o[i];
        assign dmem_be[i]     = data_be[i];
        assign dmem_wdata[i]  = data_wdata[i];
        assign data_gnt[i]    = dmem_gnt[i];
        assign data_rvalid[i] = dmem_rvalid[i] | dmem_wvalid[i];
        assign data_rdata[i]  = dmem_rdata[i];
        assign data_err[i]    = dmem_err[i];
        assign dmem_aid[i]    = data_req_id[i];
        assign data_res_id[i] = dmem_rid[i];
    end




    ///////////////////////////////////////////////////////////////////////////
    // MEMORY ARBITER // Is tracking sources necessary now that caches removed?
    

    //if cache is not enabled, no memory arbitration required
    always_comb begin

        mem_req_o   = dmem_req;
        mem_be_o    = dmem_be;
        mem_wdata_o = dmem_wdata;
        mem_we_o    = dmem_we;
        mem_addr_o  = dmem_addr;
            
    end

    assign dmem_gnt =  dmem_req;


    always_comb begin
        mem_ireq_o   = imem_req;
        mem_iaddr_o = imem_addr;       
    end

    assign imem_gnt =  imem_req;


    // shift register keeping track of the source of mem requests for up to 32 cycles (needed to keep track of reads/writes)
    logic [MEM_PORTS-1:0][31:0] req_sources;
    logic [MEM_PORTS-1:0][31:0] req_write; // keeping track of whether the request was a write
    logic [MEM_PORTS-1:0][4:0]  req_count;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            req_count <= '{default: '0};
        end else begin
            for(int i = 0; i < MEM_PORTS; i++) begin
                if (mem_rvalid_i[i]) begin
                    for (int j = 0; j < 31; j++) begin
                        req_sources [i][j] <= req_sources  [i][j+1];
                        req_write    [i][j] <= req_write    [i][j+1];
                    end
                    if (~dmem_gnt[i]) begin
                        req_count[i] <= req_count[i] - 1;
                    end else begin
                        req_sources  [i][req_count[i]-1] <= dmem_gnt[i];
                        req_write    [i][req_count[i]-1] <= dmem_we[i];
                    end
                end
                else if (dmem_gnt[i]) begin
                    req_sources  [i][req_count] <= dmem_gnt[i];
                    req_write    [i][req_count] <= dmem_we[i];
                    req_count[i]                <= req_count[i] + 1;
                end
            end
        end
    end

    assign imem_rvalid = mem_irvalid_i;

    generate
        for(genvar i = 0; i < MEM_PORTS; i++) begin
            assign dmem_rvalid[i] = mem_rvalid_i[i] & ~req_write[i][0];
            assign dmem_wvalid[i] = mem_rvalid_i[i] &  req_write[i][0]; //this could be an issue?
        end
    endgenerate

    assign imem_err    = mem_ierr_i;
    assign dmem_err    = mem_err_i;

    assign imem_rdata  = mem_irdata_i;
    assign dmem_rdata  = mem_rdata_i;
    
    assign mem_aid_o   = dmem_aid;
    assign dmem_rid    = mem_rid_i;




endmodule
