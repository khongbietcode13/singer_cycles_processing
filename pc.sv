module pc #(
    parameter WIDTH = 32
)(
    input  logic             clk,
    input  logic             reset,
    input  logic [WIDTH-1:0] pc_next,
    output logic [WIDTH-1:0] pc
);

    always_ff @(posedge clk) begin
        if (reset)
            pc <= '0;
        else
            pc <= pc_next;
    end

endmodule