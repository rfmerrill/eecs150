`include "Opcode.vh"

module OutputSelector(input Branch,
                    input [2:0] BranchType,
                    input [31:0] Instruction,
                    input [31:0] oldPC,
                    input [31:0] newPC,
                    input [31:0] RegA,
                    input [31:0] RegB,
                    output reg [31:0] NextPC,
                    output reg [4:0] BranchWriteReg);

  reg BranchTaken;
  
  wire [31:0] SignExtOffset;
  
  assign SignExtOffset = Instruction[15] ? { 14'b11111111111111, Instruction[15:0], 2'b00 }
                                         : { 14'b0, Instruction[15:0], 2'b00 };
                    
  always @(*) begin
    NextPC = newPC + 32'd4;
    BranchWriteReg = 5'd31;
    BranchTaken = 0;

    if (Branch) begin
    
      case (BranchType)
        `B_J: begin
          NextPC = { oldPC[31:28], Instruction[25:0], 2'b00 };
        end 
        `B_JR: begin
          NextPC = RegA;
          BranchWriteReg = Instruction[15:11];
        end 
        `B_BEQ: BranchTaken = (RegA == RegB);
        `B_BNE: BranchTaken = (RegA != RegB);
        `B_BLEZ: BranchTaken = (RegA[31] | (RegA == 32'b0));
        `B_BGTZ: BranchTaken = ~(RegA[31] | (RegA == 32'b0));
        `B_BLTZ: BranchTaken = RegA[31];
        `B_BGEZ: BranchTaken = ~RegA[31];
      endcase  
      
      if (BranchTaken)
        NextPC = oldPC + 32'd4 + SignExtOffset;
    end
  end
endmodule
