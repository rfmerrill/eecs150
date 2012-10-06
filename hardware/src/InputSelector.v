// 

module InputSelector(input [31:0] Instruction,
                    input [31:0] Drs,
                    input [31:0] Drt,
                    input ZeroExtend,
                    input [31:0] ForwardRD,
                    input [4:0] ForwardRA,
                    input ShiftImmediate,
                    input ALUSrc,
                    output [31:0] RegA,
                    output [31:0] RegB,
                    output [31:0] ALUInA,
                    output [31:0] ALUInB                 
                    );

  wire [31:0] shamt;
  wire [31:0] immed;
  wire [4:0] RA1;
  wire [4:0] RA2;

  assign RA1 = Instruction[25:21];
  assign RA2 = Instruction[20:16];

  assign shamt = Instruction[10:6];

  assign immed = (ZeroExtend | ~Instruction[15]) ? { 16'b0, Instruction[15:0] } : { 16'b1, Instruction[15:0] };

  assign RegA = (ForwardRA == RA1) ? ForwardRD : Drs;
  assign RegB = (ForwardRA == RA2) ? ForwardRD : Drt;
  
  assign ALUInA = ShiftImmediate ? shamt : RegA;
  assign ALUInB = ALUSrc ? immed : RegB;
endmodule
