module rptr_empty #(
    parameter int unsigned AddrWidth = 4
) (
    input                  rclk,
    input                  rrst_n,
    input                  rinc,
    input                  aempty_n,
    output                 rempty_o,
    output [AddrWidth-1:0] rptr_o
);
    logic [AddrWidth-1:0] rptr, rbin;
    logic                 rempty, rempty2;
    logic [AddrWidth-1:0] rgnext, rbnext;

    assign rptr_o = rptr;
    assign rempty_o = rempty;

    // graystyle pointer
    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin <= 0;
            rptr <= 0;
        end else begin
            rbin <= rbnext;
            rptr <= rgnext;
        end
    end

    // increment the binary count if not empty
    assign rbnext = !rempty ? rbin + rinc : rbin;
    // binary-to-gray conversion
    assign rgnext = (rbnext >> 1) ^ rbnext;

    always_ff @(posedge rclk or negedge aempty_n) begin
        if (!aempty_n) begin
            {rempty,rempty2} <= 2'b11;
        end else begin
            {rempty,rempty2} <= {rempty2,~aempty_n};
        end
    end
endmodule
