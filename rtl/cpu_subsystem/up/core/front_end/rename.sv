`include "decode_pkg.sv"

module rename (
    input clk_i,
    input rst_i,
    input save_state_i,
    input valid_i,
    input restore_i,
    input stall_i,
    input decode_pkg::decoded_t decoded_0_i,
    input decode_pkg::decoded_t decoded_1_i,
    output valid_o,
    output ready_o,
    output decode_pkg::renamed_t renamed_0_o,
    output decode_pkg::renamed_t renamed_1_o
);
    logic [5:0] renamed_0_rs1;
    logic [5:0] renamed_0_rs2;
    logic [5:0] renamed_0_rd;
    logic [5:0] old_rd_0;
    logic [5:0] renamed_1_rs1;
    logic [5:0] renamed_1_rs2;
    logic [5:0] renamed_1_rd;
    logic [5:0] old_rd_1;

    logic [5:0]  list_raddr;
    logic [5:0]  list_waddr;
    logic [11:0] list_din;
    logic [11:0] list_dout;
    logic        list_rd;
    logic        list_wr;
    logic        list_full;
    logic        list_empty;

    map_table u_map_table (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .valid_i(valid_i),
        .rs1_0_i(decoded_0_i.rs1),
        .rs2_0_i(decoded_0_i.rs2),
        .rs1_1_i(decoded_1_i.rs1),
        .rs2_1_i(decoded_1_i.rs2),
        .rd_0_i(decoded_0_i.rd),
        .rd_1_i(decoded_1_i.rd),
        .phys_rd_0_i(list_dout[5:0]),
        .phys_rd_1_i(list_dout[11:6]),
        .save_state_i(save_state_i),
        .restore_i(restore_i),
        .phys_rs1_0_o(renamed_0_rs1),
        .phys_rs2_0_o(renamed_0_rs2),
        .old_rd_0_o(old_rd_0),
        .phys_rs1_1_o(renamed_1_rs1),
        .phys_rs2_1_o(renamed_1_rs2),
        .old_rd_1_o(old_rd_1)
    );

    dual_ram32m_fifo u_free_list (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .wr_i(list_wr),
        .rd_i(list_rd),
        .raddr_wr_i('0),
        .din_i(list_din),
        .raddr_i('0),
        .empty_o(),
        .full_o(),
        .raddr_o(),
        .waddr_o(),
        .dout_o(list_dout)
    );

    assign renamed_0_rd = list_dout[5:0];
    assign renamed_1_rd = list_dout[11:6];

    // ------------------------------------------------------------------
    // FSM to manage reset and renaming
    // ------------------------------------------------------------------
    typedef enum logic [1:0] {
        StReset  = 2'h1,
        StRename = 2'h2
    } rename_state_e;

    rename_state_e state_d, state_q;

    logic [5:0] counter_d, counter_q;

    // ------------------------------------------------------------------
    // Sequential logic for state and counters
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state_q   <= StReset;
            counter_q <= 6'd32;
        end else begin
            state_q   <= state_d;
            counter_q <= counter_d;
        end
    end

    // ------------------------------------------------------------------
    // Main combinational logic: FSM and control
    // ------------------------------------------------------------------
    always_comb begin
        state_d   = state_q;
        counter_d = counter_q;

        list_wr  = 1'b0;
        list_rd  = 1'b0;
        list_din = '0;

        unique case (state_q)
            // ----------------------------------------------------------
            // Reset: initialize free list registers
            // ----------------------------------------------------------
            StReset: begin
                list_wr = 1'b1;
                list_din = {counter_q + 1'b1, counter_q};

                counter_d = counter_q + 6'd2;
                if (counter_q == 6'd62) begin
                    counter_d = 6'd32;
                    state_d = StRename;
                end
            end

            // ----------------------------------------------------------
            // Rename: read free-list registers and update map table
            // ----------------------------------------------------------
            StRename: begin
                if (valid_i && !stall_i) begin
                    list_rd = 1'b1;
                end
            end
            default: state_d = state_q;
        endcase
    end

    // ------------------------
    // Pipeline stage
    // ------------------------
    logic [5:0] pipe_renamed_0_rs1;
    logic [5:0] pipe_renamed_0_rs2;
    logic [5:0] pipe_old_rd_0;
    logic [5:0] pipe_renamed_0_rd;
    logic [5:0] pipe_renamed_1_rs1;
    logic [5:0] pipe_renamed_1_rs2;
    logic [5:0] pipe_old_rd_1;
    logic [5:0] pipe_renamed_1_rd;

    logic rename_valid;
    assign rename_valid = (state_q == StRename) && valid_i && !stall_i;

    logic [1:0] skid_ready_out;
    assign ready_o = &skid_ready_out && !stall_i;

    logic [1:0] skid_valid_out;
    assign valid_o = &skid_valid_out;

    pipeline_skid_buffer #(
        .DataWidth(24)
    ) u_rename_0_skid_buffer (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .valid_i(rename_valid),
        .data_i({old_rd_0, renamed_0_rd, renamed_0_rs2, renamed_0_rs1}),
        .ready_o(skid_ready_out[0]),
        .ready_i(!stall_i),
        .valid_o(skid_valid_out[0]),
        .data_o({pipe_old_rd_0, pipe_renamed_0_rd, pipe_renamed_0_rs2, pipe_renamed_0_rs1})
    );

    pipeline_skid_buffer #(
        .DataWidth(24)
    ) u_rename_1_skid_buffer (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .valid_i(rename_valid),
        .data_i({old_rd_1, renamed_1_rd, renamed_1_rs2, renamed_1_rs1}),
        .ready_o(skid_ready_out[1]),
        .ready_i(!stall_i),
        .valid_o(skid_valid_out[1]),
        .data_o({pipe_old_rd_1, pipe_renamed_1_rd, pipe_renamed_1_rs2, pipe_renamed_1_rs1})
    );

    logic [31:0]      pc[2];
    logic [31:0]      imm[2];
    logic [2:0]       funct3[2];
    logic [6:0]       funct7[2];
    logic [11:0]      csr_addr[2];
    logic             csr_imm_valid[2];
    decode_pkg::uop_e uop[2];
    logic             illegal[2];

    always_ff @(posedge clk_i) begin
        pc[0]            <= decoded_0_i.pc;
        imm[0]           <= decoded_0_i.imm;
        funct3[0]        <= decoded_0_i.funct3;
        funct7[0]        <= decoded_0_i.funct7;
        csr_addr[0]      <= decoded_0_i.csr_addr;
        csr_imm_valid[0] <= decoded_0_i.csr_imm_valid;
        uop[0]           <= decoded_0_i.uop;
        illegal[0]       <= decoded_0_i.illegal;

        pc[1]            <= decoded_1_i.pc;
        imm[1]           <= decoded_1_i.imm;
        funct3[1]        <= decoded_1_i.funct3;
        funct7[1]        <= decoded_1_i.funct7;
        csr_addr[1]      <= decoded_1_i.csr_addr;
        csr_imm_valid[1] <= decoded_1_i.csr_imm_valid;
        uop[1]           <= decoded_1_i.uop;
        illegal[1]       <= decoded_1_i.illegal;
    end

    assign renamed_0_o.pc            = pc[0];
    assign renamed_0_o.old_rd        = pipe_old_rd_0;
    assign renamed_0_o.rd            = pipe_renamed_0_rd;
    assign renamed_0_o.rs1           = pipe_renamed_0_rs1;
    assign renamed_0_o.rs2           = pipe_renamed_0_rs2;
    assign renamed_0_o.imm           = imm[0];
    assign renamed_0_o.funct3        = funct3[0];
    assign renamed_0_o.funct7        = funct7[0];
    assign renamed_0_o.csr_addr      = csr_addr[0];
    assign renamed_0_o.csr_imm_valid = csr_imm_valid[0];
    assign renamed_0_o.uop           = uop[0];
    assign renamed_0_o.illegal       = illegal[0];

    assign renamed_1_o.pc            = pc[1];
    assign renamed_1_o.old_rd        = pipe_old_rd_1;
    assign renamed_1_o.rd            = pipe_renamed_1_rd;
    assign renamed_1_o.rs1           = pipe_renamed_1_rs1;
    assign renamed_1_o.rs2           = pipe_renamed_1_rs2;
    assign renamed_1_o.imm           = imm[1];
    assign renamed_1_o.funct3        = funct3[1];
    assign renamed_1_o.funct7        = funct7[1];
    assign renamed_1_o.csr_addr      = csr_addr[1];
    assign renamed_1_o.csr_imm_valid = csr_imm_valid[1];
    assign renamed_1_o.uop           = uop[1];
    assign renamed_1_o.illegal       = illegal[1];

endmodule
