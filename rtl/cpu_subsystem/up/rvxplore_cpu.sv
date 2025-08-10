`define MEM_MAP_2 \
    '{ {32'h0000_0000, 32'h0000_FFFF}, \
       {32'h8000_0000, 32'hFFFF_FFFF} }

module rvxplore_cpu #(
    parameter int unsigned XLEN = 32
) (
    input clk_i,
    input rst_i,
    input en_i,

    // Inport
    axi_ar_if.slave s_axi_ar,
    axi_r_if.slave  s_axi_r,
    axi_aw_if.slave s_axi_aw,
    axi_w_if.slave  s_axi_w,
    axi_b_if.slave  s_axi_b,

    // Outport
    axi_ar_if.master m_axi_ar,
    axi_r_if.master  m_axi_r,
    axi_aw_if.master m_axi_aw,
    axi_w_if.master  m_axi_w,
    axi_b_if.master  m_axi_b
);
    localparam int unsigned NumMasters = 2;
    localparam int unsigned NumSlaves = 2;
    localparam int unsigned AxiBusWidth = 64;

    axi_aw_if #(.AddrWidth(32))          icm_m_axi_aw[NumMasters]();
    axi_w_if  #(.DataWidth(AxiBusWidth)) icm_m_axi_w[NumMasters]();
    axi_b_if                             icm_m_axi_b[NumMasters]();
    axi_ar_if #(.AddrWidth(32))          icm_m_axi_ar[NumMasters]();
    axi_r_if  #(.DataWidth(AxiBusWidth)) icm_m_axi_r[NumMasters]();

    axi_aw_if #(.AddrWidth(32))          icm_s_axi_aw[NumSlaves]();
    axi_w_if  #(.DataWidth(AxiBusWidth)) icm_s_axi_w[NumSlaves]();
    axi_b_if                             icm_s_axi_b[NumSlaves]();
    axi_ar_if #(.AddrWidth(32))          icm_s_axi_ar[NumSlaves]();
    axi_r_if  #(.DataWidth(AxiBusWidth)) icm_s_axi_r[NumSlaves]();

    logic reset_n;
    assign reset_n = ~rst_i;


    // ---------------------------------------------------------------
    // Master 0 - CPU inport
    // ---------------------------------------------------------------
    assign icm_m_axi_aw[0].awvalid = s_axi_aw.awvalid;
    assign s_axi_aw.awready        = icm_m_axi_aw[0].awready;
    assign icm_m_axi_aw[0].awid    = s_axi_aw.awid;
    assign icm_m_axi_aw[0].awaddr  = s_axi_aw.awaddr;
    assign icm_m_axi_aw[0].awlen   = s_axi_aw.awlen;
    assign icm_m_axi_aw[0].awsize  = s_axi_aw.awsize;
    assign icm_m_axi_aw[0].awburst = s_axi_aw.awburst;
    assign icm_m_axi_w[0].wvalid   = s_axi_w.wvalid;
    assign s_axi_w.wready          = icm_m_axi_w[0].wready;
    assign icm_m_axi_w[0].wdata    = s_axi_w.wdata;
    assign icm_m_axi_w[0].wstrb    = s_axi_w.wstrb;
    assign icm_m_axi_w[0].wlast    = s_axi_w.wlast;
    assign s_axi_b.bvalid          = icm_m_axi_b[0].bvalid;
    assign icm_m_axi_b[0].bready   = s_axi_b.bready;
    assign s_axi_b.bid             = icm_m_axi_b[0].bid;
    assign s_axi_b.bresp           = icm_m_axi_b[0].bresp;
    assign icm_m_axi_ar[0].arvalid = s_axi_ar.arvalid;
    assign s_axi_ar.arready        = icm_m_axi_ar[0].arready;
    assign icm_m_axi_ar[0].arid    = s_axi_ar.arid;
    assign icm_m_axi_ar[0].araddr  = s_axi_ar.araddr;
    assign icm_m_axi_ar[0].arlen   = s_axi_ar.arlen;
    assign icm_m_axi_ar[0].arsize  = s_axi_ar.arsize;
    assign icm_m_axi_ar[0].arburst = s_axi_ar.arburst;
    assign s_axi_r.rvalid          = icm_m_axi_r[0].rvalid;
    assign icm_m_axi_r[0].rready   = s_axi_r.rready;
    assign s_axi_r.rid             = icm_m_axi_r[0].rid;
    assign s_axi_r.rdata           = icm_m_axi_r[0].rdata;
    assign s_axi_r.rresp           = icm_m_axi_r[0].rresp;
    assign s_axi_r.rlast           = icm_m_axi_r[0].rlast;

    // ---------------------------------------------------------------
    // Slave N - CPU outport
    // ---------------------------------------------------------------
    assign m_axi_aw.awvalid                  = icm_s_axi_aw[NumSlaves-1].awvalid;
    assign icm_s_axi_aw[NumSlaves-1].awready = m_axi_aw.awready;
    assign m_axi_aw.awid                     = icm_s_axi_aw[NumSlaves-1].awid;
    assign m_axi_aw.awaddr                   = icm_s_axi_aw[NumSlaves-1].awaddr;
    assign m_axi_aw.awlen                    = icm_s_axi_aw[NumSlaves-1].awlen;
    assign m_axi_aw.awsize                   = icm_s_axi_aw[NumSlaves-1].awsize;
    assign m_axi_aw.awburst                  = icm_s_axi_aw[NumSlaves-1].awburst;
    assign m_axi_w.wvalid                    = icm_s_axi_w[NumSlaves-1].wvalid;
    assign icm_s_axi_w[NumSlaves-1].wready   = m_axi_w.wready;
    assign m_axi_w.wdata                     = icm_s_axi_w[NumSlaves-1].wdata;
    assign m_axi_w.wstrb                     = icm_s_axi_w[NumSlaves-1].wstrb;
    assign m_axi_w.wlast                     = icm_s_axi_w[NumSlaves-1].wlast;
    assign icm_s_axi_b[NumSlaves-1].bvalid   = m_axi_b.bvalid;
    assign m_axi_b.bready                    = icm_s_axi_b[NumSlaves-1].bready;
    assign icm_s_axi_b[NumSlaves-1].bid      = m_axi_b.bid;
    assign icm_s_axi_b[NumSlaves-1].bresp    = m_axi_b.bresp;
    assign m_axi_ar.arvalid                  = icm_s_axi_ar[NumSlaves-1].arvalid;
    assign icm_s_axi_ar[NumSlaves-1].arready = m_axi_ar.arready;
    assign m_axi_ar.arid                     = icm_s_axi_ar[NumSlaves-1].arid;
    assign m_axi_ar.araddr                   = icm_s_axi_ar[NumSlaves-1].araddr;
    assign m_axi_ar.arlen                    = icm_s_axi_ar[NumSlaves-1].arlen;
    assign m_axi_ar.arsize                   = icm_s_axi_ar[NumSlaves-1].arsize;
    assign m_axi_ar.arburst                  = icm_s_axi_ar[NumSlaves-1].arburst;
    assign icm_s_axi_r[NumSlaves-1].rvalid   = m_axi_r.rvalid;
    assign m_axi_r.rready                    = icm_s_axi_r[NumSlaves-1].rready;
    assign icm_s_axi_r[NumSlaves-1].rid      = m_axi_r.rid;
    assign icm_s_axi_r[NumSlaves-1].rdata    = m_axi_r.rdata;
    assign icm_s_axi_r[NumSlaves-1].rresp    = m_axi_r.rresp;
    assign icm_s_axi_r[NumSlaves-1].rlast    = m_axi_r.rlast;

    // ---------------------------------------------------------------
    // AXI Interconnect
    // ---------------------------------------------------------------
    axi_interconnect #(
        .NumMasters(NumMasters),
        .NumSlaves(NumSlaves),
        .AxiBusWidth(AxiBusWidth),
        .AddrWidth(32),
        .MemoryMap(`MEM_MAP_2)
    ) u_axi_interconnect (

        .mclk_i(clk_i),
        .wrst_n(reset_n),
        .axi_sl_aw(icm_m_axi_aw),
        .axi_sl_w(icm_m_axi_w),
        .axi_sl_b(icm_m_axi_b),
        .axi_sl_ar(icm_m_axi_ar),
        .axi_sl_r(icm_m_axi_r),

        .aclk(clk_i),

        .sclk_i(clk_i),
        .rrst_n(reset_n),
        .axi_m_aw(icm_s_axi_aw),
        .axi_m_w(icm_s_axi_w),
        .axi_m_b(icm_s_axi_b),
        .axi_m_ar(icm_s_axi_ar),
        .axi_m_r(icm_s_axi_r)
    );

    // ---------------------------------------------------------------
    // CPU Core
    // Slave  0: Icache
    // Master 1: Icache
    // ---------------------------------------------------------------
    cpu_core #(
        .XLEN(XLEN)
    ) u_cpu_core (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .en_i(en_i),

        .ic_s_axi_ar(icm_s_axi_ar[0]),
        .ic_s_axi_r(icm_s_axi_r[0]),
        .ic_s_axi_aw(icm_s_axi_aw[0]),
        .ic_s_axi_w(icm_s_axi_w[0]),
        .ic_s_axi_b(icm_s_axi_b[0]),

        .ic_m_axi_ar(icm_m_axi_ar[1]),
        .ic_m_axi_r(icm_m_axi_r[1]),
        .ic_m_axi_aw(icm_m_axi_aw[1]),
        .ic_m_axi_w(icm_m_axi_w[1]),
        .ic_m_axi_b(icm_m_axi_b[1])
    );




endmodule
