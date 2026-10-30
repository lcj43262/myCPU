module cache_sram #(
    parameter ADDR_BITS = 32,
    parameter READ_ONLY = 0
)(
    input wire clk,
    input wire reset,
    input wire req_valid,
    output wire req_ready,
    input wire [31:0] req_addr,
    input wire [3:0] req_wstrb,
    input wire [31:0] req_wdata,
    output wire resp_valid,
    input wire resp_ready,
    output reg [31:0] resp_rdata,
    output wire ram_en,
    output wire [3:0] ram_we,
    output wire [31:0] ram_addr,
    output wire [31:0] ram_wdata,
    input wire [31:0] ram_rdata
);
    localparam [2:0] IDLE=3'd0, LOOKUP=3'd1, READ_REQ=3'd2, READ_WAIT=3'd3,
                     WRITE_REQ=3'd4, WRITE_WAIT=3'd5, RESPONSE=3'd6;
    reg [2:0] state;
    reg [63:0] valid;
    reg [ADDR_BITS-11:0] tags [0:63];
    reg [31:0] words [0:255];
    reg [31:0] addr_q, wdata_q;
    reg [3:0] wstrb_q;
    reg [1:0] beat;
    wire [5:0] index = addr_q[9:4];
    wire [ADDR_BITS-11:0] tag = addr_q[ADDR_BITS-1:10];
    wire [7:0] word_index = addr_q[9:2];
    wire uncached = (addr_q & 32'h1fff0000) == 32'h1faf0000;
    wire hit = valid[index] && tags[index] == tag;
    wire [31:0] mask = {{8{wstrb_q[3]}}, {8{wstrb_q[2]}},
                        {8{wstrb_q[1]}}, {8{wstrb_q[0]}}};
    assign req_ready = state == IDLE && !reset;
    assign resp_valid = state == RESPONSE && !reset;
    assign ram_en = !reset && (state == READ_REQ || state == WRITE_REQ);
    assign ram_we = state == WRITE_REQ && !reset ? wstrb_q : 4'b0;
    assign ram_addr = state == READ_REQ && !uncached ?
                      {addr_q[31:4], beat, 2'b0} : addr_q;
    assign ram_wdata = wdata_q;

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            valid <= 64'b0;
            resp_rdata <= 32'b0;
            addr_q <= 32'b0;
            wdata_q <= 32'b0;
            wstrb_q <= 4'b0;
            beat <= 2'b0;
        end else begin
            case (state)
                IDLE: if (req_valid && req_ready) begin
                    addr_q <= req_addr;
                    wdata_q <= req_wdata;
                    wstrb_q <= READ_ONLY ? 4'b0 : req_wstrb;
                    state <= LOOKUP;
                end
                LOOKUP: begin
                    if (|wstrb_q) begin
                        if (!uncached && hit)
                            words[word_index] <= (words[word_index] & ~mask) |
                                                 (wdata_q & mask);
                        state <= WRITE_REQ;
                    end else if (!uncached && hit) begin
                        resp_rdata <= words[word_index];
                        state <= RESPONSE;
                    end else begin
                        beat <= 2'b0;
                        if (!uncached)
                            valid[index] <= 1'b0;
                        state <= READ_REQ;
                    end
                end
                READ_REQ: state <= READ_WAIT;
                READ_WAIT: begin
                    if (uncached) begin
                        resp_rdata <= ram_rdata;
                        state <= RESPONSE;
                    end else begin
                        words[{index,beat}] <= ram_rdata;
                        if (beat == addr_q[3:2])
                            resp_rdata <= ram_rdata;
                        if (beat == 2'd3) begin
                            tags[index] <= tag;
                            valid[index] <= 1'b1;
                            state <= RESPONSE;
                        end else begin
                            beat <= beat + 2'd1;
                            state <= READ_REQ;
                        end
                    end
                end
                WRITE_REQ: state <= WRITE_WAIT;
                WRITE_WAIT: begin
                    resp_rdata <= 32'b0;
                    state <= RESPONSE;
                end
                RESPONSE: if (resp_ready)
                    state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
