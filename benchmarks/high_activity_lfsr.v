module high_activity_lfsr (
    input clk,
    input rst,
    output reg [255:0] state
);
    always @(posedge clk) begin
        if (rst) begin
            state <= 256'h1;
        end else begin
            state <= {state[254:0], state[255] ^ state[21] ^ state[3] ^ state[0]};
        end
    end
endmodule
