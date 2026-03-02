//=============================================================================
// File        : test_pointer_wrap.sv
// Description : Stress-test pointer wrap-around by performing multiple
//               complete fill-drain cycles (3 x FIFO_DEPTH).
//               This forces the (PTR_WIDTH+1)-bit Gray code pointers to
//               wrap around multiple times, verifying the MSB-based
//               full/empty detection logic across wrap boundaries.
//=============================================================================

`ifndef TEST_POINTER_WRAP_SV
`define TEST_POINTER_WRAP_SV

`timescale 1ns/1ps

class test_pointer_wrap #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
);

    fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH) base;
    localparam NUM_CYCLES = 3;

    function new(fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH) base);
        this.base = base;
    endfunction

    task run();
        int cycle;
        $display("");
        $display("[TEST_PTR_WRAP] Starting pointer wrap test (%0d fill-drain cycles)...", NUM_CYCLES);

        for (cycle = 1; cycle <= NUM_CYCLES; cycle++) begin
            $display("[TEST_PTR_WRAP] Cycle %0d/%0d: writing %0d, reading %0d...",
                     cycle, NUM_CYCLES, FIFO_DEPTH, FIFO_DEPTH);

            base.write_n(FIFO_DEPTH);
            base.read_n(FIFO_DEPTH);
            base.wait_drain(5000);
        end

        // Final check: FIFO should be empty
        repeat (6) @(posedge base.vif.rdclk);
        if (!base.vif.fifo_empty)
            $display("[TEST_PTR_WRAP] FAIL: fifo_empty not asserted after %0d cycles", NUM_CYCLES);
        else
            $display("[TEST_PTR_WRAP] PASS: fifo_empty asserted after all cycles");

        $display("[TEST_PTR_WRAP] Done.");
    endtask

endclass : test_pointer_wrap

`endif // TEST_POINTER_WRAP_SV
