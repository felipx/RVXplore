`include "decode_pkg.sv"

module decode #(
    parameter int unsigned XLEN = 32
) (
    input  logic clk_i,
    input  logic rst_i,

    // Upstream interface (fetch)
    input  logic            valid_i,
    output logic            ready_o,
    input  logic [31:0]     instr_i,
    input  logic [XLEN-1:0] pc_i,

    // Downstream interface (rename / map table)
    output logic                 valid_o,
    input  logic                 ready_i,
    output decode_pkg::decoded_t dec_o
);

    import decode_pkg::*;

    // ------------------------
    // Combinational decoding
    // ------------------------
    decoded_t dec_c;

    logic [6:0] opcode;
    logic [5:0] rd;
    logic [2:0] funct3;
    logic [5:0] rs1;
    logic [5:0] rs2;
    logic [6:0] funct7;

    assign opcode = instr_i[6:0];
    assign rd     = {1'b0, instr_i[11:7]};
    assign funct3 = instr_i[14:12];
    assign rs1    = {1'b0, instr_i[19:15]};
    assign rs2    = {1'b0, instr_i[24:20]};
    assign funct7 = instr_i[31:25];

    function automatic logic [XLEN-1:0] imm_i_type(input logic [XLEN-1:0] instr);
        return {{20{instr[31]}}, instr[31:20]};
    endfunction

    function automatic logic [XLEN-1:0] imm_s_type(input logic [XLEN-1:0] instr);
        return {{20{instr[31]}}, instr[31:25], instr[11:7]};
    endfunction

    function automatic logic [XLEN-1:0] imm_b_type(input logic [XLEN-1:0] instr);
        return {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    endfunction

    function automatic logic [XLEN-1:0] imm_u_type(input logic [XLEN-1:0] instr);
        return {instr[31:12], 12'b0};
    endfunction

    function automatic logic [XLEN-1:0] imm_j_type(input logic [XLEN-1:0] instr);
        return {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    endfunction

    always_comb begin
        dec_c         = '0;
        dec_c.pc      = pc_i;
        dec_c.rd      = rd;
        dec_c.rs1     = rs1;
        dec_c.rs2     = rs2;
        dec_c.funct3  = funct3;
        dec_c.funct7  = funct7;
        dec_c.illegal = 1'b0;
        dec_c.uop     = UOP_ALU; // default

        unique case (opcode)
            OPC_OP: begin
                dec_c.imm = 32'h0;
                dec_c.uop = UOP_ALU;
            end

            OPC_OP_IMM: begin
                dec_c.imm = imm_i_type(instr_i);
                dec_c.uop = UOP_ALU;
            end

            OPC_LOAD: begin
                dec_c.imm = imm_i_type(instr_i);
                dec_c.uop = UOP_LOAD;
            end

            OPC_STORE: begin
                dec_c.imm = imm_s_type(instr_i);
                dec_c.uop = UOP_STORE;
            end

            OPC_BRANCH: begin
                dec_c.imm = imm_b_type(instr_i);
                dec_c.uop = UOP_BRANCH;
            end

            OPC_JAL: begin
                dec_c.imm = imm_j_type(instr_i);
                dec_c.uop = UOP_JUMP;
            end

            OPC_JALR: begin
                dec_c.imm = imm_i_type(instr_i);
                dec_c.uop = UOP_JUMP;
            end

            OPC_SYSTEM: begin
                dec_c.uop       = UOP_CSR;
                dec_c.csr_addr  = instr_i[31:20];
                if (funct3[2]) begin
                    dec_c.csr_imm_valid = 1'b1;
                    dec_c.imm           = {27'd0, rs1}; // zimm in rs1 field
                    dec_c.rs1           = 6'd0;
                end else begin
                    dec_c.csr_imm_valid = 1'b0;
                    dec_c.imm           = 32'h0;
                end
            end

            OPC_LUI, OPC_AUIPC: begin
                dec_c.imm = imm_u_type(instr_i);
                dec_c.uop = UOP_ALU;
            end

            default: begin
                dec_c.illegal = 1'b1;
            end
        endcase
    end

    // ------------------------
    // Pipeline stage
    // ------------------------
    pipeline_skid_buffer #(
        .DataWidth($bits(decoded_t))
    ) u_decode_skid_buffer (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .valid_i(valid_i),
        .data_i(dec_c),
        .ready_o(ready_o),
        .ready_i(ready_i),
        .valid_o(valid_o),
        .data_o(dec_o)
    );

endmodule
