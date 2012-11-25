
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
    output LE_color_valid,
    output LE_x0_valid,
    output LE_y0_valid,
    output LE_x1_valid,
    output LE_y1_valid,

    output LE_trigger,
    output [31:0] LE_frame,
		       
    //frame filler processor interface
    input FF_ready,
    output FF_valid,
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
     
   
   //Your code goes here. GL HF.

    reg [31:0] gpc;
    reg [31:0] line_addr;
    reg [255:0] line;

    wire gpc_valid;
    assign gpc_valid = (line_addr[31:5] == gpc[31:5]);
    wire [31:0] next_gpc;
    assign next_gpc = gpc + 31'd4;
    
    reg [1:0] rdns, rdcs;
    reg [2:0] gns, gcs;
    
    localparam rdIDLE = 2'b00;
    localparam rdREAD1 = 2'b10;
    localparam rdREAD2 = 2'b11;
    
    assign af_addr_din = { 6'b0, gpc[27:5], 2'b0 };
    
		always @(*) begin
		  rdns = rdcs;
		  if (rdcs == rdIDLE) begin
		    af_wr_en = ~gpc_valid;
		    rdf_rd_en = 1'b0;

		    if (af_wr_en & ~af_full)
		      rdns = rdREAD1;
		  end else if (rdcs == rdREAD1) begin
		    af_wr_en = 1'b0;
		    rdf_rd_en = 1'b1;
		    if (rdf_valid)
		      rdns = rdREAD2;
		  end else if (rdcs == rdREAD2) begin
		    af_wr_en = 1'b0;
		    rdf_rd_en = 1'b1;
		    if (rdf_valid)
		      rdns = rdIDLE;
		  end
		end

    always @(posedge clk) begin
      if (rst) begin
        rdcs <= rdIDLE;
        line <= 256'b0;
        line_addr <= 32'b0;
      end else begin
        rdcs <= rdns;
        if (rdf_valid) begin
          if (rdcs == rdREAD1)
            line <= { rdf_dout, line[127:0] };
          else begin
            line <= { line[255:128], rdf_dout };
            line_addr <= { gpc[31:5], 4'b0 };
          end
        end
      end
    end
    
    
    localparam gIDLE = 3'b000;
    localparam gDECODE = 3'b001;
    localparam gFILL = 3'b010;
    localparam gLINE1 = 3'b011;
    localparam gLINE2 = 3'b100;
/*        
    always @(*) begin
      gns = gcs;
      if (gpc_valid) begin
        
      end
    end
    
    always @(posedge clk) begin
      if (rst) begin
        gpc
      end else begin
      
      end
      
*/
endmodule
