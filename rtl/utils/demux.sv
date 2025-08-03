module demux #(
    parameter int unsigned DataWidth  = 32,
    parameter int unsigned NumOutputs = 8,
    localparam int unsigned SelWidth = (NumOutputs > 1) ? $clog2(NumOutputs) : 1
) (
    input  [DataWidth-1:0] data_i,
    input  [SelWidth-1:0]  sel_i,
    output [DataWidth-1:0] data_o [NumOutputs]
);

    logic [DataWidth-1:0] dout [NumOutputs];

    always_comb begin
        for (int i = 0; i < NumOutputs; i++) begin
            dout[i] = '0;
        end
        dout[sel_i] = data_i;
    end

    assign data_o = dout;

endmodule
