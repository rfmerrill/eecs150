
module MIPS150(
    input clk, rst, stall,
    input FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX
);


// D stage

  wire [31:0] NextPC;
  reg [31:0] PC;

  wire [31:0] InstructionD;
  wire [3:0] ALUControlD;
  wire BranchD;
  wire RegDstD;
  wire ALUSrcD;
  wire ShiftImmediateD;
  wire MemWriteD;
  wire MemToRegD;
  wire RegWriteD;
  wire LoadUnsignedD;
  wire [1:0] MemSizeD;
  wire [2:0] BranchTypeD;
  wire ZeroExtD;
  wire InvalidD;


// E stage

// Comes from prev. stage
  reg [31:0] InstructionE;
  reg [3:0] ALUControlE;
  reg BranchE;
  reg RegDstE;
  reg ALUSrcE;
  reg ShiftImmediateE;
  reg MemWriteE;
  reg MemToRegE;
  reg RegWriteE;
  reg LoadUnsignedE;
  reg [1:0] MemSizeE;
  reg [2:0] BranchTypeE;
  reg ZeroExtE;
  reg [31:0] PCE;


// Exists only in this stage.
  
  wire [31:0] RD1E;
  wire [31:0] RD2E;
  
  wire [31:0] RegAE;
  wire [31:0] ALUInAE;
  wire [31:0] ALUInBE;
  
  wire [31:0] ActualALUOutE;
  
  wire [3:0] InstWriteMaskE; 
  wire [3:0] DataWriteMaskE;
  wire [11:0] MemAddrE;
  wire [31:0] ShiftedDataE;
  


// Originates in this stage, goes to next.
  wire [31:0] ALUOutE;
  wire [31:0] RegBE;
  wire [4:0]  WriteRegE;

// M stage  
  
  reg MemWriteM;
  reg MemToRegM;
  reg RegWriteM;
  reg LoadUnsignedM;
  reg [1:0] MemSizeM;

  reg [31:0] ALUOutM;
  reg [31:0] WriteDataM;
  reg [4:0]  WriteRegM;

  wire [31:0] DMemOutM;
  
  wire [31:0] ResultM;
  wire [31:0] FakeResultM;

  
 
  imem_blk_ram instmem(
    .clka(clk),
    .ena(~stall),
    .wea(InstWriteMaskE),
    .addra(MemAddrE),
    .dina(ShiftedDataE),
    .clkb(clk),
    .addrb(rst ? 12'b0 : NextPC[13:2]),
    .doutb(InstructionD)
  );
  

  InstructionDecoder decoder(
    .Instruction(InstructionD),
    .Branch(BranchD),
    .RegDst(RegDstD),
    .ALUSrc(ALUSrcD),
    .Shamt(ShiftImmediateD),
    .ALUControl(ALUControlD),
    .MemWrite(MemWriteD),
    .MemToReg(MemToRegD),
    .RegWrite(RegWriteD),
    .LoadUnsigned(LoadUnsignedD),
    .MemSize(MemSizeD),
    .BranchType(BranchTypeD),
    .ZeroExt(ZeroExtD),
    .Invalid(InvalidD)
  );


// Pipeline boundary (mostly) here, on to stage two!

  RegFile Registers(
    .clk(clk),
    .we(RegWriteM),
    .ra1(InstructionE[25:21]),
    .ra2(InstructionE[20:16]),
    .wa(WriteRegM),
    .wd(ResultM),
    .rd1(RD1E),
    .rd2(RD2E)
  );

  InputSelector isel(
    .Instruction(InstructionE),
    .Drs(RD1E),
    .Drt(RD2E),
    .ZeroExtend(ZeroExtE),
    .ForwardRD(ALUOutM),
    .ForwardRA(WriteRegM),
    .ShiftImmediate(ShiftImmediateE),
    .ALUSrc(ALUSrcE),
    .RegA(RegAE),
    .RegB(RegBE),
    .ALUInA(ALUInAE),
    .ALUInB(ALUInBE)    
  );

  ALU myalu( 
    .A(ALUInAE),
    .B(ALUInBE),
    .ALUop(ALUControlE),
    .Out(ActualALUOutE)
  );
  
  OutputSelector osel(
    .Branch(BranchE),
    .RegDst(RegDstE),
    .ActualALUOut(ActualALUOutE),
    .BranchType(BranchTypeE),
    .Instruction(InstructionE),
    .oldPC(PCE),
    .newPC(PC),
    .RegA(RegAE),
    .RegB(RegBE),
    .NextPC(NextPC),
    .WriteReg(WriteRegE),
    .ALUOut(ALUOutE)
  );


  // This happens in stage two because the inst and dmem are synch read.

  MemoryMap mmap(
    .Address(ALUOutE),
    .WriteData(RegBE),
    .WriteEnable(MemWriteE & ~stall),
    .MemSize(MemSizeE),
    .MemAddr(MemAddrE),
    .InstWriteMask(InstWriteMaskE),
    .DataWriteMask(DataWriteMaskE),
    .ShiftedData(ShiftedDataE)
  );

  // The memory itself is kind of across stages

  dmem_blk_ram datamem(
    .clka(clk),
    .ena(~stall),
    .wea(DataWriteMaskE),
    .addra(MemAddrE),
    .dina(ShiftedDataE),
    .douta(DMemOutM)
  );  
  
  
  MemoryUnMap munmap(
    .MemToReg(MemToRegM),
    .MemOut(DMemOutM),
    .MemSize(MemSizeM),
    .LoadUnsigned(LoadUnsignedM),
    .ALUOut(ALUOutM),
    .Result(FakeResultM)
  );
  
  wire DataInValid;
  wire DataOutValid;
  wire DataInReady;
  wire DataOutReady;
  
  wire [7:0] DataIn;
  wire [7:0] DataOut;

  UART serport(
    .Clock(clk),
    .Reset(rst),
    .DataInValid(DataInValid),
    .DataOutValid(DataOutValid),
    .DataInReady(DataInReady),
    .DataOutReady(DataOutReady),
    .DataIn(DataIn),
    .DataOut(DataOut),
    .SIn(FPGA_SERIAL_RX),
    .SOut(FPGA_SERIAL_TX)
  );
  
  UARTInterface ui(
    .clk(clk),
    .rst(rst),
    .DataIn(DataIn),
    .DataInValid(DataInValid),
    .DataInReady(DataInReady),
    .DataOut(DataOut),
    .DataOutValid(DataOutValid),
    .DataOutReady(DataOutReady),
    .FakeResult(FakeResultM),
    .Result(ResultM),
    .LoadUnsigned(LoadUnsignedM),
    .ALUOut(ALUOutM),
    .WriteEnable(MemWriteM & ~stall),
    .WriteData(WriteDataM),
    .MemToReg(MemToRegM)
  );



  always @(posedge clk) begin

 
    if (~stall) begin
    
      // Every clock cycle, the pipeline marches along happily~
    
      PC <= NextPC;
    
      PCE <= PC;
      InstructionE <= InstructionD;
      ALUControlE <= ALUControlD;
      BranchE <= BranchD;
      RegDstE <= RegDstD;
      ALUSrcE <= ALUSrcD;
      ShiftImmediateE <= ShiftImmediateD;
      MemWriteE <= MemWriteD;
      MemToRegE <= MemToRegD;
      RegWriteE <= RegWriteD;
      LoadUnsignedE <= LoadUnsignedD;
      MemSizeE <= MemSizeD;
      BranchTypeE <= BranchTypeD;
      ZeroExtE <= ZeroExtD;
      
      
      MemWriteM <= MemWriteE;
      MemToRegM <= MemToRegE;
      RegWriteM <= RegWriteE;
      LoadUnsignedM <= LoadUnsignedE;
      MemSizeM <= MemSizeE;
      ALUOutM <= ALUOutE;
      WriteDataM <= RegBE;
      WriteRegM <= WriteRegE;
  
      
    end
    
    if (rst)
      PC <= 32'b0;  
  end



endmodule
    

