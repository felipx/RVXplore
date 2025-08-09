module pc #(
    parameter int unsigned XLEN = 32
) (
    input             clk_i,
    input             rst_i,
    input             en_i,
    input  [XLEN-1:0] pc_i,
    input  [XLEN-1:0] reset_pc_i,
    output            valid_o,
    output [XLEN-1:0] pc_o
);

    logic [XLEN-1:0] pc_q;
    logic            valid;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            pc_q  <= reset_pc_i;
            valid <= 1'b0;
        end else if (en_i) begin
            pc_q  <= pc_i;
            valid <= 1'b1;
        end else if (!en_i) begin
            valid <= 1'b0;
        end
    end

    assign pc_o    = pc_q;
    assign valid_o = valid;

endmodule
