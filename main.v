// Testbench

`define ALU_ERROR_OUT
`define ALU_FLAGS_OUT

module main;

    reg [6:0] opm = 0;
    reg [4:0] cmd = 5'b11111;
    reg signed [63:0] a = 0;
    reg signed [63:0] b = 0;
    wire signed [63:0] out;
    wire [63:0] regF;
    wire [63:0] error;

    ALU alu0 (.opm (opm),
              .cmd (cmd),
              .a (a),
              .b (b),

`ifdef ALU_ERROR_OUT
              .error(error),
`endif
`ifdef ALU_FLAGS_OUT
              .regF(regF),
`endif

              .out (out));

    task PrintError;
        begin
`ifdef ALU_ERROR_OUT
            $display("ALU error is  %h (%d)", error, error);
`endif
        end
    endtask

    task PrintOutput;
        begin
            $display("ALU output is %h (%d)", out, out);
        end
    endtask

    task PrintFlags;
        begin
`ifdef ALU_FLAGS_OUT
            $display("ALU flags are %b-%b-%b", regF[18:16], regF[12:8], regF[6:0]);
            $display("Result is %s", regF[9] ? "negative" : "positive");
            $display("Result is %s", regF[11] ? "zero" : "non-zero");
`endif
        end
    endtask

    task automatic RunALUCommand (
            input reg [8*10:0] command_label,
            input [4:0] command,
            input [6:0] operation_mode,
            input [63:0] A,
            input [63:0] B
        );
        begin
            $display("");
            $display("----------");
            $display("Command '%s' [%b]", command_label, command);
            $display("Operation mode: [%b]", operation_mode);
            $display("A: %h (%d)", A, A);
            $display("B: %h (%d)", B, B);
            PrintFlags();
            $display("--- Running ---");
            cmd = command;
            opm = operation_mode;
            a = A;
            b = B;
            #1;
            PrintError();
            PrintOutput();
            PrintFlags();
        end
    endtask

    initial begin
        $display("--- Running testbench ---");
        //            label   cmd      opm A  B
        RunALUCommand("ZERO", 5'b00000, 0, 0, 0);
        RunALUCommand("SIGN", 5'b00001, 0, 0, -1);
        RunALUCommand("PASSFLAG", 5'b00010, 0, 0, 0);
        RunALUCommand("LOADFLAG", 5'b00011, 0, 64'hFFFF, 0);
        RunALUCommand("LOADFLAG", 5'b00011, 0, 0, 0);
        RunALUCommand("INV", 5'b00100, 0, -1, 0);
        RunALUCommand("INV", 5'b00100, 0, 0, 0);
        RunALUCommand("OR", 5'b00101, 0, 64'hF0F0F0, 64'h0F0F0F);
        RunALUCommand("XOR", 5'b00111, 0, 64'b11111010, 64'b11110101);
        RunALUCommand("AND", 5'b01000, 0, 64'b1011, 64'b0111);
        RunALUCommand("XNOR", 5'b01001, 0, 64'b11111010, 64'b11110101);
        RunALUCommand("RSHIFT0", 5'b01010, 0, 64'b1111, 0);
        RunALUCommand("RSHIFT1", 5'b01011, 0, 64'b1111, 0);
        RunALUCommand("LOADFLAG", 5'b00011, 0, 4096, 0);
        RunALUCommand("RSHIFTL", 5'b01100, 0, 64'b1111, 0);
        RunALUCommand("RSHIFTS", 5'b01101, 0, -64'hF000000000000000, 0);
        RunALUCommand("LSHIFT0", 5'b01110, 0, 64'b1111, 0);
        RunALUCommand("LSHIFT1", 5'b01111, 0, 64'b1111, 0);
        RunALUCommand("LSHIFTL", 5'b10000, 0, 64'b1111, 0);
    end
endmodule