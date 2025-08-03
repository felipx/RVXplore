module async_fifo #(
    parameter int unsigned DataWidth = 32,
    parameter int unsigned AddrWidth = 4
) (
    // wclk interface
    input                 wclk,
    input                 wrst_n,
    input                 winc,
    input [DataWidth-1:0] wdata,
    output                wfull,

    // rclk interface
    input                  rclk,
    input                  rrst_n,
    input                  rinc,
    output                 rempty,
    output [DataWidth-1:0] rdata
);
    logic [AddrWidth-1:0] wptr, rptr;
    logic [AddrWidth-1:0] waddr, raddr;

    async_cmp #(
        .AddrWidth(AddrWidth)
    ) u_async_cmp(
        .wrst_n(wrst_n),
        .wptr(wptr),
        .rptr(rptr),
        .aempty_n(aempty_n),
        .afull_n(afull_n)
    );

    fifo_mem #(
        .DataWidth(DataWidth),
        .AddrWidth(AddrWidth)
    ) u_fifo_mem (
        .wclk(wclk),
        .wclken(winc),
        .waddr(wptr),
        .raddr(rptr),
        .wdata(wdata),
        .rdata(rdata)
    );

    rptr_empty #(
        .AddrWidth(AddrWidth)
    ) u_rptr_empty (
        .rclk(rclk),
        .rrst_n(rrst_n),
        .rinc(rinc),
        .aempty_n(aempty_n),
        .rempty_o(rempty),
        .rptr_o(rptr)
     );

    wptr_full #(
        .AddrWidth(AddrWidth)
    ) u_wptr_full (
        .wclk(wclk),
        .wrst_n(wrst_n),
        .winc(winc),
        .afull_n(afull_n),
        .wfull_o(wfull),
        .wptr_o(wptr)
    );
endmodule
