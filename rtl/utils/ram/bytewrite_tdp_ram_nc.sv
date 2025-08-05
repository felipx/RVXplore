module bytewrite_tdp_ram_nc #(
    parameter int unsigned  NumCol    = 4,
    parameter int unsigned  ColWidth  = 8,
    parameter int unsigned  AddrWidth = 10,
    localparam int unsigned DataWidth = NumCol*ColWidth
) (
    // Port-A
    input                      clkA,
    input                      enaA,
    input      [NumCol-1:0]    weA,
    input      [AddrWidth-1:0] addrA,
    input      [DataWidth-1:0] dinA,
    output reg [DataWidth-1:0] doutA,

    // Port-B
    input                      clkB,
    input                      enaB,
    input      [NumCol-1:0]    weB,
    input      [AddrWidth-1:0] addrB,
    input      [DataWidth-1:0] dinB,
    output reg [DataWidth-1:0] doutB
);
    localparam int unsigned Size = 2**AddrWidth;

    // Core memory
    reg [DataWidth-1:0] ram_block [Size] /* synthesis syn_ramstyle=no_rw_check*/;

    initial begin
        for (int unsigned i=0; i<Size; i=i+1)
            ram_block[i] = '0;
    end

    // Port-A Operation
    generate
        genvar i;
        for(i=0; i<NumCol; i=i+1) begin
            always @ (posedge clkA) begin
                if(enaA) begin
                    if(weA[i]) begin
                        ram_block[addrA][i*ColWidth +: ColWidth] <= dinA[i*ColWidth +: ColWidth];
                    end
                end
            end
        end
    endgenerate

    always @ (posedge clkA) begin
        if(enaA) begin
            if (~|weA)
                doutA <= ram_block[addrA];
        end
    end


    // Port-B Operation:
    generate
        for(i=0; i<NumCol; i=i+1) begin
            always @ (posedge clkB) begin
                if(enaB) begin
                    if(weB[i]) begin
                        ram_block[addrB][i*ColWidth +: ColWidth] <= dinB[i*ColWidth +: ColWidth];
                    end
                end
            end
        end
    endgenerate

    always @ (posedge clkB) begin
        if(enaB) begin
            if (~|weB)
                doutB <= ram_block[addrB];
        end
    end

endmodule
