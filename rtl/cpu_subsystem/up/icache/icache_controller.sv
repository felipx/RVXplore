module icache_controller #(
    parameter int unsigned SizeKiB   = 64,
    // block size in bytes
    parameter int unsigned BlockSize = 64
) (
    input clk_i,
    input rst_i,

    // input interface (cpu->icache)
    data_req_if.in cpu_req,

    // input interface (axi controller->icache)
    axi_req_if.slave axi_rd_req,
    axi_req_if.slave axi_wr_req,

    // input interface (axi controller->icache)
    mem_if.slave mem_port,

    // input interface (mem->axi controller->icache)
    data_res_if.in mem_res,

    // output interface (icache->cpu)
    data_res_if.out cpu_res,

    // output interface (icache->axi controller->imem)
    data_req_if.out mem_req
);
    localparam int unsigned NWays        = 4;
    localparam int unsigned DataBusWidth = 64;
    localparam int unsigned AddrWidth    = 32;

    // offset within the block
    localparam int unsigned BlockWidth   = $clog2(BlockSize/4);                     // 4

    // block index
    localparam int unsigned IndexWidth   = $clog2(SizeKiB*1024/NWays/BlockSize);    // 8

    // Tag size
    localparam int unsigned TagWidth     = AddrWidth - IndexWidth - BlockWidth - 2; // 18

    localparam int unsigned BlockLSB     = 2;                                       // 2
    localparam int unsigned BlockMSB     = BlockLSB + BlockWidth - 1;               // 5
    localparam int unsigned IndexLSB     = BlockMSB + 1;                            // 6
    localparam int unsigned IndexMSB     = IndexLSB + IndexWidth - 1;               // 13
    localparam int unsigned TagLSB       = IndexMSB + 1;                            // 14
    localparam int unsigned TagMSB       = TagLSB + TagWidth - 1;                   // 31

    localparam int unsigned AxiBusWidth  = 64;
    localparam int unsigned WordWidth    = 32;

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

    // 64 bits wide memory data bus:
    // There are 8 bytes per address so a cache block comprises 8 addresses (64 bytes) of the memory bank.
    // Each way is two banks of two 1024-depth memories. The memory address width is 3 bits larger
    // than the index width extracted from the 32 bit address.

    logic [3:0]                  enA;
    logic [(DataBusWidth/8)-1:0] weA;
    logic [BankAddrWidth-1:0]    addrA;
    logic [DataBusWidth-1:0]     dinA;
    logic [DataBusWidth-1:0]     doutA[4];

    // ----------------------------------------------------------
    // 4-way data memory instantiation
    // ----------------------------------------------------------
    generate
        for (genvar i=0; i<4; i=i+1) begin : gen_4_way_cache_mem
            dp_memory_bank_2 #(
                .SizeKiB(SizeKiB/4),
                .DataWidth(DataBusWidth)
            ) u_icahe_mem (
                .clkA_i(clk_i),
                .enA_i(enA[i]),
                .weA_i(weA),
                .addrA_i(addrA),
                .dinA_i(dinA),
                .doutA_o(doutA[i]),

                .clkB_i(clk_i),
                .enB_i(mem_port.en[i]),
                .weB_i(mem_port.we),
                .addrB_i(mem_port.addr),
                .dinB_i(mem_port.din),
                .doutB_o(mem_port.dout[i])
            );
        end
    endgenerate

    logic [3:0]          tag_enA;
    logic [3:0]          tag_weA;
    logic [TagWidth-1:0] tag_dinA;
    logic [TagWidth-1:0] tag_doutA[4];

    // ----------------------------------------------------------
    // 4-way tag memory instantiation
    // ----------------------------------------------------------
    generate
        for (genvar i=0; i<4; i=i+1) begin : gen_4_way_cache_tag
            bytewrite_tdp_ram_nc #(
                .NumCol(1),
                .ColWidth(TagWidth),
                .AddrWidth(IndexWidth)
            ) u_icache_tag_mem (
                .clkA(clk_i),
                .enaA(tag_enA[i]),
                .weA(tag_weA[i]),
                .addrA(cpu_req.addr[IndexMSB:IndexLSB]),
                .dinA(tag_dinA),
                .doutA(tag_doutA[i]),

                .clkB(1'b0),
                .enaB(1'b0),
                .weB(1'b0),
                .addrB('0),
                .dinB('0),
                .doutB()
            );
        end
    endgenerate

    localparam int unsigned ValidAddrWidth = $clog2(SizeKiB*1024/NWays/BlockSize/32); //3

    logic [3:0]  valid_we[4];
    logic [31:0] valid_din;
    logic [31:0] valid_dout[4];
    logic [31:0] valid_mask;

    logic [3:0]                valid_enB;
    logic [3:0]                valid_weB;
    logic [ValidAddrWidth-1:0] valid_addrB;
    logic [31:0]               valid_dinB;

    assign valid_mask = 32'h1 << cpu_req.addr[IndexLSB+:5];

    // ----------------------------------------------------------
    // Valid-bit RAMs for per-block cache line validity
    // ----------------------------------------------------------
    generate
        for (genvar i=0; i<4; i=i+1) begin : gen_4_way_valid_ram
            bytewrite_tdp_ram_nc #(
                .NumCol(4),
                .ColWidth(8),
                .AddrWidth(ValidAddrWidth)
            ) u_icache_valid_bit_mem (
                .clkA(clk_i),
                .enaA(tag_enA),
                .weA(valid_we[i]),
                .addrA(cpu_req.addr[IndexMSB-:3]),
                .dinA(valid_din),
                .doutA(valid_dout[i]),

                .clkB(clk_i),
                .enaB(valid_enB),
                .weB(valid_weB),
                .addrB(valid_addrB),
                .dinB(valid_dinB),
                .doutB()
            );
        end
    endgenerate

    logic          fifo_rd;
    logic [64-1:0] fifo_dout;
    logic          fifo_empty;

    // ----------------------------------------------------------
    // AXI FIFO buffer to gather incoming memory line data
    // ----------------------------------------------------------
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
    u_iache_FIFO36E1 (
       .DO(fifo_dout),
       .EMPTY(fifo_empty),
       .FULL(),
       .INJECTDBITERR(1'b0),
       .INJECTSBITERR(1'b0),
       .RDCLK(clk_i),
       .RDEN(fifo_rd),
       .REGCE(1'b1),
       .RST(rst_i),
       .RSTREG(rst_i),
       .WRCLK(clk_i),
       .WREN(mem_res.valid),
       .DI(mem_res.data),
       .DIP('0)
    );

    // ----------------------------------------------------------
    // Tag comparison and hit determination logic
    // ----------------------------------------------------------
    logic [3:0] tag_match;
    logic [3:0] hit_vect;
    logic       hit;
    logic       cache_access;

    generate
        for (genvar i=0; i<4; i=i+1) begin : gen_hit_vector
            comparator #(
                .DataWidth(TagWidth)
            ) u_tag_comparator (
                .a_i(cpu_req.addr[TagMSB:TagLSB]),
                .b_i(tag_doutA[i]),
                .comp_o(tag_match[i])
            );

            bit_reducer #(
                .Operation("AND"),
                .InputCount(2)
            ) u_cache_way_AND_gate (
                .bits_in({valid_dout[i][cpu_req.addr[IndexLSB+:5]], tag_match[i]}),
                .bit_out(hit_vect[i])
            );
        end
    endgenerate

    bit_reducer #(
        .Operation("OR"),
        .InputCount(4)
    ) u_hit_OR_gate (
        .bits_in(hit_vect),
        .bit_out(hit)
    );


    // ----------------------------------------------------------
    // PLRU replacement state machine for victim way selection
    // ----------------------------------------------------------
    logic [1:0] victim_sel;

    plru_4way u_plru_bits (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .access_i(cache_access),
        .hit_vect_i(hit_vect),
        .victim_o(victim_sel)
    );

    logic [DataBusWidth-1:0] data_out;
    logic [WordWidth-1:0]    word_out;

    mux_one_hot_flat #(
        .DataWidth(DataBusWidth),
        .NumInputs(4)
    ) u_data_out_mux (
        .data_i({doutA[3],doutA[2],doutA[1],doutA[0]}),
        .sel_i(hit_vect),
        .data_o(data_out)
    );

    //multiplexer #(
    //    .DataWidth(WordWidth),
    //    .NumInputs(DataBusWidth/WordWidth)
    //) u_word_out_mux (
    //    .data_i(data_out),
    //    .sel_i(cpu_req.addr[BlockLSB+:2]),
    //    .data_o(word_out)
    //);

    assign cpu_res.data = cache_enabled_q ? data_out : doutA[cpu_req.addr[AddrMSB-:2]];

    // ----------------------------------------------------------
    // CPU-facing FSM: request, tag compare, miss handling, allocation
    // ----------------------------------------------------------
    typedef enum logic [3:0] {
        StIdle       = 4'h1,
        StCompareTag = 4'h2,
        StMemReq     = 4'h4,
        StAllocate   = 4'h8
    } cpu_req_state_e;

    cpu_req_state_e cpu_req_state_q, cpu_req_state_d;

    logic                        en_d, en_q;
    logic [(DataBusWidth/8)-1:0] we_d, we_q;
    logic [BankAddrWidth-1:0]    addr_d, addr_q;
    logic [DataBusWidth-1:0]     din_d, din_q;
    logic                        toggle_d, toggle_q;
    logic [3:0]                  counter_d, counter_q;

    assign weA   = we_q;
    assign addrA = addr_q;
    assign dinA  = din_q;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            cpu_req_state_q <= StIdle;
            en_q            <= 1'b0;
            we_q            <= '0;
            addr_q          <= '0;
            din_q           <= '0;
            toggle_q        <= 1'b0;
            counter_q       <= '0;
        end else begin
            cpu_req_state_q <= cpu_req_state_d;
            en_q            <= en_d;
            we_q            <= we_d;
            addr_q          <= addr_d;
            din_q           <= din_d;
            toggle_q        <= toggle_d;
            counter_q       <= counter_d;
        end
    end


    // ----------------------------------------------------------
    // Cache enable/disable control via special address writes
    // ----------------------------------------------------------
    // Mode control: when 'cache_enabled' is high, normal cache operation is active.
    // When low, the memory functions as a direct instruction memory.
    logic cache_enabled_q, cache_enabled_d;
    logic cpu_enable_cache, cpu_disable_cache;
    logic axi_enable_cache, axi_disable_cache;
    logic [31:0] CacheEnableAddr = 32'h0000_FFFC;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            cache_enabled_q <= 1'b1;
        end else begin
            cache_enabled_q <= cache_enabled_d;
        end
    end

    always_comb begin
        cpu_enable_cache  = cpu_req.wr &&
                            (cpu_req.addr == CacheEnableAddr) &&
                            (cpu_req.data == 32'h0);

        cpu_disable_cache = cpu_req.wr &&
                            (cpu_req.addr != CacheEnableAddr);

        axi_enable_cache  = axi_wr_req.valid &&
                            (axi_wr_req.addr == CacheEnableAddr) &&
                            (axi_wr_req.data == 32'h0);

        axi_disable_cache = axi_wr_req.valid &&
                            (axi_wr_req.addr != CacheEnableAddr);

        if (cpu_disable_cache || axi_disable_cache) begin
            cache_enabled_d = 1'b0;
        end else if (cpu_enable_cache || axi_enable_cache) begin
            cache_enabled_d = 1'b1;
        end else begin
            cache_enabled_d = cache_enabled_q;
        end
    end

    // ----------------------------------------------------------
    // Valid-state FSM to invalidate cache when disabling
    // ----------------------------------------------------------
    typedef enum logic [1:0] {
        StCacheOperational = 2'h1,
        StInvalidateCache  = 2'h2
    } valid_state_e;

    valid_state_e valid_state_q, valid_state_d;

    logic                      cache_ready_q, cache_ready_d;
    logic [ValidAddrWidth-1:0] addr_counter_d, addr_counter_q;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            valid_state_q <= StCacheOperational;
            cache_ready_q <= 1'b1;
        end else begin
            valid_state_q <= valid_state_q;
            cache_ready_q <= cache_ready_d;
        end
    end

    always_comb begin
        valid_state_d  = valid_state_q;
        cache_ready_d  = cache_ready_q;
        addr_counter_d = addr_counter_q;

        valid_enB   = '0;
        valid_weB   = '0;
        valid_addrB = '0;
        valid_dinB  = '0;

        unique case (valid_state_q)
            StCacheOperational: begin
                cache_ready_d = 1'b1;

                if (cpu_disable_cache || axi_disable_cache) begin
                    addr_counter_d = '0;
                    valid_state_d  = StInvalidateCache;
                end
            end
            StInvalidateCache: begin
                cache_ready_d = 1'b0;

                //TODO: drive port A too, to reduce latency

                valid_enB   = '1;
                valid_weB   = '1;
                valid_addrB = addr_counter_q;
                valid_dinB  = '0;

                addr_counter_d = addr_counter_q + 1'b1;
                if (addr_counter_q == '1) begin
                    addr_counter_d = '0;
                    valid_state_d = StCacheOperational;
                end
            end
            default: valid_state_d = StCacheOperational;
        endcase
    end

    always_comb begin
        cpu_req_state_d = cpu_req_state_q;
        cpu_req.ready   = 1'b0;
        cpu_res.valid   = 1'b0;
        cpu_res.error   = 1'b0;

        tag_enA      = 4'b1111;
        tag_weA      = '0;
        tag_dinA     = '0;
        valid_we[0]  = '0;
        valid_we[1]  = '0;
        valid_we[2]  = '0;
        valid_we[3]  = '0;
        valid_din    = '0;

        mem_req.valid = 1'b0;
        mem_req.addr  = '0;
        mem_req.data  = '0;
        mem_req.wr    = 1'b0;
        mem_req.rd    = 1'b0;

        fifo_rd = 1'b0;

        enA     = '0;
        we_d    = we_q;
        addr_d  = addr_q;
        din_d   = din_q;

        toggle_d  = 1'b0;
        counter_d = counter_q;

        unique case (cpu_req_state_q)
            StIdle: begin
                cpu_req.ready = 1'b1;

                enA[cpu_req.addr[AddrMSB-:2]] = 1'b1;
                addr_d = cpu_req.addr[BankAddrWidth-1:RowOffset];
                din_d  = cpu_req.addr[3] ? {cpu_req.data,32'h0} : {32'h0, cpu_req.data};

                if (cpu_req.rd) begin
                    if (cache_enabled_q && cache_ready_q) begin
                        cpu_req_state_d = StCompareTag;
                    end else begin
                        if (!((axi_req_state_q == StAxiWr) && (cpu_req.addr == axi_wr_req.addr))) begin
                            cpu_res.valid = 1'b1;
                        end
                    end
                end

                if (cpu_req.wr) begin
                    if (!(((axi_req_state_q == StAxiWr) && (cpu_req.addr == axi_wr_req.addr)) ||
                        ((axi_req_state_q == StAxiRd) && (cpu_req.addr == axi_rd_req.addr)))) begin
                        we_d = cpu_req.addr[3] ? 8'hF0 : 8'h0F;
                        cpu_res.valid = 1'b1;
                    end
                end
            end

            StCompareTag: begin
                enA = '1;
                addr_d = cpu_req.addr[IndexMSB:3];
                if (hit) begin
                    cpu_res.valid   = 1'b1;
                    cpu_req_state_d = StIdle;
                end else begin
                    tag_weA[victim_sel]  = 1'b1;
                    tag_dinA             = cpu_req.addr[TagMSB:TagLSB];
                    valid_we[victim_sel] = '1;
                    valid_din            = valid_dout[victim_sel] | valid_mask;
                    mem_req.valid        = 1'b1;
                    mem_req.addr         = cpu_req.addr;
                    mem_req.rd           = 1'b1;
                    cpu_req_state_d      = StMemReq;
                end
            end

            StMemReq: begin
                if (!mem_res.ready) begin
                    mem_req.addr  = cpu_req.addr;
                    if (counter_q == 4'b0001) begin
                        fifo_rd         = 1'b1;
                        we_d            = '1;
                        cpu_req_state_d = StAllocate;
                        counter_d       = '0;
                    end
                end else begin
                    mem_req.valid = 1'b0;
                    mem_req.addr  = '0;
                    mem_req.rd    = 1'b0;
                    fifo_rd       = 1'b1;
                    counter_d     = counter_q + 1'b1;
                end
            end

            StAllocate: begin
                // TODO:
                // It may be needed to check for overlaps with ongoing axi transactions
                fifo_rd          = 1'b1;
                enA[victim_sel]  = 1'b1;
                we_d             = '1;
                addr_d           = cpu_req.addr[IndexMSB:3] + counter_q;
                din_d            = fifo_dout;
                counter_d        = counter_q + 1'b1;

                if (counter_q == 4'b0111) begin
                    we_d           = '0;
                end
                if (counter_q == 4'b1000) begin
                    enA             = '1;
                    we_d            = '0;
                    cpu_req_state_d = StCompareTag;
                end
            end
            default:;
        endcase
    end


    // ----------------------------------------------------------
    // AXI-request FSM: handles external read/write transactions
    // ----------------------------------------------------------
    typedef enum logic [4:0] {
        StAxiIdle   = 5'h1,
        StAxiRd     = 5'h2,
        StAxiWr     = 5'h4,
        StAxiWaitRd = 5'h8,
        StAxiWaitWr = 5'h10
    } axi_req_state_e;

    axi_req_state_e axi_req_state_q, axi_req_state_d;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            axi_req_state_q <= StAxiIdle;
        end else begin
            axi_req_state_q <= axi_req_state_d;
        end
    end

    // bit mask of byte+block offset bits
    localparam logic [AddrWidth-1:0] BlockMask = BlockSize - 1;

    // address of block being replaced
    logic [AddrWidth-1:0] block_addr;
    assign block_addr = cpu_req.addr & ~BlockMask;


    always_comb begin
        axi_req_state_d  = axi_req_state_q;
        axi_rd_req.ready = 1'b0;
        axi_wr_req.ready = 1'b0;

        unique case (axi_req_state_q)
            StAxiIdle: begin
                if (axi_rd_req.valid) begin
                    if (cpu_req.rd && !hit && ((axi_rd_req.addr & ~BlockMask) == block_addr)) begin
                        axi_req_state_d = StAxiWaitRd;
                    end else if (cpu_req.wr && (axi_rd_req.addr == cpu_req.addr)) begin
                        axi_req_state_d = StAxiWaitRd;
                    end else begin
                        axi_req_state_d = StAxiRd;
                    end
                end else if (axi_wr_req.valid) begin
                    if (cpu_req.rd && !hit && ((axi_wr_req.addr & ~BlockMask) == block_addr)) begin
                        axi_req_state_d = StAxiWaitWr;
                    end else if (cpu_req.wr && (axi_wr_req.addr == cpu_req.addr)) begin
                        axi_req_state_d = StAxiWaitWr;
                    end else begin
                        axi_req_state_d = StAxiWr;
                    end
                end
            end

            StAxiRd: begin
                axi_rd_req.ready = 1'b1;
                if (axi_rd_req.done) begin
                    axi_req_state_d = StAxiIdle;
                end
            end

            StAxiWr: begin
                axi_wr_req.ready = 1'b1;
                if (axi_wr_req.done) begin
                    axi_req_state_d = StAxiIdle;
                end
            end

            StAxiWaitRd: begin
                if (cpu_res.valid) begin
                    axi_req_state_d = StAxiIdle;
                end
            end

            StAxiWaitWr: begin
                if (cpu_res.valid) begin
                    axi_req_state_d = StAxiIdle;
                end
            end
            default: axi_req_state_d = StAxiIdle;
        endcase
    end


endmodule
