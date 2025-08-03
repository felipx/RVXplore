module pipeline_skid_buffer #(
    parameter int unsigned DataWidth = 32
) (
    input                  clk_i,
    input                  rst_i,

    // input interface
    input                  valid_i,
    input  [DataWidth-1:0] data_i,
    output                 ready_o,

    // output interface
    input                  ready_i,
    output                 valid_o,
    output [DataWidth-1:0] data_o
);
    typedef enum logic {
        StPipe = 1'b0,
        StSkid = 1'b1
    } state_e;

    state_e               state_q;
    logic [DataWidth-1:0] data_q, data_buff_q;
    logic                 valid_q, ready_q;
    logic                 ready;

    // outputs
    assign ready   = ready_i || ~valid_q;
    assign ready_o = ready_q;
    assign data_o  = data_q;
    assign valid_o = valid_q;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state_q     <= StPipe;
            data_q      <= '0;
            data_buff_q <= '0;
            valid_q     <= 1'b0;
            ready_q     <= 1'b0;
        end
        else begin
            unique case (state_q)
                StPipe : begin
                    // data is piped out
                    if (ready) begin
                        data_q  <= data_i;
                        valid_q <= valid_i;
                        ready_q <= 1'b1;
                    end
                    // pipeline stall: store input data into spare buffer (skid happened)
                    else if (valid_i) begin
                        data_buff_q <= data_i;
                        ready_q     <= 1'b0;
                        state_q     <= StSkid;
                    end
                end
                StSkid : begin
                    // downstream is ready: resume pipeline, copy data from spare buffer to data buffer
                    if (ready_i) begin
                        data_q  <= data_buff_q;
                        valid_q <= 1'b1;
                        ready_q <= 1'b1;
                        state_q <= StPipe;
                    end
                end
            endcase
       end
    end

endmodule
