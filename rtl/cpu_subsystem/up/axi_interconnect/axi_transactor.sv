`include "axi_config.svh"

module axi_transactor #(
    parameter int unsigned AxiBusWidth = 128,
    parameter int unsigned FifoAddrWidth = 6
) (
    // inport interface
    input wclk_i,
    input wrst_n,
    axi_aw_if.slave axi_s_aw,
    axi_w_if.slave axi_s_w,
    axi_b_if.slave axi_s_b,
    axi_ar_if.slave axi_s_ar,
    axi_r_if.slave axi_s_r,

    // outport interface
    input rclk_i,
    input rrst_n,
    axi_aw_if.master axi_m_aw,
    axi_w_if.master axi_m_w,
    axi_b_if.master axi_m_b,
    axi_ar_if.master axi_m_ar,
    axi_r_if.master axi_m_r
);
    localparam int unsigned AddrWidth = 32;

    // begin: AW channel inport FIFO
    localparam int unsigned AwLenWidth   = 8;
    localparam int unsigned AwSizeWidth  = 3;
    localparam int unsigned AwBurstWidth = 2;
    localparam int unsigned AwDataSize   = AddrWidth + `ID_W_WIDTH + AwLenWidth +
                                           AwSizeWidth + AwBurstWidth;

    logic aw_fifo_full, aw_fifo_empty, aw_fifo_deque;

    async_fifo #(
        .DataWidth(AwDataSize),
        .AddrWidth(FifoAddrWidth)
    ) u_awfifo (
        .wclk(wclk_i),
        .wrst_n(wrst_n),
        .winc(axi_s_aw.awvalid && axi_s_aw.awready),
        .wdata({axi_s_aw.awburst,axi_s_aw.awsize,axi_s_aw.awlen,axi_s_aw.awid,axi_s_aw.awaddr}),
        .wfull(aw_fifo_full),

        .rclk(rclk_i),
        .rrst_n(rrst_n),
        .rinc(aw_fifo_deque),
        .rempty(aw_fifo_empty),
        .rdata({axi_m_aw.awburst,axi_m_aw.awsize,axi_m_aw.awlen,axi_m_aw.awid,axi_m_aw.awaddr})
    );

    // inport interface
    logic awready_q;
    assign axi_s_aw.awready = awready_q;

    always_ff @(posedge wclk_i) begin
        if (axi_s_aw.awvalid && axi_s_aw.awready) begin
            awready_q <= 1'b0;
        end else begin
            awready_q <= ~aw_fifo_full;
        end
    end

    // outport interface
    assign axi_m_aw.awvalid = ~aw_fifo_empty;

    always_comb begin
        aw_fifo_deque = 1'b0;
        if (axi_m_aw.awready && axi_m_aw.awvalid) begin
            aw_fifo_deque = 1'b1;
        end
    end
    // end: AW channel inport FIFO

    // begin: W channel inport FIFO
    localparam int unsigned WStrbWidth = AxiBusWidth / 8;
    localparam int unsigned WLastWidth = 1;
    localparam int unsigned WDataSize  = AxiBusWidth + WStrbWidth + WLastWidth;

    logic w_fifo_full, w_fifo_empty, w_fifo_deque;

    async_fifo #(
        .DataWidth(WDataSize),
        .AddrWidth(FifoAddrWidth)
    ) u_wfifo (
        .wclk(wclk_i),
        .wrst_n(wrst_n),
        .winc(axi_s_w.wvalid && axi_s_w.wready),
        .wdata({axi_s_w.wlast,axi_s_w.wstrb,axi_s_w.wdata}),
        .wfull(w_fifo_full),

        .rclk(rclk_i),
        .rrst_n(rrst_n),
        .rinc(w_fifo_deque),
        .rempty(w_fifo_empty),
        .rdata({axi_m_w.wlast,axi_m_w.wstrb,axi_m_w.wdata})
    );

    // inport interface
    logic wready_q;
    assign axi_s_w.wready = wready_q;

    always_ff @(posedge wclk_i) begin
        if (axi_s_w.wvalid && axi_s_w.wready) begin
            wready_q <= 1'b0;
        end else begin
            wready_q <= ~w_fifo_full;
        end
    end

    // outport interface
    assign axi_m_w.wvalid = ~w_fifo_empty;

    always_comb begin
        w_fifo_deque = 1'b0;
        if (axi_m_w.wready && axi_m_w.wvalid) begin
            w_fifo_deque = 1'b1;
        end
    end
    // end: W channel inport FIFO

    // begin: B channel outport FIFO
    localparam int unsigned BDataSize = `ID_W_WIDTH + `BRESP_WIDTH;

    logic b_fifo_full, b_fifo_empty, b_fifo_deque;

    async_fifo #(
        .DataWidth(BDataSize),
        .AddrWidth(FifoAddrWidth)
    ) u_bfifo (
        .wclk(wclk_i),
        .wrst_n(wrst_n),
        .winc(axi_m_b.bvalid && axi_m_b.bvalid),
        .wdata({axi_m_b.bresp,axi_m_b.bid}),
        .wfull(b_fifo_full),

        .rclk(rclk_i),
        .rrst_n(rrst_n),
        .rinc(b_fifo_deque),
        .rempty(b_fifo_empty),
        .rdata({axi_s_b.bresp,axi_s_b.bid})
    );

    // outport interface
    logic bready_q;
    assign axi_m_b.bready = bready_q;

    always_ff @(posedge rclk_i) begin
        if (axi_m_b.bready && axi_m_b.bvalid) begin
            bready_q <= 1'b0;
        end else begin
            bready_q <= ~b_fifo_full;
        end
    end

    // inport interface
    logic bvalid_q;
    assign axi_s_b.bvalid = bvalid_q;

    always_ff @(posedge wclk_i) begin
        if (!rrst_n) begin
            bvalid_q <= 1'b0;
        end else begin
        if (axi_s_b.bready && axi_s_b.bvalid) begin
            bvalid_q <= 1'b0;
        end else begin
            bvalid_q <= ~b_fifo_empty;
        end
        end
    end

    always_comb begin
        b_fifo_deque = 1'b0;
        if (axi_s_b.bready && axi_s_b.bvalid) begin
            b_fifo_deque = 1'b1;
        end
    end
    // end: B channel outport FIFO

    // begin: AR channel inport FIFO
    localparam int unsigned ArLenWidth   = 8;
    localparam int unsigned ArSizeWidth  = 3;
    localparam int unsigned ArBurstWidth = 2;
    localparam int unsigned ArDataSize   = AddrWidth + `ID_R_WIDTH + ArLenWidth + ArSizeWidth +
                                           ArBurstWidth;

    logic ar_fifo_full, ar_fifo_empty, ar_fifo_deque;

    async_fifo #(
        .DataWidth(ArDataSize),
        .AddrWidth(FifoAddrWidth)
    ) u_arfifo (
        .wclk(wclk_i),
        .wrst_n(wrst_n),
        .winc(axi_s_ar.arvalid && axi_s_ar.arready),
        .wdata({axi_s_ar.arburst,axi_s_ar.arsize,axi_s_ar.arlen,axi_s_ar.arid,axi_s_ar.araddr}),
        .wfull(ar_fifo_full),

        .rclk(rclk_i),
        .rrst_n(rrst_n),
        .rinc(ar_fifo_deque),
        .rempty(ar_fifo_empty),
        .rdata({axi_m_ar.arburst,axi_m_ar.arsize,axi_m_ar.arlen,axi_m_ar.arid,axi_m_ar.araddr})
    );

    // inport interface
    logic arready_q;
    assign axi_s_ar.arready = arready_q;

    always_ff @(posedge wclk_i) begin
        if (axi_s_ar.arvalid && axi_s_ar.arready) begin
            arready_q <= 1'b0;
        end else begin
            arready_q <= ~ar_fifo_full;
        end
    end

    // outport interface
    assign axi_m_ar.arvalid = ~ar_fifo_empty;

    always_comb begin
        ar_fifo_deque = 1'b0;
        if (axi_m_ar.arready && axi_m_ar.arvalid) begin
            ar_fifo_deque = 1'b1;
        end
    end
    // end: AR channel inport FIFO

    // begin: R channel outport FIFO
    localparam int unsigned RRespWidth = 3;
    localparam int unsigned RLastWidth = 1;
    localparam int unsigned RDataWidth = AxiBusWidth + `ID_R_WIDTH + RRespWidth + RLastWidth;

    logic r_fifo_full, r_fifo_empty, r_fifo_deque;

    async_fifo #(
        .DataWidth(RDataWidth),
        .AddrWidth(FifoAddrWidth)
    ) u_rfifo (
        .wclk(rclk_i),
        .wrst_n(wrst_n),
        .winc(axi_m_r.rvalid && axi_m_r.rready),
        .wdata({axi_m_r.rlast,axi_m_r.rresp,axi_m_r.rid,axi_m_r.rdata}),
        .wfull(r_fifo_full),

        .rclk(wclk_i),
        .rrst_n(rrst_n),
        .rinc(r_fifo_deque),
        .rempty(r_fifo_empty),
        .rdata({axi_s_r.rlast,axi_s_r.rresp,axi_s_r.rid,axi_s_r.rdata})
    );

    // outport interface
    logic rready_q;
    assign axi_m_r.rready = rready_q;

    always_ff @(posedge rclk_i) begin
        if (axi_m_r.rready && axi_m_r.rvalid) begin
            rready_q <= 1'b0;
        end else begin
            rready_q <= ~r_fifo_full;
        end
    end

    // inport interface
    logic rvalid_q;
    assign axi_s_r.rvalid = rvalid_q;

    always_ff @(posedge wclk_i) begin
        if (!rrst_n) begin
            rvalid_q <= 1'b0;
        end else begin
        if (axi_s_r.rready && axi_s_r.rvalid) begin
            rvalid_q <= 1'b0;
        end else begin
            rvalid_q <= ~r_fifo_empty;
        end
        end
    end

    always_comb begin
        r_fifo_deque = 1'b0;
        if (axi_s_r.rready && axi_s_r.rvalid) begin
            r_fifo_deque = 1'b1;
        end
    end
    // end: R channel outport FIFO

endmodule
