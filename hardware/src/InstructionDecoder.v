// This thing turns an instruction into a bunch of useful flags. Contains an ALU decoder.
// Completely combinational, no state. I'm gonna try to make this as readable as possible...

`include "Opcode.vh"
`include "ALUop.vh"

module InstructionDecoder  (input [31:0] Instruction,
                            output reg Branch,
                            output reg RegDst,
                            output reg ALUSrc,
                            output reg Shamt,
                            output wire [3:0] ALUControl,
                            output reg MemWrite,
                            output reg MemToReg,
                            output reg RegWrite,
                            output reg LoadUnsigned,
                            output reg [1:0] MemSize, // 00 = byte, 01 = half, 11 = word
                            output reg [2:0] BranchType, // See Opcode.vh for details about branch types.
                            output reg ZeroExt,
                            output reg Invalid);

  wire [5:0] Opcode;
  wire [5:0] Funct;

  
  assign Opcode = Instruction[31:26];
  assign Funct = Instruction[5:0];
  
  ALUdec aludec (.funct(Funct),
                 .opcode(Opcode),
                 .ALUop(ALUControl));
                     
  always @(*) begin
    // Throw some default values in there (The ALU decoder takes care of ALUControl)
  
    Branch = 0;
    RegDst = 0;
    ALUSrc = 0;
    Shamt = 0;
    MemWrite = 0;
    MemToReg = 0;
    RegWrite = 0;
    LoadUnsigned = 0;
    MemSize = 2'b00;
    BranchType = `B_J;
    Invalid = 0;
    ZeroExt = 0;
    
    if (Opcode == 6'b0) begin // R-type instruction
      RegDst = 1;
      RegWrite = 1;
      
      if (Funct == `JR) begin
        Branch = 1;
        RegWrite = 0; // Only R-Type instruction that doesn't write to a register
        BranchType = `B_JR;
      end else if (Funct == `JALR) begin
        Branch = 1;
        BranchType = `B_JR;
        RegWrite = 1;
      end else if ((Funct == `SLL) || (Funct == `SRL) || (Funct == `SRA)) begin
        Shamt = 1;
      end else if (ALUControl == `ALU_XXX) begin
        Invalid = 1; // If it's not JR or JALR, it's something I don't recognize.
      end
      
      // ALU decoder takes care of all the interesting stuff for R-types
      
    end else case (Opcode[5:3])
      `T_LOAD: begin
        ALUSrc = 1;
        MemToReg = 1;
        RegWrite = 1;
        MemSize = Opcode[1:0];
        LoadUnsigned = Opcode[2];
      end
      
      `T_STORE: begin
        ALUSrc = 1;
        MemWrite = 1;
        MemSize = Opcode[1:0];
      end
      
      `T_ITYPE: begin
        ALUSrc = 1;
        RegWrite = 1;
        if (ALUControl == `ALU_XXX)
          Invalid = 1;
        if (Opcode[2] == 1)
          ZeroExt = 1;
      end
      
      `T_OTHER: begin  // Oh boy, those pesky branches!
        Branch = 1;
        
        case (Opcode)
          `J: BranchType = `B_J;
          `JAL: begin
            BranchType = `B_J;
            RegWrite = 1;
           end
          `BEQ: BranchType = `B_BEQ;
          `BNE: BranchType = `B_BNE;
          `BLEZ: BranchType = `B_BLEZ;
          `BGTZ: BranchType = `B_BGTZ;
          `BLTZ: begin
            if (Instruction[16] == 1)
              BranchType = `B_BGEZ;
            else
              BranchType = `B_BLTZ;
           end
           default: Invalid = 1;
        endcase
      end
        
      default: Invalid = 1;
      
    endcase
      
  end

endmodule
