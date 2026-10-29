`include "mycpu_head.v"

module mycpu_top #(
    parameter BP_ENABLE = 1
)(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    input  wire [ 7:0] hw_int_in
);

    reg reset;
    always @(posedge clk) reset <= ~resetn;
    wire flush;
    wire [31:0] flush_target;
    wire ms_cancel;
    wire has_int;
    wire es_csr_pending, ms_csr_pending, ws_csr_pending;

    // IF stage
    wire [`BR_BUS_WD-1:0] br_bus;
    wire [`BP_UPDATE_BUS_WD-1:0] bp_update_bus;
    wire fs_to_ds_valid;
    wire [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus;
    wire ds_allowin;

    IF_stage #(.BP_ENABLE(BP_ENABLE)) u_if_stage(
        .clk(clk),
        .reset(reset),
        .flush(flush),
        .flush_target(flush_target),
        .ds_allowin(ds_allowin),
        .br_bus(br_bus),
        .bp_update_bus(bp_update_bus),
        .inst_sram_rdata (inst_sram_rdata ),

        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),
        .inst_sram_en(inst_sram_en),
        .inst_sram_we(inst_sram_we),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata)
    );

    // ID stage
    wire  es_allowin;
    wire  ds_to_es_valid;
    wire [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus;
    wire [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus;
    wire [`ES_TO_DS_BUS_WD-1:0] es_to_ds_bus;
    wire [`MS_TO_DS_BUS_WD-1:0] ms_to_ds_bus;

    ID_stage u_id_stage(
        .clk(clk),
        .reset(reset),
        .flush(flush),
        .has_int(has_int),
        .csr_pending(es_csr_pending || ms_csr_pending || ws_csr_pending),
        .es_allowin(es_allowin),
        .fs_to_ds_valid (fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),
        .ws_to_rf_bus(ws_to_rf_bus),
        .es_to_ds_bus(es_to_ds_bus),
        .ms_to_ds_bus(ms_to_ds_bus),

        .ds_to_es_valid (ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),
        .br_bus(br_bus),
        .bp_update_bus(bp_update_bus),
        .ds_allowin(ds_allowin)
    );

    // EXE stage
    wire ms_allowin;
    wire es_to_ms_valid;
    wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus;

    EXE_stage u_exe_stage(
        .clk(clk),
        .reset(reset),
        .flush(flush),
        .ms_cancel(ms_cancel),
        .es_csr_pending(es_csr_pending),
        .ms_allowin(ms_allowin),
        .ds_to_es_valid(ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),

        .es_allowin(es_allowin),
        .es_to_ms_valid(es_to_ms_valid),
        .es_to_ms_bus(es_to_ms_bus),
        .es_to_ds_bus(es_to_ds_bus),
        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata (data_sram_wdata )
    );

    // MEM stage
    wire                        ws_allowin;
    wire                        ms_to_ws_valid;
    wire [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus;

    MEM_stage u_mem_stage(
        .clk(clk),
        .reset(reset),
        .flush(flush),
        .ms_cancel(ms_cancel),
        .ms_csr_pending(ms_csr_pending),
        .ws_allowin(ws_allowin),
        .es_to_ms_valid(es_to_ms_valid),
        .es_to_ms_bus  (es_to_ms_bus),
        .data_sram_rdata(data_sram_rdata),
        .ms_allowin(ms_allowin),
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_to_ws_bus(ms_to_ws_bus),
        .ms_to_ds_bus(ms_to_ds_bus)
    );
    // WB stage
    WB_stage u_wb_stage(
        .clk(clk),
        .reset(reset),
        .hw_int_in(hw_int_in),
        .has_int(has_int),
        .ws_csr_pending(ws_csr_pending),
        .flush(flush),
        .flush_target(flush_target),
        .ws_allowin(ws_allowin),
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_to_ws_bus(ms_to_ws_bus),
        .ws_to_rf_bus(ws_to_rf_bus),
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );
endmodule
