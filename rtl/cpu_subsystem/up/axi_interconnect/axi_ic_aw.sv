`include "axi_config.svh"

module axi_ic_aw #(
    parameter int unsigned NumMasters  = 2,
    parameter int unsigned NumSlaves   = 2,
    parameter int unsigned AddrWidth   = 32,
    localparam int unsigned GrantWidth = $clog2(NumMasters) == 0 ? 1 : $clog2(NumMasters),
    parameter logic [AddrWidth-1:0] MemoryMap[NumSlaves][2] = '{
        {32'h0000_0000, 32'h0001_FFFF},
        {32'h0002_0000, 32'h0002_FFFF}
    }
) (
    input aclk,
    input rst_n,

    input                       wlast_i[NumSlaves],

    // inport from interconnect
    axi_aw_if.slave axi_sl_aw[NumMasters],

    // outport to interconnect
    output [$clog2(NumSlaves)-1:0] slave_sel_o[NumMasters],
    output [GrantWidth-1:0]        wr_grant_o[NumSlaves],
    axi_aw_if.master               axi_m_aw[NumSlaves]
);
    // AW signals vectors
    logic                   awready_vec[NumSlaves][NumMasters];
    logic                   awvalid_vec[NumMasters][NumSlaves];
    logic [`ID_W_WIDTH-1:0] awid_vec[NumMasters][NumSlaves];
    logic [AddrWidth-1:0]   awaddr_vec[NumMasters][NumSlaves];
    logic [7:0]             awlen_vec[NumMasters][NumSlaves];
    logic [2:0]             awsize_vec[NumMasters][NumSlaves];
    logic [1:0]             awburst_vec[NumMasters][NumSlaves];

    logic [$clog2(NumSlaves)-1:0] slave_sel[NumMasters];
    assign slave_sel_o = slave_sel;

    generate
        for (genvar i=0; i<NumMasters; i=i+1) begin : gen_master_aw_routing

            // select slave based on master's araddr
            decoder #(
                .NumSlaves(NumSlaves),
                .AddrWidth(AddrWidth),
                .MemoryMap(MemoryMap)
            ) u_aw_addr_decoder (
                .addr_i(axi_sl_aw[i].awaddr),
                .sel_o(slave_sel[i]),
                .error_o()
            );

            // awvalid demux
            demux #(
                .DataWidth(1),
                .NumOutputs(NumSlaves)
            ) u_awvalid_demux (
                .data_i(axi_sl_aw[i].awvalid),
                .sel_i(slave_sel[i]),
                .data_o(awvalid_vec[i])
            );

            // awid demux
            demux #(
                .DataWidth(`ID_W_WIDTH),
                .NumOutputs(NumSlaves)
            ) u_awid_demux (
                .data_i({i,axi_sl_aw[i].awid[0+:(`ID_W_WIDTH/2)]}),
                .sel_i(slave_sel[i]),
                .data_o(awid_vec[i])
            );

            // awaddr demux
            demux #(
                .DataWidth(AddrWidth),
                .NumOutputs(NumSlaves)
            ) u_awaddr_demux (
                .data_i(axi_sl_aw[i].awaddr),
                .sel_i(slave_sel[i]),
                .data_o(awaddr_vec[i])
            );

            // awlen demux
            demux #(
                .DataWidth(8),
                .NumOutputs(NumSlaves)
            ) u_awlen_demux (
                .data_i(axi_sl_aw[i].awlen),
                .sel_i(slave_sel[i]),
                .data_o(awlen_vec[i])
            );

            // awsize demux
            demux #(
                .DataWidth(3),
                .NumOutputs(NumSlaves)
            ) u_awsize_demux (
                .data_i(axi_sl_aw[i].awsize),
                .sel_i(slave_sel[i]),
                .data_o(awsize_vec[i])
            );

            // awburst demux
            demux #(
                .DataWidth(2),
                .NumOutputs(NumSlaves)
            ) u_awburst_demux (
                .data_i(axi_sl_aw[i].awburst),
                .sel_i(slave_sel[i]),
                .data_o(awburst_vec[i])
            );
        end
    endgenerate

    generate
        logic [NumMasters-1:0] wr_req[NumSlaves];
        logic [NumMasters-1:0] wr_grant[NumSlaves];
        logic [GrantWidth-1:0] wr_bin_grant[NumSlaves];

        assign wr_grant_o = wr_bin_grant;

        // Vectors of combined masters AW signals
        logic                   awvalid_masters_vec[NumSlaves][NumMasters];
        logic [`ID_W_WIDTH-1:0] awid_masters_vec[NumSlaves][NumMasters];
        logic [AddrWidth-1:0]   awaddr_masters_vec[NumSlaves][NumMasters];
        logic [7:0]             awlen_masters_vec[NumSlaves][NumMasters];
        logic [2:0]             awsize_masters_vec[NumSlaves][NumMasters];
        logic [1:0]             awburst_masters_vec[NumSlaves][NumMasters];

        // AW signlas from selected master
        logic                   awvalid_sel[NumSlaves];
        logic [`ID_W_WIDTH-1:0] awid_sel[NumSlaves];
        logic [AddrWidth-1:0]   awaddr_sel[NumSlaves];
        logic [7:0]             awlen_sel[NumSlaves];
        logic [2:0]             awsize_sel[NumSlaves];
        logic [1:0]             awburst_sel[NumSlaves];

        for (genvar i=0; i<NumSlaves; i=i+1) begin : gen_slave_aw_routing

            always_comb begin
                for (int j=0; j<NumMasters; j=j+1) begin
                    awvalid_masters_vec[i][j] = awvalid_vec[j][i];
                    awid_masters_vec[i][j]    = awid_vec[j][i];
                    awaddr_masters_vec[i][j]  = awaddr_vec[j][i];
                    awlen_masters_vec[i][j]   = awlen_vec[j][i];
                    awsize_masters_vec[i][j]  = awsize_vec[j][i];
                    awburst_masters_vec[i][j] = awburst_vec[j][i];

                    wr_req[i][j] = awvalid_vec[j][i];
                end

            end

            // aw arbiter
            rr_arbiter_lock #(
                .Width(NumMasters)
            ) u_aw_arbiter (
                .clk(aclk),
                .rst_n(rst_n),
                .req_i(wr_req[i]),
                .unlock_i(wlast_i[i]),
                .grant_o(wr_grant[i]),
                .binary_grant_o(wr_bin_grant[i])
            );

            // awvalid mux
            mux #(
                .DataWidth(1),
                .NumInputs(NumMasters)
            ) u_awvalid_mux (
                .data_i(awvalid_masters_vec[i]),
                .sel_i(wr_bin_grant[i]),
                .data_o(awvalid_sel[i])
            );

            // awid mux
            mux #(
                .DataWidth(`ID_W_WIDTH),
                .NumInputs(NumMasters)
            ) u_awid_mux (
                .data_i(awid_masters_vec[i]),
                .sel_i(wr_bin_grant[i]),
                .data_o(awid_sel[i])
            );

            // awaddr mux
            mux #(
                .DataWidth(AddrWidth),
                .NumInputs(NumMasters)
            ) u_awaddr_mux (
                .data_i(awaddr_masters_vec[i]),
                .sel_i(wr_bin_grant[i]),
                .data_o(awaddr_sel[i])
            );

            // awlen mux
            mux #(
                .DataWidth(8),
                .NumInputs(NumMasters)
            ) u_awlen_mux (
                .data_i(awlen_masters_vec[i]),
                .sel_i(wr_bin_grant[i]),
                .data_o(awlen_sel[i])
            );

            // awsize mux
            mux #(
                .DataWidth(3),
                .NumInputs(NumMasters)
            ) u_awsize_mux (
                .data_i(awsize_masters_vec[i]),
                .sel_i(wr_bin_grant[i]),
                .data_o(awsize_sel[i])
            );

            // awburst mux
            mux #(
                .DataWidth(2),
                .NumInputs(NumMasters)
            ) u_awburst_mux (
                .data_i(awburst_masters_vec[i]),
                .sel_i(wr_bin_grant[i]),
                .data_o(awburst_sel[i])
            );

            // pipeline skid buffers
            localparam int unsigned AwIdWidth    = `ID_W_WIDTH;
            localparam int unsigned AwLenWidth   = 8;
            localparam int unsigned AwSizeWidth  = 3;
            localparam int unsigned AwBurstWidth = 2;
            localparam int unsigned AwDataSize   = AddrWidth + `ID_W_WIDTH + AwLenWidth +
                                                   AwSizeWidth + AwBurstWidth;

            logic [AwDataSize-1:0] skid_awdata_out[NumSlaves];
            logic                  skid_awvalid_out[NumSlaves];
            logic                  skid_awready_out[NumSlaves];

            pipeline_skid_buffer #(
                .DataWidth(AwDataSize)
            ) u_aw_skid_buffer (
                .clk_i(aclk),
                .rst_i(~rst_n),
                // input interface
                .valid_i(awvalid_sel[i]),
                .data_i ({awburst_sel[i],awsize_sel[i],awlen_sel[i],awid_sel[i],awaddr_sel[i]}),
                .ready_o(skid_awready_out[i]),
                // output interface
                .ready_i(axi_m_aw[i].awready),
                .valid_o(skid_awvalid_out[i]),
                .data_o (skid_awdata_out[i])
            );

            assign axi_m_aw[i].awvalid = skid_awvalid_out[i];
            assign axi_m_aw[i].awaddr  = skid_awdata_out[i][0+:AddrWidth];
            assign axi_m_aw[i].awid    = skid_awdata_out[i][AddrWidth+:`ID_W_WIDTH];
            assign axi_m_aw[i].awlen   = skid_awdata_out[i][(AddrWidth+`ID_W_WIDTH)+:AwLenWidth];
            assign axi_m_aw[i].awsize  = skid_awdata_out[i][(AddrWidth+`ID_W_WIDTH+AwLenWidth)
                                                             +:AwSizeWidth];
            assign axi_m_aw[i].awburst = skid_awdata_out[i][(AddrWidth+`ID_W_WIDTH+AwLenWidth
                                                             +AwSizeWidth)+:AwBurstWidth];

            // awready demux
            demux #(
                .DataWidth(1),
                .NumOutputs(NumMasters)
            ) u_awready_demux (
                .data_i(skid_awready_out[i]),
                .sel_i(wr_bin_grant[i]),
                .data_o(awready_vec[i])
            );
        end
    endgenerate

    generate
        logic awready_slaves_vec[NumMasters][NumSlaves];
        logic awready_sel[NumMasters];//, awready_sel_q[NumMasters];

        for (genvar i=0; i<NumMasters; i=i+1) begin : gen_awready_master_routing

            always_comb begin
                for (int j=0; j<NumSlaves; j=j+1) begin
                    awready_slaves_vec[i][j] = awready_vec[j][i];
                end
            end

            // awready mux
            mux #(
                .DataWidth(1),
                .NumInputs(NumSlaves)
            ) u_master_awready_mux (
                .data_i(awready_slaves_vec[i]),
                .sel_i(slave_sel[i]),
                .data_o(awready_sel[i])
            );

            //always_ff @(posedge aclk) begin
            //    if (axi_sl_aw[i].awvalid && axi_sl_aw[i].awready) begin
            //        awready_sel_q[i] <= 1'b0;
            //    end else begin
            //        awready_sel_q[i] <= awready_sel[i];
            //    end
            //end

            assign axi_sl_aw[i].awready = awready_sel[i];
        end
    endgenerate

endmodule
