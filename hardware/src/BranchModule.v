`include "Opcode.vh"

module BranchModule(input [2:0] BranchType,
                    input [31:0] Instruction,
                    input [31:0] PC,
                    input [31:0] Drs,
                    input [31:0] Drt,
                    output reg BranchTaken,
                    output reg [31:0] BranchAddress,
                    output reg [4:0] BranchWriteReg,
                    output reg [31:0] BranchRAOut);

                    
  always @(*) begin
    BranchRAOut = PC + 32'd8;
    BranchWriteReg = 5'd31; 
    BranchAddress = PC + 32'd4 + $signed({ Instruction[15:0], 2'b0 }); 
    BranchTaken = 0;

    case (BranchType)
      `B_J: begin
        BranchTaken = 1;
        BranchAddress = { PC[31:28], Instruction[25:0], 2'b00 };
      end 
      `B_JR: begin
        BranchTaken = 1;
        BranchAddress = Drs;
        BranchWriteReg = Instruction[15:11];
      end 
      `B_BEQ: BranchTaken = (Drs == Drt);
      `B_BNE: BranchTaken = (Drs !== Drt);
      `B_BLEZ: BranchTaken = (Drs <= 32'b0);
      `B_BGTZ: BranchTaken = (Drs > 32'b0);
      `B_BLTZ: BranchTaken = (Drs < 32'b0);
      `B_BGEZ: BranchTaken = (Drs >= 32'b0);
    endcase  
  end
endmodule
