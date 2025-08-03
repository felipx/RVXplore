`include "axi_config.svh"

module axi_ic_b #(
    parameter int unsigned NumMasters  = 2,
    parameter int unsigned NumSlaves   = 2
) (
    input aclk,
    input rst_n,

    // inport from interconnect
    axi_b_if.master axi_m_b[NumSlaves],

    // outport to interconnect
    axi_b_if.slave axi_sl_b[NumMasters]
);

    // B signals vectors
    logic                    bready_vec[NumMasters][NumSlaves];
    logic                    bvalid_vec[NumSlaves][NumMasters];
    logic [`ID_W_WIDTH-1:0]  bid_vec[NumSlaves][NumMasters];
    logic [`BRESP_WIDTH-1:0] bresp_vec[NumSlaves][NumMasters];

    generate
        logic [`ID_W_WIDTH-1:0] master_sel[NumSlaves];

        for (genvar i=0; i<NumSlaves; i=i+1) begin : gen_slaves_b_routing

            // select masters based on rid
            assign master_sel[i] = axi_m_b[i].bid[`ID_W_WIDTH-1 -: `ID_W_WIDTH/2];

            // bvalid demux
            demux #(
                .DataWidth(1),
                .NumOutputs(NumMasters)
            ) u_bvalid_demux (
                .data_i(axi_m_b[i].bvalid),
                .sel_i(master_sel[i]),
                .data_o(bvalid_vec[i])
            );

            // bid demux
            demux #(
                .DataWidth(`ID_W_WIDTH),
                .NumOutputs(NumMasters)
            ) u_bid_demux (
                .data_i(axi_m_b[i].bid),
                .sel_i(master_sel[i]),
                .data_o(bid_vec[i])
            );

            // bresp demux
            demux #(
                .DataWidth(`BRESP_WIDTH),
                .NumOutputs(NumMasters)
            ) u_bresp_demux (
                .data_i(axi_m_b[i].bresp),
                .sel_i(master_sel[i]),
                .data_o(bresp_vec[i])
            );
        end
    endgenerate

    generate
            localparam int unsigned GrantWidth = $clog2(NumSlaves) == 0 ? 1 : $clog2(NumSlaves);

            logic [NumSlaves-1:0]  wr_req[NumMasters];
            logic [NumSlaves-1:0]  wr_grant[NumMasters];
            logic [GrantWidth-1:0] wr_bin_grant[NumMasters];

            // Vectors of combined slaves B signals
            logic                    bvalid_slaves_vec[NumMasters][NumSlaves];
            logic [`ID_R_WIDTH-1:0]  bid_slaves_vec[NumMasters][NumSlaves];
            logic [`BRESP_WIDTH-1:0] bresp_slaves_vec[NumMasters][NumSlaves];

            // B signlas from selected slave
            logic                    bvalid_sel[NumMasters];
            logic [`ID_R_WIDTH-1:0]  bid_sel[NumMasters];
            logic [`BRESP_WIDTH-1:0] bresp_sel[NumMasters];

        for (genvar i=0; i<NumMasters; i=i+1) begin : gen_master_b_routing

            always_comb begin
                for (int j=0; j<NumSlaves; j=j+1) begin
                    bvalid_slaves_vec[i][j] = bvalid_vec[j][i];
                    bid_slaves_vec[i][j]    = bid_vec[j][i];
                    bresp_slaves_vec[i][j]  = bresp_vec[j][i];

                    wr_req[i][j] = bvalid_vec[j][i];
                end
            end

            // b_arbiter
            rr_arbiter #(
                .Width(NumSlaves)
            ) u_b_arbiter (
                .clk(aclk),
                .rst_n(rst_n),
                .req_i(wr_req[i]),
                .grant_o(wr_grant[i]),
                .binary_grant_o(wr_bin_grant[i])
            );

            // bvalid mux
            mux #(
                .DataWidth(1),
                .NumInputs(NumSlaves)
            ) u_bvalid_mux (
                .data_i(bvalid_slaves_vec[i]),
                .sel_i(wr_bin_grant[i]),
                .data_o(bvalid_sel[i])
            );

            // bid mux
            mux #(
                .DataWidth(`ID_W_WIDTH),
                .NumInputs(NumSlaves)
            ) u_bid_mux (
                .data_i(bid_slaves_vec[i]),
                .sel_i(wr_bin_grant[i]),
                .data_o(bid_sel[i])
            );

            // bresp mux
            mux #(
                .DataWidth(`BRESP_WIDTH),
                .NumInputs(NumSlaves)
            ) u_bresp_mux (
                .data_i(bresp_slaves_vec[i]),
                .sel_i(wr_bin_grant[i]),
                .data_o(bresp_sel[i])
            );

            // pipeline skid buffers
            localparam int unsigned BDataSize  = `ID_R_WIDTH + `BRESP_WIDTH;

            logic [BDataSize-1:0] skid_bdata_out[NumMasters];
            logic                 skid_bvalid_out[NumMasters];
            logic                 skid_bready_out[NumMasters];

            pipeline_skid_buffer #(
                 .DataWidth(BDataSize)
            ) u_b_skid_buffer (
                .clk_i(aclk),
                .rst_i(~rst_n),
                // input interface
                .valid_i(bvalid_sel[i]),
                .data_i ({bresp_sel[i],bid_sel[i]}),
                .ready_o(skid_bready_out[i]),
                // output interface
                .ready_i(axi_sl_b[i].bready),
                .valid_o(skid_bvalid_out[i]),
                .data_o (skid_bdata_out[i])
            );

            assign axi_sl_b[i].bvalid = skid_bvalid_out[i];
            assign axi_sl_b[i].bid    = {4'h0,skid_bdata_out[i][0+:`ID_R_WIDTH/2]};
            assign axi_sl_b[i].bresp  = skid_bdata_out[i][`ID_R_WIDTH+:`BRESP_WIDTH];

            // bready demux
            demux #(
                .DataWidth(1),
                .NumOutputs(NumSlaves)
            ) u_bready_demux (
                .data_i(skid_bready_out[i]),
                .sel_i(wr_bin_grant[i]),
                .data_o(bready_vec[i])
            );
        end
    endgenerate

    generate
        logic bready_masters_vec[NumSlaves][NumMasters];
        logic bready_sel[NumSlaves];//, bready_sel_q[NumSlaves];

        for (genvar i=0; i<NumSlaves; i=i+1) begin : gen_bready_slaves_routing

            always_comb begin
                for (int j=0; j<NumMasters; j=j+1) begin
                    bready_masters_vec[i][j] = bready_vec[j][i];
                end
            end

            // bready mux
            mux #(
                .DataWidth(1),
                .NumInputs(NumMasters)
            ) u_slave_bready_mux (
                .data_i(bready_masters_vec[i]),
                .sel_i(master_sel[i]),
                .data_o(bready_sel[i])
            );

            //always_ff @(posedge aclk) begin
            //    if (axi_m_b[i].bvalid && axi_m_b[i].bready) begin
            //        bready_sel_q[i] <= 1'b0;
            //    end else begin
            //        bready_sel_q[i] <= bready_sel[i];
            //    end
            //end

            assign axi_m_b[i].bready = bready_sel[i];
        end
    endgenerate

endmodule
