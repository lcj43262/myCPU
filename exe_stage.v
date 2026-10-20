`include "mycpu_head.v"

module EXE_stage(
    input wire clk,
    input wire reset,
    // allowin
    input wire ms_allowin,
    output wire es_allowin,
    // from ID stage
    input  wire ds_to_es_valid,
    input  wire [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus,
    // to MEM stage
    output wire es_to_ms_valid,
    output wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus,
    // to ID stage
    output wire [`ES_TO_DS_BUS_WD-1:0] es_to_ds_bus,
    // data SRAM interface
    output wire data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata
);

    reg es_valid;
    wire es_ready_go;
    wire is_div;
    wire div_done;
    reg  [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus_r;

    assign es_ready_go    = !is_div || div_done;
    assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
    assign es_to_ms_valid = es_valid && es_ready_go;

    always @(posedge clk) begin
        if (reset) begin
            es_valid <= 1'b0;
        end
        else if (es_allowin) begin
            es_valid <= ds_to_es_valid;
        end

        if (ds_to_es_valid && es_allowin) begin
            ds_to_es_bus_r <= ds_to_es_bus;
        end
    end

    wire [11:0] es_alu_op;
    wire [6:0] es_muldiv_op;
    assign is_div = |es_muldiv_op[6:3];
    wire div_busy;
    wire [31:0] div_quotient;
    wire [31:0] div_remainder;
    wire        es_load_op;
    wire        es_src1_is_pc;
    wire        es_src2_is_imm;
    wire        es_src2_is_4;
    wire        es_gr_we;
    wire [1:0]  es_mem_we;
    wire [2:0]  es_ld_type;
    wire [ 4:0] es_dest;
    wire [31:0] es_imm;
    wire [31:0] es_rj_value;
    wire [31:0] es_rkd_value;
    wire [31:0] es_pc;
    wire        es_res_from_mem;

    assign {
        es_muldiv_op,
        es_alu_op,
        es_load_op,
        es_src1_is_pc,
        es_src2_is_imm,
        es_src2_is_4,
        es_gr_we,
        es_mem_we,
        es_ld_type,
        es_dest,
        es_imm,
        es_rj_value,
        es_rkd_value,
        es_pc,
        es_res_from_mem
        } = ds_to_es_bus_r;

    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    wire [31:0] alu_result;

    assign alu_src1 = es_src1_is_pc  ? es_pc : es_rj_value;
    assign alu_src2 = es_src2_is_4   ? 32'd4 :
                      es_src2_is_imm ? es_imm : es_rkd_value;

    alu u_alu(
        .alu_op     (es_alu_op ),
        .alu_src1   (alu_src1  ),
        .alu_src2   (alu_src2  ),
        .alu_result (alu_result)
    );

    wire signed [63:0] signed_product = $signed(es_rj_value) * $signed(es_rkd_value);
    wire [63:0] unsigned_product = es_rj_value * es_rkd_value;
    wire [31:0] es_result = es_muldiv_op[0] ? signed_product[31:0] :
                            es_muldiv_op[1] ? signed_product[63:32] :
                            es_muldiv_op[2] ? unsigned_product[63:32] :
                            (es_muldiv_op[3] || es_muldiv_op[4]) ? div_quotient :
                            (es_muldiv_op[5] || es_muldiv_op[6]) ? div_remainder :
                            alu_result;
    divider u_divider(
        .clk(clk),
        .reset(reset),
        .start(es_valid && is_div && !div_busy && !div_done),
        .consume(es_valid && is_div && es_ready_go && ms_allowin),
        .signed_mode(es_muldiv_op[3] || es_muldiv_op[5]),
        .dividend(es_rj_value),
        .divisor(es_rkd_value),
        .busy(div_busy),
        .done(div_done),
        .quotient(div_quotient),
        .remainder(div_remainder)
    );

    assign data_sram_en    = (es_load_op || (es_mem_we != 2'b00)) && es_valid;
    assign data_sram_we    = es_valid ?
                             (es_mem_we == 2'b01 ? 4'b1111 :
                              es_mem_we == 2'b10 ? (4'b0001 << alu_result[1:0]) :
                              es_mem_we == 2'b11 ? (alu_result[1] ? 4'b1100 : 4'b0011) :
                              4'b0000) : 4'b0000;
    assign data_sram_addr  = alu_result;
    assign data_sram_wdata = (es_mem_we == 2'b01) ? es_rkd_value :
                             (es_mem_we == 2'b10) ? {4{es_rkd_value[7:0]}} :
                             (es_mem_we == 2'b11) ? {2{es_rkd_value[15:0]}} :
                             32'b0;

    // 1+3+1+5+32+32 = 74
    assign es_to_ms_bus = {
        es_res_from_mem,
        es_ld_type,
        es_gr_we,
        es_dest,
        es_result,
        es_pc
    };

    assign es_to_ds_bus = {
        es_valid && es_gr_we,
        es_load_op || !es_ready_go,
        es_dest,
        es_result
    };

endmodule
