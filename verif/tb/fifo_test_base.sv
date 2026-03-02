//=============================================================================
// File        : fifo_test_base.sv
// Description : Base test class with reusable helper tasks for all FIFO tests.
//               Provides write_n(), read_n(), write_data(), wait_drain(),
//               reset_dut(), and reset_phase() utilities.
//=============================================================================

`ifndef FIFO_TEST_BASE_SV
`define FIFO_TEST_BASE_SV

`timescale 1ns/1ps

`include "fifo_env.sv"

class fifo_test_base #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
);

    //-------------------------------------------------------------------------
    // Handles
    //-------------------------------------------------------------------------
    fifo_env #(FIFO_WIDTH) env;
    virtual fifo_if #(FIFO_WIDTH) vif;

    //-------------------------------------------------------------------------
    // Constructor
    //-------------------------------------------------------------------------
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        this.vif = vif;
        this.env = env;
    endfunction

    //-------------------------------------------------------------------------
    // write_n() – queue N write transactions with random data
    //-------------------------------------------------------------------------
    task write_n(int n);
        fifo_transaction #(FIFO_WIDTH) txn;
        repeat (n) begin
            txn = new();
            if (!txn.randomize() with { wr_en == 1'b1; rd_en == 1'b0; })
                $fatal(1, "[TEST_BASE] Randomize failed for write transaction");
            txn.txn_type = FIFO_WRITE;
            env.wr_mbx.put(txn);
        end
    endtask

    //-------------------------------------------------------------------------
    // read_n() – queue N read transactions
    //-------------------------------------------------------------------------
    task read_n(int n);
        fifo_transaction #(FIFO_WIDTH) txn;
        repeat (n) begin
            txn          = new();
            txn.wr_en    = 1'b0;
            txn.rd_en    = 1'b1;
            txn.txn_type = FIFO_READ;
            env.rd_mbx.put(txn);
        end
    endtask

    //-------------------------------------------------------------------------
    // write_data() – queue a write with a specific data value
    //-------------------------------------------------------------------------
    task write_data(bit [FIFO_WIDTH-1:0] data);
        fifo_transaction #(FIFO_WIDTH) txn;
        txn          = new();
        txn.wr_en    = 1'b1;
        txn.rd_en    = 1'b0;
        txn.data     = data;
        txn.txn_type = FIFO_WRITE;
        env.wr_mbx.put(txn);
    endtask

    //-------------------------------------------------------------------------
    // wait_drain() – wait until both driver mailboxes are empty, with timeout
    //   Also waits extra cycles for the monitor/scoreboard pipeline to flush.
    //-------------------------------------------------------------------------
    task wait_drain(int timeout_ns = 5000);
        fork
            begin
                // Wait for mailboxes to empty
                wait (env.wr_mbx.num() == 0 && env.rd_mbx.num() == 0);
                // Extra settling time for driver to finish its current transaction,
                // monitor pipeline (1-cycle data_out delay), and CDC sync latency
                repeat (20) @(posedge vif.wrclk);
                repeat (20) @(posedge vif.rdclk);
            end
            begin
                #(timeout_ns * 1ns);
                $display("[TEST_BASE] WARNING: wait_drain timed out after %0d ns", timeout_ns);
            end
        join_any
        disable fork;
    endtask

    //-------------------------------------------------------------------------
    // reset_dut() – assert reset, hold for 5 wrclk cycles, deassert
    //-------------------------------------------------------------------------
    task reset_dut();
        vif.wr_en   = 1'b0;
        vif.rd_en   = 1'b0;
        vif.data_in = '0;
        vif.wrst_n  = 1'b0;
        vif.rrst_n  = 1'b0;
        repeat (5) @(posedge vif.wrclk);
        @(posedge vif.wrclk); #1;
        vif.wrst_n = 1'b1;
        vif.rrst_n = 1'b1;
        // Allow DUT to settle after reset
        @(posedge vif.wrclk); #1;
    endtask

    //-------------------------------------------------------------------------
    // reset_phase() – reset DUT + clear env/scoreboard state between tests
    //-------------------------------------------------------------------------
    task reset_phase();
        reset_dut();
        env.reset();
    endtask

endclass : fifo_test_base

`endif // FIFO_TEST_BASE_SV
