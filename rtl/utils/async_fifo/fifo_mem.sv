module fifo_mem #(
    parameter int unsigned DataWidth = 8,
    parameter int unsigned AddrWidth = 4
) (
    input                  wclk,
    input                  wclken,
    input  [AddrWidth-1:0] waddr,
    input  [AddrWidth-1:0] raddr,
    input  [DataWidth-1:0] wdata,
    output [DataWidth-1:0] rdata
);
    localparam int unsigned Size = 1 << AddrWidth;

    logic [DataWidth-1:0] mem [Size];

    initial begin
        for (int unsigned i=0; i<Size; i=i+1)
            mem[i] = '0;
    end

    always_ff @(posedge wclk) begin
        if (wclken) begin
            mem[waddr] <= wdata;
        end
    end

    assign rdata = mem[raddr];
endmodule
