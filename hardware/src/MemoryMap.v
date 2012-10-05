

module MemoryMap (input [31:0] Address,
                  input [31:0] WriteData,
                  input WriteEnable,
                  output [11:0] IMemWriteAddr,
                  output IMemWriteEnable,
                  output [31:0] ReadWord
                  );

  wire DataMemWriteEnable;
  wire [11:0] DataMemAddress;
  wire DataMemOut;

  assign DataMemAddress = Address[13:2];
  assign IMemWriteAddr = Address[13:2];
  
  assign DataMemWriteEnable = WriteEnable & Address[28] & ~Address[31];
  assign IMemWriteEnable = WriteEnable & Address[29] & ~Address[31];
  
  always @(*) begin
    if (Address[31]) begin
      /* Implement memory mapped IO here */
    
    end
  end

endmodule
