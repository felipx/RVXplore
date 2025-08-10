`include "decode_pkg.sv"

module front_end #(
    parameter int unsigned XLEN = 32
) (
    input                        clk_i,
    input                        rst_i,
    input                        en_i,
    input                        stall_i,
    input                        branch_i,
    input [XLEN-1:0]             branch_pc_i,
    input [XLEN-1:0]             reset_pc_i,
    data_res_if.in               cpu_res_i,
    data_req_if.out              cpu_req_o,
    output decode_pkg::renamed_t renamed_o[2],
    output                       rename_valid_o
);
    logic [31:0] fetch_pc;
    logic        fetch_valid;
    logic        stall;

    logic [63:0] instr_pipe;
    logic        valid_pipe;
    logic        skid_ready;

    logic decode_ready;
    logic cpu_res_valid;

    // ------------------------------------------------------------------
    // Instruction fetch unit
    // ------------------------------------------------------------------
    fetch #(
        .XLEN(XLEN)
    ) u_fetch (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .en_i(en_i),
        .stall_i(stall_i & ~skid_ready),
        .branch_i(branch_i),
        .branch_pc_i(branch_pc_i),
        .reset_pc_i(reset_pc_i),
        .valid_o(fetch_valid),
        .pc_o(fetch_pc)
    );

    assign cpu_req_o.addr = fetch_pc;
    assign cpu_req_o.valid = fetch_valid;
    assign cpu_req_o.rd = fetch_valid;
    assign cpu_req_o.wr = 1'b0;
    assign cpu_req_o.data = '0;

    // ------------------------------------------------------------------
    // Fetched instruction pipeline skid buffer
    // ------------------------------------------------------------------
    pipeline_skid_buffer #(
        .DataWidth(64)
    ) u_instr_buffer (
        .clk_i(clk_i),
        .rst_i(rst_i),

        // upstream interface
        .valid_i(cpu_res_valid),
        .data_i(cpu_res_i.data),
        .ready_o(skid_ready),

        // downstream interface
        .ready_i(decode_ready),
        .valid_o(valid_pipe),
        .data_o(instr_pipe)
    );

    // cpu response valid delay
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            cpu_res_valid <= 1'b0;
        end else begin
            cpu_res_valid <= cpu_res_i.valid;
        end
    end

    // ------------------------------------------------------------------
    // Instruction decode units
    // ------------------------------------------------------------------
    decode_pkg::decoded_t dec_o[2];
    logic decode_valid;
    logic rename_ready;

    generate
        for (genvar i=0; i<2; i=i+1) begin : gen_decode_unit
            decode #(
                .XLEN(XLEN)
            ) u_decode_unit (
                .clk_i(clk_i),
                .rst_i(rst_i),

                // Upstream interface (fetch)
                .valid_i(valid_pipe),
                .ready_o(decode_ready),
                .instr_i(instr_pipe[i*32 +: 32]),
                .pc_i('0),

                // Downstream interface (rename / map table)
                .valid_o(decode_valid),
                .ready_i(rename_ready),
                .dec_o(dec_o[i])
            );
        end
    endgenerate

    // ------------------------------------------------------------------
    // Register renaming unit
    // ------------------------------------------------------------------
    rename u_rename_unit (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .save_state_i(1'b0),
        .valid_i(decode_valid),
        .restore_i(1'b0),
        .stall_i(stall_i),
        .decoded_0_i(dec_o[0]),
        .decoded_1_i(dec_o[1]),
        .valid_o(rename_valid_o),
        .ready_o(rename_ready),
        .renamed_0_o(renamed_o[0]),
        .renamed_1_o(renamed_o[1])
    );

endmodule
