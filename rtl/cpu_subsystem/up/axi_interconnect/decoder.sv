module decoder #(
    parameter int unsigned NumSlaves = 2,
    parameter int unsigned AddrWidth = 32,
    parameter logic [AddrWidth-1:0] MemoryMap[NumSlaves][2] = '{
        {32'h0000_0000, 32'h0001_FFFF},
        {32'h0002_0000, 32'h0002_FFFF}
    },
    localparam int unsigned SelWidth = $clog2(NumSlaves) == 0 ? 1 : $clog2(NumSlaves) // TODO: delete?
) (
    input  [AddrWidth-1:0]         addr_i,
    output [SelWidth-1:0] sel_o,
    output                         error_o
);
    logic [NumSlaves-1:0]         slave_selected;
    logic [SelWidth-1:0] sel;
    logic                         error;

    assign error_o = error;
    assign sel_o   = sel;

    // Decode logic
    always_comb begin
        slave_selected = '0;
        error = 1'b1;

        for (int i=0; i<NumSlaves; i=i+1) begin
            if (addr_i >= MemoryMap[i][0] && addr_i <= MemoryMap[i][1]) begin
                slave_selected[i] = 1'b1;
                error = 1'b0;
            end
        end
    end

    // Encode slave ID (one-hot to binary)
    always_comb begin
        sel = '0;
        foreach (slave_selected[i]) begin
            if (slave_selected[i]) begin
                sel = i;
            end
        end
    end
endmodule
