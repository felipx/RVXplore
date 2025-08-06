module dp_memory_bank #(
    parameter int unsigned SizeKiB = 64,

    // data width in bits
    parameter int unsigned DataWidth = 128,

    // number of bytes per address
    localparam int unsigned NumCol = DataWidth/8,

    // number of blocks (columns)
    localparam int unsigned NumBlocks = DataWidth/32,

    // Number of banks (rows)
    localparam int unsigned NumBanks = (SizeKiB*1024)/(NumCol*1024),

    localparam int unsigned AddrWidth = $clog2(SizeKiB*1024/(NumCol))
) (
    // Port A interface
    input                  clkA_i,
    input                  enA_i,
    input  [NumCol-1:0]    weA_i,
    input  [AddrWidth-1:0] addrA_i,
    input  [DataWidth-1:0] dinA_i,
    output [DataWidth-1:0] doutA_o,

    // Port B interface
    input                  clkB_i,
    input                  enB_i,
    input  [NumCol-1:0]    weB_i,
    input  [AddrWidth-1:0] addrB_i,
    input  [DataWidth-1:0] dinB_i,
    output [DataWidth-1:0] doutB_o
);

    logic [DataWidth-1:0] doutA [NumBanks];
    logic [DataWidth-1:0] doutB [NumBanks];

    // ------------------------------------------------------------------
    // Memory Bank. Each memory is 1024 KiB.
    // ------------------------------------------------------------------
    generate
        for (genvar bank=0; bank<NumBanks; bank=bank+1) begin : gen_ram_banks
            for (genvar i=0; i<NumBlocks; i=i+1) begin : gen_ram_col
                bytewrite_tdp_ram_nc #(
                    .NumCol   (4),
                    .ColWidth (8),
                    .AddrWidth(10)
                ) u_dp_ram (
                    .clkA(clkA_i),
                    .enaA(enA_i & ((NumBanks > 1) ? (addrA_i[AddrWidth-1:10] == bank) : 1'b1)),
                    .weA(weA_i[i*4 +: 4]),
                    .addrA(addrA_i[9:0]),
                    .dinA(dinA_i[i*32 +: 32]),
                    .doutA(doutA[bank][i*32 +: 32]),
                    .clkB(clkB_i),
                    .enaB(enB_i & ((NumBanks > 1) ? (addrB_i[AddrWidth-1:10] == bank) : 1'b1)),
                    .weB(weB_i[i*4 +: 4]),
                    .addrB(addrB_i[9:0]),
                    .dinB(dinB_i[i*32 +: 32]),
                    .doutB(doutB[bank][i*32 +: 32])
                );
            end
        end
    endgenerate

    // ------------------------------------------------------------------
    // Output multiplexer
    // ------------------------------------------------------------------
    if (NumBanks > 1) begin : gen_mux_output
        mux #(
            .DataWidth(DataWidth),
            .NumInputs(NumBanks)
        ) muxA (
            .data_i(doutA),
            .sel_i(addrA_i[AddrWidth-1:10]),
            .data_o(doutA_o)
        );

        mux #(
            .DataWidth(DataWidth),
            .NumInputs(NumBanks)
        ) muxB (
            .data_i(doutB),
            .sel_i(addrB_i[AddrWidth-1:10]),
            .data_o(doutB_o)
        );
    end else begin : gen_direct_output
        assign doutA_o = doutA[0];
        assign doutB_o = doutB[0];
    end

endmodule
