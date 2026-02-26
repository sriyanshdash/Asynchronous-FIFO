//=============================================================================
// File        : fifo_interface.sv
// Description : SystemVerilog interface for the Asynchronous FIFO DUT.
//               Bundles all write-domain and read-domain signals into a
//               single handle that can be passed via virtual interface.
//
// RTL target  : asynchronous_fifo  (FIFO_WIDTH=64, FIFO_DEPTH=8)
//=============================================================================

`ifndef FIFO_INTERFACE_SV
`define FIFO_INTERFACE_SV

`timescale 1ns/1ps

interface fifo_if #(parameter FIFO_WIDTH = 64) (
    input logic wrclk,   // Write-domain clock  (driven from tb_top)
    input logic rdclk    // Read-domain  clock  (driven from tb_top)
);

    //-------------------------------------------------------------------------
    // Write-domain signals
    //-------------------------------------------------------------------------
    logic                  wrst_n;     // Active-low write-domain reset
    logic                  wr_en;      // Write enable
    logic [FIFO_WIDTH-1:0] data_in;    // Write data bus

    logic                  fifo_full;  // Full flag  (output from DUT)

    //-------------------------------------------------------------------------
    // Read-domain signals
    //-------------------------------------------------------------------------
    logic                  rrst_n;     // Active-low read-domain reset
    logic                  rd_en;      // Read enable
    logic [FIFO_WIDTH-1:0] data_out;   // Read data bus – registered in DUT
                                       // (valid 1 rdclk after rd_en assertion)
    logic                  fifo_empty; // Empty flag (output from DUT)

    //-------------------------------------------------------------------------
    // Modport : DUT connections
    //-------------------------------------------------------------------------
    modport dut_mp (
        input  wrclk, wrst_n, wr_en, data_in,
        input  rdclk, rrst_n, rd_en,
        output fifo_full,
        output data_out,
        output fifo_empty
    );

    //-------------------------------------------------------------------------
    // Modport : Write-side testbench driver
    //-------------------------------------------------------------------------
    modport wr_tb_mp (
        input  wrclk,
        input  fifo_full,
        output wrst_n,
        output wr_en,
        output data_in
    );

    //-------------------------------------------------------------------------
    // Modport : Read-side testbench driver
    //-------------------------------------------------------------------------
    modport rd_tb_mp (
        input  rdclk,
        input  data_out,
        input  fifo_empty,
        output rrst_n,
        output rd_en
    );

    //-------------------------------------------------------------------------
    // Modport : Monitor  (observe-only access to all signals)
    //-------------------------------------------------------------------------
    modport mon_mp (
        input wrclk, wrst_n, wr_en,  data_in,  fifo_full,
        input rdclk, rrst_n, rd_en,  data_out, fifo_empty
    );

endinterface : fifo_if

`endif // FIFO_INTERFACE_SV
