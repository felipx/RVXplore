`include "axi_config.svh"

module axi_ic_r #(
    parameter int unsigned NumMasters  = 2,
    parameter int unsigned NumSlaves   = 2,
    parameter int unsigned AxiBusWidth = 128
) (
    input aclk,
    input rst_n,

    // inport from interconnect
    axi_r_if.master axi_m_r[NumSlaves],

    // outport to interconnect
    axi_r_if.slave axi_sl_r[NumMasters]
);

    // R signals vectors
    logic                   rready_vec[NumMasters][NumSlaves];
    logic                   rvalid_vec[NumSlaves][NumMasters];
    logic [`ID_R_WIDTH-1:0] rid_vec[NumSlaves][NumMasters];
    logic [AxiBusWidth-1:0] rdata_vec[NumSlaves][NumMasters];
    logic [2:0]             rresp_vec[NumSlaves][NumMasters];
    logic                   rlast_vec[NumSlaves][NumMasters];

    generate
        logic [`ID_R_WIDTH-1:0] master_sel[NumSlaves];

        for (genvar i=0; i<NumSlaves; i=i+1) begin : gen_slaves_r_routing

            // select masters based on rid
            assign master_sel[i] = axi_m_r[i].rid[`ID_R_WIDTH-1 -: `ID_R_WIDTH/2];

            // rvalid demux
            demux #(
                .DataWidth(1),
                .NumOutputs(NumMasters)
            ) u_rvalid_demux (
                .data_i(axi_m_r[i].rvalid),
                .sel_i(master_sel[i]),
                .data_o(rvalid_vec[i])
            );

            // rid demux
            demux #(
                .DataWidth(`ID_R_WIDTH),
                .NumOutputs(NumMasters)
            ) u_rid_demux (
                .data_i(axi_m_r[i].rid),
                .sel_i(master_sel[i]),
                .data_o(rid_vec[i])
            );

            // rdata demux
            demux #(
                .DataWidth(AxiBusWidth),
                .NumOutputs(NumMasters)
            ) u_rdata_demux (
                .data_i(axi_m_r[i].rdata),
                .sel_i(master_sel[i]),
                .data_o(rdata_vec[i])
            );

            // rresp demux
            demux #(
                .DataWidth(3),
                .NumOutputs(NumMasters)
            ) u_rresp_demux (
                .data_i(axi_m_r[i].rresp),
                .sel_i(master_sel[i]),
                .data_o(rresp_vec[i])
            );

            // rlast demux
            demux #(
                .DataWidth(1),
                .NumOutputs(NumMasters)
            ) u_rlast_demux (
                .data_i(axi_m_r[i].rlast),
                .sel_i(master_sel[i]),
                .data_o(rlast_vec[i])
            );
        end
    endgenerate

    generate
            localparam int unsigned GrantWidth = $clog2(NumSlaves) == 0 ? 1 : $clog2(NumSlaves);

            logic [NumSlaves-1:0] rd_req[NumMasters];
            logic [NumSlaves-1:0] rd_grant[NumMasters];
            logic [GrantWidth-1:0] rd_bin_grant[NumMasters];

            // Vectors of combined slaves R signals
            logic                   rvalid_slaves_vec[NumMasters][NumSlaves];
            logic [`ID_R_WIDTH-1:0] rid_slaves_vec[NumMasters][NumSlaves];
            logic [AxiBusWidth-1:0] rdata_slaves_vec[NumMasters][NumSlaves];
            logic [2:0]             rresp_slaves_vec[NumMasters][NumSlaves];
            logic                   rlast_slaves_vec[NumMasters][NumSlaves];

            // R signlas from selected slave
            logic                   rvalid_sel[NumMasters];
            logic [`ID_R_WIDTH-1:0] rid_sel[NumMasters];
            logic [AxiBusWidth-1:0] rdata_sel[NumMasters];
            logic [2:0]             rresp_sel[NumMasters];
            logic                   rlast_sel[NumMasters];

        for (genvar i=0; i<NumMasters; i=i+1) begin : gen_master_r_routing

            always_comb begin
                for (int j=0; j<NumSlaves; j=j+1) begin
                    rvalid_slaves_vec[i][j] = rvalid_vec[j][i];
                    rid_slaves_vec[i][j]    = rid_vec[j][i];
                    rdata_slaves_vec[i][j]  = rdata_vec[j][i];
                    rresp_slaves_vec[i][j]  = rresp_vec[j][i];
                    rlast_slaves_vec[i][j]  = rlast_vec[j][i];

                    rd_req[i][j] = rvalid_vec[j][i];
                end
            end

            // r_arbiter
            rr_arbiter #(
                .Width(NumSlaves)
            ) u_r_arbiter (
                .clk(aclk),
                .rst_n(rst_n),
                .req_i(rd_req[i]),
                .grant_o(rd_grant[i]),
                .binary_grant_o(rd_bin_grant[i])
            );

            // rvalid mux
            mux #(
                .DataWidth(1),
                .NumInputs(NumSlaves)
            ) u_rvalid_mux (
                .data_i(rvalid_slaves_vec[i]),
                .sel_i(rd_bin_grant[i]),
                .data_o(rvalid_sel[i])
            );

            // rid mux
            mux #(
                .DataWidth(`ID_R_WIDTH),
                .NumInputs(NumSlaves)
            ) u_rid_mux (
                .data_i(rid_slaves_vec[i]),
                .sel_i(rd_bin_grant[i]),
                .data_o(rid_sel[i])
            );

            // rdata mux
            mux #(
                .DataWidth(AxiBusWidth),
                .NumInputs(NumSlaves)
            ) u_rdata_mux (
                .data_i(rdata_slaves_vec[i]),
                .sel_i(rd_bin_grant[i]),
                .data_o(rdata_sel[i])
            );

            // rresp mux
            mux #(
                .DataWidth(3),
                .NumInputs(NumSlaves)
            ) u_rresp_mux (
                .data_i(rresp_slaves_vec[i]),
                .sel_i(rd_bin_grant[i]),
                .data_o(rresp_sel[i])
            );

            // rlast mux
            mux #(
                .DataWidth(1),
                .NumInputs(NumSlaves)
            ) u_rlast_mux (
                .data_i(rlast_slaves_vec[i]),
                .sel_i(rd_bin_grant[i]),
                .data_o(rlast_sel[i])
            );

            // pipeline skid buffers
            localparam int unsigned RIdWidth   = `ID_R_WIDTH;
            localparam int unsigned RRespWidth = 3;
            localparam int unsigned RLastWidth = 1;
            localparam int unsigned RDataSize  = AxiBusWidth + `ID_R_WIDTH +
                                                 RRespWidth + RLastWidth;

            logic [RDataSize-1:0] skid_rdata_out[NumMasters];
            logic                 skid_rvalid_out[NumMasters];
            logic                 skid_rready_out[NumMasters];

            pipeline_skid_buffer #(
                 .DataWidth(RDataSize)
            ) u_r_skid_buffer (
                .clk_i(aclk),
                .rst_i(~rst_n),
                // input interface
                .valid_i(rvalid_sel[i]),
                .data_i ({rlast_sel[i],rresp_sel[i],rid_sel[i],rdata_sel[i]}),
                .ready_o(skid_rready_out[i]),
                // output interface
                .ready_i(axi_sl_r[i].rready),
                .valid_o(skid_rvalid_out[i]),
                .data_o (skid_rdata_out[i])
            );

            assign axi_sl_r[i].rvalid = skid_rvalid_out[i];
            assign axi_sl_r[i].rdata  = skid_rdata_out[i][0+:AxiBusWidth];
            assign axi_sl_r[i].rid    = {4'h0, skid_rdata_out[i][AxiBusWidth+:`ID_R_WIDTH/2]};
            assign axi_sl_r[i].rresp  = skid_rdata_out[i][(AxiBusWidth+`ID_R_WIDTH)+:RRespWidth];
            assign axi_sl_r[i].rlast  = skid_rdata_out[i][(AxiBusWidth+`ID_R_WIDTH+RRespWidth)
                                                           +:RLastWidth];

            // rready demux
            demux #(
                .DataWidth(1),
                .NumOutputs(NumSlaves)
            ) u_rready_demux (
                .data_i(skid_rready_out[i]),
                .sel_i(rd_bin_grant[i]),
                .data_o(rready_vec[i])
            );
        end
    endgenerate

    generate
        logic rready_masters_vec[NumSlaves][NumMasters];
        logic rready_sel[NumSlaves];//, rready_sel_q[NumSlaves];

        for (genvar i=0; i<NumSlaves; i=i+1) begin : gen_rready_slaves_routing

            always_comb begin
                for (int j=0; j<NumMasters; j=j+1) begin
                    rready_masters_vec[i][j] = rready_vec[j][i];
                end
            end

            // rready mux
            mux #(
                .DataWidth(1),
                .NumInputs(NumMasters)
            ) u_slave_rready_mux (
                .data_i(rready_masters_vec[i]),
                .sel_i(master_sel[i]),
                .data_o(rready_sel[i])
            );

            //always_ff @(posedge aclk) begin
            //    if (axi_m_r[i].rvalid && axi_m_r[i].rready) begin
            //        rready_sel_q[i] <= 1'b0;
            //    end else begin
            //        rready_sel_q[i] <= rready_sel[i];
            //    end
            //end

            assign axi_m_r[i].rready = rready_sel[i];
        end
    endgenerate

endmodule
