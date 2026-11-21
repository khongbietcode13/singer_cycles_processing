module top (
    input  logic        clk, reset,
    output logic [31:0] WriteData, DataAdr,
    output logic        MemWrite
);

    logic [31:0] PC, Instr, ReadData;

    arm arm_cpu (
        .clk(clk),
        .reset(reset),
        .PC(PC),
        .Instr(Instr),
        .MemWrite(MemWrite),
        .ALUResult(DataAdr),
        .WriteData(WriteData),
        .ReadData(ReadData)
    );

    imem imem_inst (
        .a(PC),
        .rd(Instr)
    );

    dmem dmem_inst (
        .clk(clk),
        .we(MemWrite),
        .a(DataAdr),
        .wd(WriteData),
        .rd(ReadData)
    );

endmodule