//=============================================================================
// File        : test_overflow_underflow.sv
// Description : Tests that the FIFO correctly ignores:
//               - Writes when fifo_full  (overflow protection)
//               - Reads  when fifo_empty (underflow protection)
//               Uses direct VIF driving to bypass the driver's built-in
//               full/empty waiting logic.
//=============================================================================

`ifndef TEST_OVERFLOW_UNDERFLOW_SV
`define TEST_OVERFLOW_UNDERFLOW_SV

`timescale 1ns/1ps

class test_overflow_underflow #(
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
        $display("[TEST_OVF_UNF] Starting overflow/underflow test...");

        test_overflow();
        test_underflow();

        if (local_fail > 0)
            $display("[TEST_OVF_UNF] ** %0d check(s) FAILED **", local_fail);
        else
            $display("[TEST_OVF_UNF] All checks passed.");
        $display("[TEST_OVF_UNF] Done.");
    endtask

    //=========================================================================
    // Overflow test: fill FIFO, force an extra write, verify it's ignored
    //=========================================================================
    task test_overflow();
        bit [FIFO_WIDTH-1:0] overflow_data;
        int wait_cycles;

        $display("[TEST_OVF_UNF] --- Overflow Test ---");

        // Fill the FIFO to capacity using the normal driver
        write_n(FIFO_DEPTH);

        // Poll for fifo_full directly (reliable, unlike wait on mailbox.num())
        wait_cycles = 0;
        while (!vif.fifo_full && wait_cycles < 5000) begin
            @(posedge vif.wrclk);
            wait_cycles++;
        end

        if (!vif.fifo_full) begin
            $display("[TEST_OVF_UNF] FAIL: FIFO not full after %0d writes (cannot test overflow)", FIFO_DEPTH);
            local_fail++;
            return;
        end

        // Force an extra write directly via VIF while fifo_full=1
        overflow_data = {FIFO_WIDTH{1'b1}};  // all-ones pattern (easy to spot)
        $display("[TEST_OVF_UNF] Forcing write of 0x%016h while fifo_full=1...", overflow_data);
        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1'b1;
        vif.data_in = overflow_data;
        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1'b0;
        vif.data_in = '0;

        // Now read back exactly FIFO_DEPTH entries
        // The scoreboard already has FIFO_DEPTH entries in ref_q from the writes above.
        // If the overflow write was correctly ignored, all FIFO_DEPTH reads should match.
        // If it wasn't ignored, data would be corrupted.
        read_n(FIFO_DEPTH);

        // Poll for fifo_empty to confirm all reads completed
        wait_cycles = 0;
        while (!vif.fifo_empty && wait_cycles < 5000) begin
            @(posedge vif.rdclk);
            wait_cycles++;
        end

        // Settling time for monitor/scoreboard pipeline to flush
        repeat (20) @(posedge vif.wrclk);
        repeat (20) @(posedge vif.rdclk);

        $display("[TEST_OVF_UNF] Overflow test complete (scoreboard checks data integrity).");
    endtask

    //=========================================================================
    // Underflow test: empty FIFO, force a read, verify no spurious data
    //=========================================================================
    task test_underflow();
        int wait_cycles;

        $display("[TEST_OVF_UNF] --- Underflow Test ---");

        // FIFO should be empty after the overflow test reads drained it.
        // Poll for fifo_empty to assert (CDC latency)
        wait_cycles = 0;
        while (!vif.fifo_empty && wait_cycles < 5000) begin
            @(posedge vif.rdclk);
            wait_cycles++;
        end

        if (!vif.fifo_empty) begin
            $display("[TEST_OVF_UNF] FAIL: FIFO not empty before underflow test");
            local_fail++;
            return;
        end

        // Force a read directly via VIF while fifo_empty=1
        $display("[TEST_OVF_UNF] Forcing rd_en=1 while fifo_empty=1...");
        @(posedge vif.rdclk); #1;
        vif.rd_en = 1'b1;
        @(posedge vif.rdclk); #1;
        vif.rd_en = 1'b0;

        // Wait a few cycles – the monitor should NOT produce a transaction
        // because rd_en=1 with fifo_empty=1 is not a valid read.
        repeat (4) @(posedge vif.rdclk);

        // Verify FIFO is still functional: write 1 value, read it back
        $display("[TEST_OVF_UNF] Verifying FIFO still works after underflow attempt...");
        write_n(1);
        read_n(1);
        wait_drain(5000);

        // Extra settling time for monitor/scoreboard pipeline
        repeat (20) @(posedge vif.wrclk);
        repeat (20) @(posedge vif.rdclk);

        $display("[TEST_OVF_UNF] Underflow test complete.");
    endtask

endclass : test_overflow_underflow

`endif // TEST_OVERFLOW_UNDERFLOW_SV