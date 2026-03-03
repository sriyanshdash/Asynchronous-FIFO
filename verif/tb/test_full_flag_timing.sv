`ifndef TEST_FULL_FLAG_TIMING_SV
`define TEST_FULL_FLAG_TIMING_SV
`timescale 1ns/1ps

class test_full_flag_timing #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        int fail_cnt = 0;
        $display("[TEST_FULL_FLAG] Write one-by-one, check fifo_full after each...");

        for (int i = 1; i <= FIFO_DEPTH; i++) begin
            write_n(1);
            wait_drain(3000);
            // Allow CDC sync latency for full flag
            repeat (6) @(posedge vif.wrclk);

            if (i < FIFO_DEPTH) begin
                if (vif.fifo_full) begin
                    $display("[TEST_FULL_FLAG] FAIL: fifo_full asserted early at entry %0d/%0d", i, FIFO_DEPTH);
                    fail_cnt++;
                end
            end else begin
                if (!vif.fifo_full) begin
                    $display("[TEST_FULL_FLAG] FAIL: fifo_full not asserted at entry %0d/%0d", i, FIFO_DEPTH);
                    fail_cnt++;
                end else begin
                    $display("[TEST_FULL_FLAG] PASS: fifo_full asserted at exactly FIFO_DEPTH=%0d", FIFO_DEPTH);
                end
            end
        end

        // Read 1 entry — fifo_full should deassert
        read_n(1);
        wait_drain(3000);
        repeat (6) @(posedge vif.wrclk);
        if (vif.fifo_full) begin
            $display("[TEST_FULL_FLAG] FAIL: fifo_full still asserted after 1 read");
            fail_cnt++;
        end else begin
            $display("[TEST_FULL_FLAG] PASS: fifo_full deasserted after 1 read");
        end

        // Drain remaining
        read_n(FIFO_DEPTH - 1);
        wait_drain(5000);

        if (fail_cnt == 0) $display("[TEST_FULL_FLAG] All checks passed.");
        else                $display("[TEST_FULL_FLAG] ** %0d check(s) FAILED **", fail_cnt);
        $display("[TEST_FULL_FLAG] Done.");
    endtask

endclass
`endif
