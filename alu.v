module ALU(
    input [6:0] opm,
    input [4:0] cmd,
    input [63:0] a,
    input [63:0] b,
`ifdef ALU_ERROR_OUT
    output reg [63:0] error = 0,
`endif
`ifdef ALU_FLAGS_OUT
    output reg [63:0] regF = 0,
`endif
    output reg signed [63:0] out
);

    `define flagPRs 0
    `define flagPRe 5
    `define flagRL 6

    `define flagC 8
    `define flagN 9
    `define flagV 10
    `define flagZ 11
    `define flagL 12

    `define flagULE 16
    `define flagSLT 17
    `define flagSLE 18

`ifndef ALU_FLAGS_OUT
    reg [63:0] regF = 0;
`endif

    reg [63:0] regR = 0;

    reg writeNZFlags = 0;

    reg returnFlags = 0;

    `define CMD_ZERO 5'b00000
    `define CMD_SIGN 5'b00001
    `define CMD_PASSFLAG 5'b00010
    `define CMD_LOADFLAG 5'b00011
    `define CMD_INV 5'b00100
    `define CMD_OR 5'b00101

    always @(a or b or cmd or opm) begin
        case (cmd)
            `CMD_ZERO: begin
                regR = 64'd0;
                writeNZFlags = 1;
            end
            `CMD_SIGN: begin
                regR = b[63] ?
                64'hFFFFFFFFFFFFFFFF :
                64'd0;
                regF[`flagN] = b[0];
                regF[`flagZ] = ~b[0];
            end
            `CMD_PASSFLAG: begin
                returnFlags = 1;
            end
            `CMD_LOADFLAG: begin
                regF = a;
                regR = a;
            end
            `CMD_INV: begin
                regR = ~a;
                writeNZFlags = 1;
            end
            `CMD_OR: begin
                regR = a | b;
                writeNZFlags = 1;
            end
            default: regR = 64'd0; 
        endcase

        out = returnFlags ? regF : regR;
        returnFlags = 0;

        if (writeNZFlags)
        begin
            regF[`flagN] = regR[63];
            regF[`flagZ] = regR == 0;
        end

        writeNZFlags = 0;
    end

endmodule