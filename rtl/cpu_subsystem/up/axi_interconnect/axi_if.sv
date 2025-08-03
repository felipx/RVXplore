`include "axi_config.svh"

interface axi_aw_if #(
`ifdef ID_W_WIDTH
    parameter int unsigned IdWWidth      = `ID_W_WIDTH,
`endif // ID_W_WIDTH
    parameter int unsigned AddrWidth     = 32,
`ifdef USER_REQ_WIDTH
    parameter int unsigned UserReqWidth  = `USER_REQ_WIDTH,
`endif // USER_REQ_WIDTH
`ifdef AWSNOOP_WIDTH
    parameter int unsigned AwSnoopWidth  = `AWSNOOP_WIDTH,
`endif
`ifdef LOOP_W_WIDTH
    parameter int unsigned LoopWWidth    = `LOOP_W_WIDTH,
`endif
`ifdef SECSID_WIDTH
    parameter int unsigned SecsidWidth   = `SECSID_WIDTH,
`endif // SECSID_WIDTH
`ifdef SID_WIDTH
    parameter int unsigned SidWidth      = `SID_WIDTH,
`endif // SID_WIDTH
    parameter int unsigned SsidWidth     = 4,
    parameter int unsigned SubsysidWidth = 4,
    parameter int unsigned MpamWidth     = 4,
    parameter int unsigned AwcmoWidth    = 4
`ifdef MECID_WIDTH
    parameter int unsigned MecidWidth    = `MECID_WIDTH,
`endif // MECID_WIDTH
);
    logic                     awvalid;
    logic                     awready;
`ifdef ID_W_WIDTH
    logic [IdWWidth-1:0]      awid;
`endif // ID_W_WIDTH
    logic [AddrWidth-1:0]     awaddr;
`ifdef REGION_PRESENT
    logic [3:0]               awregion;
`endif // REGION_PRESENT
`ifdef LEN_PRESENT
    logic [7:0]               awlen;
`endif // LEN_PRESENT
`ifdef SIZE_PRESENT
    logic [2:0]               awsize;
`endif // SIZE_PRESENT
`ifdef BURST_PRESENT
    logic [1:0]               awburst;
`endif // BURST_PRESENT
`ifdef EXCLUSIVE_ACCESSES
    logic                     awlock;
`endif // EXCLUSIVE_ACCESSES
`ifdef CACHE_PRESENT
    logic [3:0]               awcache;
`endif // CACHE_PRESENT
`ifdef PROT_PRESENT
    logic [2:0]               awprot;
`endif // PROT_PRESENT
`ifdef RME_SUPPORT
    logic                     awnse;
`endif // RME_SUPPORT
`ifdef QOS_PRESENT
    logic [3:0]               awqos;
`endif // QOS_PRESENT
`ifdef USER_REQ_WIDTH
    logic [UserReqWidth-1:0]  awuser;
`endif // USER_REQ_WIDTH
`ifdef SHAREABLE_TRANSACTIONS
    logic [1:0]               awdomain;
`endif // SHAREABLE_TRANSACTIONS
`ifdef AWSNOOP_WIDTH
    logic [AwSnoopWidth-1:0]  awsnoop;
`endif // AWSNOOP_WIDTH
`ifdef STASHNID_PRESENT
    logic [10:0]              awstashnid;
    logic                     awstashniden;
`endif // STASHNID_PRESENT
`ifdef STASHLPID_PRESENT
    logic [4:0]               awstashlpid;
    logic                     awstashlpiden;
`endif // STASHLPID_PRESENT
`ifdef TRACE_SIGNALS
    logic                     awtrace;
`endif // TRACE_SIGNALS
`ifdef LOOPBACK_SIGNALS
    logic [LoopWWidth-1:0]    awloop;
`endif // LOOPBACK_SIGNALS
`ifdef UNTRANSLATED_TRANSACTIONS
    logic                     awmmuvalid;
`endif // UNTRANSLATED_TRANSACTIONS
`ifdef SECSID_WIDTH
    logic [SecsidWidth-1:0]   awmmusecsid;
`endif // SECSID_WIDTH
`ifdef SID_WIDTH
    logic [SidWidth-1:0]      awmmusid;
`endif // SID_WIDTH
    logic                     awmmussidv;
    logic [SsidWidth-1:0]     awmmussid;
    logic                     awmmuatst;
    logic [1:0]               awmmuflowl;
    logic [3:0]               awpbha;
    logic [3:0]               awnsaid;
    logic [SubsysidWidth-1:0] awsubsysid;
`ifdef ATOMIC_TRANSACTIONS
    logic [5:0]               awatop;
`endif // ATOMIC_TRANSACTIONS
    logic [MpamWidth-1:0]     awmpam;
`ifdef UNIQUE_ID_SUPPORT
    logic                     awidunq;
`endif // UNIQUE_ID_SUPPORT
    logic [AwcmoWidth-1:0]    awcmo;
    logic [1:0]               awtagop;
`ifdef MEC_SUPPORT
    logic [MecidWidth-1:0]    awmecid;
`endif // MEC_SUPPORT

    modport master (
        output awvalid,
        input awready,
`ifdef ID_W_WIDTH
        output awid,
`endif // ID_W_WIDTH
        output awaddr,
`ifdef REGION_PRESENT
        output awregion,
`endif // REGION_PRESENT
`ifdef LEN_PRESENT
        output awlen,
`endif // LEN_PRESENT
`ifdef SIZE_PRESENT
        output awsize,
`endif // SIZE_PRESENT
`ifdef BURST_PRESENT
        output awburst,
`endif // BURST_PRESENT
`ifdef EXCLUSIVE_ACCESSES
        output awlock,
`endif // EXCLUSIVE_ACCESSES
`ifdef CACHE_PRESENT
        output awcache,
`endif // CACHE_PRESENT
`ifdef PROT_PRESENT
        output awprot,
`endif // PROT_PRESENT
`ifdef RME_SUPPORT
        output awnse,
`endif // RME_SUPPORT
`ifdef QOS_PRESENT
        output awqos,
`endif // QOS_PRESENT
`ifdef USER_REQ_WIDTH
        output awuser,
`endif // USER_REQ_WIDTH
`ifdef SHAREABLE_TRANSACTIONS
        output awdomain,
`endif // SHAREABLE_TRANSACTIONS
`ifdef AWSNOOP_WIDTH
        output awsnoop,
`endif // AWSNOOP_WIDTH
`ifdef STASHNID_PRESENT
        output awstashnid,
        output awstashniden,
`endif // STASHNID_PRESENT
`ifdef STASHLPID_PRESENT
        output awstashlpid,
        output awstashlpiden,
`endif // STASHLPID_PRESENT
`ifdef TRACE_SIGNALS
        output awtrace,
`endif // TRACE_SIGNALS
`ifdef LOOPBACK_SIGNALS
        output awloop,
`endif // LOOPBACK_SIGNALS
`ifdef UNTRANSLATED_TRANSACTIONS
        output awmmuvalid,
`endif // UNTRANSLATED_TRANSACTIONS
`ifdef SECSID_WIDTH
        output awmmusecsid,
`endif // SECSID_WIDTH
`ifdef SID_WIDTH
        output awmmusid,
`endif // SID_WIDTH
        output awmmussidv,
        output awmmussid,
        output awmmuatst,
        output awmmuflowl,
        output awpbha,
        output awnsaid,
        output awsubsysid,
`ifdef ATOMIC_TRANSACTIONS
        output awatop,
`endif // ATOMIC_TRANSACTIONS
        output awmpam,
`ifdef UNIQUE_ID_SUPPORT
        output awidunq,
`endif // UNIQUE_ID_SUPPORT
        output awcmo,
        output awtagop
`ifdef MEC_SUPPORT
        output awmecid
`endif // MEC_SUPPORT
    );

    modport slave (
        input awvalid,
        output awready,
`ifdef ID_W_WIDTH
        input awid,
`endif // ID_W_WIDTH
        input awaddr,
`ifdef REGION_PRESENT
        input awregion,
`endif // REGION_PRESENT
`ifdef LEN_PRESENT
        input awlen,
`endif // LEN_PRESENT
`ifdef SIZE_PRESENT
        input awsize,
`endif // SIZE_PRESENT
`ifdef BURST_PRESENT
        input awburst,
`endif // BURST_PRESENT
`ifdef EXCLUSIVE_ACCESSES
        input awlock,
`endif // EXCLUSIVE_ACCESSES
`ifdef CACHE_PRESENT
        input awcache,
`endif // CACHE_PRESENT
`ifdef PROT_PRESENT
        input awprot,
`endif // PROT_PRESENT
`ifdef RME_SUPPORT
        input awnse,
`endif // RME_SUPPORT
`ifdef QOS_PRESENT
        input awqos,
`endif // QOS_PRESENT
`ifdef USER_REQ_WIDTH
        input awuser,
`endif // USER_REQ_WIDTH
`ifdef SHAREABLE_TRANSACTIONS
        input awdomain,
`endif // SHAREABLE_TRANSACTIONS
`ifdef AWSNOOP_WIDTH
        input awsnoop,
`endif // AWSNOOP_WIDTH
`ifdef STASHNID_PRESENT
        input awstashnid,
        input awstashniden,
`endif // STASHNID_PRESENT
`ifdef STASHLPID_PRESENT
        input awstashlpid,
        input awstashlpiden,
`endif // STASHLPID_PRESENT
`ifdef TRACE_SIGNALS
        input awtrace,
`endif // TRACE_SIGNALS
`ifdef LOOPBACK_SIGNALS
        input awloop,
`endif // LOOPBACK_SIGNALS
`ifdef UNTRANSLATED_TRANSACTIONS
        input awmmuvalid,
`endif // UNTRANSLATED_TRANSACTIONS
`ifdef SECSID_WIDTH
        input awmmusecsid,
`endif // SECSID_WIDTH
`ifdef SID_WIDTH
        input awmmusid,
`endif // SID_WIDTH
        input awmmussidv,
        input awmmussid,
        input awmmuatst,
        input awmmuflowl,
        input awpbha,
        input awnsaid,
        input awsubsysid,
`ifdef ATOMIC_TRANSACTIONS
        input awatop,
`endif // ATOMIC_TRANSACTIONS
        input awmpam,
`ifdef UNIQUE_ID_SUPPORT
        input awidunq,
`endif // UNIQUE_ID_SUPPORT
        input awcmo,
        input awtagop
`ifdef MEC_SUPPORT
        input awmecid,
`endif // MEC_SUPPORT
    );
endinterface //axi_aw

interface axi_w_if #(
    parameter int unsigned DataWidth      = 32
`ifdef USER_DATA_WIDTH
    ,parameter int unsigned UserDataWidth = `USER_DATA_WIDTH
`endif // USER_DATA_WIDTH
);
    logic                                    wvalid;
    logic                                    wready;
    logic [DataWidth-1:0]                    wdata;
`ifdef WSTRB_PRESENT
    logic [(DataWidth/8)-1:0]                wstrb;
`endif // WSTRB_PRESENT
    logic [int'($ceil(DataWidth/128)*4)-1:0] wtag;
    logic [int'($ceil(DataWidth/128))-1:0]   wtagupdate;
`ifdef WLAST_PRESENT
    logic                                    wlast;
`endif // WLAST_PRESENT
`ifdef USER_DATA_WIDTH
    logic [UserDataWidth-1:0]                wuser;
`endif // USER_DATA_WIDTH
    logic [int'($ceil(DataWidth/64))-1:0]    wpoison;
`ifdef TRACE_SIGNALS
    logic wtrace;
`endif // TRACE_SIGNALS

    function automatic logic sl_handshake();
        if (wvalid && wready) begin
            return 1'b1;
        end else begin
            return 1'b0;
        end
    endfunction

    modport master (
        output wvalid
        ,input wready
        ,output wdata
`ifdef WSTRB_PRESENT
        ,output wstrb
`endif // WSTRB_PRESENT
        ,output wtag
        ,output wtagupdate
        ,output wlast
`ifdef USER_DATA_WIDTH
        ,output wuser
`endif // USER_DATA_WIDTH
        ,output wpoison
`ifdef TRACE_SIGNALS
        ,output wtrace
`endif //TRACE_SIGNALS
    );

    modport slave (
        input wvalid
        ,output wready
        ,input wdata
`ifdef WSTRB_PRESENT
        ,input wstrb
`endif // WSTRB_PRESENT
        ,input wtag
        ,input wtagupdate
        ,input wlast
`ifdef USER_DATA_WIDTH
        ,input wuser
`endif // USER_DATA_WIDTH
        ,input wpoison
`ifdef TRACE_SIGNALS
        ,input wtrace
`endif //TRACE_SIGNALS

        ,import sl_handshake
    );


endinterface //axi_w

interface axi_b_if #(
`ifdef ID_W_WIDTH
    parameter int unsigned IdWWidth       = `ID_W_WIDTH,
`endif // ID_W_WIDTH
`ifdef BRESP_WIDTH
    parameter int unsigned BrespWidth     = `BRESP_WIDTH
`endif // BRESP_WIDTH
`ifdef USER_RESP_WIDTH
    ,parameter int unsigned UserRespWidth = `USER_RESP_WIDTH
`endif // USER_RESP_WIDTH
`ifdef LOOP_W_WIDTH
    ,parameter int unsigned LoopWWidth    = 32
`endif // LOOP_W_WIDTH
);
    logic                     bvalid;
    logic                     bready;
`ifdef ID_W_WIDTH
    logic [IdWWidth-1:0]      bid;
`endif // ID_W_WIDTH
`ifdef UNIQUE_ID_SUPPORT
    logic                     bidunq;
`endif // UNIQUE_ID_SUPPORT
`ifdef BRESP_WIDTH
    logic [BrespWidth-1:0]    bresp;
`endif // BRESP_WIDTH
    logic                     bcomp;
    logic                     bpersist;
    logic [1:0]               btagmatch;
`ifdef USER_RESP_WIDTH
    logic [UserRespWidth-1:0] buser;
`endif // USER_RESP_WIDTH
`ifdef TRACE_SIGNALS
    logic                     btrace;
`endif //TRACE_SIGNALS
`ifdef LOOPBACK_SIGNALS
    logic [LoopWWidth-1:0]    bloop;
`endif // LOOPBACK_SIGNALS
`ifdef BUSY_SUPPORT
    logic [1:0]               bbusy;
`endif // BUSY_SUPPORT

    modport master (
        input bvalid,
        output bready,
`ifdef ID_W_WIDTH
        input bid,
`endif // ID_W_WIDTH
`ifdef UNIQUE_ID_SUPPORT
        input bidunq,
`endif // UNIQUE_ID_SUPPORT
`ifdef BRESP_WIDTH
        input bresp,
`endif // BRESP_WIDTH
        input bcomp,
        input bpersist,
        input btagmatch
`ifdef USER_RESP_WIDTH
        input buser,
`endif // USER_RESP_WIDTH
`ifdef TRACE_SIGNALS
        input btrace,
`endif // TRACE_SIGNALS
`ifdef LOOPBACK_SIGNALS
        input bloop,
`endif // LOOPBACK_SIGNALS
`ifdef BUSY_SUPPORT
        input bbusy,
`endif // BUSY_SUPPORT
    );

    modport slave (
        output bvalid,
        input bready,
`ifdef ID_W_WIDTH
        output bid,
`endif // ID_W_WIDTH
`ifdef UNIQUE_ID_SUPPORT
        output bidunq,
`endif // UNIQUE_ID_SUPPORT
`ifdef BRESP_WIDTH
        output bresp,
`endif // BRESP_WIDTH
        output bcomp,
        output bpersist,
        output btagmatch
`ifdef USER_RESP_WIDTH
        output buser,
`endif // USER_RESP_WIDTH
`ifdef TRACE_SIGNALS
        output btrace,
`endif // TRACE_SIGNALS
`ifdef LOOPBACK_SIGNALS
        output bloop,
`endif // LOOPBACK_SIGNALS
`ifdef BUSY_SUPPORT
        output bbusy,
`endif // BUSY_SUPPORT
    );
endinterface //axi_b

interface axi_ar_if #(
`ifdef ID_R_WIDTH
    parameter int unsigned IdRWidth      = `ID_R_WIDTH,
`endif // ID_R_WIDTH
    parameter int unsigned AddrWidth     = 32,
`ifdef USER_REQ_WIDTH
    parameter int unsigned UserReqWidth  = `USER_REQ_WIDTH,
`endif // USER_REQ_WIDTH
`ifdef ARSNOOP_WIDTH
    parameter int unsigned ArSnoopWidth  = `ARSNOOP_WIDTH,
`endif // ARSNOOP_WIDTH
`ifdef LOOP_R_WIDTH
    parameter int unsigned LoopRWidth    = 2,
`endif // LOOP_R_WIDTH
`ifdef SECSID_WIDTH
    parameter int unsigned SecsidWidth   = `SECSID_WIDTH,
`endif // SECSID_WIDTH
`ifdef SID_WIDTH
    parameter int unsigned SidWidth      = `SID_WIDTH,
`endif // SID_WIDTH
    parameter int unsigned SsidWidth     = 2,
    parameter int unsigned SubsysidWidth = 2,
    parameter int unsigned MpamWidth     = 2
`ifdef MECID_WIDTH
    parameter int unsigned MecidWidth    = `MECID_WIDTH
`endif // MECID_WIDTH
);
    logic                     arvalid;
    logic                     arready;
`ifdef ID_R_WIDTH
    logic [IdRWidth-1:0]      arid;
`endif // ID_R_WIDTH
    logic [AddrWidth-1:0]     araddr;
`ifdef REGION_PRESENT
    logic [3:0]               arregion;
`endif // REGION_PRESENT
`ifdef LEN_PRESENT
    logic [7:0]               arlen;
`endif // LEN_PRESENT
`ifdef SIZE_PRESENT
    logic [2:0]               arsize;
`endif // SIZE_PRESENT
`ifdef BURST_PRESENT
    logic [1:0]               arburst;
`endif // BURST_PRESENT
`ifdef EXCLUSIVE_ACCESSES
    logic                     arlock;
`endif // EXCLUSIVE_ACCESSES
`ifdef CACHE_PRESENT
    logic [3:0]               arcache;
`endif // CACHE_PRESENT
`ifdef PROT_PRESENT
    logic [2:0]               arprot;
`endif // PROT_PRESENT
`ifdef RME_SUPPORT
    logic                     arnse;
`endif // RME_SUPPORT
`ifdef QOS_PRESENT
    logic [3:0]               arqos;
`endif // QOS_PRESENT
`ifdef USER_REQ_WIDTH
    logic [UserReqWidth-1:0]  aruser;
`endif // USER_REQ_WIDTH
`ifdef SHAREABLE_TRANSACTIONS
    logic [1:0]               ardomain;
`endif // SHAREABLE_TRANSACTIONS
`ifdef ARSNOOP_WIDTH
    logic [ArSnoopWidth-1:0]  arsnoop;
`endif // ARSNOOP_WIDTH
`ifdef TRACE_SIGNALS
    logic                     artrace;
`endif // TRACE_SIGNALS
`ifdef LOOPBACK_SIGNALS
    logic [LoopRWidth-1:0]    arloop;
`endif // LOOPBACK_SIGNALS
`ifdef UNTRANSLATED_TRANSACTIONS
    logic                     armmuvalid;
`endif // UNTRANSLATED_TRANSACTIONS
`ifdef SECSID_WIDTH
    logic [SecsidWidth-1:0]   armmusecsid;
`endif // SECSID_WIDTH
`ifdef SID_WIDTH
    logic [SidWidth-1:0]      armmusid;
`endif // SID_WIDTH
    logic                     armmussidv;
    logic [SsidWidth-1:0]     armmussid;
    logic                     armmuatst;
    logic [1:0]               armmuflowl;
    logic [3:0]               arpbha;
    logic [3:0]               arnsaid;
    logic [SubsysidWidth-1:0] arsubsysid;
    logic [MpamWidth-1:0]     armpam;
    logic                     archunken;
`ifdef UNIQUE_ID_SUPPORT
    logic                     aridunq;
`endif // UNIQUE_ID_SUPPORT
    logic [1:0]               artagop;
`ifdef MEC_SUPPORT
    logic [MecidWidth-1:0]    armecid;
`endif // MEC_SUPPORT

    modport master (
        output arvalid,
        input arready,
`ifdef ID_R_WIDTH
        output arid,
`endif // ID_R_WIDTH
        output araddr,
`ifdef REGION_PRESENT
        output arregion,
`endif // REGION_PRESENT
`ifdef LEN_PRESENT
        output arlen,
`endif //LEN_PRESENT
`ifdef SIZE_PRESENT
        output arsize,
`endif // SIZE_PRESENT
`ifdef BURST_PRESENT
        output arburst,
`endif // BURST_PRESENT
`ifdef EXCLUSIVE_ACCESSES
        output arlock,
`endif // EXCLUSIVE_ACCESSES
`ifdef CACHE_PRESENT
        output arcache,
`endif // CACHE_PRESENT
`ifdef PROT_PRESENT
        output arprot,
`endif // PROT_PRESENT
`ifdef RME_SUPPORT
        output arnse,
`endif // RME_SUPPORT
`ifdef QOS_PRESENT
        output arqos,
`endif // QOS_PRESENT
`ifdef USER_REQ_WIDTH
        output aruser,
`endif // USER_REQ_WIDTH
`ifdef SHAREABLE_TRANSACTIONS
        output ardomain,
`endif // SHAREABLE_TRANSACTIONS
`ifdef ARSNOOP_WIDTH
        output arsnoop,
`endif // ARSNOOP_WIDTH
`ifdef TRACE_SIGNALS
        output artrace,
`endif // TRACE_SIGNALS
`ifdef LOOPBACK_SIGNALS
        output arloop,
`endif // LOOPBACK_SIGNALS
`ifdef UNTRANSLATED_TRANSACTIONS
        output armmuvalid,
`endif // UNTRANSLATED_TRANSACTIONS
`ifdef SECSID_WIDTH
        output armmusecsid,
`endif // SECSID_WIDTH
`ifdef SID_WIDTH
        output armmusid,
`endif // SID_WIDTH
        output armmussidv,
        output armmussid,
        output armmuatst,
        output armmuflowl,
        output arpbha,
        output arnsaid,
        output arsubsysid,
        output armpam,
        output archunken,
`ifdef UNIQUE_ID_SUPPORT
        output aridunq,
`endif // UNIQUE_ID_SUPPORT
        output artagop
`ifdef MEC_SUPPORT
        output armecid
`endif // MEC_SUPPORT
    );

    modport slave (
        input arvalid,
        output arready,
`ifdef ID_R_WIDTH
        input arid,
`endif // ID_R_WIDTH
        input araddr,
`ifdef REGION_PRESENT
        input arregion,
`endif // REGION_PRESENT
`ifdef LEN_PRESENT
        input arlen,
`endif // LEN_PRESENT
`ifdef SIZE_PRESENT
        input arsize,
`endif // SIZE_PRESENT
`ifdef BURST_PRESENT
        input arburst,
`endif // BURST_PRESENT
`ifdef EXCLUSIVE_ACCESSES
        input arlock,
`endif // EXCLUSIVE_ACCESSES
`ifdef CACHE_PRESENT
        input arcache,
`endif // CACHE_PRESENT
`ifdef PROT_PRESENT
        input arprot,
`endif // PROT_PRESENT
`ifdef RME_SUPPORT
        input arnse,
`endif // RME_SUPPORT
`ifdef QOS_PRESENT
        input arqos,
`endif // QOS_PRESENT
`ifdef USER_REQ_WIDTH
        input aruser,
`endif // USER_REQ_WIDTH
`ifdef SHAREABLE_TRANSACTIONS
        input ardomain,
`endif // SHAREABLE_TRANSACTIONS
`ifdef ARSNOOP_WIDTH
        input arsnoop,
`endif // ARSNOOP_WIDTH
`ifdef TRACE_SIGNALS
        input artrace,
`endif // TRACE_SIGNALS
`ifdef LOOPBACK_SIGNALS
        input arloop,
`endif // LOOPBACK_SIGNALS
`ifdef UNTRANSLATED_TRANSACTIONS
        input armmuvalid,
`endif // UNTRANSLATED_TRANSACTIONS
`ifdef SECSID_WIDTH
        input armmusecsid,
`endif // SECSID_WIDTH
`ifdef SID_WIDTH
        input armmusid,
`endif // SID_WIDTH
        input armmussidv,
        input armmussid,
        input armmuatst,
        input armmuflowl,
        input arpbha,
        input arnsaid,
        input arsubsysid,
        input armpam,
        input archunken,
`ifdef UNIQUE_ID_SUPPORT
        input aridunq,
`endif // UNIQUE_ID_SUPPORT
        input artagop
`ifdef MEC_SUPPORT
        input armecid,
`endif // MEC_SUPPORT
    );
endinterface //axi_ar

interface axi_r_if #(
`ifdef ID_R_WIDTH
    parameter int unsigned IdRWidth = `ID_R_WIDTH,
`endif // ID_R_WIDTH
    parameter int unsigned DataWidth = 32,
`ifdef RRESP_WIDTH
    parameter int unsigned RRespWidth = `RRESP_WIDTH,
`endif // RRESP_WIDTH
`ifdef USER_DATA_WIDTH
    parameter int unsigned UserDataWidth = `USER_DATA_WIDTH,
`endif // USER_DATA_WIDTH
`ifdef USER_RESP_WIDTH
    parameter int unsigned UserRespWidth = `USER_RESP_WIDTH,
`endif // USER_RESP_WIDTH
`ifdef LOOP_R_WIDTH
    parameter int unsigned LoopRWidth = `LOOP_R_WIDTH,
`endif // LOOP_R_WIDTH
    parameter int unsigned RchunknumWidth  = 32,
    parameter int unsigned RchunkstrbWidth = 32
);
    localparam int unsigned RTagWidth    = $ceil(DataWidth/128)*4;
    localparam int unsigned RPoisonWidth = $ceil(DataWidth/64);

    logic                       rvalid;
    logic                       rready;
`ifdef ID_R_WIDTH
    logic [IdRWidth-1:0]        rid;
`endif // ID_R_WIDTH
`ifdef UNIQUE_ID_SUPPORT
    logic                       ridunq;
`endif // UNIQUE_ID_SUPPORT
    logic [DataWidth-1:0]       rdata;
    logic [RTagWidth-1:0]       rtag;
`ifdef RRESP_WIDTH
    logic [RRespWidth-1:0]      rresp;
`endif // RRESP_WIDTH
`ifdef RLAST_PRESENT
    logic                       rlast;
`endif // RLAST_PRESENT
`ifdef USER_DATA_WIDTH
`ifdef USER_RESP_WIDTH
    logic [(UserDataWidth+UserRespWidth)-1:0] ruser;
`endif // USER_DATA_WIDTH
`endif // USER_RESP_WIDTH
    logic [RPoisonWidth-1:0]    rpoison;
`ifdef TRACE_SIGNALS
    logic                       rtrace;
`endif // TRACE_SIGNALS
`ifdef LOOPBACK_SIGNALS
    logic [LoopRWidth-1:0]      rloop;
`endif // LOOPBACK_SIGNALS
    logic                       rchunkv;
    logic [RchunknumWidth-1:0]  rchunknum;
    logic [RchunkstrbWidth-1:0] rchunkstrb;
`ifdef BUSY_SUPPORT
    logic [1:0]                 rbusy;
`endif // BUSY_SUPPORT

    modport master (
        input rvalid
        ,output rready
`ifdef ID_R_WIDTH
        ,input rid
`endif // ID_R_WIDTH
`ifdef UNIQUE_ID_SUPPORT
        ,input ridunq
`endif // UNIQUE_ID_SUPPORT
        ,input rdata
        ,input rtag
`ifdef RRESP_WIDTH
        ,input rresp
`endif // RRESP_WIDTH
`ifdef RLAST_PRESENT
        ,input rlast
`endif // RLAST_PRESENT
`ifdef USER_DATA_WIDTH
`ifdef USER_RESP_WIDTH
        ,input ruser
`endif // USER_DATA_WIDTH
`endif // USER_RESP_WIDTH
        ,input rpoison
`ifdef TRACE_SIGNALS
        ,input rtrace
`endif // TRACE_SIGNALS
`ifdef LOOPBACK_SIGNALS
        ,input rloop
`endif // LOOPBACK_SIGNALS
        ,input rchunkv
        ,input rchunknum
        ,input rchunkstrb
`ifdef BUSY_SUPPORT
        ,input rbusy
`endif // BUSY_SUPPORT
    );

    modport slave (
        output rvalid
        ,input rready
`ifdef ID_R_WIDTH
        ,output rid
`endif // ID_R_WIDTH
`ifdef UNIQUE_ID_SUPPORT
        ,output ridunq
`endif // UNIQUE_ID_SUPPORT
        ,output rdata
        ,output rtag
`ifdef RRESP_WIDTH
        ,output rresp
`endif // RRESP_WIDTH
`ifdef RLAST_PRESENT
        ,output rlast
`endif // RLAST_PRESENT
`ifdef USER_DATA_WIDTH
`ifdef USER_RESP_WIDTH
        ,output ruser
`endif // USER_DATA_WIDTH
`endif // USER_RESP_WIDTH
        ,output rpoison
`ifdef TRACE_SIGNALS
        ,output rtrace
`endif // TRACE_SIGNALS
`ifdef LOOPBACK_SIGNALS
        ,output rloop
`endif // LOOPBACK_SIGNALS
        ,output rchunkv
        ,output rchunknum
        ,output rchunkstrb
`ifdef BUSY_SUPPORT
        ,output rbusy
`endif // BUSY_SUPPORT
    );
endinterface //axi_r
