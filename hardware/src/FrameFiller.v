module FrameFiller(//system:
  input             clk,
  input             rst,
  // fill control:
  input             valid,
  input [23:0]      color,
  // ddr2 fifo control:
  input             af_full,
  input             wdf_full,
  // ddr2 fifo outputs:
  output [127:0]    wdf_din,
  output            wdf_wr_en,
  output [30:0]     af_addr_din,
  output            af_wr_en,
  output reg [15:0] wdf_mask_din,
  // handshaking:
  output            ready,
  
  input [31:0]      FF_frame_base
  );

  
  localparam IDLE = 2'b00;
  localparam DRAW1 = 2'b01;
  localparam DRAW2 = 2'b10;

  reg [1:0] state, next_state;
  reg [9:0] x, y;
  reg [23:0] Color;

    always @(posedge clk) begin
        if(rst) begin
           state <= IDLE;

        end else 
           state <= next_state;
    end 

    //State Transition
    always@( * ) begin
        next_state = state;
        begin 
         case(state) 
         
         IDLE: if (valid)
              next_state = DRAW1;
         DRAW1: if(!af_full && !wdf_full) 
                    next_state = DRAW2;
         DRAW2: if(!af_full && !wdf_full) begin 
                   if (!((x == 14'd792) && (y == 14'd599))) 
                     next_state = DRAW1;        
                   else
                     next_state = IDLE;
                end
         endcase
       end
    end
    
    //Setting up and writing
    always @(posedge clk) begin
        if (rst) begin
           Color <= 32'b0;
            x <= 10'b0;
           y <= 10'b0;
        end else if (state == IDLE) begin
           if(valid) 
              Color <= color;
        end else if ((state == DRAW1) & (next_state == DRAW2)) begin
             if(x  == 10'd792) begin
                x <= 10'd0;
                y <= (y == 10'd599) ? 10'b0 : (y + 10'd1);                                        
             end else begin
                x <= x + 10'd8;
                y <= y;
             end
        end
    end

    //Mask
    always@( * ) begin
        if((state == DRAW1) || (state == DRAW2)) 
           wdf_mask_din = 16'h0000;
        else
           wdf_mask_din = 16'hFFFF;
    end

    //Outputs
    assign wdf_din   = {4{8'b0, Color}}; 
    assign wdf_wr_en = (state == DRAW1) || (state == DRAW2);
    assign af_wr_en  = (state == DRAW1);
    assign ready     = (state == IDLE);
    assign af_addr_din = {6'b0, FF_frame_base[27:22], y, x[9:3], 2'b0};




endmodule
