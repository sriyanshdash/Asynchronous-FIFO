//=============================================================================
// File        : test_simultaneous_rw.sv
// Description : Test concurrent read and write operations.
//               Half-fills the FIFO, then queues writes and reads
//               simultaneously so both clock domains are active at once.
//=============================================================================

`ifndef TEST_SIMULTANEOUS_RW_SV
`define TEST_SIMULTANEOUS_RW_SV

`timescale 1ns/1ps

class test_simultaneous_rw #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        int half_depth;
        int concurrent_txns;

        half_depth      = FIFO_DEPTH / 2;
        concurrent_txns = FIFO_DEPTH * 2;

        $display("");
        $display("[TEST_SIM_RW] Starting simultaneous read/write test...");

        // Phase 1: Half-fill the FIFO
        $display("[TEST_SIM_RW] Phase 1: Writing %0d entries to half-fill...", half_depth);
        write_n(half_depth);
        wait_drain(5000);

        // Phase 2: Queue writes and reads at the same time
        // The FIFO is half-full, so both sides can run concurrently
        // without the write side hitting full or read side hitting empty immediately
        $display("[TEST_SIM_RW] Phase 2: Queuing %0d writes and %0d reads concurrently...",
                 concurrent_txns, half_depth + concurrent_txns);

        fork
            write_n(concurrent_txns);
            read_n(half_depth + concurrent_txns);
        join

        wait_drain(15000);

        $display("[TEST_SIM_RW] Done.");
    endtask

endclass : test_simultaneous_rw

`endif // TEST_SIMULTANEOUS_RW_SV