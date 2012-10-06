// This module is (mostly) control For the stuff that happens kind of
// halfway between the second and third pipeline stage.

// There's a little bit of datapath mixed in because I thought it was just way
// too stupid to split this into two modules.

module MemoryMap (input [31:0] Address,
                  input [31:0] WriteData,
                  input WriteEnable,
                  input [1:0] MemSize,
                  output [11:0] MemAddr,
                  output [3:0] InstWriteMask,
                  output [3:0] DataWriteMask,
                  output reg [31:0] ShiftedData
                  );

  
  reg [3:0] WriteMask;
  
  
 
  always @(*) begin
    if (MemSize == 2'b00) begin
      WriteMask = 4'b0001 << Address[1:0];
      ShiftedData = WriteData << 8 * Address[1:0];
    end else if (MemSize == 2'b01) begin
      WriteMask = Address[1] ? 4'b1100 : 4'b0011;
      ShiftedData = Address[1] ? { WriteData[15:0], 16'b0 } : WriteData;
    end else begin
      WriteMask = 4'b1111;
      ShiftedData = WriteData;
    end
  end

  assign InstWriteMask = (~Address[31] & Address[29]) ? WriteMask : 4'b0000;
  assign DataWriteMask = (~Address[31] & Address[29]) ? WriteMask : 4'b0000;

endmodule
