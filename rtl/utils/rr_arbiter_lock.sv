module rr_arbiter_lock #(
    parameter int unsigned Width = 4,
    localparam int unsigned BinWidth = $clog2(Width) == 0 ? 1 : $clog2(Width) // TODO: delete?
) (
    input                 clk,
    input                 rst_n,
    input  [Width-1:0]    req_i,
    input                 unlock_i,
    output [Width-1:0]    grant_o,
    output [BinWidth-1:0] binary_grant_o
);
    // Priority pointer
    logic [Width-1:0] base_ptr;

    // Double-sized request and grant vectors
    logic [2*Width-1:0] double_req, double_grant;

    logic [BinWidth-1:0] binary_grant;

    // Initialize and update base_ptr pointer
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // Initial priority to master 0
            base_ptr <= 'b1;
        end else if (|grant_o) begin
            // Left shift with wrap-around
            base_ptr <= {grant_o[Width-2:0], grant_o[Width-1]};
        end
    end

    logic lock;
    logic unlock;
    //logic unlock_1;
    logic [Width-1:0] grant;

    always_ff @(posedge clk) begin
        unlock <= unlock_i;
        //unlock_1 <= unlock;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            lock <= 1'b0;
        end else if (|req_i && !lock) begin
            lock <= 1'b1;
            grant <= double_grant[Width-1:0] | double_grant[2*Width-1:Width];
        end else if (unlock) begin
            lock <= 1'b0;
        end
    end

    // Round-robin arbitration logic
    assign double_req   = {req_i, req_i};
    assign double_grant = double_req & ~(double_req - base_ptr);
    assign grant_o      = lock ? grant : double_grant[Width-1:0] | double_grant[2*Width-1:Width];

    // Encode logic (one-hot to binary)
    always_comb begin
        binary_grant = '0;
        foreach (grant_o[i]) begin
            if (grant_o[i]) begin
                binary_grant = i;
            end
        end
    end

    assign binary_grant_o = binary_grant;

endmodule
