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

    `define flagsMask 64'h71f7f // 1110001111101111111

`ifndef ALU_FLAGS_OUT
    reg [63:0] regF = 0;
`endif

    reg [63:0] regR = 0;

    reg recalculateFlags = 0;

    reg returnFlags = 1;

    `define CMD_ZERO 5'b00000
    `define CMD_SIGN 5'b00001
    `define CMD_PASSFLAG 5'b00010
    `define CMD_LOADFLAG 5'b00011

    `define CMD_INV 5'b00100
    `define CMD_OR 5'b00101
    `define CMD_XOR 5'b00111
    `define CMD_AND 5'b01000
    `define CMD_XNOR 5'b01001

    `define CMD_RSHIFT0 5'b01010
    `define CMD_RSHIFT1 5'b01011
    `define CMD_RSHIFTL 5'b01100
    `define CMD_RSHIFTS 5'b01101

    `define CMD_LSHIFT0 5'b01110
    `define CMD_LSHIFT1 5'b01111
    `define CMD_LSHIFTL 5'b10000

    always @(a or b or cmd or opm) begin
        case (cmd)
            `CMD_ZERO: begin
                regR = 64'd0;
            end
            `CMD_SIGN: begin
                regR = b[63] ?
                64'hFFFFFFFFFFFFFFFF :
                64'd0;
            end
            `CMD_PASSFLAG: begin
                returnFlags = 1;
                recalculateFlags = 0;
            end
            `CMD_LOADFLAG: begin
                regF = a & `flagsMask;
                regR = a;
                recalculateFlags = 0;
            end
            `CMD_INV: begin
                regR = ~a;
            end
            `CMD_OR: begin
                regR = a | b;
            end
            `CMD_XOR: begin
                regR = a ^ b;
            end
            `CMD_AND: begin
                regR = a & b;
            end
            `CMD_XNOR: begin
                regR = ~(a ^ b);
            end
            `CMD_RSHIFT0: begin
                regR = a >> 1;
                regR[63] = 0;
            end
            `CMD_RSHIFT1: begin
                regR = a >> 1;
                regR[63] = 1;
            end
            `CMD_RSHIFTL: begin
                regR = a >> 1;
                regR[63] = regF[`flagL];
            end
            `CMD_RSHIFTS: begin
                regR = a >> 1;
                regR[63] = regR[62];
            end
            `CMD_LSHIFT0: begin
                regR = a << 1; 
                regR[0] = 0;
            end
            `CMD_LSHIFT1: begin
                regR = a << 1;
                regR[0] = 1;
            end
            `CMD_LSHIFTL: begin
                regR = a << 1;
                regR[0] = regF[`flagL];
            end
            default: regR = 64'd0; 
        endcase

        out = returnFlags ? regF & `flagsMask : regR;
        returnFlags = 0;

        if (recalculateFlags)
        begin
            regF[`flagN] = regR[63];
            regF[`flagZ] = regR == 0;
            regF[`flagULE] = ~regF[`flagC] | regF[`flagZ];
            regF[`flagSLT] = regF[`flagN] ^ regF[`flagV];
            regF[`flagSLE] = regF[`flagSLT] | regF[`flagZ];
        end

        recalculateFlags = 1;
    end

endmodule