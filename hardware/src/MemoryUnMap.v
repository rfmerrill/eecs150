module MemoryUnMap (input         MemToReg,
                    input  [31:0] MemOut,
                    input  [1:0]  MemSize,
                    input         LoadUnsigned,
                    input  [31:0] ALUOut, // This is the address, remember!
                    output reg [31:0] Result);

  reg [15:0] Half;
  reg [7:0] Single;

  always @(*) begin
    Result = ALUOut; // Default
    Half = 0;
    Single = 0;
    
    if (MemToReg) begin
      Half = ALUOut[1] ? MemOut[31:16] : MemOut[15:0];
      Single = ALUOut[0] ? Half[15:8] : Half[7:0];
      
      case (MemSize)
        2'b00: Result = LoadUnsigned ? Single : $signed(Single);
        2'b01: Result = LoadUnsigned ? Half   : $signed(Half);
        2'b11: Result = MemOut;
      endcase
    end
  end

endmodule
