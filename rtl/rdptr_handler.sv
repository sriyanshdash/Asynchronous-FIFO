

/* -.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-. 
 ######################################################################################
 #    Marquee Semiconductor Inc Confidential and Proprietary Information              #
 #    Copyright 2021 Marquee Semiconductor Inc                                        #
 #    All Rights Reserved.                                                            #
 #    This is UNPUBLISHED PROPRIETARY SOURCE CODE OF Marquee Semiconductor Inc        #
 #    The copyright notice above does not evidence any actual or intended publication #
 #    of such source code.                                                            #
 ######################################################################################

 * File Name     : rdptr_handler.sv
 
 * Creation Date : 18-04-2024
 
 * Last Modified : Mon 22 Apr 2024 12:17:50 AM PDT
 
 * Created By    : smishra
 
 * Copyright     : The rights belong to Marquee Semiconductor Inc.
 
 * Description   :
 _._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._*/

`timescale 1ns/1ps
  module rptr_handler #(parameter PTR_WIDTH=3) (
    input rdclk, rrst_n, rd_en,
    input [PTR_WIDTH:0] g_wptr_sync,
    output reg [PTR_WIDTH:0] b_rptr, g_rptr,
    output reg fifo_empty
    );

    reg [PTR_WIDTH:0] b_rptr_next;
    reg [PTR_WIDTH:0] g_rptr_next;

    assign b_rptr_next = b_rptr+(rd_en & !fifo_empty);
    assign g_rptr_next = (b_rptr_next >>1)^b_rptr_next;
    assign rempty = (g_wptr_sync == g_rptr_next);
  
    always@(posedge rdclk or negedge rrst_n) begin
     if(!rrst_n) begin
       b_rptr <= 0;
       g_rptr <= 0;
     end
     else begin
       b_rptr <= b_rptr_next;
       g_rptr <= g_rptr_next;
     end
    end
  
    always@(posedge rdclk or negedge rrst_n) begin
     if(!rrst_n) fifo_empty <= 1;
     else        fifo_empty <= rempty;
    end
  endmodule
