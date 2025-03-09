module ALU(
    input [6:0] opm,
    input [4:0] cmd,
    input [63:0] a,
    input [63:0] b,
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

    reg [63:0] regF = 0;
    reg [63:0] regR = 0;

    reg return_flags = 0;

    `define CMD_ZERO 5'b00000
    `define CMD_SIGN 5'b00001
    `define CMD_PASSFLAG 5'b00010
    `define CMD_LOADFLAG 5'b00011
    `define CMD_INV 5'b00100

    always @(a or b or cmd or opm) begin
        case (cmd)
            `CMD_ZERO: begin
                regR = 64'd0;
                regF[`flagN] = 0;
                regF[`flagZ] = 1;
            end
            `CMD_SIGN: begin
                regR = b[63] ?
                64'hFFFFFFFFFFFFFFFF :
                64'd0;
                regF[`flagN] = b[0];
                regF[`flagZ] = ~b[0];
            end
            `CMD_PASSFLAG: begin
                return_flags = 1;
            end
            `CMD_LOADFLAG: begin
                regF = a;
                regR = a;
            end
            `CMD_INV: begin
                regR = ~a;
                regF[`flagN] = regR[63];
                regF[`flagZ] = regR == 0;
            end
            default: regR = 64'd0; 
        endcase

        out = return_flags ? regF : regR;
        return_flags = 0;
    end

endmodule