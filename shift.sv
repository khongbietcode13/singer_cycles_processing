module shift (
    input  logic [31:0] a,       
    input  logic [1:0]  sh,       
    input  logic [4:0]  shamt,    
    output logic [31:0] y         
);

    always_comb begin
        case (sh)
            2'b00: y = a << shamt;                           // LSL: Dịch trái logic
            2'b01: y = a >> shamt;                           // LSR: Dịch phải logic
            2'b10: y = $signed(a) >>> shamt;                 // ASR: Dịch phải số học (ép kiểu $signed)
            2'b11: y = (a >> shamt) | (a << (32 - shamt));   // ROR: Quay phải
            default: y = a;
        endcase
    end

endmodule