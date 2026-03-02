//=============================================================================
// File        : fifo_transaction.sv
// Description : Transaction class for the Async FIFO testbench.
//               Carries stimulus fields (wr_en, rd_en, data) and observed
//               fields (data_out, flags) captured by the monitor.
//=============================================================================

`ifndef FIFO_TRANSACTION_SV
`define FIFO_TRANSACTION_SV

`timescale 1ns/1ps

//-----------------------------------------------------------------------------
// Enum : categorises what kind of FIFO operation a transaction represents.
// Defined at package scope so driver, monitor and scoreboard all share it.
//-----------------------------------------------------------------------------
typedef enum logic [1:0] {
    FIFO_IDLE  = 2'b00,
    FIFO_WRITE = 2'b01,
    FIFO_READ  = 2'b10
} fifo_txn_type_e;

//-----------------------------------------------------------------------------
// Class : fifo_transaction
//-----------------------------------------------------------------------------
class fifo_transaction #(parameter FIFO_WIDTH = 64);

    //-------------------------------------------------------------------------
    // Randomisable stimulus fields
    //-------------------------------------------------------------------------
    rand bit                  wr_en;   // Write enable
    rand bit                  rd_en;   // Read  enable
    rand bit [FIFO_WIDTH-1:0] data;    // Write data (ignored on pure reads)

    //-------------------------------------------------------------------------
    // Non-randomised observed / annotated fields
    //-------------------------------------------------------------------------
    bit [FIFO_WIDTH-1:0] data_out;    // Read data captured by monitor
    bit                  fifo_full;   // Full  flag observed at sample time
    bit                  fifo_empty;  // Empty flag observed at sample time

    // Set by monitor or test to classify the transaction
    fifo_txn_type_e txn_type;

    // Timestamp set by the monitor at capture time
    time capture_time;

    //-------------------------------------------------------------------------
    // Constraints
    //-------------------------------------------------------------------------
    //-------------------------------------------------------------------------
    // display() – print transaction contents to transcript
    //-------------------------------------------------------------------------
    function void display(string tag = "TXN");
        $display("[%0t] [%-8s] type=%-6s  wr_en=%0b  rd_en=%0b  data=0x%016h | full=%0b  empty=%0b",
                 $time, tag, txn_type.name(),
                 wr_en, rd_en, data, fifo_full, fifo_empty);
    endfunction
/*
    //-------------------------------------------------------------------------
    // copy() – return a deep copy of this transaction
    //-------------------------------------------------------------------------
    function fifo_transaction #(FIFO_WIDTH) copy();
        fifo_transaction #(FIFO_WIDTH) t = new();
        t.wr_en      = this.wr_en;
        t.rd_en      = this.rd_en;
        t.data       = this.data;
        t.data_out   = this.data_out;
        t.fifo_full  = this.fifo_full;
        t.fifo_empty = this.fifo_empty;
        t.txn_type   = this.txn_type;
        return t;
    endfunction
*/
endclass : fifo_transaction

//-----------------------------------------------------------------------------
// Class : fifo_txn_log  (static)
// Shared timestamp log so the scoreboard can display driver-side times
// in the grouped transaction view.  Driver pushes times here; scoreboard
// pops them in FIFO order when printing each grouped block.
//-----------------------------------------------------------------------------
class fifo_txn_log;
    static time wr_drv_times[$];   // write-driver timestamps, in order
    static time rd_drv_times[$];   // read-driver  timestamps, in order
endclass

`endif // FIFO_TRANSACTION_SV
