`include "axi_config.svh"

module axi_icache #(
    parameter int unsigned SizeKiB     = 64,

    // block size in bytes
    parameter int unsigned BlockSize   = 64,
    parameter int unsigned AxiBusWidth = 64
) (
    input aclk,
    input reset_n,

    // icache interface
    data_req_if.in cpu_req_i,
    data_res_if.out cpu_res_o,

    // axi master interfaces
    axi_ar_if.master m_axi_ar,
    axi_r_if.master m_axi_r,
    axi_aw_if.master m_axi_aw,
    axi_w_if.master m_axi_w,
    axi_b_if.master m_axi_b,

    // axi slave interfaces
    axi_ar_if.slave s_axi_ar,
    axi_r_if.slave s_axi_r,
    axi_aw_if.slave s_axi_aw,
    axi_w_if.slave s_axi_w,
    axi_b_if.slave s_axi_b
);

    localparam int unsigned DataBusWidth  = 64;
    localparam int unsigned AddrWidth     = 32;
    localparam int unsigned BlockWidth    = $clog2(BlockSize);

    typedef enum logic [1:0] {
        AXI_BURST_FIXED = 2'b00,
        AXI_BURST_INCR  = 2'b01,
        AXI_BURST_WRAP  = 2'b10,
        AXI_BURST_RSVD  = 2'b11
    } axi_burst_t;

    typedef enum logic [1:0] {
        AXI_RESP_OKAY   = 2'b00,
        AXI_RESP_EXOKAY = 2'b01,
        AXI_RESP_SLVERR = 2'b10,
        AXI_RESP_DECERR = 2'b11
    } axi_resp_t;

    typedef enum logic [4:0] {
        AXI_SIZE_1B    = 3'b000,
        AXI_SIZE_2B    = 3'b001,
        AXI_SIZE_4B    = 3'b010,
        AXI_SIZE_8B    = 3'b011,
        AXI_SIZE_16B   = 3'b100,
        AXI_SIZE_32B   = 3'b101,
        AXI_SIZE_64B   = 3'b110,
        AXI_SIZE_128B  = 3'b111
    } axi_size_t;

    // icache controller interface
    data_req_if #(.DataWidth(DataBusWidth), .AddrWidth(AddrWidth)) mem_req();
    data_res_if #(.DataWidth(AxiBusWidth))                         mem_res();
    axi_req_if  #(.AddrWidth(AddrWidth))                           axi_rd_req();
    axi_req_if  #(.AddrWidth(AddrWidth))                           axi_wr_req();

    mem_if #(.NumBanks(4), .DataBusWidth(DataBusWidth), .AddrWidth(11)) mem_port();

    logic rst;
    assign rst = ~reset_n;

    icache_controller #(
        .SizeKiB(SizeKiB),
        .BlockSize(BlockSize)
    ) u_icache_controller (
        .clk_i(aclk),
        .rst_i(rst),
        .cpu_req(cpu_req_i),
        .axi_rd_req(axi_rd_req),
        .axi_wr_req(axi_wr_req),
        .mem_port(mem_port),
        .mem_res(mem_res),
        .cpu_res(cpu_res_o),
        .mem_req(mem_req)
    );

    logic wdata_fifo_empty, wdata_fifo_full;
    logic wfifo_rd, wfifo_wr;
    logic [AxiBusWidth-1:0] wdata_in_d, wdata_in_q;
    logic [AxiBusWidth-1:0] wdata;

    FIFO36E1 #(
       .ALMOST_EMPTY_OFFSET(13'h0080),
       .ALMOST_FULL_OFFSET(13'h0080),
       .DATA_WIDTH(72),
       .DO_REG(1),
       .EN_ECC_READ("FALSE"),
       .EN_ECC_WRITE("FALSE"),
       .EN_SYN("TRUE"),
       .FIFO_MODE("FIFO36_72"),
       .FIRST_WORD_FALL_THROUGH("FALSE"),
       .INIT(72'h000000000000000000),
       .SIM_DEVICE("7SERIES"),
       .SRVAL(72'h000000000000000000)
    )
    u_wdata_FIFO36E1 (
       .DO(wdata),
       .EMPTY(wdata_fifo_empty),
       .FULL(wdata_fifo_full),
       .INJECTDBITERR(1'b0),
       .INJECTSBITERR(1'b0),
       .RDCLK(aclk),
       .RDEN(wfifo_rd),
       .REGCE(1'b1),
       .RST(!reset_n),
       .RSTREG(!reset_n),
       .WRCLK(aclk),
       .WREN(wfifo_wr),
       .DI(wdata_in_q),
       .DIP('0)
    );

    logic wctrl_fifo_empty, wctrl_fifo_full;
    logic                       wlast;
    logic [31:0]                wctrl_in_d, wctrl_in_q;
    logic [(AxiBusWidth/8)-1:0] wstrb;

    FIFO18E1 #(
       .ALMOST_EMPTY_OFFSET(13'h0080),
       .ALMOST_FULL_OFFSET(13'h0080),
       .DATA_WIDTH(1+(AxiBusWidth/8)),
       .DO_REG(1),
       .EN_SYN("TRUE"),
       .FIFO_MODE("FIFO18"),
       .FIRST_WORD_FALL_THROUGH("FALSE"),
       .INIT(36'h000000000),
       .SIM_DEVICE("7SERIES"),
       .SRVAL(36'h000000000)
    )
    u_wctrl_FIFO18E1 (
       .DO({wlast, wstrb}),
       .EMPTY(wctrl_fifo_empty),
       .FULL(wctrl_fifo_full),
       .RDCLK(aclk),
       .RDEN(wfifo_rd),
       .REGCE(1'b1),
       .RST(!reset_n),
       .RSTREG(!reset_n),
       .WRCLK(aclk),
       .WREN(wfifo_wr),
       .DI(wctrl_in_q),
       .DIP('0)
    );

    //////////////////////
    // AXI Master Logic //
    //////////////////////

    typedef enum logic [2:0] {
        StRdReqIdle = 3'b001,
        StAddrReq   = 3'b010,
        StRRes      = 3'b100
    } read_req_state_e;

    read_req_state_e read_req_state_q;

    logic rlast_d, rlast_q;
    logic rready_d, rready_q;
    logic mem_res_ready_d, mem_res_ready_q;

    always_ff @(posedge aclk) begin
        rready_q        <= rready_d;
        rlast_q         <= rlast_d;
        mem_res_ready_q <= mem_res_ready_d;
    end

    assign m_axi_r.rready = rready_q;
    assign mem_res.ready = mem_res_ready_q;

    // read request FSM next state logic
    always_ff @(posedge aclk) begin
        if (!reset_n) begin
            read_req_state_q <= StRdReqIdle;
        end else begin
            unique case (read_req_state_q)
                StRdReqIdle: begin
                    if (mem_req.valid && mem_req.rd) begin
                        read_req_state_q <= StAddrReq;
                    end
                end
                StAddrReq: begin
                    if (m_axi_ar.arvalid && m_axi_ar.arready) begin
                        read_req_state_q <= StRRes;
                    end
                end
                StRRes: begin
                    if (rlast_q) begin
                        read_req_state_q <= StRdReqIdle;
                    end
                end
                default: read_req_state_q <= StRdReqIdle;
            endcase
        end
    end

    localparam logic [AddrWidth-1:0] BlockOffsetMask = ((1 << BlockWidth) - 1);
    localparam logic [2:0] AxiReqSize = $clog2(AxiBusWidth / 8);
    localparam logic [7:0] AxiReqLen = (BlockSize >> AxiReqSize) - 1; //(BlockSize*8/AxiBusWidth)-1

    // read request FSM logic
    always_comb begin
        m_axi_ar.arvalid = 1'b0;
        m_axi_ar.araddr  = '0;
        m_axi_ar.arid    = '0;
        m_axi_ar.arlen   = '0;
        m_axi_ar.arsize  = '0;
        m_axi_ar.arburst = '0;

        rready_d = 1'b0;
        rlast_d  = 1'b0;

        mem_res.data = m_axi_r.rdata;
        mem_res.valid = 1'b0;
        mem_res_ready_d = 1'b0;

        unique case (read_req_state_q)

            StAddrReq: begin
                if (m_axi_ar.arvalid && m_axi_ar.arready) begin
                    m_axi_ar.arvalid = 1'b0;
                    m_axi_ar.araddr  = '0;
                    m_axi_ar.arid    = '0;
                    m_axi_ar.arlen   = '0;
                    m_axi_ar.arsize  = '0;
                    m_axi_ar.arburst = '0;
                end else begin
                    m_axi_ar.arvalid = 1'b1;
                    // send address of first word of block
                    m_axi_ar.araddr  = mem_req.addr & ~BlockOffsetMask;
                    m_axi_ar.arid    = 'b1;
                    m_axi_ar.arlen   = AxiReqLen;
                    m_axi_ar.arsize  = AxiReqSize;
                    m_axi_ar.arburst = 2'b01;
                end
            end

            StRRes: begin
                // R interface logic
                if (m_axi_r.rvalid && m_axi_r.rready) begin
                    rready_d = 1'b0;
                end else begin
                    rready_d = 1'b1;
                end
                rlast_d = m_axi_r.rlast;

                // fifo write logic
                mem_res.data = m_axi_r.rdata;
                if (m_axi_r.rvalid && m_axi_r.rready) begin
                    mem_res.valid = 1'b1;
                end else begin
                    mem_res.valid = 1'b0;
                end
                if (rlast_q) begin
                    mem_res_ready_d = 1'b1;
                end else begin
                    mem_res_ready_d = 1'b0;
                end
            end

            default: begin
                m_axi_ar.arvalid = 1'b0;
                m_axi_ar.araddr  = '0;
                m_axi_ar.arid    = '0;
                m_axi_ar.arlen   = '0;
                m_axi_ar.arsize  = '0;
                m_axi_ar.arburst = '0;

                rready_d = 1'b0;
                rlast_d  = 1'b0;

                mem_res.data = m_axi_r.rdata;
                mem_res.valid = 1'b0;

                mem_res_ready_d = 1'b0;
            end
        endcase
    end

    /////////////////////////
    // AXI Slave Logic     //
    /////////////////////////

    // Slave AR interface
    logic                   s_arready_d, s_arready_q;
    logic [AddrWidth-1:0]   s_araddr_q;
    logic [`ID_R_WIDTH-1:0] s_arid_q;
    logic [7:0]             s_arlen_q;
    logic [2:0]             s_arsize_q;
    logic [1:0]             s_arburst_q;

    always_ff @(posedge aclk) begin
        if (s_axi_ar.arvalid && s_axi_ar.arready) begin
            s_araddr_q  <= s_axi_ar.araddr;
            s_arid_q    <= s_axi_ar.arid;
            s_arlen_q   <= s_axi_ar.arlen;
            s_arsize_q  <= s_axi_ar.arsize;
            s_arburst_q <= s_axi_ar.arburst;
        end

        s_arready_q <= s_arready_d;
    end

    assign s_axi_ar.arready = s_arready_q;

    // Slave R interface
    logic                   s_rvalid_d, s_rvalid_q;
    logic [AxiBusWidth-1:0] s_rdata_d, s_rdata_q;
    logic [`ID_R_WIDTH-1:0] s_rid_d, s_rid_q;
    logic [2:0]             s_rresp_d, s_rresp_q;
    logic                   s_rlast_d, s_rlast_q;
    logic                   s_rready_q;

    always_ff @(posedge aclk) begin
        if (!reset_n) begin
            s_rvalid_q <= 1'b0;
            s_rdata_q  <= '0;
            s_rid_q    <= '0;
            s_rresp_q  <= '0;
            s_rlast_q  <= 1'b0;
        end else begin
            s_rvalid_q <= s_rvalid_d;
            s_rdata_q  <= s_rdata_d;
            s_rid_q    <= s_rid_d;
            s_rresp_q  <= s_rresp_d;
            s_rlast_q  <= s_rlast_d;
        end

        s_rready_q <= s_axi_r.rready;
    end

    assign s_axi_r.rvalid = s_rvalid_q;
    assign s_axi_r.rid    = s_rid_q;
    assign s_axi_r.rresp  = s_rresp_q;
    assign s_axi_r.rlast  = s_rlast_q;

    // Slave AW interface
    logic                   s_awready_d, s_awready_q;
    logic [`ID_W_WIDTH-1:0] s_awid_q;
    logic [AddrWidth-1:0]   s_awaddr_q;
    logic [7:0]             s_awlen_q;
    logic [2:0]             s_awsize_q;
    logic [1:0]             s_awburst_q;

    assign s_axi_aw.awready = s_awready_q;

    always_ff @(posedge aclk) begin
        if (!reset_n) begin
            s_awready_q <= 1'b1;
        end else begin
            s_awready_q <= s_awready_d;
        end
        if (s_axi_aw.awvalid && s_axi_aw.awready) begin
            s_awid_q    <= s_axi_aw.awid;
            s_awaddr_q  <= s_axi_aw.awaddr;
            s_awlen_q   <= s_axi_aw.awlen;
            s_awsize_q  <= s_axi_aw.awsize;
            s_awburst_q <= s_axi_aw.awburst;
        end
    end

    // Slave W interface
    logic s_wready_d, s_wready_q;
    assign s_axi_w.wready = s_wready_q;

    always_ff @(posedge aclk) begin
        if (!reset_n) begin
            s_wready_q <= 1'b0;
        end else begin
            s_wready_q <= s_wready_d;
        end
    end

    // Slave B interface
    logic                    s_bvalid_d, s_bvalid_q;
    logic [`ID_W_WIDTH-1:0]  s_bid_d, s_bid_q;
    axi_resp_t               s_bresp_d, s_bresp_q;

    always_ff @(posedge aclk) begin
        if (!reset_n) begin
            s_bvalid_q <= 1'b0;
            s_bid_q    <= '0;
            s_bresp_q  <= AXI_RESP_OKAY;
        end else begin
            s_bvalid_q <= s_bvalid_d;
            s_bid_q    <= s_bid_d;
            s_bresp_q  <= s_bresp_d;
        end
    end

    assign s_axi_b.bvalid = s_bvalid_q;
    assign s_axi_b.bid    = s_bid_q;
    assign s_axi_b.bresp  = s_bresp_q;


    // External AXI master's read request FSM
    typedef enum logic [1:0] {
        StReadReqIdle = 2'b01,
        StReadReq     = 2'b10
    } rd_req_state_e;

    rd_req_state_e rd_req_state_d, rd_req_state_q;

    logic rd_req_valid_d, rd_req_valid_q;

    always_ff @(posedge aclk) begin
        if (!reset_n) begin
            rd_req_state_q <= StReadReqIdle;
            rd_req_valid_q <= 1'b0;
        end else begin
            rd_req_state_q <= rd_req_state_d;
            rd_req_valid_q <= rd_req_valid_d;
        end
    end

    always_comb begin
        rd_req_state_d = rd_req_state_q;
        rd_req_valid_d = rd_req_valid_q;
        s_arready_d      = s_araddr_q;

        unique case (rd_req_state_q)
            StReadReqIdle: begin
                s_arready_d = 1'b1;
                if (s_axi_ar.arvalid && s_axi_ar.arready) begin
                    rd_req_valid_d = 1'b1;
                    rd_req_state_d = StReadReq;
                    s_arready_d = 1'b0;
                end
            end

            StReadReq: begin
                s_arready_d = 1'b0;
                if (axi_rd_req.done) begin
                    rd_req_valid_d = 1'b0;
                    rd_req_state_d = StReadReqIdle;
                end
            end

            default: begin
                rd_req_state_d = rd_req_state_q;
                rd_req_valid_d = rd_req_valid_q;
                s_arready_d      = s_araddr_q;
            end
        endcase
    end


    // External AXI master's write request FSM
    typedef enum logic [1:0] {
        StWriteReqIdle = 2'b01,
        StWriteReq     = 2'b10
    } write_req_state_e;

    write_req_state_e write_req_state_d, write_req_state_q;

    logic awready_en_d, awready_en_q;
    logic wready_en_d, wready_en_q;
    logic wr_req_valid_d, wr_req_valid_q;
    logic wfifo_wr_d, wfifo_wr_q;

    assign wfifo_wr = wfifo_wr_q;

    always_ff @(posedge aclk) begin
        if (!reset_n) begin
            write_req_state_q <= StWriteReqIdle;
            awready_en_q      <= 1'b1;
            wready_en_q       <= 1'b1;
            wr_req_valid_q    <= 1'b0;
            wdata_in_q        <= '0;
            wctrl_in_q        <= '0;
            wfifo_wr_q <= 1'b0;
        end else begin
            write_req_state_q <= write_req_state_d;
            awready_en_q      <= awready_en_d;
            wready_en_q       <= wready_en_d;
            wr_req_valid_q    <= wr_req_valid_d;
            wdata_in_q        <= wdata_in_d;
            wctrl_in_q        <= wctrl_in_d;
            wfifo_wr_q <= wfifo_wr_d;
        end
    end

    always_comb begin
        write_req_state_d = write_req_state_q;
        s_awready_d       = s_awready_q;
        s_wready_d        = s_wready_q;
        awready_en_d      = awready_en_q;
        wready_en_d       = wready_en_q;
        wr_req_valid_d    = wr_req_valid_q;
        wdata_in_d        = wdata_in_q;
        wfifo_wr_d = wfifo_wr_q;

        unique case (write_req_state_q)
            StWriteReqIdle: begin
                // AW and W ready signals control logic
                if (!awready_en_q) begin
                    s_awready_d = 1'b0;
                end else if (s_axi_aw.awvalid && s_axi_aw.awready) begin
                    s_awready_d = 1'b0;
                end else begin
                    s_awready_d = 1'b1;
                end

                if (s_axi_aw.awvalid && s_axi_aw.awready) begin
                    awready_en_d = 1'b0;
                end

                if (!wready_en_q) begin
                    s_wready_d = 1'b0;
                end else if (s_axi_w.wvalid && s_axi_w.wready && s_axi_w.wlast) begin
                    s_wready_d = 1'b0;
                end else begin
                    s_wready_d = 1'b1;
                end

                if (s_axi_w.wvalid && s_axi_w.wready && s_axi_w.wlast) begin
                    wready_en_d = 1'b0;
                end

                // wdata and wstrb/wlast fifo write logic
                if (s_axi_w.wvalid && s_axi_w.wready) begin
                    wdata_in_d = s_axi_w.wdata;
                    wctrl_in_d = 32'h0 | {s_axi_w.wlast,s_axi_w.wstrb};
                    wfifo_wr_d   = 1'b1;
                end else begin
                    wfifo_wr_d = 1'b0;
                end

                // Next state condition
                if ((!s_awready_q) && (!wready_en_q)) begin
                    wr_req_valid_d   = 1'b1;
                    write_req_state_d = StWriteReq;
                end
            end

            StWriteReq: begin
                awready_en_d = 1'b0;
                wready_en_d  = 1'b0;
                wfifo_wr_d = 1'b0;

                if (axi_wr_req.done) begin
                    awready_en_d      = 1'b1;
                    wready_en_d       = 1'b1;
                    wr_req_valid_d    = 1'b0;
                    write_req_state_d = StWriteReqIdle;
                end
            end

            default: begin
                write_req_state_d = StWriteReqIdle;
            end
        endcase
    end


    typedef enum logic [8:0] {
        StReqIdle          = 9'h1,
        StAXIInitReadReq   = 9'h2,
        StAXIReadReq       = 9'h4,
        StAXIInitWriteReq  = 9'h8,
        StAXIRead          = 9'h10,
        StAXIWriteReq      = 9'h20,
        StAXIWriteFifoInit = 9'h40,
        StAXIWrite         = 9'h80,
        StAXIWriteResp     = 9'h100
    } axi_req_state_e;

    axi_req_state_e axi_req_state_d, axi_req_state_q;

    always_ff @(posedge aclk) begin
        if (!reset_n) begin
            axi_req_state_q <= StReqIdle;
        end else begin
            axi_req_state_q <= axi_req_state_d;
        end
    end


    // Address width of each bank (way). For example, for a 4-way 64 KiB memory, there
    // are 4 banks of 16 KiB each and if the data bus of each bank is 64 bits, then each
    // bank has 16 KiB / 8 = 2048 addresses and the addr width is 11 bits
    localparam int unsigned BankAddrWidth = $clog2((SizeKiB*1024/4)/(DataBusWidth/8));

    // Offset in the address to select a row of a memory bank
    localparam int unsigned RowOffset = $clog2((DataBusWidth/8));

    // There are four banks (ways). When accessing as plain memory,
    // the banks are accessed sequentially as addresses increment.
    // The two most significant bits of the request address select the bank.
    localparam int unsigned AddrMSB = $clog2(SizeKiB * 1024) - 1;

    // Start address aligned to bank's size
    logic [BankAddrWidth-1:0] start_addr_d, start_addr_q;

    // AXI transfer's size in bytes
    logic [15:0] size_d, size_q;

    // Start address aligned to transfer's size
    logic [AddrWidth-1:0] aligned_addr_d, aligned_addr_q;

    // Number of bytes requested in a transaction
    logic [15:0] container_size_d, container_size_q;

    // Lower and upper wrap boundaries for wrap bursts
    logic [AddrWidth-1:0] lower_wrap_boundary_d, lower_wrap_boundary_q;
    logic [AddrWidth-1:0] upper_wrap_boundary_d, upper_wrap_boundary_q;

    //assign upper_wrap_boundary = lower_wrap_boundary + container_size - 1'b1;

    // Register to keep track of next transfer address
    logic [AddrWidth-1:0] addr_d, addr_q;

    logic [1:0] init_counter_d, init_counter_q;

    logic [7:0] beats_counter_d, beats_counter_q;

    logic rd_req_ready_q, wr_req_ready_q;

    always_ff @(posedge aclk) begin
        start_addr_q          <= start_addr_d;
        size_q                <= size_d;
        aligned_addr_q        <= aligned_addr_d;
        container_size_q      <= container_size_d;
        lower_wrap_boundary_q <= lower_wrap_boundary_d;
        upper_wrap_boundary_q <= upper_wrap_boundary_d;
        addr_q                <= addr_d;
        init_counter_q        <= init_counter_d;
        beats_counter_q       <= beats_counter_d;
        rd_req_ready_q        <= axi_rd_req.ready;
        wr_req_ready_q        <= axi_wr_req.ready;
    end


    always_comb begin
        axi_req_state_d  = axi_req_state_q;

        axi_rd_req.valid = 1'b0;
        axi_rd_req.addr  = '0;
        axi_rd_req.data  = '0;
        axi_rd_req.done  = 1'b0;
        axi_wr_req.valid = 1'b0;
        axi_wr_req.addr  = '0;
        axi_wr_req.data  = '0;
        axi_wr_req.done  = 1'b0;

        start_addr_d          = start_addr_q;
        size_d                = size_q;
        aligned_addr_d        = aligned_addr_q;
        container_size_d      = container_size_q;
        lower_wrap_boundary_d = lower_wrap_boundary_q;
        upper_wrap_boundary_d = upper_wrap_boundary_q;
        addr_d                = addr_q;
        beats_counter_d       = beats_counter_q;
        init_counter_d        = init_counter_q;

        mem_port.en   = '0;
        mem_port.we   = '0;
        mem_port.addr = '0;
        mem_port.din  = '0;

        s_rvalid_d    = s_rvalid_q;
        s_rdata_d     = '0;
        s_axi_r.rdata = '0;
        s_rid_d       = '0;
        s_rresp_d     = '0;
        s_rlast_d     = s_rlast_q;

        s_bvalid_d = s_bvalid_q;
        s_bid_d    = s_bid_q;
        s_bresp_d  = s_bresp_q;

        wfifo_rd = 1'b0;

        unique case (axi_req_state_q)
            StReqIdle: begin
                init_counter_d = '0;
                if (rd_req_valid_q) begin
                    axi_req_state_d = StAXIInitReadReq;
                end else if (wr_req_valid_q) begin
                    axi_req_state_d = StAXIInitWriteReq;
                end
            end

            StAXIInitReadReq: begin
                start_addr_d          = s_araddr_q[BankAddrWidth-1:RowOffset];
                size_d                = 1 << s_arsize_q;
                aligned_addr_d        = s_araddr_q & ~(size_q - 1);
                container_size_d      = (s_arlen_q + 1'b1) << s_arsize_q;
                lower_wrap_boundary_d = s_araddr_q & ~(container_size_q - 1'b1);

                init_counter_d = init_counter_q + 1'b1;

                if (init_counter_q == 2'b01) begin
                    init_counter_d  = '0;
                    axi_req_state_d = StAXIReadReq;
                end
            end

            StAXIReadReq: begin
                axi_rd_req.valid = 1'b1;
                axi_rd_req.addr  = s_araddr_q;
                if (rd_req_ready_q) begin
                    mem_port.en[s_araddr_q[AddrMSB-:2]] = 1'b1;
                    mem_port.we = '0;
                    mem_port.addr = aligned_addr_q[BankAddrWidth-1:RowOffset];
                    addr_d = aligned_addr_q;
                    beats_counter_d = '0;

                    axi_req_state_d = StAXIRead;
                end
            end

            StAXIRead: begin
                axi_rd_req.addr = addr_q;

                mem_port.en[addr_q[AddrMSB-:2]] = 1'b1;
                mem_port.we = '0;
                mem_port.addr = addr_q[BankAddrWidth-1:RowOffset];

                if (s_axi_r.rvalid && s_axi_r.rready) begin
                    s_rvalid_d = '0;
                    s_rdata_d  = '0;
                    s_axi_r.rdata = s_rdata_q;
                    s_rid_d    = '0;
                    s_rresp_d  = '0;
                    s_rlast_d  = '0;

                    beats_counter_d = beats_counter_q + 1'b1;

                    unique case (s_arburst_q)
                        // Fixed burst
                        2'b00: addr_d = aligned_addr_q;
                        // Incr burst
                        2'b01: addr_d = addr_q + size_q;
                        // Wrap burst
                        2'b10: addr_d = lower_wrap_boundary_q | ((addr_q + size_q) & (container_size_q - 1'b1));
                        default: addr_d = addr_q;
                    endcase
                    if (s_rlast_q) begin
                        axi_rd_req.done = 1'b1;
                        axi_req_state_d = StReqIdle;
                    end
                end else begin
                    s_rvalid_d    = 1'b1;
                    s_rdata_d     = mem_port.dout[addr_q[AddrMSB-:2]];
                    s_axi_r.rdata = mem_port.dout[addr_q[AddrMSB-:2]];
                    s_rid_d       = s_arid_q;
                    s_rresp_d     = '0;
                    if (beats_counter_q == s_arlen_q) begin
                        s_rlast_d = 1'b1;
                    end else begin
                        s_rlast_d = 1'b0;
                    end
                end
            end

            StAXIInitWriteReq: begin
                start_addr_d          = s_awaddr_q[BankAddrWidth-1:RowOffset];
                size_d                = 1 << s_awsize_q;
                aligned_addr_d        = s_awaddr_q & ~(size_q - 1);
                container_size_d      = (s_awlen_q + 1'b1) << s_awsize_q;
                lower_wrap_boundary_d = s_awaddr_q & ~(container_size_q - 1'b1);
                upper_wrap_boundary_d = lower_wrap_boundary_q + container_size_q - 1'b1;

                init_counter_d = init_counter_q + 1'b1;

                if (init_counter_q == 2'b10) begin
                    init_counter_d  = '0;
                    axi_req_state_d = StAXIWriteReq;
                end
            end

            StAXIWriteReq: begin
                axi_wr_req.valid = 1'b1;
                axi_wr_req.addr  = s_awaddr_q;
                if (wr_req_ready_q) begin
                    beats_counter_d = '0;
                    wfifo_rd        = 1'b1;
                    axi_req_state_d = StAXIWriteFifoInit;
                end
            end

            StAXIWriteFifoInit: begin
                axi_wr_req.addr  = s_awaddr_q;

                wfifo_rd = 1'b1;

                mem_port.en[s_awaddr_q[AddrMSB-:2]] = 1'b1;
                mem_port.addr   = aligned_addr_q[BankAddrWidth-1:RowOffset];
                mem_port.din    = wdata;
                addr_d          = aligned_addr_q;
                axi_req_state_d = StAXIWrite;
            end

            StAXIWrite: begin
                axi_wr_req.addr = addr_q;
                axi_wr_req.data = wdata;

                mem_port.en[addr_q[AddrMSB-:2]] = 1'b1;
                mem_port.we   = wstrb;
                mem_port.addr = addr_q[BankAddrWidth-1:RowOffset];
                mem_port.din  = wdata;

                wfifo_rd = 1'b1;

                unique case (s_awburst_q)
                    // Fixed burst
                    2'b00: addr_d = aligned_addr_q;
                    // Incr burst
                    2'b01: addr_d = addr_q + size_q;
                    // Wrap burst
                    2'b10: addr_d = lower_wrap_boundary_q | ((addr_q + size_q) & (container_size_q - 1'b1));
                    default: addr_d = addr_q;
                endcase

                beats_counter_d = beats_counter_q + 1'b1;

                if (beats_counter_q == s_awlen_q) begin
                    axi_wr_req.done = 1'b1;
                    axi_req_state_d = StAXIWriteResp;
                end
            end

            StAXIWriteResp: begin
                if (s_axi_b.bvalid && s_axi_b.bready) begin
                    s_bvalid_d = 1'b0;
                    s_bid_d    = '0;
                    s_bresp_d  = AXI_RESP_OKAY;
                    axi_req_state_d = StReqIdle;
                end else begin
                    s_bvalid_d = 1'b1;
                    s_bid_d    = s_awid_q;
                    s_bresp_d  = AXI_RESP_OKAY;
                end
            end
            default: axi_req_state_d = StReqIdle;
        endcase
    end

    // ------------------------------------------------------------------
    // Unused AXI Master Interfaces
    // ------------------------------------------------------------------
    assign m_axi_aw.awvalid = 1'b0;
    assign m_axi_aw.awid    = '0;
    assign m_axi_aw.awaddr  = '0;
    assign m_axi_aw.awlen   = '0;
    assign m_axi_aw.awsize  = '0;
    assign m_axi_aw.awburst = '0;
    assign m_axi_w.wvalid   = 1'b0;
    assign m_axi_w.wdata    = '0;
    assign m_axi_w.wstrb    = '0;
    assign m_axi_w.wlast    = '0;
    assign m_axi_b.bready   = 1'b0;

endmodule
