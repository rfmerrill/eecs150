// 

module InputSelector(input [31:0] Instruction,
                    input [31:0] Drs,
                    input [31:0] Drt,
                    input [31:0] SignExtImmed,
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
  wire [4:0] RA1;
  wire [4:0] RA2;

  assign RA1 = Instruction[25:21];
  assign RA2 = Instruction[20:16];

  assign shamt = { 27'b0, Instruction[10:6] };

  assign RegA = (ForwardRA == RA1) ? ForwardRD : Drs;
  assign RegB = (ForwardRA == RA2) ? ForwardRD : Drt;
  
  assign ALUInA = ShiftImmediate ? shamt : RegA;
  assign ALUInB = ALUSrc ? SignExtImmed : RegB;
endmodule
