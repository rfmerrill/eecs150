`include "Opcode.vh"

module OutputSelector(input Branch,
                    input RegDst,
                    input [31:0] ActualALUOut,
                    input [2:0] BranchType,
                    input [31:0] Instruction,
                    input [31:0] oldPC,
                    input [31:0] newPC,
                    input [31:0] RegA,
                    input [31:0] RegB,
                    output reg [31:0] NextPC,
                    output reg [4:0] WriteReg,
                    output reg [31:0] ALUOut);

  reg BranchTaken;
  
  wire [31:0] SignExtOffset;
  
  assign SignExtOffset = Instruction[15] ? { 14'b11111111111111, Instruction[15:0], 2'b00 }
                                         : { 14'b0, Instruction[15:0], 2'b00 };
                    
  always @(*) begin
    NextPC = newPC + 32'd4;
    WriteReg = RegDst ? Instruction[15:11] : Instruction[20:16];
    ALUOut = ActualALUOut;
    BranchTaken = 0;

    if (Branch) begin
      WriteReg = 5'd31;  
      ALUOut = oldPC + 32'd8;

      case (BranchType)
        `B_J: begin
          NextPC = { oldPC[31:28], Instruction[25:0], 2'b00 };
        end 
        `B_JR: begin
          NextPC = RegA;
          WriteReg = Instruction[15:11];
        end 
        `B_BEQ: BranchTaken = (RegA == RegB);
        `B_BNE: BranchTaken = (RegA != RegB);
        `B_BLEZ: BranchTaken = (RegA <= 32'b0);
        `B_BGTZ: BranchTaken = (RegA >  32'b0);
        `B_BLTZ: BranchTaken = (RegA <  32'b0);
        `B_BGEZ: BranchTaken = (RegA >= 32'b0);
      endcase  
      
      if (BranchTaken)
        NextPC = oldPC + 32'd4 + SignExtOffset;
    end
  end
endmodule
