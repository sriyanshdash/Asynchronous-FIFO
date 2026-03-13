// =============================================================================
// File        : fifo_transaction.sv
// Description : Transaction class — the "data packet" that flows between
//               testbench components (driver -> monitor -> scoreboard).
//
//               Think of it as a form that carries:
//                 - What we want to do (write? read? what data?)
//                 - What we observed (flags, read data, timestamp)
// =============================================================================

`ifndef FIFO_TRANSACTION_SIMPLE_SV
`define FIFO_TRANSACTION_SIMPLE_SV

`timescale 1ns/1ps

// Operation type — shared across all components
typedef enum logic [1:0] {
    FIFO_IDLE  = 2'b00,   // No operation
    FIFO_WRITE = 2'b01,   // Write operation
    FIFO_READ  = 2'b10    // Read operation
} fifo_op_t;

class fifo_transaction #(parameter FIFO_WIDTH = 64);

    // --- Stimulus fields (set by test, consumed by driver) ---
    rand bit                  wr_en;
    rand bit                  rd_en;
    rand bit [FIFO_WIDTH-1:0] data;    // Write data (ignored for reads)

    // --- Observed fields (set by monitor) ---
    bit [FIFO_WIDTH-1:0] data_out;     // Read data captured from DUT
    bit                  fifo_full;    // Full flag at capture time
    bit                  fifo_empty;   // Empty flag at capture time

    // --- Metadata ---
    fifo_op_t txn_type;                // What kind of operation
    time      capture_time;            // When monitor captured this

    // Print transaction info (useful for debugging)
    function void display(string tag = "TXN");
        $display("[%0t] [%s] type=%s  wr=%0b  rd=%0b  data=0x%016h  full=%0b  empty=%0b",
                 $time, tag, txn_type.name(), wr_en, rd_en, data, fifo_full, fifo_empty);
    endfunction

endclass : fifo_transaction

`endif
