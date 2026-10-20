`include "mycpu_head.v"

module MEM_stage(
    input wire clk,
    input wire reset,
    input wire flush,
    output wire ms_cancel,

    input wire ws_allowin,
    output wire ms_allowin,

    input  wire es_to_ms_valid,
    input  wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus,

    input  wire [31:0] data_sram_rdata,

    output wire ms_to_ws_valid,
    output wire [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus,
    // to ID stage
    output wire [`MS_TO_DS_BUS_WD-1:0] ms_to_ds_bus
);
    reg ms_valid;
    wire ms_ready_go;
    reg [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus_r;

    assign ms_ready_go = 1'b1;
    assign ms_allowin = !ms_valid || ms_ready_go && ws_allowin;
    assign ms_to_ws_valid = ms_valid && ms_ready_go && !flush;

    always @(posedge clk)begin
        if(reset || flush)begin
            ms_valid <= 1'b0;
        end
        else if(ms_allowin)begin
            ms_valid <= es_to_ms_valid;
        end
        if(es_to_ms_valid && ms_allowin)begin
            es_to_ms_bus_r <= es_to_ms_bus;
        end
    end

    wire        ms_res_from_mem;
    wire [2:0]  ms_ld_type;
    wire        ms_gr_we;
    wire [ 4:0] ms_dest;
    wire [31:0] ms_alu_result;
    wire [31:0] ms_pc;
    wire [`CSR_BUS_WD-1:0] ms_csr_bus;
    assign ms_cancel = ms_valid && (ms_csr_bus[81] || ms_csr_bus[80]);

    assign {
        ms_csr_bus,
        ms_res_from_mem,
        ms_ld_type,
        ms_gr_we,
        ms_dest,
        ms_alu_result,
        ms_pc
        } = es_to_ms_bus_r;
    wire [31:0] ms_load_result;
    wire [1:0] ms_addr_low;
    assign ms_addr_low = ms_alu_result[1:0];
    assign ms_load_result = (ms_ld_type == 3'b001) ?
                            (ms_addr_low == 2'b00 ? {{24{data_sram_rdata[7]}}, data_sram_rdata[7:0]} :
                             ms_addr_low == 2'b01 ? {{24{data_sram_rdata[15]}}, data_sram_rdata[15:8]} :
                             ms_addr_low == 2'b10 ? {{24{data_sram_rdata[23]}}, data_sram_rdata[23:16]} :
                                                    {{24{data_sram_rdata[31]}}, data_sram_rdata[31:24]}) :
                            (ms_ld_type == 3'b010) ?
                            (ms_addr_low == 2'b00 ? {24'b0, data_sram_rdata[7:0]} :
                             ms_addr_low == 2'b01 ? {24'b0, data_sram_rdata[15:8]} :
                             ms_addr_low == 2'b10 ? {24'b0, data_sram_rdata[23:16]} :
                                                    {24'b0, data_sram_rdata[31:24]}) :
                            (ms_ld_type == 3'b011) ?
                            (ms_addr_low[1] ? {{16{data_sram_rdata[31]}}, data_sram_rdata[31:16]} :
                                               {{16{data_sram_rdata[15]}}, data_sram_rdata[15:0]}) :
                            (ms_ld_type == 3'b100) ?
                            (ms_addr_low[1] ? {16'b0, data_sram_rdata[31:16]} :
                                               {16'b0, data_sram_rdata[15:0]}) :
                            data_sram_rdata;
    wire [31:0] ms_result;
    assign ms_result = ms_res_from_mem ? ms_load_result : ms_alu_result;
    //1+5+32+32
    assign ms_to_ws_bus = {
        ms_csr_bus,
        ms_gr_we,
        ms_dest,
        ms_result,
        ms_pc
    };

    assign ms_to_ds_bus = {
        ms_valid && ms_gr_we,
        ms_csr_bus[79],
        ms_dest,
        ms_result
    };
endmodule
