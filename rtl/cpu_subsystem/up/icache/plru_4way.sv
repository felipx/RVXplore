module plru_4way (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        access_i,
    input  logic [3:0]  hit_vect_i,  // Which way was accessed
    output logic [1:0]  victim_o     // Victim way on replacement
);
    // ------------------------------------------------------------------
    // Tree bits: B0 is root, B1 = left subtree, B2 = right subtree
    // ------------------------------------------------------------------
    logic [2:0] plru_bits;

    // ------------------------------------------------------------------
    // Update logic on cache hit
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            plru_bits <= 3'b000;  // Default state: choose W0 first
        end else if (access_i) begin
            unique case (hit_vect_i)
                4'b0001: plru_bits <= {1'b0, 1'b0, plru_bits[0]};  // W0 -> left, left
                4'b0010: plru_bits <= {1'b0, 1'b1, plru_bits[0]};  // W1 -> left, right
                4'b0100: plru_bits <= {1'b1, plru_bits[1], 1'b0};  // W2 -> right, left
                4'b1000: plru_bits <= {1'b1, plru_bits[1], 1'b1};  // W3 -> right, right
                default: plru_bits <= 3'b000;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // Victim selection logic
    // ------------------------------------------------------------------
    always_comb begin
    unique case (plru_bits)
        3'b000:  victim_o = 2'd0; // B0=0 -> left,  B1=0 -> way 0
        3'b001:  victim_o = 2'd0; // B0=0 -> left,  B1=0 -> way 0
        3'b010:  victim_o = 2'd1; // B0=0 -> left,  B1=1 -> way 1
        3'b011:  victim_o = 2'd1; // B0=0 -> left,  B1=1 -> way 1
        3'b100:  victim_o = 2'd2; // B0=1 -> right, B2=0 -> way 2
        3'b101:  victim_o = 2'd3; // B0=1 -> right, B2=1 -> way 3
        3'b110:  victim_o = 2'd2; // B0=1 -> right, B2=0 -> way 2
        3'b111:  victim_o = 2'd3; // B0=1 -> right, B2=1 -> way 3
    endcase
end

endmodule
