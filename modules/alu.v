/*VerilogDebugModuleTemplate
decl {
    module:ALU
    def:ALU_FLAGS_OUT
    i:5:n:cmd:Command
    i:7:n:opm:Operation mode
    i:64:s:a:A
    i:64:s:b:B
    o:64:s:out:Output
    o:64:n:regF:Flags
}
test All-functions {
    ZERO:1:0:0:0
    SIGN:2:0:0:-1
    PASSFLAG:3:0:0:0
    LOADFLAG:4:0:0xFFFF:0
    LOADFLAG:4:0:0:0
    INV:5:0:-1:0
    INV:5:0:0:0
    OR:6:0:0xF0F0F0:0x0F0F0F
    XOR:7:0:0b11111010:0b11110101
    AND:8:0:0b1011:0b0111
    XNOR:9:0:0b11111010:0b11110101
    RSHIFT0:10:0:0b1111:0
    RSHIFT1:11:0:0b1111:0
    LOADFLAG:4:0:4096:0
    RSHIFTL:12:0:0b1111:0
    RSHIFTS:13:0:-0xF000000000000000:0
    LSHIFT0:14:0:0b1111:0
    LSHIFT1:15:0:0b1111:0
    LSHIFTL:16:0:0b1111:0
    PRIOR:17:0:0b1000:0
    NEG:18:0:-5:0
    NEG:18:0:5:0
    ADDM:19:-2:5:0
    ADD:20:0:10:-15
    ADDC:21:0:1:1
    SUB:22:0:100:15
    SUB:22:0:-15:100
    SUBC:23:0:10:5
    LOADFLAG:4:0:0b0000010:0
    SHIFTN0:24:0:1:0
    LOADFLAG:4:0:0b1000010:0
    SHIFTNS:25:0:-4:0
    LOADFLAG:4:0:0b0000100:0
    ROTN:26:0:0xC000000000000003:0
    SHFITM0:27:0b0000010:1:0
    SHIFTMS:28:0b1000010:-4:0
    ROTM:29:0b0000100:0xC000000000000003:0
    MODBITM:30:0b1000011:0:0
}
test Sum-spec {
    ADD:20:0:10:15
    NEG:18:0:5:0
}
*/

module ALU(
    input [6:0] opm,
    input [4:0] cmd,
    input [63:0] a,
    input [63:0] b,
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

    reg recalculateFlags = 1;

    reg returnFlags = 0;

    reg [`flagPRe:`flagPRs] flagsPR = 0;

    reg [63:0] mask = 0;

    `define CMD_ZERO 5'b00001
    `define CMD_SIGN 5'b00010
    `define CMD_PASSFLAG 5'b00011
    `define CMD_LOADFLAG 5'b00100

    `define CMD_INV 5'b00101
    `define CMD_OR 5'b00110
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

    `define CMD_PRIOR 5'b10001
    `define CMD_NEG 5'b10010
    
    `define CMD_ADDM 5'b10011
    `define CMD_ADD 5'b10100
    `define CMD_ADDC 5'b10101

    `define CMD_SUB 5'b10110
    `define CMD_SUBC 5'b10111

    `define CMD_SHIFTN0 5'b11000
    `define CMD_SHIFTNS 5'b11001
    `define CMD_ROTN 5'b11010

    `define CMD_SHIFTM0 5'b11011
    `define CMD_SHIFTMS 5'b11100
    `define CMD_ROTM 5'b11101

    `define CMD_MODBITM 5'b11110

    reg sumFlagV = 0;
    reg sumFlagC = 0;

    function [63:0] sum (input [63:0] A, B);
        reg [64:0] C;
        reg [63:0] G, P, SUM;
        integer jj;
        begin
            C[0] = 1'b0;
            for (jj = 0; jj < 64; jj = jj + 1) begin
                C[jj+1] = (A[jj] & B[jj]) | ((A[jj] ^ B[jj]) & C[jj]);
                SUM[jj] = A[jj] ^ B[jj] ^ C[jj];
            end
            sumFlagC = C[64];
            sumFlagV = C[64] ^ C[63];
            sum = SUM;
        end
    endfunction

    function [63:0] shift (input [63:0] A, input[5:0] bits, input direction, input rotation, input fill_bit);
        reg shiftRotationBit;
        reg [63:0] shiftResult;
        integer i;
        begin
            shiftResult = A;
            for (i = 0; i < 6'b111111; i = i + 1) begin
                if (i < bits) begin
                    if (rotation == 0) begin
                        if (direction == 0) begin
                            shiftResult = shiftResult << 1;
                            shiftResult[0] = fill_bit;
                        end else begin
                            shiftResult = shiftResult >> 1;
                            shiftResult[63] = fill_bit;
                        end
                    end else begin
                        if (direction == 0) begin
                            shiftRotationBit = shiftResult[63];
                            shiftResult = shiftResult << 1;
                            shiftResult[0] = shiftRotationBit;
                        end else begin
                            shiftRotationBit = shiftResult[0];
                            shiftResult = shiftResult >> 1;
                            shiftResult[63] = shiftRotationBit;
                        end
                    end
                end
            end
            shift = shiftResult;
        end
    endfunction

    //always @(a or b or cmd or opm) begin
    always @* begin
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
                regF[`flagV] = regR[63] != a[63];
            end
            `CMD_LSHIFT1: begin
                regR = a << 1;
                regR[0] = 1;
                regF[`flagV] = regR[63] != a[63];
            end
            `CMD_LSHIFTL: begin
                regR = a << 1;
                regR[0] = regF[`flagL];
                regF[`flagV] = regR[63] != a[63];
            end
            `CMD_PRIOR: begin
                integer i;
                reg found;
                flagsPR = 6'd0;
                found = 1'b0;
                for (i = 63; i >= 0; i = i - 1) begin
                    if (a[i] && !found) begin
                        flagsPR = i;
                        found = 1'b1;
                    end
                end
                regR = flagsPR;
                regF[`flagPRe:`flagPRs] = flagsPR;
            end
            `CMD_NEG: begin
                regR = sum(~a, 1);
                regF[`flagV] = sumFlagV;
                regF[`flagC] = sumFlagC;
            end
            `CMD_ADDM: begin
                regR = 64'b0;
                regR[63:6] = {58{opm[6]}};
                regR[5:0] = opm[5:0];
                regR = sum(a, regR);
                regF[`flagV] = sumFlagV;
                regF[`flagC] = sumFlagC;
            end
            `CMD_ADD: begin
                regR = sum(a, b);
                regF[`flagV] = sumFlagV;
                regF[`flagC] = sumFlagC;
            end
            `CMD_ADDC: begin
                regR = sum(a, b);
                regR = sum(regR, sumFlagC);
                regF[`flagV] = sumFlagV;
                regF[`flagC] = sumFlagC;
            end
            `CMD_SUB: begin
                regR = sum(~b, 1);
                regR = sum(a, regR);
                regF[`flagV] = sumFlagV;
                regF[`flagC] = sumFlagC;
            end
            `CMD_SUBC: begin
                regR = sum(a, ~b);
                regR = sum(regR, 1);
                regR = sum(regR, sumFlagC);
                regF[`flagV] = sumFlagV;
                regF[`flagC] = sumFlagC;
            end
            `CMD_SHIFTN0: begin
                regR = shift(a, regF[`flagPRe:`flagPRs], regF[`flagRL], 0, 0);
            end
            `CMD_SHIFTNS: begin
                regR = shift(a, regF[`flagPRe:`flagPRs], regF[`flagRL], 0, a[63]);
            end
            `CMD_ROTN: begin
                regR = shift(a, regF[`flagPRe:`flagPRs], regF[`flagRL], 1, 0);
            end
            `CMD_SHIFTM0: begin
                regR = shift(a, opm[`flagPRe:`flagPRs], opm[`flagRL], 0, 0);
            end
            `CMD_SHIFTMS: begin
                regR = shift(a, opm[`flagPRe:`flagPRs], opm[`flagRL], 0, a[63]);
            end
            `CMD_ROTM: begin
                regR = shift(a, opm[`flagPRe:`flagPRs], opm[`flagRL], 1, 0);
            end
            `CMD_MODBITM: begin
                mask = 64'b1;
                regR = a;
                if (opm[5]) begin
                    mask = mask << 32;
                end
                if (opm[4]) begin
                    mask = mask << 16;
                end
                if (opm[3]) begin
                    mask = mask << 8;
                end
                if (opm[2]) begin
                    mask = mask << 4;
                end
                if (opm[1]) begin
                    mask = mask << 2;
                end
                if (opm[0]) begin
                    mask = mask << 1;
                end
                if (opm[6] == 0) begin
                    mask = ~mask;
                    regR &= mask;
                end else begin
                    regR |= mask;
                end
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