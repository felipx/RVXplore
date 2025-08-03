module wptr_full #(
    parameter int unsigned AddrWidth = 4
) (
    input                  wclk,
    input                  wrst_n,
    input                  winc,
    input                  afull_n,
    output                 wfull_o,
    output [AddrWidth-1:0] wptr_o
);
    logic [AddrWidth-1:0] wptr, wbin;
    logic                 wfull, wfull2;
    logic [AddrWidth-1:0] wgnext, wbnext;

    assign wptr_o = wptr;
    assign wfull_o = wfull;

    // graystyle pointer
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin <= 0;
            wptr <= 0;
        end else begin
            wbin <= wbnext;
            wptr <= wgnext;
        end
    end

    // increment the binary count if not full
    assign wbnext = !wfull ? wbin + winc : wbin;
    // binary-to-gray conversion
    assign wgnext = (wbnext >> 1) ^ wbnext;

    always_ff @(posedge wclk or negedge wrst_n or negedge afull_n) begin
        if (!wrst_n ) begin
            {wfull,wfull2} <= 2'b00;
        end else if (!afull_n) begin
            {wfull,wfull2} <= 2'b11;
        end else begin
            {wfull,wfull2} <= {wfull2,~afull_n};
        end
    end
endmodule
