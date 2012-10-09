module UARTInterface(
  input clk,
  input rst,
  output  reg [7:0] DataIn,
  output    reg  DataInValid,
  input          DataInReady,

  input  [7:0]   DataOut,
  input          DataOutValid,
  output    reg  DataOutReady,

  input   [31:0] FakeResult,
  output reg [31:0] Result,
  
  input   [1:0]  MemSize,
  input          LoadUnsigned,
  input   [31:0] ALUOut,
  input          WriteEnable,
  input          MemToReg,
  input   [31:0] WriteData  
);

  reg reading;
  reg writing;

  always @(*) begin
    Result = FakeResult;
    reading = 0;
    writing = 0;
    
    if (~WriteEnable & MemToReg) begin
      case (ALUOut)
        32'h80000000: Result = { 31'b0, DataInReady };
        32'h80000004: Result = { 31'b0, DataOutValid };
        32'h8000000c: begin
          reading = 1;
          if (MemSize == 2'b00 & ~LoadUnsigned & DataOut[7]) 
            Result = { 24'hFFFFFF, DataOut };
          else
            Result = { 24'b0, DataOut };
        end
      endcase
    end 
      
    if (WriteEnable & (ALUOut == 32'h80000008)) 
      writing = 1;              
  end

  always @(posedge clk) begin
    if (rst) begin
      DataIn <= 8'b0;
      DataOutReady <= 0;
      DataInValid <= 0;
    end else begin

      if (reading)
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
