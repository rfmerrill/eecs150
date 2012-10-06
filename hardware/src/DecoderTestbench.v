// If #1 is in the initial block of your testbench, time advances by
// 1ns rather than 1ps
`timescale 1ns / 1ps
`include "Opcode.vh"

module DecoderTestbench();

  parameter Halfcycle = 5; //half period is 5ns

  localparam Cycle = 2*Halfcycle;

  reg Clock;

  // Clock Sinal generation:
  initial Clock = 0; 
  always #(Halfcycle) Clock = ~Clock;

  // Register and wires to test the Decoder

  reg [5:0] Opcode;
  reg [5:0] Funct;
  reg [4:0] rt;
  wire [31:0] Instruction;
  
  integer i;
  
  wire Branch, RegDst, ALUSrc, Shamt, MemWrite, MemToReg, RegWrite, LoadUnsigned, PCToReg, ZeroExt, Invalid;
  wire [3:0] ALUControl;
  wire [1:0] MemSize;
  wire [2:0] BranchType;

  InstructionDecoder DUT(
    .Instruction(Instruction ),
    .Branch(Branch ),
    .RegDst(RegDst ),
    .ALUSrc(ALUSrc ),
    .Shamt(Shamt ),
    .ALUControl(ALUControl ),
    .MemWrite(MemWrite ),
    .MemToReg(MemToReg ),
    .RegWrite(RegWrite ),
    .LoadUnsigned(LoadUnsigned ),
    .MemSize(MemSize ),
    .BranchType(BranchType ),
    .PCToReg(PCToReg ),
    .ZeroExt(ZeroExt),
    .Invalid(Invalid )
   );

 
   assign Instruction = { Opcode, 5'b01010, rt, 10'b1010111100, Funct };

   // Testing logic:
  initial begin
    #1;

    Opcode = 6'b0;
    rt = 5'b0;
    
    
    for (i = 0; i < 64; i = i + 1) begin
      Funct = i & 6'b111111;
      
      #1;
      
      if (~Invalid) begin
        $display ("funct: %b valid, flags %b, ALUControl %b, MemSize %b, BranchType %b", Funct, { Branch, RegDst, ALUSrc, Shamt, MemWrite, MemToReg, RegWrite, LoadUnsigned, PCToReg, ZeroExt }, ALUControl, MemSize, BranchType);
      end
       
    
    end   

    for (i = 0; i < 64; i = i + 1) begin
      Opcode = i & 6'b111111;
      
      #1;
      
      if (~Invalid) begin
        $display ("opcode: %b valid, flags %b, ALUControl %b, MemSize %b, BranchType %b", Opcode, { Branch, RegDst, ALUSrc, Shamt, MemWrite, MemToReg, RegWrite, LoadUnsigned, PCToReg, ZeroExt }, ALUControl, MemSize, BranchType);
      end
       
    end  
    
    Opcode = `BLTZ;
    
    #1;
    
    if (~Invalid) begin
        $display ("opcode: %b valid, flags %b, ALUControl %b, MemSize %b, BranchType %b", Opcode, { Branch, RegDst, ALUSrc, Shamt, MemWrite, MemToReg, RegWrite, LoadUnsigned, PCToReg, ZeroExt }, ALUControl, MemSize, BranchType);
    end
    
    rt = 5'b1;
    
    #1;
    
    if (~Invalid) begin
        $display ("opcode: %b valid, flags %b, ALUControl %b, MemSize %b, BranchType %b", Opcode, { Branch, RegDst, ALUSrc, Shamt, MemWrite, MemToReg, RegWrite, LoadUnsigned, PCToReg, ZeroExt }, ALUControl, MemSize, BranchType);
    end
    
    $finish();
  end
endmodule
