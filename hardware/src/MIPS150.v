module MIPS150(
    input clk,
    input rst,

    // Serial
    input FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX,

    // Memory system connections
    output [31:0] dcache_addr,
    output reg [31:0] icache_addr,
    output [3:0] dcache_we,
    output [3:0] icache_we,
    output dcache_re,
    output reg icache_re,
    output [31:0] dcache_din,
    output [31:0] icache_din,
    input [31:0] dcache_dout,
    input [31:0] instruction,
    input stall,

    output [31:0] gp_code,
    output [31:0] gp_frame,
    output gp_valid,
    input frame_interrupt,
    output [31:0] frame_addr,
    output frame_valid
);

//  assign frame_addr = 32'b0;
//  assign frame_valid = 1'b0;
  
  

  // BIOS memory.

  wire [11:0] IMemAddr;
  wire [11:0] MemAddr;
  reg  [11:0] OldMemAddr;
  wire [31:0] BIOSOutA;
  wire [31:0] BIOSOutB;
    
  always @(posedge clk) begin
    if (rst) OldMemAddr <= 12'b0;
    else if (~stall) OldMemAddr <= MemAddr;
  end

  bios_mem bios(
    .clka(clk),
    .ena(1'b1),
    .addra(IMemAddr),
    .douta(BIOSOutA),
    .clkb(clk),
    .enb(1'b1),
    .addrb(stall ? OldMemAddr : MemAddr),
    .doutb(BIOSOutB)
  );
  
  wire [31:0] ISRIn;
  wire ISRWe;
  wire [31:0] ISROut;
  
  ISRMem isr_mem(
    .clk(clk),
    .stall(stall),
    .we(ISRWe),
    .wa(MemAddr),
    .wd(ISRIn),
    .ra(IMemAddr),
    .rd(ISROut)
  );

// Interrupt stuff goes here!
  wire InterruptRequest;
  wire InterruptHandled;
  


// Instruction fetch logic (technically part of the decode stage?)

  wire [31:0] NextPC;
  reg [31:0] PCD;
  reg [31:0] PC;
  
  wire [31:0] fake_dcache_addr;
  
  always @(*) begin
    if (rst)
      PC = 32'h40000000;
    else if (stall)
      PC = PCD;
    else if (InterruptHandled)
      PC = 32'hC0000180;
    else 
      PC = NextPC;      
  end

  always @(posedge clk) PCD <= PC;  

  assign IMemAddr = PC[13:2];


  always @(*) begin      
    if (PC[31:28] == 4'b0100) begin
      // Executing from BIOS
      icache_re = 0;
      icache_addr = fake_dcache_addr & 32'h0FFFFFFF;
    end else if (PC[31:28] == 4'b1100) begin
      // Executing from ISR
      icache_re = 0;
      icache_addr = fake_dcache_addr & 32'h0FFFFFFF;
    end else begin
      // Executing from instruction cache
      icache_re = 1;
      icache_addr = PC & 32'h0FFFFFFF;
    end
  end
  




// ******************************
// ******** DECODE STAGE ********
// ******************************

  reg [31:0] InstructionD;
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
 
  wire MXC0D;

  wire [31:0] SignExtImmedD;


  //assign InstructionD = (PCD[31:28] == 4'b0100) ? BIOSOutA : instruction;

  always @(*) begin
    case (PCD[31:28])
      4'b0100: InstructionD = BIOSOutA;
      4'b1100: InstructionD = ISROut;
      default: InstructionD = instruction;
    endcase
  end


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
    .MXC0(MXC0D),
    .Invalid(InvalidD)
  );


  // Don't interrupt branches and loads or things get nuts
  assign InterruptHandled = InterruptRequest & ~(BranchD | MemToRegD);


  assign SignExtImmedD = (ZeroExtD | ~InstructionD[15]) ? { 16'b0, InstructionD[15:0] } : { 16'hFFFF, InstructionD[15:0] };


// *******************************
// ******** EXECUTE STAGE ********
// *******************************

// Pipeline stuff from decode stage
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
  reg MXC0E;


  always @(posedge clk) begin
    if (rst) begin
      PCE <= 32'h40000000;
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
      OldMemAddr <= 12'b0;
      MXC0E <= 0;
    end else if (~stall) begin  
      // Every clock cycle, the pipeline marches along happily~
        
      PCE <= PCD;
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
      OldMemAddr <= MemAddr;
      MXC0E <= MXC0D;
    end    
  end

// Declare some signals so that the M stage
// Can talk to the regfile

  wire        reg_we;
  wire        reg_fwd;
  wire [4:0]  reg_wa;
  wire [31:0] reg_wd;
  wire [31:0] reg_fwd_wd;

// Other RegFile-related signals
  wire [4:0] rs_addr_E;
  wire [4:0] rt_addr_E;
  wire [4:0] rd_addr_E;
  
  assign rs_addr_E = InstructionE[25:21];
  assign rt_addr_E = InstructionE[20:16];
  assign rd_addr_E = InstructionE[15:11];

  wire [31:0] rs_data_E;
  wire [31:0] rt_data_E;

  RegFile Registers(
    .clk(clk),
    .we(reg_we),
    .ra1(rs_addr_E),
    .ra2(rt_addr_E),
    .wa(reg_wa),
    .wd(reg_wd),
    .rd1(rs_data_E),
    .rd2(rt_data_E)
  );
  
  wire [31:0] CP0OutE;
  wire UART0Request;
  wire UART1Request;
  
  
  // Handle forwarding. Maybe this violates the control/datapath paradigm
  // but I don't see a non-hairy way to do it otherwise
  wire [31:0] RegAE;
  wire [31:0] RegBE;
  
  assign RegAE = (reg_fwd & (reg_wa == rs_addr_E)) ? reg_fwd_wd : rs_data_E;
  assign RegBE = (reg_fwd & (reg_wa == rt_addr_E)) ? reg_fwd_wd : rt_data_E;

  COP0150 cp0(
    .Clock(clk),
    .Enable(1'b1),
    .Reset(rst),
    .DataAddress(rd_addr_E),
    .DataOut(CP0OutE),
    .DataInEnable(MXC0E & InstructionE[23]),
    .DataIn(RegBE),
    .InterruptedPC(NextPC),
    .InterruptHandled(InterruptHandled & ~stall),
    .InterruptRequest(InterruptRequest),
    .UART0Request(UART0Request),
    .UART1Request(UART1Request),
    .frame_interrupt(frame_interrupt)
  );

  
  // These are distinct from the above because branching
  // doesn't use them.   
  wire [31:0] ALUInAE;
  wire [31:0] ALUInBE;

  assign ALUInAE = ShiftImmediateE ? { 27'b0, InstructionE[10:6] } : RegAE;
  assign ALUInBE = ALUSrcE ? SignExtImmedE : RegBE;


  wire [31:0] ActualALUOutE;

  ALU myalu( 
    .A(ALUInAE),
    .B(ALUInBE),
    .ALUop(ALUControlE),
    .Out(ActualALUOutE)
  );

  wire [4:0] BranchWriteRegE;

  OutputSelector osel(
    .Branch(BranchE),
    .BranchType(BranchTypeE),
    .Instruction(InstructionE),
    .oldPC(PCE),
    .newPC(PCD),
    .RegA(RegAE),
    .RegB(RegBE),
    .NextPC(NextPC),
    .BranchWriteReg(BranchWriteRegE)
  );

  wire [31:0] ALUOutE;
  wire [4:0]  WriteRegE;
  
  assign ALUOutE = MXC0E ? CP0OutE:
                   (BranchE ? (PCE + 32'd8) : ActualALUOutE);
  assign WriteRegE = BranchE ? BranchWriteRegE :
                    (RegDstE ? rd_addr_E : rt_addr_E);

  // Bypass ALU and related things for memory stuff, improves timing a bit
  wire [31:0] AddressE; 
  assign AddressE = RegAE + SignExtImmedE;
  
  wire [31:0] WriteDataE;
  assign WriteDataE = RegBE;

  // This happens in stage two because the inst and dmem are synch read.
  wire [3:0]  WriteMaskE;
  wire [31:0] ShiftedDataE; 

  MemoryMap mmap(
    .Address(AddressE),
    .WriteData(RegBE),
    .WriteEnable(MemWriteE & ~stall),
    .MemSize(MemSizeE),
    .MemAddr(MemAddr),
    .WriteMask(WriteMaskE),
    .ShiftedData(ShiftedDataE)
  );

  // The memory itself is kind of across stages

  // ******************************
  // ******** WRITE STAGE ********
  // ******************************
  

  reg MemWriteM;
  reg MemToRegM;
  reg RegWriteM;
  reg LoadUnsignedM;
  reg [1:0] MemSizeM;

  reg [31:0] ALUOutM;
  reg [31:0] WriteDataM;
  reg [4:0]  WriteRegM;
  
  reg [31:0] AddressM;

  wire [31:0] DMemOutM;
  
  wire [31:0] IOResultM;
  reg [31:0] ResultM;

 
  always @(posedge clk) begin
    if (rst) begin
      MemWriteM <= 0;
      MemToRegM <= 0;
      RegWriteM <= 0;
      LoadUnsignedM <= 0;
      MemSizeM <= 2'b0;
      ALUOutM <= 32'b0;
      AddressM <= 32'b0;
      WriteDataM <= 32'b0;
      WriteRegM <= 0;
    end else if (~stall) begin  
      MemWriteM <= MemWriteE;
      MemToRegM <= MemToRegE;
      RegWriteM <= RegWriteE;
      LoadUnsignedM <= LoadUnsignedE;
      MemSizeM <= MemSizeE;
      ALUOutM <= ALUOutE;
      AddressM <= AddressE;
      WriteDataM <= WriteDataE;
      WriteRegM <= WriteRegE;
    end    
  end
  

  
  assign fake_dcache_addr = (stall ? AddressM : AddressE) & 32'h1FFFFFFF;
  assign dcache_addr = fake_dcache_addr & 32'h0FFFFFFF;
  
  assign dcache_re = MemToRegE & (fake_dcache_addr[28]);

  assign dcache_we = (~AddressE[31] & ~AddressE[30] & AddressE[28]) ? WriteMaskE : 4'b0000;
  assign icache_we = (~AddressE[31] & ~AddressE[30] & AddressE[29] & ~icache_re) ? WriteMaskE : 4'b0000;

  assign ISRWe = (AddressE[31:28] == 4'b1100);
  assign ISRIn = WriteDataE;

  assign dcache_din = ShiftedDataE;
  assign icache_din = ShiftedDataE;

  
  assign reg_we = RegWriteM;
  assign reg_fwd = RegWriteM & ~MemToRegM;
  assign reg_wa = WriteRegM;
  assign reg_wd = ResultM;
  assign reg_fwd_wd = ALUOutM;


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
  
  reg DataOutWasValid;
  reg DataInWasReady;
  
  always @(posedge clk) begin
    DataOutWasValid <= DataOutValid;
    DataInWasReady <= DataInReady;
  end
  
  assign UART0Request = DataOutValid & ~DataOutWasValid;
  assign UART1Request = DataInReady & ~DataInWasReady;
  
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
    
    .Result(IOResultM),
    .LoadUnsigned(LoadUnsignedM),
    .MemSize(MemSizeM),
    .Address(stall ? 32'b0 : AddressM),
    .WriteEnable(MemWriteM & ~stall),
    .WriteData(WriteDataM),
    .ReadEnable(MemToRegM),
    .frame_valid(frame_valid),
    .frame_addr(frame_addr),
    .gp_code(gp_code),
    .gp_frame(gp_frame),
    .gp_valid(gp_valid)
  );
  

  reg [15:0] Half;
  reg [7:0] Single;
  reg [31:0] MemOut;
   
  always @(*) begin 
    if (MemToRegM)
      if (AddressM[31:28] == 4'b1000) // IO
        ResultM = IOResultM;
      else begin
        if (AddressM[31:28] == 4'b0100) // BIOS 
          MemOut = BIOSOutB;
        else
          MemOut = dcache_dout;
  
        Half = ~AddressM[1] ? MemOut[31:16] : MemOut[15:0];
        Single = ~AddressM[0] ? Half[15:8] : Half[7:0];
     
        case (MemSizeM)
          2'b00: ResultM = (LoadUnsignedM | ~Single[7]) ? { 24'b0, Single } : { 24'hFFFFFF, Single };
          2'b01: ResultM = (LoadUnsignedM | ~Half[15]) ? { 16'b0, Half } : { 16'hFFFF, Half };
          2'b11: ResultM = MemOut;
        endcase
      end
    else
      ResultM = ALUOutM;
  end




endmodule
