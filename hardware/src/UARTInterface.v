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
  
  input          LoadUnsigned,
  input   [31:0] ALUOut,
  input          WriteEnable,
  input          MemToReg,
  input   [31:0] WriteData  
);

  reg [7:0] receivedbyte;
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
          Result = { 24'b0, receivedbyte };
        end
      endcase
    end 
      
    if (WriteEnable & (ALUOut == 32'h80000008)) 
      writing = 1;              
  end

  always @(posedge clk) begin
    if (rst) begin
      DataIn <= 8'b0;
      DataInValid <= 0;
      DataOutReady <= 1;
      receivedbyte <= 0;
    end else begin
    
    
      if (DataOutReady & DataOutValid) begin
        receivedbyte <= DataOut;
        DataOutReady <= 0;
      end
      
      if (reading)
        DataOutReady <= 1;
      
      if (writing) begin
        // Software is supposed to check ready, so don't do it here.
        DataIn <= WriteData[7:0];
        DataInValid <= 1;
      end else if (DataInValid) begin
        DataInValid <= 0;
      end
    end    
  end
endmodule
