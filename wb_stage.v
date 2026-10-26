`include "mycpu_head.v"

module WB_stage(
    input wire clk,
    input wire reset,
    input wire [7:0] hw_int_in,
    output wire has_int,
    output wire ws_csr_pending,
    output wire flush,
    output wire [31:0] flush_target,

    output wire ws_allowin,

    input  wire ms_to_ws_valid,
    input  wire [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus,

    output wire [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus,
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

    reg ws_valid;
    wire ws_ready_go;
    reg [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus_r;

    assign ws_ready_go = 1'b1;
    assign ws_allowin  = !ws_valid || ws_ready_go;

    always @(posedge clk) begin
        if (reset || flush) begin
            ws_valid <= 1'b0;
        end
        else if (ws_allowin) begin
            ws_valid <= ms_to_ws_valid;
        end

        if (ms_to_ws_valid && ws_allowin) begin
            ms_to_ws_bus_r <= ms_to_ws_bus;
        end
    end

    wire        ws_gr_we;
    wire [ 4:0] ws_dest;
    wire [31:0] ws_result;
    wire [31:0] ws_pc;
    wire        ws_rf_we;
    wire [`CSR_BUS_WD-1:0] ws_csr_bus;
    wire [`EX_BUS_WD-1:0] ws_ex_bus;
    wire ws_syscall, ws_ertn, ws_csr_read, ws_csr_write;
    wire [13:0] ws_csr_num;
    wire [31:0] ws_csr_wmask, ws_csr_wvalue;
    wire [31:0] csr_rvalue, ex_entry, ex_return;
    wire wb_ex = ws_valid && ((|ws_ex_bus[36:32]) || ws_syscall) && !reset;
    wire ertn_flush = ws_valid && ws_ertn && !wb_ex && !reset;
    // Interrupts have priority over synchronous exceptions on the same instruction.
    wire [5:0] wb_ecode = ws_ex_bus[35] ? `ECODE_INT :
                         ws_ex_bus[36] ? `ECODE_ADEF :
                         ws_ex_bus[33] ? `ECODE_INE :
                         ws_syscall ? `ECODE_SYS :
                         ws_ex_bus[34] ? `ECODE_BRK : `ECODE_ALE;
    assign ws_csr_pending = ws_valid && (ws_csr_write || ws_ertn);
    wire [31:0] ws_final_result = ws_csr_read ? csr_rvalue : ws_result;

    assign {ws_syscall, ws_ertn, ws_csr_read, ws_csr_write,
            ws_csr_num, ws_csr_wmask, ws_csr_wvalue} = ws_csr_bus;
    assign flush = wb_ex || ertn_flush;
    assign flush_target = wb_ex ? ex_entry : ex_return;

    csr u_csr(
        .clk(clk), .reset(reset), .csr_num(ws_csr_num),
        .csr_rvalue(csr_rvalue),
        .csr_we(ws_valid && ws_csr_write && !flush && !reset),
        .csr_wmask(ws_csr_wmask), .csr_wvalue(ws_csr_wvalue),
        .wb_ex(wb_ex), .wb_pc(ws_pc), .ertn_flush(ertn_flush),
        .wb_ecode(wb_ecode), .wb_badv(ws_ex_bus[31:0]),
        .hw_int_in(hw_int_in), .has_int(has_int),
        .ex_entry(ex_entry), .ex_return(ex_return)
    );

    assign {
        ws_ex_bus,
        ws_csr_bus,
        ws_gr_we,
        ws_dest,
        ws_result,
        ws_pc
    } = ms_to_ws_bus_r;

    assign ws_rf_we = ws_valid && ws_gr_we && !flush && !reset;
    assign ws_to_rf_bus = {ws_rf_we, ws_dest, ws_final_result};

    assign debug_wb_pc      = ws_pc;
    assign debug_wb_rf_we   = {4{ws_rf_we}};
    assign debug_wb_rf_wnum = ws_dest;
    assign debug_wb_rf_wdata = ws_final_result;
endmodule
