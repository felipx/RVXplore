`include "axi_config.svh"

module axi_ic_ar #(
    parameter int unsigned NumMasters  = 2,
    parameter int unsigned NumSlaves   = 2,
    parameter int unsigned AddrWidth   = 32,
    parameter logic [AddrWidth-1:0] MemoryMap[NumSlaves][2] = '{
        {32'h0000_0000, 32'h0001_FFFF},
        {32'h0002_0000, 32'h0002_FFFF}
    }
) (
    input aclk,
    input rst_n,

    // inport from interconnect
    axi_ar_if.slave axi_sl_ar[NumMasters],

    // outport to interconnect
    axi_ar_if.master axi_m_ar[NumSlaves]
);
    // AR signals vectors
    logic                   arready_vec[NumSlaves][NumMasters];
    logic                   arvalid_vec[NumMasters][NumSlaves];
    logic [`ID_R_WIDTH-1:0] arid_vec[NumMasters][NumSlaves];
    logic [AddrWidth-1:0]   araddr_vec[NumMasters][NumSlaves];
    logic [7:0]             arlen_vec[NumMasters][NumSlaves];
    logic [2:0]             arsize_vec[NumMasters][NumSlaves];
    logic [1:0]             arburst_vec[NumMasters][NumSlaves];

    logic [$clog2(NumSlaves)-1:0] slave_sel[NumMasters];

    generate
        for (genvar i=0; i<NumMasters; i=i+1) begin : gen_master_ar_routing

            // select slave based on master's araddr
            decoder #(
                .NumSlaves(NumSlaves),
                .AddrWidth(AddrWidth),
                .MemoryMap(MemoryMap)
            ) u_ar_addr_decoder (
                .addr_i(axi_sl_ar[i].araddr),
                .sel_o(slave_sel[i]),
                .error_o()
            );

            // arvalid demux
            demux #(
                .DataWidth(1),
                .NumOutputs(NumSlaves)
            ) u_arvalid_demux (
                .data_i(axi_sl_ar[i].arvalid),
                .sel_i(slave_sel[i]),
                .data_o(arvalid_vec[i])
            );

            // arid demux
            demux #(
                .DataWidth(`ID_R_WIDTH),
                .NumOutputs(NumSlaves)
            ) u_arid_demux (
                .data_i({i,axi_sl_ar[i].arid[0+:(`ID_R_WIDTH/2)]}),
                .sel_i(slave_sel[i]),
                .data_o(arid_vec[i])
            );

            // araddr demux
            demux #(
                .DataWidth(AddrWidth),
                .NumOutputs(NumSlaves)
            ) u_araddr_demux (
                .data_i(axi_sl_ar[i].araddr),
                .sel_i(slave_sel[i]),
                .data_o(araddr_vec[i])
            );

            // arlen demux
            demux #(
                .DataWidth(8),
                .NumOutputs(NumSlaves)
            ) u_arlen_demux (
                .data_i(axi_sl_ar[i].arlen),
                .sel_i(slave_sel[i]),
                .data_o(arlen_vec[i])
            );

            // arsize demux
            demux #(
                .DataWidth(3),
                .NumOutputs(NumSlaves)
            ) u_arsize_demux (
                .data_i(axi_sl_ar[i].arsize),
                .sel_i(slave_sel[i]),
                .data_o(arsize_vec[i])
            );

            // arburst demux
            demux #(
                .DataWidth(2),
                .NumOutputs(NumSlaves)
            ) u_arburst_demux (
                .data_i(axi_sl_ar[i].arburst),
                .sel_i(slave_sel[i]),
                .data_o(arburst_vec[i])
            );
        end
    endgenerate

    generate
        localparam int unsigned GrantWidth = $clog2(NumMasters) == 0 ? 1 : $clog2(NumMasters);

        logic [NumMasters-1:0] rd_req[NumSlaves];
        logic [NumMasters-1:0] rd_grant[NumSlaves];
        logic [GrantWidth-1:0] rd_bin_grant[NumSlaves];

        // Vectors of combined masters AR signals
        logic                   arvalid_masters_vec[NumSlaves][NumMasters];
        logic [`ID_R_WIDTH-1:0] arid_masters_vec[NumSlaves][NumMasters];
        logic [AddrWidth-1:0]   araddr_masters_vec[NumSlaves][NumMasters];
        logic [7:0]             arlen_masters_vec[NumSlaves][NumMasters];
        logic [2:0]             arsize_masters_vec[NumSlaves][NumMasters];
        logic [1:0]             arburst_masters_vec[NumSlaves][NumMasters];

        // AR signlas from selected master
        logic                   arvalid_sel[NumSlaves];
        logic [`ID_R_WIDTH-1:0] arid_sel[NumSlaves];
        logic [AddrWidth-1:0]   araddr_sel[NumSlaves];
        logic [7:0]             arlen_sel[NumSlaves];
        logic [2:0]             arsize_sel[NumSlaves];
        logic [1:0]             arburst_sel[NumSlaves];

        for (genvar i=0; i<NumSlaves; i=i+1) begin : gen_slave_ar_routing

            always_comb begin
                for (int j=0; j<NumMasters; j=j+1) begin
                    arvalid_masters_vec[i][j] = arvalid_vec[j][i];
                    arid_masters_vec[i][j]    = arid_vec[j][i];
                    araddr_masters_vec[i][j]  = araddr_vec[j][i];
                    arlen_masters_vec[i][j]   = arlen_vec[j][i];
                    arsize_masters_vec[i][j]  = arsize_vec[j][i];
                    arburst_masters_vec[i][j] = arburst_vec[j][i];

                    rd_req[i][j] = arvalid_vec[j][i];
                end

            end

            // arbiter
            rr_arbiter #(
                .Width(NumMasters)
            ) u_ar_arbiter (
                .clk(aclk),
                .rst_n(rst_n),
                .req_i(rd_req[i]),
                .grant_o(rd_grant[i]),
                .binary_grant_o(rd_bin_grant[i])
            );

            // arvalid mux
            mux #(
                .DataWidth(1),
                .NumInputs(NumMasters)
            ) u_arvalid_mux (
                .data_i(arvalid_masters_vec[i]),
                .sel_i(rd_bin_grant[i]),
                .data_o(arvalid_sel[i])
            );

            // arid mux
            mux #(
                .DataWidth(`ID_R_WIDTH),
                .NumInputs(NumMasters)
            ) u_arid_mux (
                .data_i(arid_masters_vec[i]),
                .sel_i(rd_bin_grant[i]),
                .data_o(arid_sel[i])
            );

            // araddr mux
            mux #(
                .DataWidth(AddrWidth),
                .NumInputs(NumMasters)
            ) u_araddr_mux (
                .data_i(araddr_masters_vec[i]),
                .sel_i(rd_bin_grant[i]),
                .data_o(araddr_sel[i])
            );

            // arlen mux
            mux #(
                .DataWidth(8),
                .NumInputs(NumMasters)
            ) u_arlen_mux (
                .data_i(arlen_masters_vec[i]),
                .sel_i(rd_bin_grant[i]),
                .data_o(arlen_sel[i])
            );

            // arsize mux
            mux #(
                .DataWidth(3),
                .NumInputs(NumMasters)
            ) u_arsize_mux (
                .data_i(arsize_masters_vec[i]),
                .sel_i(rd_bin_grant[i]),
                .data_o(arsize_sel[i])
            );

            // arburst mux
            mux #(
                .DataWidth(2),
                .NumInputs(NumMasters)
            ) u_arburst_mux (
                .data_i(arburst_masters_vec[i]),
                .sel_i(rd_bin_grant[i]),
                .data_o(arburst_sel[i])
            );

            // pipeline skid buffers
            localparam int unsigned ArIdWidth    = `ID_R_WIDTH;
            localparam int unsigned ArLenWidth   = 8;
            localparam int unsigned ArSizeWidth  = 3;
            localparam int unsigned ArBurstWidth = 2;
            localparam int unsigned ArDataSize   = AddrWidth + `ID_R_WIDTH + ArLenWidth +
                                                   ArSizeWidth + ArBurstWidth;

            logic [ArDataSize-1:0] skid_ardata_out[NumSlaves];
            logic                  skid_arvalid_out[NumSlaves];
            logic                  skid_arready_out[NumSlaves];

            pipeline_skid_buffer #(
                .DataWidth(ArDataSize)
            ) u_ar_skid_buffer (
                .clk_i(aclk),
                .rst_i(~rst_n),
                // input interface
                .valid_i(arvalid_sel[i]),
                .data_i ({arburst_sel[i],arsize_sel[i],arlen_sel[i],arid_sel[i],araddr_sel[i]}),
                .ready_o(skid_arready_out[i]),
                // output interface
                .ready_i(axi_m_ar[i].arready),
                .valid_o(skid_arvalid_out[i]),
                .data_o (skid_ardata_out[i])
            );

            assign axi_m_ar[i].arvalid = skid_arvalid_out[i];
            assign axi_m_ar[i].araddr  = skid_ardata_out[i][0+:AddrWidth];
            assign axi_m_ar[i].arid    = skid_ardata_out[i][AddrWidth+:`ID_R_WIDTH];
            assign axi_m_ar[i].arlen   = skid_ardata_out[i][(AddrWidth+`ID_R_WIDTH)+:ArLenWidth];
            assign axi_m_ar[i].arsize  = skid_ardata_out[i][(AddrWidth+`ID_R_WIDTH+ArLenWidth)
                                                             +:ArSizeWidth];
            assign axi_m_ar[i].arburst = skid_ardata_out[i][(AddrWidth+`ID_R_WIDTH+ArLenWidth
                                                             +ArSizeWidth)+:ArBurstWidth];

            // arready demux
            demux #(
                .DataWidth(1),
                .NumOutputs(NumMasters)
            ) u_arready_demux (
                .data_i(skid_arready_out[i]),
                .sel_i(rd_bin_grant[i]),
                .data_o(arready_vec[i])
            );
        end
    endgenerate

    generate
        logic arready_slaves_vec[NumMasters][NumSlaves];
        logic arready_sel[NumMasters];//, arready_sel_q[NumMasters];

        for (genvar i=0; i<NumMasters; i=i+1) begin : gen_arready_master_routing

            always_comb begin
                for (int j=0; j<NumSlaves; j=j+1) begin
                    arready_slaves_vec[i][j] = arready_vec[j][i];
                end
            end

            // arready mux
            mux #(
                .DataWidth(1),
                .NumInputs(NumSlaves)
            ) u_master_arready_mux (
                .data_i(arready_slaves_vec[i]),
                .sel_i(slave_sel[i]),
                .data_o(arready_sel[i])
            );

            //always_ff @(posedge aclk) begin
            //    if (axi_sl_ar[i].arvalid && axi_sl_ar[i].arready) begin
            //        arready_sel_q[i] <= 1'b0;
            //    end else begin
            //        arready_sel_q[i] <= arready_sel[i];
            //    end
            //end

            assign axi_sl_ar[i].arready = arready_sel[i];
        end
    endgenerate

endmodule
