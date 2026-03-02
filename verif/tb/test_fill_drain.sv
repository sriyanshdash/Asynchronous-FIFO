//=============================================================================
// File        : test_fill_drain.sv
// Description : Fill the FIFO to exactly FIFO_DEPTH, check fifo_full asserts,
//               drain it completely, check fifo_empty asserts.
//               Repeats a second time to exercise pointer wrap-around.
//=============================================================================

`ifndef TEST_FILL_DRAIN_SV
`define TEST_FILL_DRAIN_SV

`timescale 1ns/1ps

class test_fill_drain #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
);

    fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH) base;
    int local_fail;

    function new(fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH) base);
        this.base = base;
        local_fail = 0;
    endfunction

    task run();
        $display("");
        $display("[TEST_FILL_DRAIN] Starting fill/drain test (2 cycles)...");

        // --- Cycle 1 ---
        $display("[TEST_FILL_DRAIN] Cycle 1: Writing %0d entries (fill)...", FIFO_DEPTH);
        base.write_n(FIFO_DEPTH);
        base.wait_drain(5000);

        // Check fifo_full after all writes are consumed
        // Allow CDC latency for flag to propagate
        repeat (6) @(posedge base.vif.wrclk);
        if (!base.vif.fifo_full) begin
            $display("[TEST_FILL_DRAIN] FAIL: fifo_full not asserted after %0d writes", FIFO_DEPTH);
            local_fail++;
        end else begin
            $display("[TEST_FILL_DRAIN] PASS: fifo_full asserted as expected");
        end

        $display("[TEST_FILL_DRAIN] Cycle 1: Reading %0d entries (drain)...", FIFO_DEPTH);
        base.read_n(FIFO_DEPTH);
        base.wait_drain(5000);

        // Check fifo_empty after all reads are consumed
        repeat (6) @(posedge base.vif.rdclk);
        if (!base.vif.fifo_empty) begin
            $display("[TEST_FILL_DRAIN] FAIL: fifo_empty not asserted after drain");
            local_fail++;
        end else begin
            $display("[TEST_FILL_DRAIN] PASS: fifo_empty asserted as expected");
        end

        // --- Cycle 2 (pointer wrap-around) ---
        $display("[TEST_FILL_DRAIN] Cycle 2: Fill/drain again (pointers wrap around)...");
        base.write_n(FIFO_DEPTH);
        base.wait_drain(5000);

        repeat (6) @(posedge base.vif.wrclk);
        if (!base.vif.fifo_full) begin
            $display("[TEST_FILL_DRAIN] FAIL: fifo_full not asserted on 2nd fill");
            local_fail++;
        end else begin
            $display("[TEST_FILL_DRAIN] PASS: fifo_full asserted on 2nd fill");
        end

        base.read_n(FIFO_DEPTH);
        base.wait_drain(5000);

        repeat (6) @(posedge base.vif.rdclk);
        if (!base.vif.fifo_empty) begin
            $display("[TEST_FILL_DRAIN] FAIL: fifo_empty not asserted on 2nd drain");
            local_fail++;
        end else begin
            $display("[TEST_FILL_DRAIN] PASS: fifo_empty asserted on 2nd drain");
        end

        if (local_fail > 0)
            $display("[TEST_FILL_DRAIN] ** %0d flag check(s) FAILED **", local_fail);
        else
            $display("[TEST_FILL_DRAIN] All flag checks passed.");
        $display("[TEST_FILL_DRAIN] Done.");
    endtask

endclass : test_fill_drain

`endif // TEST_FILL_DRAIN_SV
