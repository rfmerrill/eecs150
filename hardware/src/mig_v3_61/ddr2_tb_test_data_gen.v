//*****************************************************************************
// DISCLAIMER OF LIABILITY
// 
// This text/file contains proprietary, confidential
// information of Xilinx, Inc., is distributed under license
// from Xilinx, Inc., and may be used, copied and/or
// disclosed only pursuant to the terms of a valid license
// agreement with Xilinx, Inc. Xilinx hereby grants you a 
// license to use this text/file solely for design, simulation, 
// implementation and creation of design files limited 
// to Xilinx devices or technologies. Use with non-Xilinx 
// devices or technologies is expressly prohibited and 
// immediately terminates your license unless covered by
// a separate agreement.
//
// Xilinx is providing this design, code, or information 
// "as-is" solely for use in developing programs and 
// solutions for Xilinx devices, with no obligation on the 
// part of Xilinx to provide support. By providing this design, 
// code, or information as one possible implementation of 
// this feature, application or standard, Xilinx is making no 
// representation that this implementation is free from any 
// claims of infringement. You are responsible for 
// obtaining any rights you may require for your implementation. 
// Xilinx expressly disclaims any warranty whatsoever with 
// respect to the adequacy of the implementation, including 
// but not limited to any warranties or representations that this
// implementation is free from claims of infringement, implied 
// warranties of merchantability or fitness for a particular 
// purpose.
//
// Xilinx products are not intended for use in life support
// appliances, devices, or systems. Use in such applications is
// expressly prohibited.
//
// Any modifications that are made to the Source Code are 
// done at the user’s sole risk and will be unsupported.
//
// Copyright (c) 2006-2007 Xilinx, Inc. All rights reserved.
//
// This copyright and support notice must be retained as part 
// of this text at all times. 
//*****************************************************************************
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor: Xilinx
// \   \   \/     Version: 2.3
//  \   \         Application: MIG
//  /   /         Filename: ddr2_tb_test_data_gen.v
// /___/   /\     Date Last Modified: $Date: 2008/07/02 14:03:08 $
// \   \  /  \    Date Created: Fri Sep 01 2006
//  \___\/\___\
//
//Device: Virtex-5
//Design Name: DDR2
//Purpose:
//   This module contains the data generation logic for the synthesizable
//   testbench.
//Reference:
//Revision History:
//*****************************************************************************

`timescale 1ns/1ps

module ddr2_tb_test_data_gen #
  (
   // Following parameters are for 72-bit RDIMM design (for ML561 Reference 
   // board design). Actual values may be different. Actual parameters values 
   // are passed from design top module ddr2_sdram module. Please refer to
   // the ddr2_sdram module for actual values.
   parameter DM_WIDTH      = 9,
   parameter DQ_WIDTH      = 72,
   parameter APPDATA_WIDTH = 144,
   parameter ECC_ENABLE    = 0
   )
  (
   input                                      clk,
   input                                      rst,
   input                                      wr_data_en,
   input                                      rd_data_valid,
   output                                     app_wdf_wren,
   output reg [APPDATA_WIDTH-1:0]             app_wdf_data,
   output reg [(APPDATA_WIDTH/8)-1:0]         app_wdf_mask_data,
   output     [APPDATA_WIDTH-1:0]             app_cmp_data
   );

  localparam WR_IDLE_FIRST_DATA = 2'b00;
  localparam WR_SECOND_DATA     = 2'b01;
  localparam WR_THIRD_DATA      = 2'b10;
  localparam WR_FOURTH_DATA     = 2'b11;
  localparam RD_IDLE_FIRST_DATA = 2'b00;
  localparam RD_SECOND_DATA     = 2'b01;
  localparam RD_THIRD_DATA      = 2'b10;
  localparam RD_FOURTH_DATA     = 2'b11;

  reg [APPDATA_WIDTH-1:0]              app_wdf_data_r;
  reg [(APPDATA_WIDTH/8)-1:0]          app_wdf_mask_data_r;
  wire                                 app_wdf_wren_r;
  reg [(APPDATA_WIDTH/2)-1:0]          rd_data_pat_fall;
  reg [(APPDATA_WIDTH/2)-1:0]          rd_data_pat_rise;
  wire                                 rd_data_valid_r;
  reg [1:0]                            rd_state;
  reg                                  rst_r
                                       /* synthesis syn_preserve = 1 */;
  reg                                  rst_r1
                                       /* synthesis syn_maxfan = 10 */;
  wire [APPDATA_WIDTH-1:0]             wr_data;
  reg                                  wr_data_en_r;
  reg [(APPDATA_WIDTH/2)-1:0]          wr_data_fall
                                       /* synthesis syn_maxfan = 2 */;
  reg [(APPDATA_WIDTH/2)-1:0]          wr_data_rise
                                        /* synthesis syn_maxfan = 2 */;
  wire [(APPDATA_WIDTH/8)-1:0]         wr_mask_data;
  wire [(APPDATA_WIDTH/16)-1:0]        wr_mask_data_fall;
  wire [(APPDATA_WIDTH/16)-1:0]        wr_mask_data_rise;
  reg [1:0]                            wr_state;

  // XST attributes for local reset "tree"
  // synthesis attribute shreg_extract of rst_r is "no";
  // synthesis attribute shreg_extract of rst_r1 is "no";
  // synthesis attribute equivalent_register_removal of rst_r is "no"

  //***************************************************************************

  // local reset "tree" for controller logic only. Create this to ease timing
  // on reset path. Prohibit equivalent register removal on RST_R to prevent
  // "sharing" with other local reset trees (caution: make sure global fanout
  // limit is set to larger than fanout on RST_R, otherwise SLICES will be
  // used for fanout control on RST_R.
  always @(posedge clk) begin
    rst_r  <= rst;
    rst_r1 <= rst_r;
  end

  always @(posedge clk) begin
    app_wdf_data_r      <= wr_data;
    app_wdf_mask_data_r <= wr_mask_data;
    app_wdf_data        <= app_wdf_data_r;
    app_wdf_mask_data   <= app_wdf_mask_data_r;
  end

  // inst ff for timing
  FDRSE ff_wdf_wren
    (
     .Q   (app_wdf_wren_r),
     .C   (clk),
     .CE  (1'b1),
     .D   (wr_data_en_r),
     .R   (1'b0),
     .S   (1'b0)
     );

  FDRSE ff_wdf_wren_r
    (
     .Q   (app_wdf_wren),
     .C   (clk),
     .CE  (1'b1),
     .D   (app_wdf_wren_r),
     .R   (1'b0),
     .S   (1'b0)
     );

  FDRSE ff_rd_data_valid_r
    (
     .Q   (rd_data_valid_r),
     .C   (clk),
     .CE  (1'b1),
     .D   (rd_data_valid),
     .R   (1'b0),
     .S   (1'b0)
     );

  //***************************************************************************
  // DATA generation for WRITE DATA FIFOs & for READ DATA COMPARE
  //***************************************************************************

  assign wr_data      = {wr_data_fall, wr_data_rise};
  assign wr_mask_data = {wr_mask_data_fall, wr_mask_data_rise};

  //*****************************************************************
  // For now, don't vary data masks
  //*****************************************************************

  assign wr_mask_data_rise = {(APPDATA_WIDTH/8){1'b0}};
  assign wr_mask_data_fall = {(APPDATA_WIDTH/8){1'b0}};

  //*****************************************************************
  // Write data logic
  //*****************************************************************

  // write data generation
  //synthesis attribute max_fanout of wr_data_fall is 2
  //synthesis attribute max_fanout of wr_data_rise is 2
  always @(posedge clk) begin
    if (rst_r1) begin
      wr_data_rise <= {(APPDATA_WIDTH/2){1'bx}};
      wr_data_fall <= {(APPDATA_WIDTH/2){1'bx}};
      wr_state <= WR_IDLE_FIRST_DATA;
    end else begin
      case (wr_state)
        WR_IDLE_FIRST_DATA:
          if (wr_data_en) begin
            wr_data_rise <= {(APPDATA_WIDTH/2){1'b1}}; // 0xF
            wr_data_fall <= {(APPDATA_WIDTH/2){1'b0}}; // 0x0
            wr_state <= WR_SECOND_DATA;
          end
        WR_SECOND_DATA:
          if (wr_data_en) begin
            wr_data_rise <= {(APPDATA_WIDTH/4){2'b10}}; // 0xA
            wr_data_fall <= {(APPDATA_WIDTH/4){2'b01}}; // 0x5
            wr_state <= WR_THIRD_DATA;
          end
        WR_THIRD_DATA:
          if (wr_data_en) begin
            wr_data_rise <= {(APPDATA_WIDTH/4){2'b01}}; // 0x5
            wr_data_fall <= {(APPDATA_WIDTH/4){2'b10}}; // 0xA
            wr_state <= WR_FOURTH_DATA;
          end
        WR_FOURTH_DATA:
          if (wr_data_en) begin
            wr_data_rise <= {(APPDATA_WIDTH/8){4'b1001}}; // 0x9
            wr_data_fall <= {(APPDATA_WIDTH/8){4'b0110}}; // 0x6
            wr_state <= WR_IDLE_FIRST_DATA;
          end
      endcase
    end
  end

  always @(posedge clk)
    if (rst_r1)
      wr_data_en_r <= 1'b0;
    else
      wr_data_en_r <= wr_data_en;

  //*****************************************************************
  // Read data logic
  //*****************************************************************

  // read comparison data generation
  always @(posedge clk)
    if (rst_r1) begin
      rd_data_pat_rise <= {(APPDATA_WIDTH/2){1'bx}};
      rd_data_pat_fall <= {(APPDATA_WIDTH/2){1'bx}};
      rd_state <= RD_IDLE_FIRST_DATA;
    end else begin
      case (rd_state)
        RD_IDLE_FIRST_DATA:
          if (rd_data_valid_r)
            begin
              rd_data_pat_rise <= {(APPDATA_WIDTH/2){1'b1}}; // 0xF
              rd_data_pat_fall <= {(APPDATA_WIDTH/2){1'b0}}; // 0x0
              rd_state <= RD_SECOND_DATA;
            end
        RD_SECOND_DATA:
          if (rd_data_valid_r) begin
            rd_data_pat_rise <= {(APPDATA_WIDTH/4){2'b10}};  // 0xA
            rd_data_pat_fall <= {(APPDATA_WIDTH/4){2'b01}};  // 0x5
            rd_state <= RD_THIRD_DATA;
          end
        RD_THIRD_DATA:
          if (rd_data_valid_r) begin
            rd_data_pat_rise <= {(APPDATA_WIDTH/4){2'b01}};  // 0x5
            rd_data_pat_fall <= {(APPDATA_WIDTH/4){2'b10}};  // 0xA
            rd_state <= RD_FOURTH_DATA;
          end
        RD_FOURTH_DATA:
          if (rd_data_valid_r) begin
            rd_data_pat_rise <= {(APPDATA_WIDTH/8){4'b1001}}; // 0x9
            rd_data_pat_fall <= {(APPDATA_WIDTH/8){4'b0110}}; // 0x6
            rd_state <= RD_IDLE_FIRST_DATA;
          end
      endcase
    end

  //data to the compare circuit during read
  assign app_cmp_data = {rd_data_pat_fall, rd_data_pat_rise};

endmodule
