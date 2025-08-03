module multiplexer
#(
    parameter int unsigned DataWidth  = 0,
    parameter int unsigned NumInputs = 0,

    localparam int unsigned TotalWidth = DataWidth * NumInputs,
    localparam int unsigned SelWidth = (NumInputs > 1) ? $clog2(NumInputs) : 1
)
(
    input  wire [TotalWidth-1:0] data_i,
    input  wire [SelWidth-1:0]   sel_i,
    output reg  [DataWidth-1:0]  data_o
);

    always_comb begin
        data_o = data_i[(sel_i * DataWidth) +: DataWidth];
    end

endmodule
