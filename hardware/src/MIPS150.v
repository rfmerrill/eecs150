module MIPS150(
    input clk,
    input rst,

    // Serial
    input FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX,

    // Memory system connections
    output [31:0] dcache_addr,
    output [31:0] icache_addr,
    output [3:0] dcache_we,
    output [3:0] icache_we,
    output dcache_re,
    output icache_re,
    output [31:0] dcache_din,
    output [31:0] icache_din,
    input [31:0] dcache_dout,
    input [31:0] instruction,
    input stall
);

  reg [31:0] CycleCounter;
  reg [31:0] InstrCounter;

// D stage

  wire [31:0] NextPC;
  reg [31:0] PC;
  
  wire [31:0] PCtoIMem;

  wire [31:0] IMemOutD;
  wire [31:0] IBIOSOutD;
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

  wire [31:0] SignExtImmedD;


// E stage

// Comes from prev. stage
  reg [31:0] InstructionE;
  reg [31:0] SignExtImmedE;
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
  reg  [11:0] OldMemAddrE;
  wire [31:0] ShiftedDataE;
  


// Originates in this stage, goes to next.
  wire [31:0] AddressE;
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
  wire [31:0] DBIOSOutM;
  
  wire [31:0] ResultM;
  wire [31:0] FakeResultM;
   
  wire DataInValid;
  wire DataOutValid;
  wire DataInReady;
  wire DataOutReady;
  
  wire [7:0] DataIn;
  wire [7:0] DataOut;


  wire [35:0] csctrl;

/*  
  chipscope_icon ICON(
   .CONTROL0(csctrl)
  );

  chipscope_ila ILA(
    .CONTROL(csctrl),
    .CLK(clk),
    .DATA({NextPC, InstructionE, FPGA_SERIAL_TX, FPGA_SERIAL_RX, clk, stall, rst, 19'b0,
           MemWriteM, MemToRegM, RegWriteM, WriteRegM, ResultM,
           ALUOutM, wtf, 32'b0,
           DataInValid, DataInReady, DataOutValid, DataOutReady, 12'b0,
           DataIn, DataOut} ),
    .TRIG0(DataOutValid)
  );
*/



  assign PCtoIMem = rst ? 32'b0 : (stall ? PC : NextPC);
  
  assign icache_re = ~(PCtoIMem[31:28] == 4'b0100);
  assign icache_addr = (icache_re ? PCtoIMem : dcache_addr) & 32'h1FFFFFFF;
  assign IMemOutD = instruction;

/* 
  imem_blk_ram instmem(
    .clka(clk),
    .ena(1'b1),
    .wea(InstWriteMaskE),
    .addra(MemAddrE),
    .dina(ShiftedDataE),
    .clkb(clk),
    .addrb(PCtoIMem),
    .doutb(IMemOutD)
  );
*/
  
/*
  dmem_blk_ram datamem(
    .clka(clk),
    .ena(1'b1),
    .wea(DataWriteMaskE),
    .addra(stall ? OldMemAddrE : MemAddrE),
    .dina(ShiftedDataE),
    .douta(DMemOutM)
  );   
*/
  bios_mem bios(
    .clka(clk),
    .ena(1'b1),
    .addra(PCtoIMem[13:2]),
    .douta(IBIOSOutD),
    .clkb(clk),
    .enb(1'b1),
    .addrb(stall ? OldMemAddrE : MemAddrE),
    .doutb(DBIOSOutM)
  );

  assign InstructionD = (PC[31:28] == 4'b0100) ? IBIOSOutD : IMemOutD;

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


  assign SignExtImmedD = (ZeroExtD | ~InstructionD[15]) ? { 16'b0, InstructionD[15:0] } : { 16'hFFFF, InstructionD[15:0] };


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
    .SignExtImmed(SignExtImmedE),
    .ForwardRD((RegWriteM & ~MemToRegM) ? ALUOutM : 32'b0 ),
    .ForwardRA((RegWriteM & ~MemToRegM) ? WriteRegM : 5'b0 ),
    .ShiftImmediate(ShiftImmediateE),
    .ALUSrc(ALUSrcE),
    .RegA(RegAE),
    .RegB(RegBE),
    .ALUInA(ALUInAE),
    .ALUInB(ALUInBE)    
  );

  assign AddressE = RegAE + SignExtImmedE;

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
    .Address(AddressE),
    .WriteData(RegBE),
    .WriteEnable(MemWriteE & ~stall),
    .MemSize(MemSizeE),
    .MemAddr(MemAddrE),
    .InstWriteMask(InstWriteMaskE),
    .DataWriteMask(DataWriteMaskE),
    .ShiftedData(ShiftedDataE)
  );

  // The memory itself is kind of across stages
  
  assign dcache_addr = (stall ? ALUOutM : AddressE) & 32'h1FFFFFFF;
  
  assign dcache_re = MemToRegE & ((dcache_addr[31:28] == 4'b0001) | (dcache_addr[31:28] == 4'b0011));

  assign dcache_we = DataWriteMaskE;
  assign icache_we = (PCE[30]) ? InstWriteMaskE : 4'b0000;

  assign dcache_din = ShiftedDataE;
  assign icache_din = ShiftedDataE;
  
  assign DMemOutM = dcache_dout;
  
  
  MemoryUnMap munmap(
    .MemToReg(MemToRegM),
    .MemOut((ALUOutM[31:28] == 4'b0100) ? DBIOSOutM : DMemOutM),
    .MemSize(MemSizeM),
    .LoadUnsigned(LoadUnsignedM),
    .ALUOut(ALUOutM),
    .Result(FakeResultM)
  );


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
    .stall(stall),
    .DataIn(DataIn),
    .DataInValid(DataInValid),
    .DataInReady(DataInReady),
    .DataOut(DataOut),
    .DataOutValid(DataOutValid),
    .DataOutReady(DataOutReady),
    .FakeResult(FakeResultM),
    .Result(ResultM),
    .LoadUnsigned(LoadUnsignedM),
    .MemSize(MemSizeM),
    .ALUOut(stall ? 32'b0 : ALUOutM),
    .WriteEnable(MemWriteM & ~stall),
    .WriteData(WriteDataM),
    .MemToReg(MemToRegM)
  );



  always @(posedge clk) begin

 
    if (rst) begin
      PC <= 32'h40000000;
      PCE <= 32'h40000000;
      
      CycleCounter <= 32'b0;
      InstrCounter <= 32'b0;
      
      InstructionE <= 32'b0;
      ALUControlE <= 4'b0;
      BranchE <= 0;
      RegDstE <= 0;
      ALUSrcE <= 0;
      ShiftImmediateE <= 0;
      MemWriteE <= 0;
      MemToRegE <= 0;
      RegWriteE <= 0;
      LoadUnsignedE <= 0;
      MemSizeE <= 2'b0;
      BranchTypeE <= 3'b0;
      ZeroExtE <= 0;
      SignExtImmedE <= 32'b0;
      OldMemAddrE <= 12'b0;
      
      
      MemWriteM <= 0;
      MemToRegM <= 0;
      RegWriteM <= 0;
      LoadUnsignedM <= 0;
      MemSizeM <= 2'b0;
      ALUOutM <= 32'b0;
      WriteDataM <= 32'b0;
      WriteRegM <= 0;
    end else if (~stall) begin
    
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
      SignExtImmedE <= SignExtImmedD;
      
      OldMemAddrE <= MemAddrE;
      
      
      MemWriteM <= MemWriteE;
      MemToRegM <= MemToRegE;
      RegWriteM <= RegWriteE;
      LoadUnsignedM <= LoadUnsignedE;
      MemSizeM <= MemSizeE;
      ALUOutM <= ALUOutE;
      WriteDataM <= RegBE;
      WriteRegM <= WriteRegE;
  
      
    end
    
  end

endmodule
