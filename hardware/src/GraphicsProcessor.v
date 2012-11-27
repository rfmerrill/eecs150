/*
 Command procesor module that handles the logic for parsing the graphics commands
 Three graphics commands for line engine:
 1. Write start point
 2. Write end-point
 3. Write line color
 If trigger bit set in command, command will also fire on start or end point
 Frame buffer fill will trigger automatically

 */
`include "gpcommands.vh"

module GraphicsProcessor(
    input clk,
    input rst,

    //line engine processor interface
    input LE_ready,
    output [31:0] LE_color,
    output [9:0] LE_point,
    output reg LE_color_valid,
    output reg LE_x0_valid,
    output reg LE_y0_valid,
    output reg LE_x1_valid,
    output reg LE_y1_valid,

    output reg LE_trigger,
    output [31:0] LE_frame,
                       
    //frame filler processor interface
    input FF_ready,
    output reg FF_valid,
    output [23:0] FF_color,
    output [31:0] FF_frame,
                       
    //DRAM request controller interface
    input rdf_valid,
    input af_full,
    input [127:0] rdf_dout,
    output reg rdf_rd_en,
    output reg af_wr_en,
    output [30:0] af_addr_din,
                       
    //processor interface
    input [31:0] GP_CODE,
    input [31:0] GP_FRAME,
    input GP_valid);
     
   
    //Your code goes here. GL HF. <--- well screw you!
    localparam IDLE = 3'b000;
    localparam READ1 = 3'b010;
    localparam READ2 = 3'b011;


    localparam DECODE = 3'b001;
    localparam LINE1 = 3'b010;
    localparam LINE2 = 3'b011;
    localparam LINE3 = 3'b100;
    localparam LINE4 = 3'b101;

    localparam FILL = 3'b111;

    wire [127:0] rdf_dout_fixed;
    assign rdf_dout_fixed = { rdf_dout[31:0], rdf_dout[63:32], rdf_dout[95:64], rdf_dout[127:96] };


    reg [31:0] GP_frame_reg;
    reg [2:0] state, next_state;
    reg [2:0] rd_state, rd_next_state;
    reg [255:0] command_reg, next_command_reg;
    reg [31:0] gpc, next_gpc;
    reg [31:0] line_addr, next_line_addr;
    wire line_valid;

    wire [31:0] request_addr;

    assign request_addr = gpc;

    assign line_valid = (gpc[27:5] == line_addr[27:5]);

    assign af_addr_din =  { 6'b0, request_addr[27:5], 2'b0 };

    always @(posedge clk) begin
      if(rst) begin
        command_reg <= 256'b0;
        line_addr <= 32'b0;
        rd_state <= IDLE;
        next_line_addr <= 32'b0;
      end else begin
        command_reg <= next_command_reg;
        rd_state <= rd_next_state;
        
        if (GP_valid) begin //invalidate our little cache whenever we are re-invoked.
          line_addr <= ~gpc; // You'd have to do some incredible acrobatics to defeat this.
          next_line_addr <= ~gpc;
        end else if ((rd_state == IDLE) && (rd_next_state == READ1))
          next_line_addr <= gpc;
        else if ((rd_state == READ2) && (rd_next_state == IDLE))
          line_addr <= next_line_addr;
      end
    end

    always @(*) begin
      rd_next_state = rd_state;
      next_command_reg = command_reg;
      af_wr_en = 1'b0;
      rdf_rd_en = 1'b0;
      case (rd_state)
        IDLE: 
          begin
            rdf_rd_en = 1'b0;
            af_wr_en = ~line_valid;
            if (af_wr_en & ~af_full)
              rd_next_state = READ1;
          end
        READ1:
          begin
            af_wr_en = 1'b0;
            rdf_rd_en = 1'b1;
            if (rdf_valid) begin
              next_command_reg = { command_reg[255:128], rdf_dout_fixed };
              rd_next_state = READ2;
            end
          end
        READ2:
          begin
            af_wr_en = 1'b0;
            rdf_rd_en = 1'b1;
            if (rdf_valid) begin
              next_command_reg = { rdf_dout_fixed, command_reg[127:0] };
              rd_next_state = IDLE;
            end
          end
      endcase
    end
    
    reg [31:0] instruction;
    
    always @(*) begin
      case (gpc[4:2])
        3'b000: instruction = command_reg[255:224];
        3'b001: instruction = command_reg[223:192];
        3'b010: instruction = command_reg[191:160];
        3'b011: instruction = command_reg[159:128];
        3'b100: instruction = command_reg[127:96];
        3'b101: instruction = command_reg[95:64];
        3'b110: instruction = command_reg[63:32];
        3'b111: instruction = command_reg[31:0];
      endcase
    end


    assign FF_color = instruction[23:0];
    assign LE_color = instruction[23:0];
    assign LE_point = (LE_x0_valid | LE_x1_valid) ? instruction[25:16] : instruction[9:0];

    assign LE_frame = GP_frame_reg;
    assign FF_frame = GP_frame_reg;
    
    wire [7:0] opcode = instruction[31:24];

    always @(posedge clk) begin
        if(rst) begin
           state <= IDLE;
           GP_frame_reg <= 32'b0;
           gpc <= 32'b0;
        end else begin
           state <= next_state;
           gpc <= next_gpc;
           if (GP_valid)
                GP_frame_reg <= GP_FRAME;
        end
    end 
 
    always@( * ) begin
        next_state = state;
        FF_valid = 1'b0;
        LE_color_valid = 1'b0;
        LE_x0_valid = 1'b0;
        LE_x1_valid = 1'b0;
        LE_y0_valid = 1'b0;
        LE_y1_valid = 1'b0;                
        LE_trigger = 1'b0;
        next_gpc = gpc;
        

        if (GP_valid) begin
                next_state = DECODE;
                next_gpc = GP_CODE;
        end else if (line_valid) begin
                case(state) 
                 IDLE: if(GP_valid) begin        
                         next_state = DECODE;
                         next_gpc = GP_CODE;
                       end
                 DECODE: begin
                         if(opcode == `LINE) begin
                           if (LE_ready) begin
                             next_state = LINE1;
                             LE_color_valid = 1'b1;
                             next_gpc = gpc + 32'd4;
                           end
                         end else if(opcode == `FILL) begin
                           if (FF_ready) begin
                             next_state = FILL;
                             FF_valid = 1'b1;        
                             next_gpc = gpc + 32'd4;
                           end
                         end else
                             next_state = IDLE;
                      end
                 LINE1: begin
                           next_state = LINE2;
                           LE_x0_valid = 1'b1;
                        end
                 LINE2: begin
                           next_state = LINE3;
                           LE_y0_valid = 1'b1;
                           next_gpc = gpc + 32'd4;
                        end
                 LINE3: begin
                           next_state = LINE4;
                           LE_x1_valid = 1'b1;
                        end
                 LINE4: begin
                           next_state = DECODE;
                           LE_y1_valid = 1'b1;
                           next_gpc = gpc + 32'd4;
                           LE_trigger = 1'b1;
                        end
                 FILL: if(FF_ready) begin
                           next_state = DECODE;
                       end
                 endcase
        end
    end
    


                       
endmodule
