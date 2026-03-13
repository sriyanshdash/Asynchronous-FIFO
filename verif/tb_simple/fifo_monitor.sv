// =============================================================================
// File        : fifo_monitor.sv
// Description : Monitor — observes DUT signals and sends observed transactions
//               to the scoreboard for checking.
//
//               Two independent always-running tasks:
//                 monitor_write() — watches write-domain (wrclk)
//                 monitor_read()  — watches read-domain  (rdclk)
//
//               KEY DETAIL: The DUT has a REGISTERED data_out, meaning:
//                 Cycle N  : rd_en=1 & fifo_empty=0  → valid read request
//                 Cycle N+1: data_out has the read data ← capture HERE
//               We use a flag (rd_was_valid) to handle this 1-cycle delay.
// =============================================================================

`ifndef FIFO_MONITOR_SIMPLE_SV
`define FIFO_MONITOR_SIMPLE_SV

`timescale 1ns/1ps

class fifo_monitor #(parameter FIFO_WIDTH = 64);

    // Virtual interface — observe DUT signals
    virtual fifo_if #(FIFO_WIDTH) vif;

    // Mailboxes to scoreboard
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx;   // Write observations
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx;   // Read observations

    // Constructor
    function new(
        virtual fifo_if #(FIFO_WIDTH)             vif,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx
    );
        this.vif        = vif;
        this.wr_scb_mbx = wr_scb_mbx;
        this.rd_scb_mbx = rd_scb_mbx;
    endfunction

    // Start the monitor
    task run();
        fork
            monitor_write();
            monitor_read();
        join_none
    endtask

    // ---- Write Monitor (wrclk domain) ----
    // A valid write happens when: wr_en=1, fifo_full=0, and not in reset.
    // We capture the data_in value and send it to the scoreboard.
    task monitor_write();
        fifo_transaction #(FIFO_WIDTH) txn;

        forever begin
            @(posedge vif.wrclk);
            if (vif.wrst_n && vif.wr_en && !vif.fifo_full) begin
                txn              = new();
                txn.txn_type     = FIFO_WRITE;
                txn.wr_en        = vif.wr_en;
                txn.data         = vif.data_in;
                txn.fifo_full    = vif.fifo_full;
                txn.fifo_empty   = vif.fifo_empty;
                txn.capture_time = $time;
                wr_scb_mbx.put(txn);
            end
        end
    endtask

    // ---- Read Monitor (rdclk domain) ----
    // Because data_out is REGISTERED in the DUT:
    //   Cycle N   : rd_en=1 & fifo_empty=0 → we note "a valid read started"
    //   Cycle N+1 : data_out is now valid   → we capture it and send to scoreboard
    //
    // The flag rd_was_valid tracks whether the PREVIOUS cycle had a valid read.
    task monitor_read();
        fifo_transaction #(FIFO_WIDTH) txn;
        bit rd_was_valid = 0;

        forever begin
            @(posedge vif.rdclk);

            // If previous cycle was a valid read, data_out is stable now
            if (rd_was_valid) begin
                txn              = new();
                txn.txn_type     = FIFO_READ;
                txn.rd_en        = 1;
                txn.data_out     = vif.data_out;
                txn.fifo_full    = vif.fifo_full;
                txn.fifo_empty   = vif.fifo_empty;
                txn.capture_time = $time;
                rd_scb_mbx.put(txn);
            end

            // Was THIS cycle a valid read initiation?
            rd_was_valid = (vif.rrst_n && vif.rd_en && !vif.fifo_empty);
        end
    endtask

endclass : fifo_monitor

`endif
