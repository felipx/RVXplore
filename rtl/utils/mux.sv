module mux #(
    parameter int unsigned DataWidth = 32,
    parameter int unsigned NumInputs = 8,
    localparam int unsigned SelWidth = (NumInputs > 1) ? $clog2(NumInputs) : 1
    ) (
        input  [DataWidth-1:0] data_i [NumInputs],
        input  [SelWidth-1:0]  sel_i,
        output [DataWidth-1:0] data_o
    );

    assign data_o = data_i[sel_i];
endmodule
