module UARTInterface(
  input clk,
  input rst,
  input stall,
  output  reg [7:0] DataIn,
  output    reg  DataInValid,
  input          DataInReady,

  input  [7:0]   DataOut,
  input          DataOutValid,
  output    reg  DataOutReady,

  output reg [31:0] Result,
  
  input   [1:0]  MemSize,
  input          LoadUnsigned,
  input   [31:0] Address,
  input          WriteEnable,
  input          ReadEnable,
  input   [31:0] WriteData  
);

  reg reading;
  reg writing;
  reg resetcounters;
  
  reg [31:0] CycleCounter;
  reg [31:0] InstrCounter;

  always @(*) begin
    Result = 32'b0;
    reading = 0;
    writing = 0;
    resetcounters = 0;
    
    if (~WriteEnable & ReadEnable) begin
      case (Address)
        32'h80000000: Result = { 31'b0, DataInReady };
        32'h80000004: Result = { 31'b0, DataOutValid };
        32'h8000000c: begin
          reading = 1;
          if (MemSize == 2'b00 & ~LoadUnsigned & DataOut[7]) 
            Result = { 24'hFFFFFF, DataOut };
          else
            Result = { 24'b0, DataOut };
        end
        
        32'h80000010: Result = CycleCounter;
        32'h80000014: Result = InstrCounter;
      endcase
    end 
      
    if (WriteEnable & (Address == 32'h80000008)) 
      writing = 1;
    if (WriteEnable & (Address == 32'h80000018))
      resetcounters = 1;
  end

  always @(posedge clk) begin
    if (rst) begin
      DataIn <= 8'b0;
      DataOutReady <= 0;
      DataInValid <= 0;
      CycleCounter <= 32'b0;
      InstrCounter <= 32'b0;
    end else begin
      if (resetcounters) begin
        CycleCounter <= 32'b0;
        InstrCounter <= 32'b0;
      end else begin
        CycleCounter <= (CycleCounter + 32'b1);
        if (~stall) InstrCounter <= (InstrCounter + 32'b1);
      end

      if (reading & ~stall)
        DataOutReady <= 1;
      else
        DataOutReady <= 0;
     
      if (writing) begin
        // Software is supposed to check ready, so don't do it here.
        DataIn <= WriteData[7:0];
        DataInValid <= 1;
      end else begin
        DataInValid <= 0;
      end    
    end  
  end
endmodule
