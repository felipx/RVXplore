
////////////////////
// Write and Read //
////////////////////
`define WLAST_PRESENT
`define RLAST_PRESENT

/////////////////////////
// Transaction Request //
/////////////////////////
`define SIZE_PRESENT
`define LEN_PRESENT
`define BURST_PRESENT
//`define FIXED_BURST_DISABLE
//`define REGULAR_TRANSACTIONS_ONLY

/////////////////////////
// Write and Read Data //
/////////////////////////
`define WSTRB_PRESENT

//////////////////////////
// Transaction Response //
//////////////////////////
`define BRESP_WIDTH 2
`define RRESP_WIDTH 2
//`define CONSISTENT_DECERR False
//`define BUSY_SUPPORT

///////////////////////
// Memory Attributes //
///////////////////////
//`define CACHE_PRESENT

///////////////////////
// Memory Protection //
///////////////////////
//`define PROT_PRESENT

/////////////////////////////////
//  Realm Management Extension //
/////////////////////////////////
//`define RME_SUPPORT

////////////////////////////////
// Memory Encryption Contexts //
////////////////////////////////
//`define MEC_SUPPORT
`ifdef MEC_SUPPORT
    `define MECID_WIDTH 0
`endif // MEC_SUPPORT

////////////////////////////////
// Multiple Region Interfaces //
////////////////////////////////
//`define REGION_PRESENT

///////////////////
// QoS Signaling //
///////////////////
//`define QOS_PRESENT
`ifdef QOS_PRESENT
    `define QOS_ACCEPT False
`endif

/////////////////////////////
// Transaction Identifiers //
/////////////////////////////
`define ID_W_WIDTH 8
`define ID_R_WIDTH 8
//`define UNIQUE_ID_SUPPORT

//////////////////////
// Request Ordering //
//////////////////////
//`define DEVICE_NORMAL_INDEPENDENCE False
//`define ORDERED_WRITE_OBSERVATION False

////////////////////////
// Read Data Ordering //
////////////////////////
//`define READ_INTERLEAVING_DISABLED False
//`define READ_DATA_CHUNKING False

////////////////////////////////
// Multi-copy Write Atomicity //
////////////////////////////////
//`define MULTI_COPY_ATOMICITY False

////////////////////////
// Exclusive Accesses //
////////////////////////
//`define EXCLUSIVE_ACCESSES

/////////////////////////
// Atomic Transactions //
/////////////////////////
//`define ATOMIC_TRANSACTIONS

//////////////////////
// Opcode Signaling //
//////////////////////
//`define AWSNOOP_WIDTH 0
//`define ARSNOOP_WIDTH 0

////////////
// Caches //
////////////
//`define CACHE_LINE_SIZE 64
//`define SHAREABLE_TRANSACTIONS
//`define WRITENOSNOOPFULL_TRANSACTION False
//`define SHAREABLE_CACHE_SUPPORT False
//`define PREFETCH_TRANSACTION False
//`define CACHE_STASH_TRANSACTIONS False
`ifdef CACHE_STASH_TRANSACTIONS
    `define STASHNID_PRESENT
    `define STASHLPID_PRESENT
`endif // CACHE_STASH_TRANSACTIONS
//`define DEALLOCATION_TRANSACTIONS False
//`define INVALIDATEHINT_TRANSACTION False

////////////////////////
// left on cache maintenance op (cmo)

//TODO:`define PERSIST_CMO
//TODO:`define CMO_ON_WRITE





//`define USER_REQ_WIDTH 0

//`define UNTRANSLATED_TRANSACTIONS False
//`define SECSID_WIDTH 0
//`define SID_WIDTH 0

//`define USER_DATA_WIDTH 0

//`define USER_RESP_WIDTH 0

//`define TRACE_SIGNALS
//`define LOOPBACK_SIGNALS
`ifdef LOOPBACK_SIGNALS
    `define LOOP_W_WIDTH 0
    `define LOOP_R_WIDTH 0
`endif // LOOPBACK_SIGNALS
