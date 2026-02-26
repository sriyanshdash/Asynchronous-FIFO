//=============================================================================
// File        : fifo_monitor.sv
// Description : Monitor for the Async FIFO testbench.
//               Two independent tasks observe the write and read clock domains
//               and forward captured transactions to the scoreboard via mailboxes.
//
//               data_out latency note:
//               The DUT memory (fifo_memory.sv) has a REGISTERED output:
//                   always @(posedge rdclk) data_out <= fifo[b_rptr];
//               Therefore data_out is valid ONE rdclk cycle AFTER rd_en was
//               asserted with fifo_empty=0.  The monitor uses a one-cycle
//               delayed flag (rd_was_valid) to capture at the correct time.
//=============================================================================

`ifndef FIFO_MONITOR_SV
`define FIFO_MONITOR_SV

`timescale 1ns/1ps

`include "fifo_interface.sv"
`include "fifo_transaction.sv"

class fifo_monitor #(parameter FIFO_WIDTH = 64);

    //-------------------------------------------------------------------------
    // Virtual interface handle
    //-------------------------------------------------------------------------
    virtual fifo_if #(FIFO_WIDTH) vif;

    //-------------------------------------------------------------------------
    // Mailboxes to scoreboard
    //-------------------------------------------------------------------------
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx;  // write observations
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx;  // read  observations

    //-------------------------------------------------------------------------
    // Constructor
    //-------------------------------------------------------------------------
    function new(
        virtual fifo_if #(FIFO_WIDTH)             vif,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx
    );
        this.vif        = vif;
        this.wr_scb_mbx = wr_scb_mbx;
        this.rd_scb_mbx = rd_scb_mbx;
    endfunction

    //-------------------------------------------------------------------------
    // run() – launch both domain monitors in parallel background threads
    //-------------------------------------------------------------------------
    task run();
        $display("[MONITOR] Starting at %0t", $time);
        fork
            monitor_write();
            monitor_read();
        join_none
    endtask

    //=========================================================================
    // Write-domain monitor  (samples on posedge wrclk)
    // A transaction is captured when wr_en=1, fifo_full=0, and out of reset.
    //=========================================================================
    task monitor_write();
        fifo_transaction #(FIFO_WIDTH) txn;
        forever begin
            @(posedge vif.wrclk);
            if (vif.wrst_n && vif.wr_en && !vif.fifo_full) begin
                txn            = new();
                txn.txn_type   = FIFO_WRITE;
                txn.wr_en      = vif.wr_en;
                txn.data       = vif.data_in;
                txn.fifo_full  = vif.fifo_full;
                txn.fifo_empty = vif.fifo_empty;
                wr_scb_mbx.put(txn);
                txn.display("MON-WR");
            end
        end
    endtask

    //=========================================================================
    // Read-domain monitor  (samples on posedge rdclk)
    //
    // Because data_out is registered in the DUT, the flow is:
    //   Cycle N  : rd_en=1 & fifo_empty=0  → valid read request
    //   Cycle N+1: data_out holds the read data  ← capture here
    //
    // rd_was_valid tracks whether the previous cycle had a valid read request.
    //=========================================================================
    task monitor_read();
        fifo_transaction #(FIFO_WIDTH) txn;
        bit rd_was_valid;
        rd_was_valid = 1'b0;

        forever begin
            @(posedge vif.rdclk);

            // If the previous cycle was a valid read, data_out is stable now
            if (rd_was_valid) begin
                txn            = new();
                txn.txn_type   = FIFO_READ;
                txn.rd_en      = 1'b1;
                txn.data_out   = vif.data_out;
                txn.fifo_full  = vif.fifo_full;
                txn.fifo_empty = vif.fifo_empty;
                rd_scb_mbx.put(txn);
                txn.display("MON-RD");
            end

            // Update flag: was this clock cycle a valid read initiation?
            rd_was_valid = (vif.rrst_n && vif.rd_en && !vif.fifo_empty);
        end
    endtask

endclass : fifo_monitor

`endif // FIFO_MONITOR_SV
