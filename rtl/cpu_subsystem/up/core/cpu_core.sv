module cpu_core #(
    parameter int unsigned XLEN = 32
) (
    input clk_i,
    input rst_i,
    input en_i,

    // Icahce AXI Inport
    axi_ar_if.slave ic_s_axi_ar,
    axi_r_if.slave  ic_s_axi_r,
    axi_aw_if.slave ic_s_axi_aw,
    axi_w_if.slave  ic_s_axi_w,
    axi_b_if.slave  ic_s_axi_b,

    // Icache AXI outport
    axi_ar_if.master ic_m_axi_ar,
    axi_r_if.master  ic_m_axi_r,
    axi_aw_if.master ic_m_axi_aw,
    axi_w_if.master  ic_m_axi_w,
    axi_b_if.master  ic_m_axi_b

//    // Dcahce AXI Inport
//    axi_ar_if.slave dc_s_axi_ar,
//    axi_r_if.slave  dc_s_axi_r,
//    axi_aw_if.slave dc_s_axi_aw,
//    axi_w_if.slave  dc_s_axi_w,
//    axi_b_if.slave  dc_s_axi_b,
//
//    // Dache AXI outport
//    axi_ar_if.master dc_m_axi_ar,
//    axi_r_if.master  dc_m_axi_r,
//    axi_aw_if.master dc_m_axi_aw,
//    axi_w_if.master  dc_m_axi_w,
//    axi_b_if.master  dc_m_axi_b
);

    data_req_if #(.DataWidth(32), .AddrWidth(32)) cpu_req();
    data_res_if #(.DataWidth(64))                 cpu_res();

    logic reset_n;
    assign reset_n = ~rst_i;

    logic front_end_stall;

    decode_pkg::renamed_t renamed_instr[2];
    logic front_end_valid;

    logic dispatch_ready;

    assign front_end_stall = ~dispatch_ready;

    // ------------------------------------------------------------------
    // Instruction cache
    // ------------------------------------------------------------------
    axi_icache #(
        .SizeKiB(64),
        .BlockSize(64),
        .AxiBusWidth(64)
    ) u_icache (
        .aclk(clk_i),
        .reset_n(reset_n),

        // icache interface
        .cpu_req_i(cpu_req),
        .cpu_res_o(cpu_res),

        // axi master interfaces
        .m_axi_ar(ic_m_axi_ar),
        .m_axi_r(ic_m_axi_r),
        .m_axi_aw(ic_m_axi_aw),
        .m_axi_w(ic_m_axi_w),
        .m_axi_b(ic_m_axi_b),

        // axi slave interfaces
        .s_axi_ar(ic_s_axi_ar),
        .s_axi_r(ic_s_axi_r),
        .s_axi_aw(ic_s_axi_aw),
        .s_axi_w(ic_s_axi_w),
        .s_axi_b(ic_s_axi_b)
    );

    // ------------------------------------------------------------------
    // Front_end
    // ------------------------------------------------------------------
    front_end #(
        .XLEN(XLEN)
    ) u_front_end (
        .rst_i(rst_i),
        .clk_i(clk_i),
        .en_i(en_i),
        .stall_i(front_end_stall),
        .branch_i(1'b0),
        .branch_pc_i('0),
        .reset_pc_i('0),
        .cpu_res_i(cpu_res),
        .cpu_req_o(cpu_req),
        .renamed_o(renamed_instr),
        .renamed_valid_o(front_end_valid)
    );



endmodule
