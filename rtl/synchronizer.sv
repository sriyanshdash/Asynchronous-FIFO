

/* -.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-. 
 ######################################################################################
 #    Marquee Semiconductor Inc Confidential and Proprietary Information              #
 #    Copyright 2021 Marquee Semiconductor Inc                                        #
 #    All Rights Reserved.                                                            #
 #    This is UNPUBLISHED PROPRIETARY SOURCE CODE OF Marquee Semiconductor Inc        #
 #    The copyright notice above does not evidence any actual or intended publication #
 #    of such source code.                                                            #
 ######################################################################################

 * File Name     : synchronizer.sv
 
 * Creation Date : 18-04-2024
 
 * Last Modified : Mon 22 Apr 2024 12:18:00 AM PDT
 
 * Created By    : smishra
 
 * Copyright     : The rights belong to Marquee Semiconductor Inc.
 
 * Description   :
 _._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._*/

`timescale 1ns/1ps
 module synchronizer #(parameter WIDTH=3) (input clk, rst_n, [WIDTH:0] d_in, output reg [WIDTH:0] d_out);
   reg [WIDTH:0] q1;
   always@(posedge clk) begin
     if(!rst_n) begin
       q1 <= 0;
       d_out <= 0;
     end
     else begin
       q1 <= d_in;
       d_out <= q1;
     end
    end
 endmodule
