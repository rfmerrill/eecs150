`timescale 1ns/1ps

module EchoTestbench();

    reg Clock, Reset;
    wire FPGA_SERIAL_RX, FPGA_SERIAL_TX;

    reg   [7:0] DataIn;
    reg         DataInValid;
    wire        DataInReady;
    wire  [7:0] DataOut;
    wire        DataOutValid;
    reg         DataOutReady;
    reg stall;

    parameter HalfCycle = 5;
    parameter Cycle = 2*HalfCycle;
    parameter ClockFreq = 50_000_000;

    initial Clock = 0;
    initial stall = 0;
    always #(HalfCycle) Clock <= ~Clock;
    always #(Cycle) stall <= ~stall;

    // Instantiate your CPU here and connect the FPGA_SERIAL_TX wires
    // to the UART we use for testing

    MIPS150 CPU (
      .clk(Clock),
      .rst(Reset),
      .stall(stall),
      .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
      .FPGA_SERIAL_RX(FPGA_SERIAL_RX)
    );



    UART          #( .ClockFreq(       ClockFreq))
                  uart( .Clock(           Clock),
                        .Reset(           Reset),
                        .DataIn(          DataIn),
                        .DataInValid(     DataInValid),
                        .DataInReady(     DataInReady),
                        .DataOut(         DataOut),
                        .DataOutValid(    DataOutValid),
                        .DataOutReady(    DataOutReady),
                        .SIn(             FPGA_SERIAL_TX),
                        .SOut(            FPGA_SERIAL_RX));

    initial begin
      // Reset. Has to be long enough to not be eaten by the debouncer.
      Reset = 0;
 
      DataIn = 8'h7a;
      DataInValid = 0;
      DataOutReady = 0;
      #(100*Cycle)

      Reset = 1;
      #(30*Cycle)
      Reset = 0;

      // Wait until transmit is ready
      while (!DataInReady) begin
     //   stall = 1;
        #(Cycle);
     //   stall = 0;
        #(Cycle);
      end
      
      DataInValid = 1'b1;
      #(Cycle)
      DataInValid = 1'b0;
  //    stall = 1;
      #(Cycle);
 //     stall = 0;
      #(Cycle);

      // Wait for something to come back
      while (!DataOutValid) begin
 //       stall = 1;
        #(Cycle);
 //       stall = 0;
        #(Cycle);
      end
      
      $display("Got %d", DataOut);

      DataOutReady = 1'b1;
      #(Cycle)
      DataOutReady = 1'b0;
      
      DataIn = 8'h89;
      while (!DataInReady) #(Cycle);
      DataInValid = 1'b1;
      #(Cycle)
      DataInValid = 1'b0;
      
      // Wait for something to come back
      while (!DataOutValid) #(Cycle);
      $display("Got %d", DataOut);

      DataOutReady = 1'b1;
      #(Cycle)
      DataOutReady = 1'b0;

      DataIn = 8'h08;
      while (!DataInReady) #(Cycle);
      DataInValid = 1'b1;
      #(Cycle)
      DataInValid = 1'b0;
      
      // Wait for something to come back
      while (!DataOutValid) #(Cycle);
      $display("Got %d", DataOut);

      // Add more test cases!
     


      $finish();
  end

endmodule
