//=============================================================================
// File        : fifo_test.sv
// Description : Basic directed-random test for the Async FIFO.
//
//               Test sequence:
//               1. Start the environment (driver / monitor / scoreboard).
//               2. Push NUM_TXNS WRITE transactions into the driver mailbox.
//               3. Push NUM_TXNS READ  transactions into the driver mailbox.
//               4. Both driver threads consume their mailboxes concurrently:
//                   - Write driver stalls when fifo_full, resumes when space.
//                   - Read  driver stalls when fifo_empty, resumes when data.
//               5. Wait a generous timeout, print the scoreboard report, finish.
//=============================================================================

`ifndef FIFO_TEST_SV
`define FIFO_TEST_SV

`timescale 1ns/1ps

`include "fifo_env.sv"

class fifo_test #(
    parameter FIFO_WIDTH = 64,
    parameter NUM_TXNS   = 20   // number of write AND read transactions each
);

    //-------------------------------------------------------------------------
    // Handles
    //-------------------------------------------------------------------------
    fifo_env    #(FIFO_WIDTH) env;
    virtual fifo_if #(FIFO_WIDTH) vif;

    //-------------------------------------------------------------------------
    // Constructor
    //-------------------------------------------------------------------------
    function new(virtual fifo_if #(FIFO_WIDTH) vif);
        this.vif = vif;
        env      = new(vif);
    endfunction

    //-------------------------------------------------------------------------
    // run() – top-level test task
    //-------------------------------------------------------------------------
    task run();
        fifo_transaction #(FIFO_WIDTH) txn;

        $display("");
        $display("[TEST] ============================================");
        $display("[TEST]   Async FIFO – Basic Functional Test START  ");
        $display("[TEST]   WIDTH=%0d  NUM_TXNS=%0d", FIFO_WIDTH, NUM_TXNS);
        $display("[TEST] ============================================");

        // Start driver / monitor / scoreboard background threads
        env.run();

        //---------------------------------------------------------------------
        // Phase 1 : generate WRITE transactions
        // Each transaction has wr_en=1, rd_en=0, randomised data.
        //---------------------------------------------------------------------
        $display("[TEST] Phase 1: Generating %0d WRITE transactions...", NUM_TXNS);
        repeat(NUM_TXNS) begin
            txn = new();
            if (!txn.randomize() with { wr_en == 1'b1; rd_en == 1'b0; })
                $fatal(1, "[TEST] Randomize failed for write transaction");
            txn.txn_type = FIFO_WRITE;
            env.wr_mbx.put(txn);  // non-blocking put into unbounded mailbox
        end
        $display("[TEST] All WRITE transactions queued.");

        //---------------------------------------------------------------------
        // Phase 2 : generate READ transactions
        // rd_en=1, wr_en=0.  Data field is irrelevant for reads.
        //---------------------------------------------------------------------
        $display("[TEST] Phase 2: Generating %0d READ transactions...", NUM_TXNS);
        repeat(NUM_TXNS) begin
            txn          = new();
            txn.wr_en    = 1'b0;
            txn.rd_en    = 1'b1;
            txn.txn_type = FIFO_READ;
            env.rd_mbx.put(txn);
        end
        $display("[TEST] All READ transactions queued.");

        //---------------------------------------------------------------------
        // Phase 3 : Wait for all transactions to be processed.
        //
        // Worst-case drain estimate:
        //   20 writes  × 2 wrclk cycles × 10 ns  =  400 ns
        //   20 reads   × 2 rdclk cycles × 13 ns  =  520 ns
        //   CDC sync overhead (~4 × 13 ns)        =   52 ns
        //   Safety margin ×10                     → 10000 ns
        //---------------------------------------------------------------------
        $display("[TEST] Waiting for transactions to drain (10000 ns)...");
        #10000;

        //---------------------------------------------------------------------
        // Phase 4 : Report and finish
        //---------------------------------------------------------------------
        env.scb.report();
        $display("[TEST] ============================================");
        $display("[TEST]   Async FIFO – Basic Functional Test END    ");
        $display("[TEST] ============================================");
        $display("");
        $finish;
    endtask

endclass : fifo_test

`endif // FIFO_TEST_SV
