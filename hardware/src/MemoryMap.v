// This module is (mostly) control For the stuff that happens kind of
// halfway between the second and third pipeline stage.

// There's a little bit of datapath mixed in because I thought it was just way
// too stupid to split this into two modules.

module MemoryMap (input [31:0] Address,
                  input [31:0] WriteData,
                  input WriteEnable,
                  input [1:0] MemSize,
                  output [11:0] MemAddr,
                  output reg [3:0] WriteMask,
                  output reg [31:0] ShiftedData
                  );

  
  assign MemAddr = Address[13:2];
 
  always @(*) begin
    if (MemSize == 2'b00) begin
      WriteMask = 4'b1000 >> Address[1:0];
      ShiftedData = { WriteData[7:0], 24'b0 } >> 8 * Address[1:0];
    end else if (MemSize == 2'b01) begin
      WriteMask = ~Address[1] ? 4'b1100 : 4'b0011;
      ShiftedData = ~Address[1] ? { WriteData[15:0], 16'b0 } : WriteData;
    end else begin
      WriteMask = 4'b1111;
      ShiftedData = WriteData;
    end
    
    if (~WriteEnable)
      WriteMask = 4'b0000;
  end

//  assign InstWriteMask = (~Address[31] & ~Address[30] & Address[29] & WriteEnable) ? WriteMask : 4'b0000;
//  assign DataWriteMask = (~Address[31] & ~Address[30] & Address[28] & WriteEnable) ? WriteMask : 4'b0000;

endmodule
