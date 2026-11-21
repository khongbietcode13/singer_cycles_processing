// ============================================================================
// 1. TOP-LEVEL CONTROLLER
// ============================================================================
module controller (
    input  logic         clk, reset,
    input  logic [31:12] Instr,        // Các bit [31:12]: Cond, Op, Funct, Rd
    input  logic [3:0]   ALUFlags,     // {N, Z, C, V} từ Datapath
    
    // Các tín hiệu điều khiển xuất ra Datapath & Data Memory
    output logic [1:0]   RegSrc,
    output logic         RegWrite,
    output logic [1:0]   ImmSrc,
    output logic         ALUSrc,
    output logic [1:0]   ALUControl,
    output logic         MemWrite,
    output logic         MemtoReg,
    output logic         PCSrc
);

    logic [1:0] FlagW;
    logic       PCS, RegW, MemW, NoWrite;

    // Khối giải mã lệnh (Main Decoder + ALU Decoder + PC Logic)
    decoder dec (
        .Op(Instr[27:26]),
        .Funct(Instr[25:20]),
        .Rd(Instr[15:12]),
        .FlagW(FlagW),
        .PCS(PCS),
        .RegW(RegW),
        .MemW(MemW),
        .MemtoReg(MemtoReg),
        .ALUSrc(ALUSrc),
        .ImmSrc(ImmSrc),
        .RegSrc(RegSrc),
        .ALUControl(ALUControl),
        .NoWrite(NoWrite)
    );

    // Khối kiểm tra điều kiện và chốt cờ trạng thái
    condlogic cl (
        .clk(clk),
        .reset(reset),
        .Cond(Instr[31:28]),
        .ALUFlags(ALUFlags),
        .FlagW(FlagW),
        .PCS(PCS),
        .RegW(RegW),
        .MemW(MemW),
        .NoWrite(NoWrite),
        .PCSrc(PCSrc),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite)
    );

endmodule

// ============================================================================
// 2. DECODER (MAIN DECODER + ALU DECODER + PC LOGIC)
// ============================================================================
module decoder (
    input  logic [1:0] Op,
    input  logic [5:0] Funct,
    input  logic [3:0] Rd,
    output logic [1:0] FlagW,
    output logic       PCS, RegW, MemW,
    output logic       MemtoReg, ALUSrc,
    output logic [1:0] ImmSrc, RegSrc, ALUControl,
    output logic       NoWrite
);

    logic [9:0] controls;
    logic       Branch, ALUOp;

    // --- MAIN DECODER (Theo bảng Slide 49) ---
    // Thứ tự vector controls: {Branch, MemtoReg, MemW, ALUSrc, ImmSrc[1:0], RegW, RegSrc[1:0], ALUOp}
    always_comb begin
        casex (Op)
            // Data-processing
            2'b00: begin
                if (Funct[5]) // DP Immediate
                    controls = 10'b0_0_0_1_00_1_00_1;
                else          // DP Register
                    controls = 10'b0_0_0_0_00_1_00_1;
            end

            // Memory (LDR / STR)
            2'b01: begin
                if (Funct[0]) // LDR
                    controls = 10'b0_1_0_1_01_1_00_0;
                else          // STR
                    controls = 10'b0_0_1_1_01_0_10_0;
            end

            // Branch (B)
            2'b10: controls = 10'b1_0_0_1_10_0_01_0;

            default: controls = 10'bx;
        endcase
    end

    assign {Branch, MemtoReg, MemW, ALUSrc, ImmSrc, RegW, RegSrc, ALUOp} = controls;

    // --- ALU DECODER (Theo bảng Slide 78 - Hỗ trợ CMP & NoWrite) ---
    always_comb begin
        if (ALUOp) begin // Nhóm lệnh Data-processing
            case (Funct[4:1])
                4'b0100: begin // ADD
                    ALUControl = 2'b00;
                    NoWrite    = 1'b0;
                end
                4'b0010: begin // SUB
                    ALUControl = 2'b01;
                    NoWrite    = 1'b0;
                end
                4'b0000: begin // AND
                    ALUControl = 2'b10;
                    NoWrite    = 1'b0;
                end
                4'b1100: begin // ORR
                    ALUControl = 2'b11;
                    NoWrite    = 1'b0;
                end
                4'b1010: begin // CMP (Thực hiện phép trừ, không ghi thanh ghi)
                    ALUControl = 2'b01;
                    NoWrite    = 1'b1;
                end
                default: begin
                    ALUControl = 2'bx;
                    NoWrite    = 1'bx;
                end
            endcase

            // Cập nhật cờ trạng thái dựa vào bit S (Funct[0])
            FlagW[1] = Funct[0]; // Cập nhật N, Z
            FlagW[0] = Funct[0] & (ALUControl == 2'b00 | ALUControl == 2'b01); // Cập nhật C, V cho ADD/SUB/CMP
        end else begin
            // Không phải lệnh DP (LDR, STR, Branch)
            ALUControl = 2'b00; // Cộng địa chỉ
            FlagW      = 2'b00; // Không cập nhật cờ
            NoWrite    = 1'b0;
        end
    end

    // --- PC LOGIC ---
    assign PCS = ((Rd == 4'd15) & RegW) | Branch;

endmodule

// ============================================================================
// 3. CONDITIONAL LOGIC & CONDITION CHECK (Theo sơ đồ Slide 77 & bảng Slide 64)
// ============================================================================
module condlogic (
    input  logic       clk, reset,
    input  logic [3:0] Cond,
    input  logic [3:0] ALUFlags,
    input  logic [1:0] FlagW,
    input  logic       PCS, RegW, MemW, NoWrite,
    output logic       PCSrc, RegWrite, MemWrite
);

    logic [1:0] FlagWrite;
    logic [3:0] Flags;
    logic       CondEx;

    // Flip-Flop lưu cờ N, Z
    flopenr #(2) flagreg1 (
        .clk(clk),
        .reset(reset),
        .en(FlagWrite[1]),
        .d(ALUFlags[3:2]),
        .q(Flags[3:2])
    );

    // Flip-Flop lưu cờ C, V
    flopenr #(2) flagreg0 (
        .clk(clk),
        .reset(reset),
        .en(FlagWrite[0]),
        .d(ALUFlags[1:0]),
        .q(Flags[1:0])
    );

    // Kiểm tra mã điều kiện Cond[31:28]
    condcheck cc (
        .Cond(Cond),
        .Flags(Flags),
        .CondEx(CondEx)
    );

    // Cổng AND điều khiển tín hiệu ghi (Chặn RegWrite nếu NoWrite = 1)
    assign FlagWrite = FlagW & {2{CondEx}};
    assign RegWrite  = RegW  & CondEx & ~NoWrite;
    assign MemWrite  = MemW  & CondEx;
    assign PCSrc     = PCS   & CondEx;

endmodule

module condcheck (
    input  logic [3:0] Cond,
    input  logic [3:0] Flags,
    output logic       CondEx
);

    logic neg, zero, carry, overflow, ge;

    assign {neg, zero, carry, overflow} = Flags;
    assign ge = ~(neg ^ overflow); // Tương đương (neg == overflow)

    always_comb begin
        case (Cond)
            4'b0000: CondEx = zero;                  // EQ: Equal
            4'b0001: CondEx = ~zero;                 // NE: Not equal
            4'b0010: CondEx = carry;                 // CS/HS: Carry set / Unsigned higher or same
            4'b0011: CondEx = ~carry;                // CC/LO: Carry clear / Unsigned lower
            4'b0100: CondEx = neg;                   // MI: Minus / Negative
            4'b0101: CondEx = ~neg;                  // PL: Plus / Positive or zero
            4'b0110: CondEx = overflow;              // VS: Overflow
            4'b0111: CondEx = ~overflow;             // VC: No overflow
            4'b1000: CondEx = ~zero & carry;         // HI: Unsigned higher
            4'b1001: CondEx = zero | ~carry;         // LS: Unsigned lower or same
            4'b1010: CondEx = ge;                    // GE: Signed greater than or equal
            4'b1011: CondEx = ~ge;                   // LT: Signed less than
            4'b1100: CondEx = ~zero & ge;            // GT: Signed greater than
            4'b1101: CondEx = zero | ~ge;            // LE: Signed less than or equal
            4'b1110: CondEx = 1'b1;                  // AL: Always / unconditional
            default: CondEx = 1'bx;
        endcase
    end

endmodule

// Flip-Flop có Enable và Reset đồng bộ
module flopenr #(
    parameter WIDTH = 8
)(
    input  logic             clk, reset, en,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);

    always_ff @(posedge clk) begin
        if (reset)   q <= 0;
        else if (en) q <= d;
    end

endmodule

