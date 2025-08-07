module mux_one_hot_flat #(
    parameter int unsigned DataWidth = 32,
    parameter int unsigned NumInputs = 4
) (
    input  wire  [NumInputs*DataWidth-1:0] data_i,
    input  wire  [NumInputs-1:0]           sel_i,
    output logic [DataWidth-1:0]           data_o
);

    always_comb begin
        data_o = '0;
        for (int i = 0; i < NumInputs; i++) begin
            if (sel_i[i])
                data_o |= data_i[i*DataWidth +: DataWidth];
        end
    end
endmodule
