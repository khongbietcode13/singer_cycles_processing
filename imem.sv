
module imem (
    input  logic [31:0] a,   
    output logic [31:0] rd 
);

    logic [31:0] ROM[63:0];

    initial begin
        $readmemh("memfile.dat", ROM);
    end
    assign rd = (a[31:2] < 30'd64) ? ROM[a[7:2]] : 32'h00000000;

endmodule
 
