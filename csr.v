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
    input  wire [5:0]  wb_ecode,
    input  wire [31:0] wb_badv,
    input  wire        ertn_flush,
    input  wire [7:0]  hw_int_in,
    output wire        has_int,
    output wire [31:0] ex_entry,
    output wire [31:0] ex_return,
    output wire [63:0] stable_counter_value,
    output wire [31:0] tid_value
);
    reg [1:0] crmd_plv;
    reg       crmd_ie;
    reg [1:0] prmd_pplv;
    reg       prmd_pie;
    reg [12:0] ecfg_lie;
    reg [1:0] estat_sw;
    reg [7:0] estat_hw;
    reg       estat_timer;
    reg [5:0] estat_ecode;
    reg [31:0] era;
    reg [31:6] eentry;
    reg [31:0] badv;
    reg [31:0] tid;
    reg [31:0] save0, save1, save2, save3;

    reg [63:0] stable_counter;
    reg        tcfg_en;
    reg        tcfg_periodic;
    reg [29:0] tcfg_initval;
    reg [31:0] timer_cnt;

    // This lab has no IPI input. IS[10] is reserved and always reads zero.
    wire [12:0] estat_is = {1'b0, estat_timer, 1'b0, estat_hw, estat_sw};
    // DA=1, PG=0, DATF=DATM=0 until address translation is implemented.
    wire [31:0] crmd_value = {28'b0, 1'b1, crmd_ie, crmd_plv};
    wire [31:0] prmd_value = {29'b0, prmd_pie, prmd_pplv};
    wire [31:0] ecfg_value = {19'b0, ecfg_lie};
    wire [31:0] estat_value = {1'b0, 9'b0, estat_ecode, 3'b0, estat_is};
    wire [31:0] tcfg_value = {tcfg_initval, tcfg_periodic, tcfg_en};
    wire [31:0] write_value = (csr_wmask & csr_wvalue) |
                              (~csr_wmask & csr_rvalue);
    wire [31:0] tcfg_next_value = (csr_wmask & csr_wvalue) |
                                  (~csr_wmask & tcfg_value);
    wire csr_write = csr_we && !wb_ex && !ertn_flush;
    wire write_tcfg = csr_write && (csr_num == `CSR_TCFG);
    wire timer_expired = tcfg_en && (timer_cnt == 32'b0);
    wire clear_timer = csr_write && (csr_num == `CSR_TICLR) &&
                      csr_wmask[0] && csr_wvalue[0];
    wire address_exception = (wb_ecode == `ECODE_ADEF) ||
                             (wb_ecode == `ECODE_ALE);

    assign ex_entry = {eentry, 6'b0};
    assign ex_return = era;
    assign has_int = crmd_ie && (|(estat_is & ecfg_lie));
    assign stable_counter_value = stable_counter;
    assign tid_value = tid;

    always @(*) begin
        case (csr_num)
            `CSR_CRMD:   csr_rvalue = crmd_value;
            `CSR_PRMD:   csr_rvalue = prmd_value;
            `CSR_ECFG:   csr_rvalue = ecfg_value;
            `CSR_ESTAT:  csr_rvalue = estat_value;
            `CSR_ERA:    csr_rvalue = era;
            `CSR_BADV:   csr_rvalue = badv;
            `CSR_EENTRY: csr_rvalue = ex_entry;
            `CSR_SAVE0:  csr_rvalue = save0;
            `CSR_SAVE1:  csr_rvalue = save1;
            `CSR_SAVE2:  csr_rvalue = save2;
            `CSR_SAVE3:  csr_rvalue = save3;
            `CSR_TID:    csr_rvalue = tid;
            `CSR_TCFG:   csr_rvalue = tcfg_value;
            `CSR_TVAL:   csr_rvalue = timer_cnt; // Read-only countdown value.
            `CSR_TICLR:  csr_rvalue = 32'b0;    // W1 action, no stored CLR bit.
            default:     csr_rvalue = 32'b0;
        endcase
    end

    // Free-running 64-bit time source, separate from the interrupt countdown.
    // Stalls, exceptions, ERTN and TCFG writes must not stop or clear it.
    always @(posedge clk) begin
        if (reset)
            stable_counter <= 64'b0;
        else
            stable_counter <= stable_counter + 64'd1;
    end

    always @(posedge clk) begin
        if (reset) begin
            crmd_plv <= 2'b0;
            crmd_ie <= 1'b0;
            prmd_pplv <= 2'b0;
            prmd_pie <= 1'b0;
            ecfg_lie <= 13'b0;
            estat_sw <= 2'b0;
            estat_ecode <= 6'b0;
            era <= 32'b0;
            eentry <= 26'b0;
            tid <= 32'b0;
            save0 <= 32'b0;
            save1 <= 32'b0;
            save2 <= 32'b0;
            save3 <= 32'b0;
        end else begin
            if (wb_ex) begin
                prmd_pplv <= crmd_plv;
                prmd_pie <= crmd_ie;
                crmd_plv <= 2'b0;
                crmd_ie <= 1'b0;
                estat_ecode <= wb_ecode;
                era <= wb_pc;
            end else if (ertn_flush) begin
                crmd_plv <= prmd_pplv;
                crmd_ie <= prmd_pie;
            end else if (csr_write) begin
                case (csr_num)
                    `CSR_CRMD: begin
                        crmd_plv <= write_value[1:0];
                        crmd_ie <= write_value[2];
                    end
                    `CSR_PRMD: begin
                        prmd_pplv <= write_value[1:0];
                        prmd_pie <= write_value[2];
                    end
                    // LIE[10] is reserved; [12:11] and [9:0] are writable.
                    `CSR_ECFG:  ecfg_lie <= write_value[12:0] & 13'h1bff;
                    `CSR_ESTAT: estat_sw <= write_value[1:0];
                    `CSR_ERA:   era <= write_value;
                    `CSR_EENTRY:eentry <= write_value[31:6];
                    `CSR_TID:   tid <= write_value;
                    `CSR_SAVE0: save0 <= write_value;
                    `CSR_SAVE1: save1 <= write_value;
                    `CSR_SAVE2: save2 <= write_value;
                    `CSR_SAVE3: save3 <= write_value;
                endcase
            end
        end
    end

    // External interrupt sampling runs even while handling an exception.
    always @(posedge clk) begin
        if (reset)
            estat_hw <= 8'b0;
        else
            estat_hw <= hw_int_in;
    end

    // Only address exceptions overwrite BADV. Other exceptions preserve it.
    // Software may also update BADV through CSRWR/CSRXCHG.
    always @(posedge clk) begin
        if (reset)
            badv <= 32'b0;
        else if (wb_ex && address_exception)
            badv <= (wb_ecode == `ECODE_ADEF) ? wb_pc : wb_badv;
        else if (csr_write && (csr_num == `CSR_BADV))
            badv <= write_value;
    end

    always @(posedge clk) begin
        if (reset) begin
            tcfg_en <= 1'b0;
            tcfg_periodic <= 1'b0;
            tcfg_initval <= 30'b0;
        end else if (write_tcfg) begin
            tcfg_en <= tcfg_next_value[0];
            tcfg_periodic <= tcfg_next_value[1];
            tcfg_initval <= tcfg_next_value[31:2];
        end
    end

    // Use the newly merged TCFG value on a write, including CSRXCHG masks.
    // In one-shot mode, zero decrements to all ones and then holds (guide 6.4.14).
    always @(posedge clk) begin
        if (reset)
            timer_cnt <= 32'hffff_ffff;
        else if (write_tcfg) begin
            if (tcfg_next_value[0])
                timer_cnt <= {tcfg_next_value[31:2], 2'b0};
            // Disabling TCFG freezes the current value.
        end else if (tcfg_en && (timer_cnt != 32'hffff_ffff)) begin
            if ((timer_cnt == 32'b0) && tcfg_periodic)
                timer_cnt <= {tcfg_initval, 2'b0};
            else
                timer_cnt <= timer_cnt - 32'd1;
        end
    end

    // Timeout is sticky, and wins over a simultaneous TICLR write (guide 6.4.6).
    always @(posedge clk) begin
        if (reset)
            estat_timer <= 1'b0;
        else if (timer_expired)
            estat_timer <= 1'b1;
        else if (clear_timer)
            estat_timer <= 1'b0;
    end
endmodule
