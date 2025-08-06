// Data request (CPU->cache controller / cache controller->memory)
interface data_req_if #(
    parameter int unsigned DataWidth = 32,
    parameter int unsigned AddrWidth = 32
);
    logic                 valid;
    logic                 ready;
    logic [AddrWidth-1:0] addr;
    logic [DataWidth-1:0] data;
    logic                 wr;
    logic                 rd;

    modport in  (
        input valid,
        output ready,
        input addr,
        input data,
        input wr,
        input rd
    );
    modport out (
        output valid,
        input ready,
        output addr,
        output data,
        output wr,
        output rd
    );
endinterface

// Data result (cache controller->cpu / memory->cache controller)
interface data_res_if #(
    parameter int unsigned DataWidth = 64
);
    logic                 valid;
    logic                 ready;
    logic                 error;
    logic [DataWidth-1:0] data;

    modport in  (
        input valid,
        output ready,
        input error,
        input data
    );
    modport out (
        output valid,
        input ready,
        output error,
        output data
    );
endinterface

// Tag data (tag<->cache controller)
interface tag_data_if #(
    parameter int unsigned TagWidth = 18
);
    logic [TagWidth-1:0] tag;
    logic                valid;

    modport in  (
        input tag,
        input valid
    );
    modport out (
        output tag,
        output valid
    );
endinterface

interface axi_req_if #(
    parameter int unsigned AddrWidth = 32,
    parameter int unsigned DataWidth = 64
);
    logic                 valid;
    logic                 done;
    logic                 ready;
    logic [AddrWidth-1:0] addr;
    logic [DataWidth-1:0] data;

    modport master (
        output valid,
        output done,
        input  ready,
        output addr,
        output data
    );

    modport slave (
        input  valid,
        input  done,
        output ready,
        input  addr,
        input  data
    );
endinterface // axi_req_if


interface mem_if #(
    parameter int unsigned NumBanks     = 4,
    parameter int unsigned DataBusWidth = 64,
    parameter int unsigned AddrWidth    = 10
);
    logic [NumBanks-1:0]         en;
    logic [(DataBusWidth/8)-1:0] we;
    logic [AddrWidth-1:0]        addr;
    logic [DataBusWidth-1:0]     din;
    logic [DataBusWidth-1:0]     dout[NumBanks];

    modport master (
        output en,
        output we,
        output addr,
        output din,
        input  dout
    );

    modport slave (
        input  en,
        input  we,
        input  addr,
        input  din,
        output dout
    );
endinterface // mem_if
