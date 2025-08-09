module fetch #(
    parameter int unsigned XLEN = 32
) (
    input             clk_i,
    input             rst_i,
    input             en_i,
    input             stall_i,
    input             branch_i,
    input  [XLEN-1:0] branch_pc_i,
    input  [XLEN-1:0] reset_pc_i,
    output            valid_o,
    output [XLEN-1:0] pc_o
);

    logic [XLEN-1:0] pc_next;
    logic [XLEN-1:0] pc_out;
    logic            pc_valid;
    logic            valid_pipe;

    // ------------------------------------------------------------------
    // Program Counter register
    // ------------------------------------------------------------------
    pc #(
        .XLEN(XLEN)
    ) u_pc (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .en_i(en_i & ~stall_i),
        .pc_i(pc_next),
        .reset_pc_i(reset_pc_i),
        .valid_o(pc_valid),
        .pc_o(pc_out)
    );

    assign pc_next = branch_i ? branch_pc_i : (pc_out + 32'h8);

    // ------------------------------------------------------------------
    // 1‑deep skid buffer (elastic pipeline register)
    // ------------------------------------------------------------------
    pipeline_skid_buffer #(
        .DataWidth(XLEN)
    ) u_pc_pipe_buffer (
        .clk_i(clk_i),
        .rst_i(rst_i),

        // upstream interface (producer = NEXT‑PC logic)
        .valid_i(pc_valid & ~stall_i),
        .data_i(pc_out),
        .ready_o(/* unused */),

        // downstream interface (consumer = PC register)
        .ready_i(~stall_i),
        .valid_o(valid_pipe),
        .data_o(pc_o)
    );

    assign valid_o = valid_pipe;

endmodule
