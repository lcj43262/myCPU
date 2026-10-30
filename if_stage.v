`include "mycpu_head.v"

module IF_stage #(
    parameter BP_ENABLE = 1
)(
    input wire clk,
    input wire reset,
    input wire flush,
    input wire [31:0] flush_target,
    input wire ds_allowin,
    input wire [`BR_BUS_WD-1:0] br_bus,
    input wire [`BP_UPDATE_BUS_WD-1:0] bp_update_bus,
    output wire inst_req_valid,
    input wire inst_req_ready,
    output wire [31:0] inst_req_addr,
    input wire inst_resp_valid,
    output wire inst_resp_ready,
    input wire [31:0] inst_resp_rdata,
    output wire fs_to_ds_valid,
    output wire [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus
);
    reg fs_valid;
    reg [31:0] fs_pc, fs_inst, fs_prediction;
    reg [31:0] fetch_pc, pending_pc, pending_prediction;
    reg pending, discard;
    wire br_redirect;
    wire [31:0] br_target;
    assign {br_redirect, br_target} = br_bus;
    wire redirect = flush || br_redirect;
    wire [31:0] redirect_target = flush ? flush_target : br_target;
    wire predict_taken;
    wire [31:0] predict_target;
    wire bp_update_valid, bp_is_branch, bp_is_conditional, bp_actual_taken;
    wire [31:0] bp_update_pc, bp_update_target;
    assign {bp_update_valid, bp_is_branch, bp_is_conditional, bp_actual_taken,
            bp_update_pc, bp_update_target} = bp_update_bus;
    generate if (BP_ENABLE) begin : gen_bp
        branch_predictor u_predictor(
            .clk(clk), .reset(reset), .lookup_pc(fetch_pc),
            .predict_taken(predict_taken), .predict_target(predict_target),
            .update_valid(bp_update_valid && !flush),
            .update_is_branch(bp_is_branch),
            .update_is_conditional(bp_is_conditional),
            .update_taken(bp_actual_taken), .update_pc(bp_update_pc),
            .update_target(bp_update_target)
        );
    end else begin : gen_no_bp
        assign predict_taken = 1'b0;
        assign predict_target = 32'b0;
    end endgenerate
    wire [31:0] prediction = predict_taken ? predict_target : fetch_pc + 32'd4;
    assign inst_req_valid = !reset && !redirect && !pending && !fs_valid &&
                            fetch_pc[1:0] == 2'b00;
    assign inst_req_addr = fetch_pc;
    assign inst_resp_ready = 1'b1;
    assign fs_to_ds_valid = fs_valid && !redirect && !reset;
    assign fs_to_ds_bus = {fs_prediction, |fs_pc[1:0], fs_inst, fs_pc};

    always @(posedge clk) begin
        if (reset) begin
            fs_valid <= 1'b0;
            fs_pc <= 32'b0;
            fs_inst <= 32'b0;
            fs_prediction <= 32'b0;
            fetch_pc <= 32'h1c000000;
            pending_pc <= 32'b0;
            pending_prediction <= 32'b0;
            pending <= 1'b0;
            discard <= 1'b0;
        end else begin
            if (fs_to_ds_valid && ds_allowin)
                fs_valid <= 1'b0;
            if (inst_req_valid && inst_req_ready) begin
                pending <= 1'b1;
                discard <= 1'b0;
                pending_pc <= fetch_pc;
                pending_prediction <= prediction;
                fetch_pc <= prediction;
            end
            if (inst_resp_valid && pending) begin
                pending <= 1'b0;
                discard <= 1'b0;
                if (!discard && !redirect) begin
                    fs_valid <= 1'b1;
                    fs_pc <= pending_pc;
                    fs_inst <= inst_resp_rdata;
                    fs_prediction <= pending_prediction;
                end
            end
            if (!pending && !fs_valid && !redirect && |fetch_pc[1:0]) begin
                fs_valid <= 1'b1;
                fs_pc <= fetch_pc;
                fs_inst <= 32'b0;
                fs_prediction <= fetch_pc + 32'd4;
                fetch_pc <= fetch_pc + 32'd4;
            end
            if (redirect) begin
                fs_valid <= 1'b0;
                fetch_pc <= redirect_target;
                if (pending && !inst_resp_valid)
                    discard <= 1'b1;
            end
        end
    end
endmodule
