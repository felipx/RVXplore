module comparator #(
    parameter int unsigned DataWidth = 32
) (
    input  [DataWidth-1:0] a_i,
    input  [DataWidth-1:0] b_i,
    output                 comp_o
);
    assign comp_o = (a_i == b_i) ? 1'b1 : 1'b0;

endmodule
