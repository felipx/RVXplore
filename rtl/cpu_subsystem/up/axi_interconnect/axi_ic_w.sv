`include "axi_config.svh"

module axi_ic_w #(
    parameter int unsigned NumMasters  = 2,
    parameter int unsigned NumSlaves   = 2,
    parameter int unsigned AxiBusWidth = 128,
    localparam int unsigned GrantWidth = $clog2(NumMasters) == 0 ? 1 : $clog2(NumMasters)
) (
    input aclk,
    input rst_n,

    // inport from interconnect
    axi_w_if.slave                axi_sl_w[NumMasters],
    input [$clog2(NumSlaves)-1:0] slave_sel_i[NumMasters],
    input [GrantWidth-1:0]        wr_grant_i[NumSlaves],

    output                       wlast_o[NumSlaves],

    // outport to interconnect
    axi_w_if.master axi_m_w[NumSlaves]
);
    // W signals vectors
    logic                       wready_vec[NumSlaves][NumMasters];
    logic                       wvalid_vec[NumMasters][NumSlaves];
    logic [AxiBusWidth-1:0]     wdata_vec[NumMasters][NumSlaves];
    logic [(AxiBusWidth/8)-1:0] wstrb_vec[NumMasters][NumSlaves];
    logic                       wlast_vec[NumMasters][NumSlaves];

    generate
        for (genvar i=0; i<NumMasters; i=i+1) begin : gen_master_w_routing

            // wvalid demux
            demux #(
                .DataWidth(1),
                .NumOutputs(NumSlaves)
            ) u_wvalid_demux (
                .data_i(axi_sl_w[i].wvalid),
                .sel_i(slave_sel_i[i]),
                .data_o(wvalid_vec[i])
            );

            // wdata demux
            demux #(
                .DataWidth(AxiBusWidth),
                .NumOutputs(NumSlaves)
            ) u_wdata_demux (
                .data_i(axi_sl_w[i].wdata),
                .sel_i(slave_sel_i[i]),
                .data_o(wdata_vec[i])
            );

            // wstrb demux
            demux #(
                .DataWidth((AxiBusWidth/8)),
                .NumOutputs(NumSlaves)
            ) u_wstrb_demux (
                .data_i(axi_sl_w[i].wstrb),
                .sel_i(slave_sel_i[i]),
                .data_o(wstrb_vec[i])
            );

            // wlast demux
            demux #(
                .DataWidth(1),
                .NumOutputs(NumSlaves)
            ) u_wlast_demux (
                .data_i(axi_sl_w[i].wlast),
                .sel_i(slave_sel_i[i]),
                .data_o(wlast_vec[i])
            );
        end
    endgenerate

    generate
        // Vectors of combined masters W signals
        logic                       wvalid_masters_vec[NumSlaves][NumMasters];
        logic [AxiBusWidth-1:0]     wdata_masters_vec[NumSlaves][NumMasters];
        logic [(AxiBusWidth/8)-1:0] wstrb_masters_vec[NumSlaves][NumMasters];
        logic                       wlast_masters_vec[NumSlaves][NumMasters];

        // W signlas from selected master
        logic                       wvalid_sel[NumSlaves];
        logic [AxiBusWidth-1:0]     wdata_sel[NumSlaves];
        logic [(AxiBusWidth/8)-1:0] wstrb_sel[NumSlaves];
        logic                       wlast_sel[NumSlaves];

        localparam int unsigned WStrbWidth  = AxiBusWidth/8;
        localparam int unsigned WLastWidth  = 1;
        localparam int unsigned WDataSize   = AxiBusWidth + WStrbWidth + WLastWidth;

        logic [WDataSize-1:0] skid_wdata_out[NumSlaves];
        logic                 skid_wvalid_out[NumSlaves];
        logic                 skid_wready_out[NumSlaves];

        //always_comb begin
            for (genvar i=0; i<NumSlaves; i=i+1) begin
                assign wlast_o[i] = wlast_sel[i] & wvalid_sel[i];
            end
        //end

        for (genvar i=0; i<NumSlaves; i=i+1) begin : gen_slave_w_routing

            always_comb begin
                for (int j=0; j<NumMasters; j=j+1) begin
                    wvalid_masters_vec[i][j] = wvalid_vec[j][i];
                    wdata_masters_vec[i][j]  = wdata_vec[j][i];
                    wstrb_masters_vec[i][j]  = wstrb_vec[j][i];
                    wlast_masters_vec[i][j]  = wlast_vec[j][i];
                end
            end

            // wvalid mux
            mux #(
                .DataWidth(1),
                .NumInputs(NumMasters)
            ) u_wvalid_mux (
                .data_i(wvalid_masters_vec[i]),
                .sel_i(wr_grant_i[i]),
                .data_o(wvalid_sel[i])
            );

            // wdata mux
            mux #(
                .DataWidth(AxiBusWidth),
                .NumInputs(NumMasters)
            ) u_wdata_mux (
                .data_i(wdata_masters_vec[i]),
                .sel_i(wr_grant_i[i]),
                .data_o(wdata_sel[i])
            );

            // wstrb mux
            mux #(
                .DataWidth((AxiBusWidth/8)),
                .NumInputs(NumMasters)
            ) u_wstrb_mux (
                .data_i(wstrb_masters_vec[i]),
                .sel_i(wr_grant_i[i]),
                .data_o(wstrb_sel[i])
            );

            // wlast mux
            mux #(
                .DataWidth(1),
                .NumInputs(NumMasters)
            ) u_wlast_mux (
                .data_i(wlast_masters_vec[i]),
                .sel_i(wr_grant_i[i]),
                .data_o(wlast_sel[i])
            );

            // pipeline skid buffers
            pipeline_skid_buffer #(
                .DataWidth(WDataSize)
            ) u_w_skid_buffer (
                .clk_i(aclk),
                .rst_i(~rst_n),
                // input interface
                .valid_i(wvalid_sel[i]),
                .data_i ({wlast_sel[i],wstrb_sel[i],wdata_sel[i]}),
                .ready_o(skid_wready_out[i]),
                // output interface
                .ready_i(axi_m_w[i].wready),
                .valid_o(skid_wvalid_out[i]),
                .data_o (skid_wdata_out[i])
            );

            assign axi_m_w[i].wvalid = skid_wvalid_out[i];
            assign axi_m_w[i].wdata  = skid_wdata_out[i][0+:AxiBusWidth];
            assign axi_m_w[i].wstrb  = skid_wdata_out[i][AxiBusWidth+:WStrbWidth];
            assign axi_m_w[i].wlast  = skid_wdata_out[i][(AxiBusWidth+WStrbWidth)+:WLastWidth];

            // wready demux
            demux #(
                .DataWidth(1),
                .NumOutputs(NumMasters)
            ) u_wready_demux (
                .data_i(skid_wready_out[i]),
                .sel_i(wr_grant_i[i]),
                .data_o(wready_vec[i])
            );
        end
    endgenerate

    generate
        logic wready_slaves_vec[NumMasters][NumSlaves];
        logic wready_sel[NumMasters];//, wready_sel_q[NumMasters];

        for (genvar i=0; i<NumMasters; i=i+1) begin : gen_wready_master_routing

            always_comb begin
                for (int j=0; j<NumSlaves; j=j+1) begin
                    wready_slaves_vec[i][j] = wready_vec[j][i];
                end
            end

            // wready mux
            mux #(
                .DataWidth(1),
                .NumInputs(NumSlaves)
            ) u_master_wready_mux (
                .data_i(wready_slaves_vec[i]),
                .sel_i(slave_sel_i[i]),
                .data_o(wready_sel[i])
            );

            //always_ff @(posedge aclk) begin
            //    if (axi_sl_w[i].wvalid && axi_sl_w[i].wready) begin
            //        wready_sel_q[i] <= 1'b0;
            //    end else begin
            //        wready_sel_q[i] <= wready_sel[i];
            //    end
            //end

            assign axi_sl_w[i].wready = wready_sel[i];
        end
    endgenerate
endmodule
