`include "axi_config.svh"

module axi_interconnect #(
    parameter int unsigned NumMasters  = 4,
    parameter int unsigned NumSlaves   = 2,
    parameter int unsigned AxiBusWidth = 128,
    parameter int unsigned AddrWidth   = 32,
    parameter logic [AddrWidth-1:0] MemoryMap[NumSlaves][2] = '{
        {32'h0000_0000, 32'h0001_FFFF},
        {32'h0002_0000, 32'h0002_FFFF}
    }
) (
    // inport from masters
    input mclk_i,
    input wrst_n,

    axi_aw_if.slave axi_sl_aw[NumMasters],
    axi_w_if.slave axi_sl_w[NumMasters],
    axi_b_if.slave axi_sl_b[NumMasters],
    axi_ar_if.slave axi_sl_ar[NumMasters],
    axi_r_if.slave axi_sl_r[NumMasters],

    // interconnect clk
    input aclk,

    // outport to slaves
    input sclk_i,
    input rrst_n,
    axi_aw_if.master axi_m_aw[NumSlaves],
    axi_w_if.master axi_m_w[NumSlaves],
    axi_b_if.master axi_m_b[NumSlaves],
    axi_ar_if.master axi_m_ar[NumSlaves],
    axi_r_if.master axi_m_r[NumSlaves]
);

    // slave transactor -> interconnect interface
    axi_aw_if #(.AddrWidth(AddrWidth))   axi_sl_ic_aw[NumMasters]();
    axi_w_if  #(.DataWidth(AxiBusWidth)) axi_sl_ic_w[NumMasters]();
    axi_b_if                             axi_sl_ic_b[NumMasters]();
    axi_ar_if #(.AddrWidth(AddrWidth))   axi_sl_ic_ar[NumMasters]();
    axi_r_if  #(.DataWidth(AxiBusWidth)) axi_sl_ic_r[NumMasters]();

    // interconnect -> master transactor interface
    axi_aw_if #(.AddrWidth(AddrWidth))   axi_ic_m_aw[NumSlaves]();
    axi_w_if  #(.DataWidth(AxiBusWidth)) axi_ic_m_w[NumSlaves]();
    axi_b_if                             axi_ic_m_b[NumSlaves]();
    axi_ar_if #(.AddrWidth(AddrWidth))   axi_ic_m_ar[NumSlaves]();
    axi_r_if  #(.DataWidth(AxiBusWidth)) axi_ic_m_r[NumSlaves]();

    localparam int unsigned FifoAddrWidth = 8;

    // slave transactors (master <-> slave-transactor <-> interconnect)
    generate
        for (genvar i=0; i<NumMasters; i=i+1) begin : gen_slave_transactors
            axi_transactor #(
                .AxiBusWidth(AxiBusWidth),
                .FifoAddrWidth(FifoAddrWidth)
            ) u_axi_slave_transactor (
                .wclk_i(mclk_i),
                .wrst_n(wrst_n),
                .axi_s_aw(axi_sl_aw[i]),
                .axi_s_w(axi_sl_w[i]),
                .axi_s_b(axi_sl_b[i]),
                .axi_s_ar(axi_sl_ar[i]),
                .axi_s_r(axi_sl_r[i]),

                .rclk_i(aclk),
                .rrst_n(rrst_n),
                .axi_m_aw(axi_sl_ic_aw[i]),
                .axi_m_w(axi_sl_ic_w[i]),
                .axi_m_b(axi_sl_ic_b[i]),
                .axi_m_ar(axi_sl_ic_ar[i]),
                .axi_m_r(axi_sl_ic_r[i])
            );
        end
    endgenerate

    // begin: write channel
    localparam int unsigned GrantWidth = $clog2(NumMasters) == 0 ? 1 : $clog2(NumMasters);

    logic [GrantWidth-1:0] wr_grant[NumSlaves];
    logic [$clog2(NumSlaves)-1:0] wr_slave_sel[NumMasters];

    logic wlast_sel[NumSlaves];

    axi_ic_aw #(
        .NumMasters(NumMasters),
        .NumSlaves(NumSlaves),
        .AddrWidth(AddrWidth),
        .MemoryMap(MemoryMap)
    ) u_axi_aw_channel (
        .aclk(aclk),
        .rst_n(rrst_n),
        .wlast_i(wlast_sel),
        .axi_sl_aw(axi_sl_ic_aw),
        .slave_sel_o(wr_slave_sel),
        .wr_grant_o(wr_grant),
        .axi_m_aw(axi_ic_m_aw)
    );

    axi_ic_w #(
        .NumMasters(NumMasters),
        .NumSlaves(NumSlaves),
        .AxiBusWidth(AxiBusWidth)
    ) u_axi_w_channel (
        .aclk(aclk),
        .rst_n(rrst_n),
        .axi_sl_w(axi_sl_ic_w),
        .slave_sel_i(wr_slave_sel),
        .wr_grant_i(wr_grant),
        .wlast_o(wlast_sel),
        .axi_m_w(axi_ic_m_w)
    );

    // B channel
    axi_ic_b #(
        .NumMasters(NumMasters),
        .NumSlaves(NumSlaves)
    ) u_axi_b_channel (
        .aclk(aclk),
        .rst_n(rrst_n),
        .axi_m_b(axi_ic_m_b),
        .axi_sl_b(axi_sl_ic_b)
    );
    //end: write channel

    // begin: read channel
    // AR channel
    axi_ic_ar #(
        .NumMasters(NumMasters),
        .NumSlaves(NumSlaves),
        .AddrWidth(AddrWidth),
        .MemoryMap(MemoryMap)
    ) u_axi_ar_channel (
        .aclk(aclk),
        .rst_n(rrst_n),
        .axi_sl_ar(axi_sl_ic_ar),
        .axi_m_ar(axi_ic_m_ar)
    );

    // R channel
    axi_ic_r #(
        .NumMasters(NumMasters),
        .NumSlaves(NumSlaves),
        .AxiBusWidth(AxiBusWidth)
    ) u_axi_r_channel (
        .aclk(aclk),
        .rst_n(rrst_n),
        .axi_m_r(axi_ic_m_r),
        .axi_sl_r(axi_sl_ic_r)
    );
    // end: read channel

    // master transactors (interconnect <-> master-transactor <-> slave)
    generate
        for (genvar i=0; i<NumSlaves; i=i+1) begin : gen_master_transactors
            axi_transactor #(
                .AxiBusWidth(AxiBusWidth),
                .FifoAddrWidth(FifoAddrWidth)
            ) u_axi_master_transactor (
                .wclk_i(aclk),
                .wrst_n(wrst_n),
                .axi_s_aw(axi_ic_m_aw[i]),
                .axi_s_w(axi_ic_m_w[i]),
                .axi_s_b(axi_ic_m_b[i]),
                .axi_s_ar(axi_ic_m_ar[i]),
                .axi_s_r(axi_ic_m_r[i]),

                .rclk_i(sclk_i),
                .rrst_n(rrst_n),
                .axi_m_aw(axi_m_aw[i]),
                .axi_m_w(axi_m_w[i]),
                .axi_m_b(axi_m_b[i]),
                .axi_m_ar(axi_m_ar[i]),
                .axi_m_r(axi_m_r[i])
            );
        end
    endgenerate

endmodule
