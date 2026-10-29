// Tagged direct-mapped BTB with per-branch two-bit direction counters.
module branch_predictor #(
    parameter INDEX_BITS = 6
)(
    input wire clk,
    input wire reset,
    input wire [31:0] lookup_pc,
    output wire predict_taken,
    output wire [31:0] predict_target,
    input wire update_valid,
    input wire update_is_branch,
    input wire update_is_conditional,
    input wire update_taken,
    input wire [31:0] update_pc,
    input wire [31:0] update_target
);
    localparam ENTRIES = 1 << INDEX_BITS;
    localparam TAG_BITS = 30 - INDEX_BITS;
    reg valid [0:ENTRIES-1];
    reg [TAG_BITS-1:0] tags [0:ENTRIES-1];
    reg [31:0] targets [0:ENTRIES-1];
    reg conditional [0:ENTRIES-1];
    reg [1:0] counters [0:ENTRIES-1];
    wire [INDEX_BITS-1:0] lookup_index = lookup_pc[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0] lookup_tag = lookup_pc[31:INDEX_BITS+2];
    wire [INDEX_BITS-1:0] update_index = update_pc[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0] update_tag = update_pc[31:INDEX_BITS+2];
    wire update_hit = valid[update_index] && (tags[update_index] == update_tag);

    assign predict_taken = !reset && (lookup_pc[1:0] == 2'b00) &&
                           valid[lookup_index] && (tags[lookup_index] == lookup_tag) &&
                           (!conditional[lookup_index] || counters[lookup_index][1]);
    assign predict_target = targets[lookup_index];

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < ENTRIES; i = i + 1)
                valid[i] <= 1'b0;
        end else if (update_valid) begin
            if (update_is_branch) begin
                valid[update_index] <= 1'b1;
                tags[update_index] <= update_tag;
                targets[update_index] <= update_target;
                conditional[update_index] <= update_is_conditional;
                if (!update_is_conditional)
                    counters[update_index] <= 2'b11;
                else if (!update_hit || !conditional[update_index])
                    counters[update_index] <= update_taken ? 2'b10 : 2'b01;
                else if (update_taken && counters[update_index] != 2'b11)
                    counters[update_index] <= counters[update_index] + 2'b01;
                else if (!update_taken && counters[update_index] != 2'b00)
                    counters[update_index] <= counters[update_index] - 2'b01;
            end else if (update_hit) begin
                valid[update_index] <= 1'b0;
            end
        end
    end
endmodule
