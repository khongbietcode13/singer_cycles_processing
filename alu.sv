module alu (
    input  logic [31:0] Srca, Srcb,         
    input  logic [1:0]  ALUControl,     // 00: ADD, 01: SUB, 10: AND, 11: ORR
    output logic [31:0] Result,         
    output logic [3:0]  ALUFlags        // {N, Z, C, V}
);

    logic        N, Z, C, V;
    logic [32:0] sum;                   // Bit thứ 33 dùng để hứng bit nhớ (Carry Out)


    assign sum = (ALUControl[0]) ? (Srca - Srcb) : (Srca + Srcb);

    // Tính toán Kết quả (Result) dựa theo ALUControl
    always_comb begin
        case (ALUControl)
            2'b00: Result = sum[31:0]; // ADD
            2'b01: Result = sum[31:0]; // SUB
            2'b10: Result = Srca & Srcb;     // AND
            2'b11: Result = Srca | Srcb;     // ORR
            default: Result = 32'bx;
        endcase
    end

    assign N = Result[31];
    assign Z = (Result == 32'b0);

    
    // - phép ADD: C = bit nhớ ra sum[32]
    // - phép SUB: C = ~sum[32] (Chuẩn ARM: 1 là KHÔNG thiếu hàng / No Borrow)
    assign C = (ALUControl[0] == 1'b0) ? sum[32] : ~sum[32];
	 
    assign V = (ALUControl[0] == 1'b0) 
                      ? (~(Srca[31] ^ Srcb[31]) & (Srca[31] ^ Result[31]))  // Tràn ADD
                      : ( (Srca[31] ^ Srcb[31]) & (Srca[31] ^ Result[31])); // Tràn SUB

    // Gom thành vector cờ ALUFlags
    assign ALUFlags = {N, Z, C, V};

endmodule
