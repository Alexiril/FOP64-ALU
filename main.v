// Testbench
module main;

    wire [6:0] opm = 0;
    reg [4:0] cmd = 0;
    reg signed [63:0] a = 0;
    reg signed [63:0] b = 0;
    wire signed [63:0] out;

    ALU alu0 (.opm (opm),
              .cmd (cmd),
              .a (a),
              .b (b),
              .out (out));

    initial begin
        $display("Start testbench");
        #0 begin
            $display("Command ZERO");
            cmd <= 5'b00000;
        end
        #1 $display("Output of zero is %d", out);
        #1 begin
            $display("Command SIGN(b)");
            cmd <= 5'b00001;
            b <= -1;
        end
        #2 $display("Sign of %d is %d", b, out);
        #2 begin
            $display("Command PASSFLAG");
            cmd <= 5'b00010;
        end
        #3 $display("Flags are %h (%d)", out, out);
        #3 begin
            $display("Command LOADFLAG");
            cmd <= 5'b00011;
            a <= 64'hFFFFFFFFFFFFFFFF;
        end
        #4 $display("Loadflag out is %d", out);
        #4 begin
            $display("Command PASSFLAG");
            cmd <= 5'b00010;
        end
        #5 $display("Flags are %h (%d)", out, out);
        #5 begin
            $display("Command LOADFLAG");
            cmd <= 5'b00011;
            a <= 64'd0;
        end
        #6 $display("Loadflag out is %d", out);
        #6 begin
            $display("Command INV");
            cmd <= 5'b00100;
            a <= 64'hFFFFFFFFFFFFFFFF;
        end
        #7 $display("Inverse of A (%d) is %h (%d)", a, out, out);
        #7 begin
            $display("Command PASSFLAG");
            cmd <= 5'b00010;
        end
        #8 $display("Flags are %h (%d)", out, out);
    end
endmodule