module divider(
    input wire clk,
    input wire reset,
    input wire start,
    input wire consume,
    input wire signed_mode,
    input wire [31:0] dividend,
    input wire [31:0] divisor,
    output reg busy,
    output reg done,
    output reg [31:0] quotient,
    output reg [31:0] remainder
);
    reg [31:0] q;//商
    reg [32:0] r;//余数
    reg [31:0] d;
    reg [5:0] count;
    reg negate_q;
    reg negate_r;
    wire [32:0] shifted_r = {r[31:0], q[31]};
    wire subtract = shifted_r >= {1'b0, d};//是否够减
    wire [32:0] next_r = subtract ? shifted_r - {1'b0, d} : shifted_r;
    wire [31:0] next_q = {q[30:0], subtract};

    always @(posedge clk) begin
        if (reset) begin
            busy <= 1'b0;
            done <= 1'b0;
            quotient <= 32'b0;
            remainder <= 32'b0;
            q <= 32'b0;
            r <= 33'b0;
            d <= 32'b0;
            count <= 6'b0;
            negate_q <= 1'b0;
            negate_r <= 1'b0;
        end else if (consume) begin
            done <= 1'b0;
        end else if (start && !busy && !done) begin
            q <= signed_mode && dividend[31] ? -dividend : dividend;
            d <= signed_mode && divisor[31] ? -divisor : divisor;
            r <= 33'b0;
            count <= 6'd32;
            negate_q <= signed_mode && (dividend[31] ^ divisor[31]);
            negate_r <= signed_mode && dividend[31];
            busy <= 1'b1;
        end else if (busy) begin
            q <= next_q;
            r <= next_r;
            count <= count - 1'b1;
            if (count == 6'd1) begin
                quotient <= negate_q ? -next_q : next_q;
                remainder <= negate_r ? -next_r[31:0] : next_r[31:0];
                busy <= 1'b0;
                done <= 1'b1;
            end
        end
    end
endmodule
