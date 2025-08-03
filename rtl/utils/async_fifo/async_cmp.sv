module async_cmp #(
    parameter int unsigned AddrWidth = 4,
    localparam int unsigned N = AddrWidth-1
) (
    input       wrst_n,
    input [N:0] wptr,
    input [N:0] rptr,
    output      aempty_n,
    output      afull_n
);
    logic direction;
    logic high;
    assign high = 1'b1;

    logic dirset_n, dirclr_n;
    assign dirset_n= ~((wptr[N] ^ rptr[N-1]) & ~(wptr[N-1] ^ rptr[N]));
    assign dirclr_n = ~((~(wptr[N] ^ rptr[N-1]) & (wptr[N-1] ^ rptr[N])) | ~wrst_n);

    //always @(posedge high or negedge dirset_n or negedge dirclr_n) begin
    //    if (!dirclr_n) begin
    //        direction <= 1'b0;
    //    end else if (!dirset_n) begin
    //        direction <= 1'b1;
    //    end else begin
    //        direction <= high;
    //    end
    //end

    always @(negedge dirset_n or negedge dirclr_n) begin
        if (!dirclr_n) begin
            direction <= 1'b0;
        end else begin
            direction <= 1'b1;
        end
    end

    assign aempty_n = ~((wptr == rptr) && !direction);
    assign afull_n = ~((wptr == rptr) && direction);
endmodule
