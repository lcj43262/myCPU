`include "mycpu_head.v"

module csr(
    input  wire        clk,
    input  wire        reset,
    input  wire [13:0] csr_num,
    output reg  [31:0] csr_rvalue,
    input  wire        csr_we,
    input  wire [31:0] csr_wmask,
    input  wire [31:0] csr_wvalue,
    input  wire        wb_ex,
    input  wire [31:0] wb_pc,
    input  wire        ertn_flush,
    output wire [31:0] ex_entry,
    output wire [31:0] ex_return
);
    reg [1:0] crmd_plv;
    reg       crmd_ie;
    reg [1:0] prmd_pplv;
    reg       prmd_pie;
    reg [1:0] estat_is;
    reg [5:0] estat_ecode;
    reg [31:0] era;
    reg [31:6] eentry;
    reg [31:0] save0, save1, save2, save3;

    //DA=1, PG=0, DATF=DATM=0.
    wire [31:0] crmd_value = {28'b0, 1'b1, crmd_ie, crmd_plv};
    wire [31:0] prmd_value = {29'b0, prmd_pie, prmd_pplv};
    wire [31:0] estat_value = {1'b0, 9'b0, estat_ecode, 3'b0, 11'b0, estat_is};
    wire [31:0] write_value = (csr_wmask & csr_wvalue)
                                   | (~csr_wmask & csr_rvalue);

    assign ex_entry = {eentry, 6'b0};
    assign ex_return = era;

    always @(*) begin
        case (csr_num)
            `CSR_CRMD:   csr_rvalue = crmd_value;
            `CSR_PRMD:   csr_rvalue = prmd_value;
            `CSR_ESTAT:  csr_rvalue = estat_value;
            `CSR_ERA:    csr_rvalue = era;
            `CSR_EENTRY: csr_rvalue = ex_entry;
            `CSR_SAVE0:  csr_rvalue = save0;
            `CSR_SAVE1:  csr_rvalue = save1;
            `CSR_SAVE2:  csr_rvalue = save2;
            `CSR_SAVE3:  csr_rvalue = save3;
            default:     csr_rvalue = 32'b0;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            crmd_plv <= 2'b0;
            crmd_ie <= 1'b0;
            prmd_pplv <= 2'b0;
            prmd_pie <= 1'b0;
            estat_is <= 2'b0;
            estat_ecode <= 6'b0;
            era <= 32'b0;
            eentry <= 26'b0;
            save0 <= 32'b0;
            save1 <= 32'b0;
            save2 <= 32'b0;
            save3 <= 32'b0;
        end else if (wb_ex) begin
            prmd_pplv <= crmd_plv;
            prmd_pie <= crmd_ie;
            crmd_plv <= 2'b0;
            crmd_ie <= 1'b0;
            estat_ecode <= `ECODE_SYS;
            era <= wb_pc;
        end else if (ertn_flush) begin
            crmd_plv <= prmd_pplv;
            crmd_ie <= prmd_pie;
        end else if (csr_we) begin
            case (csr_num)
                `CSR_CRMD: begin
                    crmd_plv <= write_value[1:0];
                    crmd_ie <= write_value[2];
                end
                `CSR_PRMD: begin
                    prmd_pplv <= write_value[1:0];
                    prmd_pie <= write_value[2];
                end
                `CSR_ESTAT: estat_is <= write_value[1:0];
                `CSR_ERA: era <= write_value;
                `CSR_EENTRY: eentry <= write_value[31:6];
                `CSR_SAVE0: save0 <= write_value;
                `CSR_SAVE1: save1 <= write_value;
                `CSR_SAVE2: save2 <= write_value;
                `CSR_SAVE3: save3 <= write_value;
            endcase
        end
    end
endmodule
