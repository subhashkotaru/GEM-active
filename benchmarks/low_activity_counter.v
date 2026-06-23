module low_activity_counter (
    input clk,
    input rst,
    input en,
    input [31:0] din,
    output reg [31:0] out
);
    reg [31:0] cold_regs [0:255];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            out <= 0;
            for (i = 0; i < 256; i = i + 1)
                cold_regs[i] <= 0;
        end else begin
            if (en) begin
                out <= din + 1;
            end
        end
    end
endmodule
