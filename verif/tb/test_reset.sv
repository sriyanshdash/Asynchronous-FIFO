//=============================================================================
// File        : test_reset.sv
// Description : Test reset behavior:
//               1. Fill FIFO with data
//               2. Assert reset mid-operation
//               3. Verify fifo_empty=1, fifo_full=0 after reset
//               4. Write new data, read it back – verify FIFO recovers cleanly
//=============================================================================

`ifndef TEST_RESET_SV
`define TEST_RESET_SV

`timescale 1ns/1ps

class test_reset #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    int local_fail;

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
        local_fail = 0;
    endfunction

    virtual task run();
        $display("");
        $display("[TEST_RESET] Starting reset-with-data test...");

        // Phase 1: Write some data into the FIFO
        $display("[TEST_RESET] Phase 1: Writing %0d entries...", FIFO_DEPTH / 2);
        write_n(FIFO_DEPTH / 2);
        wait_drain(5000);

        // Phase 2: Assert reset while FIFO has data
        $display("[TEST_RESET] Phase 2: Asserting reset while FIFO contains data...");
        vif.wr_en   = 1'b0;
        vif.rd_en   = 1'b0;
        vif.data_in = '0;
        vif.wrst_n  = 1'b0;
        vif.rrst_n  = 1'b0;
        repeat (5) @(posedge vif.wrclk);

        // Phase 3: Check flags during reset
        if (vif.fifo_full) begin
            $display("[TEST_RESET] FAIL: fifo_full should be 0 during reset");
            local_fail++;
        end else begin
            $display("[TEST_RESET] PASS: fifo_full=0 during reset");
        end

        if (!vif.fifo_empty) begin
            $display("[TEST_RESET] FAIL: fifo_empty should be 1 during reset");
            local_fail++;
        end else begin
            $display("[TEST_RESET] PASS: fifo_empty=1 during reset");
        end

        // Phase 4: Deassert reset
        @(posedge vif.wrclk); #1;
        vif.wrst_n = 1'b1;
        vif.rrst_n = 1'b1;
        @(posedge vif.wrclk); #1;
        $display("[TEST_RESET] Reset deasserted.");

        // Clear scoreboard state – the old writes are gone (DUT was reset)
        env.reset();

        // Phase 5: Verify FIFO works after reset
        // The old data should be gone. Write fresh data and read it back.
        $display("[TEST_RESET] Phase 5: Writing %0d fresh entries after reset...", FIFO_DEPTH);
        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH);
        wait_drain(10000);

        // Check fifo_empty after full drain
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) begin
            $display("[TEST_RESET] FAIL: fifo_empty not asserted after post-reset drain");
            local_fail++;
        end else begin
            $display("[TEST_RESET] PASS: fifo_empty asserted after post-reset drain");
        end

        if (local_fail > 0)
            $display("[TEST_RESET] ** %0d check(s) FAILED **", local_fail);
        else
            $display("[TEST_RESET] All checks passed.");
        $display("[TEST_RESET] Done.");
    endtask

endclass : test_reset

`endif // TEST_RESET_SV