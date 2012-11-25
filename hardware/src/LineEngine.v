module LineEngine(
  input                 clk,
  input                 rst,
  output                LE_ready,
  // 8-bit each for RGB, and 8 bits zeros at the top
  input [31:0]          LE_color,
  input [9:0]           LE_point,
  // Valid signals for the inputs
  input                 LE_color_valid,
  input                 LE_x0_valid,
  input                 LE_y0_valid,
  input                 LE_x1_valid,
  input                 LE_y1_valid,
  // Trigger signal - line engine should
  // Start drawing the line
  input                 LE_trigger,
  // FIFO connections
  input                 af_full,
  input                 wdf_full,
  
  output [30:0]         af_addr_din,
  output                af_wr_en,
  output [127:0]        wdf_din,
  output reg [15:0]     wdf_mask_din,
  output                wdf_wr_en,
  input [31:0]                 LE_frame_base
);

  localparam IDLE = 2'b00;
  localparam SET = 2'b01;
  localparam DRAW1 = 2'b10;
  localparam DRAW2 = 2'b11;

  reg [1:0] state, next_state;
  reg [31:0] color;
  reg [9:0]  x, y, x0, y0, x1, y1, ABSx, ABSy, deltax, deltay, ystep;  //x,..x0,..signed?
  reg [10:0] error, new_error;
  reg steep;

    
    always @(posedge clk) begin
        if(rst) begin
           state <= IDLE;
        end else state <= next_state;
    end 

    //State Transition
    always@( * ) begin
        next_state = state;
        begin 
         case(state) 
         
         IDLE: // if(LE_color_valid || LE_y1_valid || LE_y0_valid || LE_x0_valid || LE_x1_valid) 
                if (LE_trigger)        
                        next_state = SET;

         SET:   next_state = DRAW1;
         DRAW1: if(!af_full && !wdf_full) //how long is LE-Trigger on/??
                    next_state = DRAW2;
         DRAW2: if(!af_full && !wdf_full && !(x == x1)) 
                    next_state = DRAW1;        
                 else if((x == x1))
                    next_state = IDLE;  
         endcase
       end

     deltax = (x1 - x0);
     deltay = ((y1 - y0) < 0) ? (y0 - y1) : (y1 - y0);
     

     ABSy = ((y1 < y0)) ? (y0 - y1) : (y1 - y0);
     ABSx = ((x1 < x0)) ? (x0 - x1) : (x1 - x0);

     ystep = (y0 < y1) ? 10'd1 : 10'b1111111111;   

     new_error = error - { 1'b0, ((y1 < y0) ? (y0 - y1) : (y1 - y0)) };
    end

    // Implement Bresenham's line drawing algorithm here!
   
    always @(posedge clk) begin
        if (rst) begin      
           color <= 32'b0;
           steep <= 1'b0;
           error <= 11'b0;
        end else if (state == IDLE) begin
             if(LE_color_valid) 
                color <= LE_color;
             if(LE_x0_valid)
                x0 <= LE_point;
             if(LE_y0_valid)
                y0 <= LE_point;
             if(LE_x1_valid)
                x1 <= LE_point;
             if(LE_y1_valid)
                y1 <= LE_point;
                   

                 steep <= (ABSy > ABSx);

        end else if (state == SET) begin
             steep <= (ABSy > ABSx);

             if ((ABSy > ABSx) & (y0 > y1)) begin
                x0 <= y1;
                y0 <= x1;
                x1 <= y0;
                y1 <= x0;
                     x <= y1;
                     y <= x1;
                error <= {1'b0, ((y0 - y1) >> 1)};
             end else if((ABSy > ABSx)) begin
                x0 <= y0;
                y0 <= x0;
                x1 <= y1;
                y1 <= x1;
                x <= y0;
                y <= x0;
                error <= {1'b0, ((y1 - y0) >> 1)};
             end else if(x0 > x1) begin
                x0 <= x1;
                x1 <= x0;
                y0 <= y1;
                y1 <= y0;
                x <= x1;
                y <= y1;
                error <= {1'b0, ((x0 - x1) >> 1) };
             end else begin
                x <= x0;
                y <= y0;
                error <= {1'b0, ((x1 - x0) >> 1) };
             end
             
        //end
        end else if ((state == DRAW2)) begin
/*                  if(steep) begin
                     x = y;
                     y = x;
                     //x <= y;
                    // y <= x;
                  end else begin
                    x = x; 
                    y = y;
                    //x <= x;
                     //y <= y;
                  end */
                  
                  
                  if(new_error[10]) begin
                     y <= y + ystep;
                     error <= new_error + {1'b0, deltax};
                  end else begin
                     error <= new_error;
                  end
                  x <= x + 10'b1;
        end
     
    end        
    
    //Mask Generation
    always@( * ) begin
      if (steep) begin
        if (state == DRAW1) begin
                if(y[2:0] == 3'b000)
                    wdf_mask_din = 16'h0FFF;
                else if(y[2:0] == 3'b001) 
                        wdf_mask_din = 16'hF0FF;
                else if(y[2:0] == 3'b010) 
                    wdf_mask_din = 16'hFF0F;
                else if(y[2:0] == 3'b011) 
                       wdf_mask_din = 16'hFFF0;
                else
                    wdf_mask_din = 16'hFFFF;
        end else begin
                if(y[2:0] == 3'b100)
                    wdf_mask_din = 16'h0FFF;
                else if(y[2:0] == 3'b101) 
                    wdf_mask_din = 16'hF0FF;
                else if(y[2:0] == 3'b110) 
                    wdf_mask_din = 16'hFF0F;
                else if(y[2:0] == 3'b111) 
                        wdf_mask_din = 16'hFFF0;
                else
                    wdf_mask_din = 16'hFFFF;
        end
      end else begin
        if (state == DRAW1) begin
                if(x[2:0] == 3'b000)
                    wdf_mask_din = 16'h0FFF;
                else if(x[2:0] == 3'b001) 
                        wdf_mask_din = 16'hF0FF;
                else if(x[2:0] == 3'b010) 
                    wdf_mask_din = 16'hFF0F;
                else if(x[2:0] == 3'b011) 
                       wdf_mask_din = 16'hFFF0;
                else
                    wdf_mask_din = 16'hFFFF;
        end else begin
                if(x[2:0] == 3'b100)
                    wdf_mask_din = 16'h0FFF;
                else if(x[2:0] == 3'b101) 
                    wdf_mask_din = 16'hF0FF;
                else if(x[2:0] == 3'b110) 
                    wdf_mask_din = 16'hFF0F;
                else if(x[2:0] == 3'b111) 
                        wdf_mask_din = 16'hFFF0;
                else
                    wdf_mask_din = 16'hFFFF;
        end

                
      end
    end

    //Outputs
    assign wdf_din = {4{color}};    //send one pixel out at a time masking the rest???
    assign af_wr_en = (state == DRAW1);
    assign wdf_wr_en = (state == DRAW1) || (state == DRAW2);
    assign LE_ready = (state == IDLE);
    assign af_addr_din = steep ? {6'b0, LE_frame_base[27:22], x, y[9:3], 2'b0} :
                                 {6'b0, LE_frame_base[27:22], y, x[9:3], 2'b0};

endmodule




