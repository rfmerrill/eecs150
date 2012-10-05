//  Module: ALUTestbench
//  Desc:   32-bit ALU testbench for the MIPS150 Processor
//  Feel free to edit this testbench to add additional functionality
//  
//  Note that this testbench only tests correct operation of the ALU,
//  it doesn't check that you're mux-ing the correct values into the inputs
//  of the ALU. 

// If #1 is in the initial block of your testbench, time advances by
// 1ns rather than 1ps
`timescale 1ns / 1ps

`include "Opcode.vh"

module ALUTestbench();

    parameter Halfcycle = 5; //half period is 5ns
    
    localparam Cycle = 2*Halfcycle;
    
    reg Clock;
    
    // Clock Signal generation:
    initial Clock = 0; 
    always #(Halfcycle) Clock = ~Clock;
    
    // Register and wires to test the ALU
    reg [5:0] funct;
    reg [5:0] opcode;
    reg [31:0] A, B;
    wire [31:0] DUTout;
    reg [31:0] REFout; 
    wire [3:0] ALUop;

    reg [30:0] rand_31;
    reg [14:0] rand_15;

    // Signed operations; these are useful
    // for signed operations
    wire signed [31:0] B_signed;
    assign B_signed = $signed(B);

    wire signed_comp, unsigned_comp;
    assign signed_comp = ($signed(A) < $signed(B));
    assign unsigned_comp = A < B;

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

    //This is where the modules being tested are instantiated. 
    ALUdec DUT1(.funct(funct),
        .opcode(opcode),
        .ALUop(ALUop));

    ALU DUT2( .A(A),
        .B(B),
        .ALUop(ALUop),
        .Out(DUTout));

    integer i;
    localparam loops = 25; // number of times to run the tests for

    // Testing logic:
    initial begin
        for(i = 0; i < loops; i = i + 1)
        begin
            /////////////////////////////////////////////
            // Put your random tests inside of this loop
            // and hard-coded tests outside of the loop
            // (see comment below)
            // //////////////////////////////////////////
            #1;
            // Make both A and B negative to check signed operations
            rand_31 = {$random} & 31'h7FFFFFFF;
            rand_15 = {$random} & 15'h7FFF;
            A = {1'b1, rand_31};
            // Hard-wire 16 1's in front of B for sign extension
            B = {16'hFFFF, 1'b1, rand_15};
            // Set funct random to test that it doesn't affect non-R-type insts
            funct = {$random} % 6'b111111;

            // Test load and store instructions (should add operands)
            opcode = `LB;
            REFout = A + B; 
            #1;
            checkOutput(opcode, funct);

            opcode = `LH;
            #1;
            checkOutput(opcode, funct);

            opcode = `LW;
            #1;
            checkOutput(opcode, funct);

            opcode = `LBU;
            #1;
            checkOutput(opcode, funct);

            opcode = `LHU;
            #1;
            checkOutput(opcode, funct);

            opcode = `SB;
            #1;
            checkOutput(opcode, funct);

            opcode = `SH;
            #1;
            checkOutput(opcode, funct);

            opcode = `SW;
            #1;
            checkOutput(opcode, funct);
            
            opcode = `ADDIU;
            REFout = A + B;
            #1;
            checkOutput(opcode, funct);

            opcode = `SLTI;
            REFout = ($signed(A) < $signed(B)) ? 32'b1 : 32'b0;
            #1;
            checkOutput(opcode, funct);

            opcode = `SLTIU;
            REFout = (A < B) ? 32'b1 : 32'b0;
            #1;
            checkOutput(opcode, funct);

            opcode = `ANDI;
            REFout = A & B;
            #1;
            checkOutput(opcode, funct);

            opcode = `ORI;
            REFout = A | B;
            #1;
            checkOutput(opcode, funct);

            opcode = `XORI;
            REFout = A ^ B;
            #1;
            checkOutput(opcode, funct);


            opcode = `RTYPE;
            
            A = {$random} & 32'hFFFFFFFF;
            B = {$random} & 32'hFFFFFFFF;
            
            funct = `ADDU;
            REFout = A + B;
            #1;
            checkOutput(opcode, funct);

            funct = `SLT;
            REFout = ($signed(A) < $signed(B)) ? 32'b1 : 32'b0;
            #1;
            checkOutput(opcode, funct);

            funct = `SLTU;
            REFout = (A < B) ? 32'b1 : 32'b0;
            #1;
            checkOutput(opcode, funct);

            funct = `AND;
            REFout = A & B;
            #1;
            checkOutput(opcode, funct);

            funct = `OR;
            REFout = A | B;
            #1;
            checkOutput(opcode, funct);

            funct = `XOR;
            REFout = A ^ B;
            #1;
            checkOutput(opcode, funct);

            funct = `NOR;
            REFout = ~(A | B);
            #1;
            checkOutput(opcode, funct);

        end
        ///////////////////////////////
        // Hard coded tests go here
        //////////////////////////////

        $display("\n\nALL TESTS PASSED!");
        $finish();
    end

  endmodule
