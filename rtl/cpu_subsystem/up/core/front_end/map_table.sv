// Register Rename Map Table
// File: map_table.sv

module map_table #(
    localparam int unsigned NumRegs  = 64,
    localparam int unsigned RegWidth = $clog2(NumRegs)
) (
    input                 clk_i,
    input                 rst_i,
    input                 valid_i,
    input  [5:0]          rs1_0_i,
    input  [5:0]          rs2_0_i,
    input  [5:0]          rs1_1_i,
    input  [5:0]          rs2_1_i,
    input  [5:0]          rd_0_i,
    input  [5:0]          rd_1_i,
    input  [RegWidth-1:0] phys_rd_0_i,
    input  [RegWidth-1:0] phys_rd_1_i,
    input                 save_state_i,
    input                 restore_i,
    output [RegWidth-1:0] phys_rs1_0_o,
    output [RegWidth-1:0] phys_rs2_0_o,
    output [RegWidth-1:0] old_rd_0_o,
    output [RegWidth-1:0] phys_rs1_1_o,
    output [RegWidth-1:0] phys_rs2_1_o,
    output [RegWidth-1:0] old_rd_1_o
);

    logic [31:0]              we;
    logic [4:0]               addrA;
    logic [4:0]               addrB;
    logic [RegWidth-1:0]      di[32];
    logic [RegWidth-1:0]      dout[32];
    logic [(32*RegWidth)-1:0] map_out;


    //assign map_out = {dout[31],dout[30],dout[29],dout[28],dout[27],dout[26],dout[25],dout[24],
    //                  dout[23],dout[22],dout[21],dout[20],dout[19],dout[18],dout[17],dout[16],
    //                  dout[15],dout[14],dout[13],dout[12],dout[11],dout[10],dout[9],dout[8],
    //                  dout[7],dout[6],dout[5],dout[4],dout[3],dout[2],dout[1],dout[0]};

    // ------------------------------------------------------------------
    // Mapping for rs1 and rs2
    // ------------------------------------------------------------------
    // Instruction 0. No forwarding
    assign phys_rs1_0_o = dout[rs1_0_i];
    assign phys_rs2_0_o = dout[rs2_0_i];
    assign old_rd_0_o   = dout[rd_0_i];
    //assign phys_rs1_0_o = map_out[rs1_0_i * RegWidth +: RegWidth];
    //assign phys_rs2_0_o = map_out[rs2_0_i * RegWidth +: RegWidth];
    // Instruction 1. Forwarding if rs1 == rd and/or rs2 == rd
    assign phys_rs1_1_o = (rs1_1_i == rd_0_i) ? phys_rd_0_i : dout[rs1_1_i];
    assign phys_rs2_1_o = (rs2_1_i == rd_0_i) ? phys_rd_0_i : dout[rs2_1_i];
    assign old_rd_1_o   = (rd_1_i == rd_0_i)  ? phys_rd_0_i : dout[rd_1_i];

    // ------------------------------------------------------------------
    // Map Table Storage
    // Each physical register mapping is stored in a 6-bit-wide word
    // using 3 RAM32M ports. For 32 entries (32 arch registers), 32
    // instances of RAM32M are used. Only DOA-DOC are used for read; DOD
    // is unused.
    // Write input addressed by ADDRD, read addressed by ADDRB
    // ------------------------------------------------------------------
    generate
        for (genvar i=0; i<32; i=i+1) begin : gen_register_map_rams
            RAM32M #(
               .INIT_A(64'h0000000000000000), // Initial contents of A Port
               .INIT_B(64'h0000000000000000), // Initial contents of B Port
               .INIT_C(64'h0000000000000000), // Initial contents of C Port
               .INIT_D(64'h0000000000000000)  // Initial contents of D Port
            ) RAM32M_inst (
               .DOA(dout[i][1:0]),            // Read output part 0
               .DOB(dout[i][3:2]),            // Read output part 1
               .DOC(dout[i][5:4]),            // Read output part 2
               .DOD(/* unused */),            // Read/write port D 2-bit output
               .ADDRA(addrA),                 // Read address
               .ADDRB(addrA),                 // Read address
               .ADDRC(addrA),                 // Read address
               .ADDRD(addrB),                 // Write address
               .DIA(di[i][1:0]),              // Write input part 0
               .DIB(di[i][3:2]),              // Write input part 1
               .DIC(di[i][5:4]),              // Write input part 2
               .DID(2'b00),                   // Write input part 3
               .WCLK(clk_i),                  // Write clock input
               .WE(we[i])                     // Write enable input
            );
        end
    endgenerate

    // ------------------------------------------------------------------
    // FSM to manage mapping, checkpointing, and recovery
    // ------------------------------------------------------------------
    typedef enum logic [3:0] {
        StReset    = 4'h1,
        StMap      = 4'h2,
        StSaveMap  = 4'h4,
        StRecovery = 4'h8
    } map_table_state_e;

    map_table_state_e state_d, state_q;

    logic [4:0] counter_d, counter_q;
    logic [4:0] checkpoint_d, checkpoint_q;

    // ------------------------------------------------------------------
    // Sequential logic for state and counters
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state_q      <= StReset;
            counter_q    <= '0;
            checkpoint_q <= 5'd1;
        end else begin
            state_q      <= state_d;
            counter_q    <= counter_d;
            checkpoint_q <= checkpoint_d;
        end
    end

    // ------------------------------------------------------------------
    // Main combinational logic: FSM and control
    // ------------------------------------------------------------------
    always_comb begin
        state_d      = state_q;
        checkpoint_d = checkpoint_q;
        counter_d    = counter_q;

        we    = '0;
        addrA = '0;
        addrB = '0;

        for (int i=0; i<32; i=i+1) begin
            di[i] = '0;
        end

        unique case (state_q)
            // ----------------------------------------------------------
            // Reset: initialize each logical reg to physical = logical
            // ----------------------------------------------------------
            StReset: begin
                we[counter_q] = '1;
                //addrB         = counter_q;
                di[counter_q] = {1'b0, counter_q};

                counter_d = counter_q + 1'b1;
                if (counter_q == 5'd31) begin
                    counter_d = '0;
                    state_d = StMap;
                end
            end

            // ----------------------------------------------------------
            // Normal rename update (map architectural rd_i to phys_rd_i)
            // ----------------------------------------------------------
            StMap: begin
                addrA      = '0;
                addrB      = '0;
                if (valid_i) begin
                    if (rd_0_i != rd_1_i) begin
                        we[rd_0_i] = 1'b1;
                        we[rd_1_i] = 1'b1;
                        di[rd_0_i] = phys_rd_0_i;
                        di[rd_1_i] = phys_rd_1_i;
                    end else begin
                        we[rd_1_i] = 1'b1;
                        di[rd_1_i] = phys_rd_1_i;
                    end
                end

                if (save_state_i) begin
                    state_d = StSaveMap;
                end else if (restore_i) begin
                    state_d = StRecovery;
                end
            end

            // ----------------------------------------------------------
            // Save the current map state into checkpoint slot
            // ----------------------------------------------------------
            StSaveMap: begin
                we    = '1;
                addrA = '0;
                addrB = checkpoint_q;

                for (int i=0; i<32; i=i+1) begin
                    di[i] = dout[i];
                end

                checkpoint_d = checkpoint_q + 1'b1;
                state_d = StMap;
            end

            // ----------------------------------------------------------
            // Restore map from checkpoint
            // ----------------------------------------------------------
            StRecovery: begin
                addrA  = checkpoint_q;
                addrB = '0;
                we    = '1;

                for (int i=0; i<32; i=i+1) begin
                    di[i] = dout[i];
                end

                checkpoint_d = checkpoint_q - 1'b1;

                state_d = StMap;
            end
            default: state_d = StReset;
        endcase
    end

endmodule
