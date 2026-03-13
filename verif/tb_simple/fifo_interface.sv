// =============================================================================
// File        : fifo_interface.sv
// Description : Interface for the Async FIFO DUT.
//               Groups all write-domain and read-domain signals into one handle
//               so the testbench components can share a single virtual interface.
// =============================================================================

`ifndef FIFO_INTERFACE_SIMPLE_SV
`define FIFO_INTERFACE_SIMPLE_SV

`timescale 1ns/1ps

interface fifo_if #(parameter FIFO_WIDTH = 64) (
    input logic wrclk,   // Write-domain clock
    input logic rdclk    // Read-domain clock
);

    // Write-domain signals
    logic                  wrst_n;      // Active-low write reset
    logic                  wr_en;       // Write enable
    logic [FIFO_WIDTH-1:0] data_in;     // Write data bus

    // Read-domain signals
    logic                  rrst_n;      // Active-low read reset
    logic                  rd_en;       // Read enable
    logic [FIFO_WIDTH-1:0] data_out;    // Read data bus (registered — 1 cycle latency)

    // Status flags from DUT
    logic                  fifo_full;   // FIFO is full
    logic                  fifo_empty;  // FIFO is empty

endinterface : fifo_if

`endif
