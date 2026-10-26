`include "mycpu_head.v"

module csr(
    input wire clk, input wire reset, input wire [13:0] csr_num,
    output reg [31:0] csr_rvalue,
    input wire csr_we, input wire [31:0] csr_wmask, input wire [31:0] csr_wvalue,
    input wire wb_ex, input wire [31:0] wb_pc, input wire [5:0] wb_ecode,
    input wire [31:0] wb_badv, input wire ertn_flush, input wire [7:0] hw_int_in,
    output wire has_int, output wire [31:0] ex_entry, output wire [31:0] ex_return
);
    reg [1:0] crmd_plv; reg crmd_ie; reg [1:0] prmd_pplv; reg prmd_pie;
    reg [12:0] ecfg_lie; reg [12:0] estat_is; reg [5:0] estat_ecode;
    reg [31:0] era; reg [31:6] eentry; reg [31:0] badv;
    reg [31:0] tid; reg tcfg_en; reg tcfg_periodic; reg [29:0] tcfg_initval;
    reg [31:0] timer_cnt; reg [31:0] save0, save1, save2, save3;

    wire [31:0] crmd_value = {28'b0,1'b1,crmd_ie,crmd_plv};
    wire [31:0] prmd_value = {29'b0,prmd_pie,prmd_pplv};
    wire [31:0] ecfg_value = {19'b0,ecfg_lie};
    wire [31:0] estat_value = {1'b0,9'b0,estat_ecode,3'b0,estat_is};
    wire [31:0] tcfg_value = {tcfg_initval,tcfg_periodic,tcfg_en};
    wire [31:0] write_value = (csr_wmask & csr_wvalue) | (~csr_wmask & csr_rvalue);
    wire [31:0] tcfg_next_value = (csr_wmask & csr_wvalue) | (~csr_wmask & tcfg_value);
    wire timer_expired = timer_cnt == 32'b0;

    assign ex_entry = {eentry,6'b0};
    assign ex_return = era;
    assign has_int = crmd_ie && (|(estat_is & ecfg_lie));

    always @(*) begin
        case (csr_num)
            `CSR_CRMD: csr_rvalue=crmd_value; `CSR_PRMD: csr_rvalue=prmd_value;
            `CSR_ECFG: csr_rvalue=ecfg_value; `CSR_ESTAT: csr_rvalue=estat_value;
            `CSR_ERA: csr_rvalue=era; `CSR_BADV: csr_rvalue=badv;
            `CSR_EENTRY: csr_rvalue=ex_entry; `CSR_SAVE0: csr_rvalue=save0;
            `CSR_SAVE1: csr_rvalue=save1; `CSR_SAVE2: csr_rvalue=save2;
            `CSR_SAVE3: csr_rvalue=save3; `CSR_TID: csr_rvalue=tid;
            `CSR_TCFG: csr_rvalue=tcfg_value; `CSR_TVAL: csr_rvalue=timer_cnt;
            `CSR_TICLR: csr_rvalue=32'b0; default: csr_rvalue=32'b0;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            crmd_plv<=0; crmd_ie<=0; prmd_pplv<=0; prmd_pie<=0; ecfg_lie<=0;
            estat_is<=0; estat_ecode<=0; era<=0; eentry<=0;
            badv<=0; tid<=0; tcfg_en<=0; tcfg_periodic<=0; tcfg_initval<=0;
            timer_cnt<=32'hffff_ffff; save0<=0; save1<=0; save2<=0; save3<=0;
        end else begin
            estat_is[9:2] <= hw_int_in; estat_is[10] <= 1'b0; estat_is[12] <= 1'b0;
            if (timer_expired) estat_is[11] <= 1'b1;
            else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[0] && csr_wvalue[0]) estat_is[11] <= 1'b0;
            if (tcfg_en && timer_cnt != 32'hffff_ffff) begin
                if (timer_expired && tcfg_periodic) timer_cnt <= {tcfg_initval,2'b0};
                else timer_cnt <= timer_cnt - 1'b1;
            end
            if (csr_we && csr_num==`CSR_TCFG) begin
                tcfg_en<=tcfg_next_value[0]; tcfg_periodic<=tcfg_next_value[1];
                tcfg_initval<=tcfg_next_value[31:2];
                if (tcfg_next_value[0]) timer_cnt <= {tcfg_next_value[31:2],2'b0};
            end
            if (wb_ex) begin
                prmd_pplv<=crmd_plv; prmd_pie<=crmd_ie; crmd_plv<=0; crmd_ie<=0;
                estat_ecode<=wb_ecode; era<=wb_pc; badv<=wb_badv;
            end else if (ertn_flush) begin
                crmd_plv<=prmd_pplv; crmd_ie<=prmd_pie;
            end else if (csr_we) begin
                case (csr_num)
                    `CSR_CRMD: begin crmd_plv<=write_value[1:0]; crmd_ie<=write_value[2]; end
                    `CSR_PRMD: begin prmd_pplv<=write_value[1:0]; prmd_pie<=write_value[2]; end
                    `CSR_ECFG: ecfg_lie<=write_value[12:0];
                    `CSR_ESTAT: estat_is[1:0]<=write_value[1:0];
                    `CSR_ERA: era<=write_value; `CSR_EENTRY: eentry<=write_value[31:6];
                    `CSR_TID: tid<=write_value; `CSR_SAVE0: save0<=write_value;
                    `CSR_SAVE1: save1<=write_value; `CSR_SAVE2: save2<=write_value;
                    `CSR_SAVE3: save3<=write_value;
                endcase
            end
        end
    end
endmodule
