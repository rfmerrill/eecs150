//  Module: ALUTestVectorTestbench
//  Desc:   Alternative 32-bit ALU testbench for the MIPS150 Processor
//  Feel free to edit this testbench to add additional functionality
//  
//  Note that this testbench only tests correct operation of the ALU,
//  it doesn't check that you're mux-ing the correct values into the inputs
//  of the ALU. 

`timescale 1ns / 1ps

module ALUTestVectorTestbench();

    parameter Halfcycle = 5; //half period is 5ns

    localparam Cycle = 2*Halfcycle;

    reg Clock;

    // Clock Signal generation:
    initial Clock = 0; 
    always #(Halfcycle) Clock = ~Clock;

    // Wires to test the ALU
    // These are read from the input vector
    reg [5:0] opcode;
    reg [5:0] funct;
    reg [31:0] A, B;
    reg [31:0] REFout; 

    wire [31:0] DUTout;
    wire [3:0] ALUop;

    // Task for checking output
    task checkOutput;
        input [5:0] opcode, funct;
        if ( REFout !== DUTout ) begin
            $display("FAIL: Incorrect result for opcode %b, funct: %b:", opcode, funct);
            $display("\tA: 0x%h, B: 0x%h, DUTout: 0x%h, REFout: 0x%h", A, B, DUTout, REFout);
        $finish();
        end
        else begin
            $display("PASS: opcode %b, funct %b", opcode, funct);
            $display("\tA: 0x%h, B: 0x%h, DUTout: 0x%h, REFout: 0x%h", A, B, DUTout, REFout);
        end
    endtask


    // This is where the modules being tested are instantiated. 
    ALUdec DUT1(.funct(funct),
        .opcode(opcode),
        .ALUop(ALUop));

    ALU DUT2( .A(A),
      .B(B),
      .ALUop(ALUop),
      .Out(DUTout));

    /////////////////////////////////////////////////////////////////
    // Change this number to reflect the number of testcases in your
    // testvector input file, which you can find with the command:
    // % wc -l ../sim/tests/testvectors.input
    // //////////////////////////////////////////////////////////////
    localparam testcases = 580;

    reg [107:0] testvector [0:testcases-1]; // Each testcase has 108 bits:
    // 64 for A and B, 32 for REFout, 6 for
    // opcode, 6 for funct
    
    integer i; // integer used for looping in non-generate statement

    initial 
    begin
        $readmemb("testvectors.input", testvector);
        
        for (i = 0; i < testcases; i = i+1) begin
            opcode = testvector[i][107:102];
            funct = testvector[i][101:96];
            A = testvector[i][95:64];
            B = testvector[i][63:32];
            REFout = testvector[i][31:0];
            
            #1;
            
            checkOutput (opcode, funct);
        end
    
        $display("\n\nALL TESTS PASSED!");
        $finish();
    end

endmodule
