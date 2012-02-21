module UART(
  input   Clock,
  input   Reset,

  input   [7:0] DataIn,
  input         DataInValid,
  output        DataInReady,

  output  [7:0] DataOut,
  output        DataOutValid,
  input         DataOutReady,

  input         SIn,
  output        SOut
);

  parameter ClockFreq =                   50_000_000;
  parameter BaudRate  =                   115_200;

  wire      SOutInt, SInInt;

  IORegister            #(.Width(         1),
                          .Initial(       1'b1))
                    txreg(.Clock(         Clock),
                          .Reset(         1'b0),
                          .Set(           Reset),
                          .Enable(        1'b1),
                          .In(            SOutInt),
                          .Out(           SOut)),

                    rxreg(.Clock(         Clock),
                          .Reset(         1'b0),
                          .Set(           Reset),
                          .Enable(        1'b1),
                          .In(            SIn),
                          .Out(           SInInt));




  UATransmit           #( .ClockFreq(     ClockFreq),
                          .BaudRate(      BaudRate))
              uatransmit( .Clock(         Clock),
                          .Reset(         Reset),
                          .DataIn(        DataIn),
                          .DataInValid(   DataInValid),
                          .DataInReady(   DataInReady),
                          .SOut(          SOutInt));

  UAReceive            #( .ClockFreq(     ClockFreq),
                          .BaudRate(      BaudRate))
               uareceive( .Clock(         Clock),
                          .Reset(         Reset),
                          .DataOut(       DataOut),
                          .DataOutValid(  DataOutValid),
                          .DataOutReady(  DataOutReady),
                          .SIn(           SInInt));

endmodule
