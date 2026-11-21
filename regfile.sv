module regfile (
    input  logic        clk,
    input  logic        we3,        
    input  logic [3:0]  ra1, ra2,  
    input  logic [3:0]  wa3,        
    input  logic [31:0] wd3,        
    input  logic [31:0] r15,        
    output logic [31:0] rd1, rd2    
);

    
    logic [31:0] rf [14:0];
    always_ff @(posedge clk) begin
        if (we3 && (wa3 != 4'd15)) begin
            rf[wa3] <= wd3;
        end
    end
    assign rd1 = (ra1 == 4'd15) ? r15 : rf[ra1];
    assign rd2 = (ra2 == 4'd15) ? r15 : rf[ra2];

endmodule