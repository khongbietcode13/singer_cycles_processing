`timescale 1ns/1ps

module tb_top;

    // 1. Các chân giao tiếp chính của module top
    logic        clk;
    logic        reset;
    logic [31:0] WriteData;
    logic [31:0] DataAdr;
    logic        MemWrite;

    // Khởi tạo DUT (giữ nguyên top.sv gốc, không cần sửa port)
    top dut (
        .clk       (clk),
        .reset     (reset),
        .WriteData (WriteData),
        .DataAdr   (DataAdr),
        .MemWrite  (MemWrite)
    );

    // 2. MÓC THẲNG TÍN HIỆU NỘI BỘ (HIERARCHICAL REFERENCE) ĐỂ XEM TRÊN WAVE
    // --- Tín hiệu giữa CPU với IMEM / DMEM ---
    logic [31:0] PC, Instr, ReadData;
    assign PC       = dut.PC;
    assign Instr    = dut.Instr;
    assign ReadData = dut.ReadData;

    // --- Tín hiệu khối Controller & Cờ trạng thái ---
    logic [3:0]  ALUFlags, Flags;
    logic [1:0]  ALUControl, ImmSrc, RegSrc;
    logic        RegWrite, ALUSrc, MemtoReg, PCSrc, NoWrite;
    assign ALUFlags   = dut.arm_cpu.ALUFlags;
    assign Flags      = dut.arm_cpu.c.cl.Flags;      // 4 cờ {N, Z, C, V} đã lưu
    assign ALUControl = dut.arm_cpu.ALUControl;
    assign ImmSrc     = dut.arm_cpu.ImmSrc;
    assign RegSrc     = dut.arm_cpu.RegSrc;
    assign RegWrite   = dut.arm_cpu.RegWrite;
    assign ALUSrc     = dut.arm_cpu.ALUSrc;
    assign MemtoReg   = dut.arm_cpu.MemtoReg;
    assign PCSrc      = dut.arm_cpu.PCSrc;
    assign NoWrite    = dut.arm_cpu.c.NoWrite;

    // --- Tín hiệu bên trong Datapath (Toán hạng ALU & Kết quả) ---
    logic [31:0] SrcA, SrcB, Result;
    assign SrcA   = dut.arm_cpu.dp.SrcA;
    assign SrcB   = dut.arm_cpu.dp.SrcB;
    assign Result = dut.arm_cpu.dp.Result;

    // --- Quan sát trực tiếp các thanh ghi R0 -> R8 trong Register File ---
    logic [31:0] R0, R1, R2, R3, R4, R5, R6, R7, R8;
    assign R0 = dut.arm_cpu.dp.rf.rf[0];
    assign R1 = dut.arm_cpu.dp.rf.rf[1];
    assign R2 = dut.arm_cpu.dp.rf.rf[2];
    assign R3 = dut.arm_cpu.dp.rf.rf[3];
    assign R4 = dut.arm_cpu.dp.rf.rf[4];
    assign R5 = dut.arm_cpu.dp.rf.rf[5];
    assign R6 = dut.arm_cpu.dp.rf.rf[6];
    assign R7 = dut.arm_cpu.dp.rf.rf[7];
    assign R8 = dut.arm_cpu.dp.rf.rf[8];

    // 3. Tạo xung clock chu kỳ 10ns
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // 4. Kịch bản cấp Reset và giới hạn thời gian
    initial begin
        reset = 1'b1;
        #22;
        reset = 1'b0;

        #500;
        $display("TIMEOUT: Mo phong vuot qua thoi gian cho phep!");
        $finish;
    end

    // 5. Tự động kiểm tra kết quả ghi RAM
    always @(negedge clk) begin
        if (MemWrite) begin
            $display("[Time %0t ns] Ghi RAM: Dia chi = %0d | Du lieu = %0d", 
                     $time, DataAdr, WriteData);

            if (DataAdr === 32'd80) begin
                assert (WriteData === 32'd10)
                    else $error("LOI LAN GHI 1: Ky vong 10, nhan duoc %0d", WriteData);
            end
            else if (DataAdr === 32'd84) begin
                assert (WriteData === 32'd5)
                    else $error("LOI LAN GHI 2: Ky vong 5, nhan duoc %0d", WriteData);

                $display("=== THANH CONG: CPU da thuc thi dung toan bo tap lenh! ===");
                #20;
                $finish;
            end
            else begin
                $error("LOI: Ghi vao dia chi khong xac dinh %0d!", DataAdr);
                $finish;
            end
        end
    end

endmodule