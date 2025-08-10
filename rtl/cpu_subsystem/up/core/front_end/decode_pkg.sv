package decode_pkg;

    // --------------------------------------------------
    // Enumeration of instruction micro-operations
    // --------------------------------------------------
    typedef enum logic [2:0] {
        UOP_ALU,
        UOP_LOAD,
        UOP_STORE,
        UOP_BRANCH,
        UOP_JUMP,
        UOP_CSR,
        UOP_SYS
    } uop_e;

    // --------------------------------------------------
    // Named opcode values for decoding
    // --------------------------------------------------
    typedef enum logic [6:0] {
        OPC_LUI      = 7'b0110111,
        OPC_AUIPC    = 7'b0010111,
        OPC_JAL      = 7'b1101111,
        OPC_JALR     = 7'b1100111,
        OPC_BRANCH   = 7'b1100011,
        OPC_LOAD     = 7'b0000011,
        OPC_STORE    = 7'b0100011,
        OPC_OP_IMM   = 7'b0010011,
        OPC_OP       = 7'b0110011,
        OPC_MISC_MEM = 7'b0001111,
        OPC_SYSTEM   = 7'b1110011
    } opcode_e;

    // --------------------------------------------------
    // Main decoded instruction bundle
    // --------------------------------------------------
    typedef struct packed {
        logic [31:0] pc;
        logic [5:0]  rd;
        logic [5:0]  rs1;
        logic [5:0]  rs2;
        logic [31:0] imm;
        logic [2:0]  funct3;
        logic [6:0]  funct7;
        logic [11:0] csr_addr;
        logic        csr_imm_valid;
        uop_e        uop;
        logic        illegal;
    } decoded_t;

    // --------------------------------------------------
    // Main renamed instruction bundle
    // --------------------------------------------------
    typedef struct packed {
        logic [31:0] pc;
        logic [5:0]  old_rd;
        logic [5:0]  rd;
        logic [5:0]  rs1;
        logic [5:0]  rs2;
        logic [31:0] imm;
        logic [2:0]  funct3;
        logic [6:0]  funct7;
        logic [11:0] csr_addr;
        logic        csr_imm_valid;
        uop_e        uop;
        logic        illegal;
    } renamed_t;

endpackage : decode_pkg
