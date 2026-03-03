`ifndef TEST_FIFO_DEPTH_BOUNDARY_SV
`define TEST_FIFO_DEPTH_BOUNDARY_SV
`timescale 1ns/1ps

class test_fifo_depth_boundary #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        int fail_cnt = 0;
        $display("[TEST_DEPTH_BND] Interleaved operations at the full boundary...");

        // Write DEPTH-1 (almost full)
        write_n(FIFO_DEPTH - 1);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);

        if (vif.fifo_full) begin
            $display("[TEST_DEPTH_BND] FAIL: fifo_full asserted at DEPTH-1");
            fail_cnt++;
        end

        // Read 1 (make space: now DEPTH-2 entries)
        read_n(1);
        wait_drain(3000);

        // Write 2 more (should fill to DEPTH-1 again, then DEPTH = full)
        write_n(2);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);

        if (!vif.fifo_full) begin
            $display("[TEST_DEPTH_BND] FAIL: fifo_full not asserted after interleaved fill");
            fail_cnt++;
        end else begin
            $display("[TEST_DEPTH_BND] PASS: fifo_full asserted correctly after interleaved ops");
        end

        // Drain all remaining: DEPTH-1 + 2 - 1 = DEPTH entries
        read_n(FIFO_DEPTH);
        wait_drain(5000);

        if (fail_cnt == 0) $display("[TEST_DEPTH_BND] All checks passed.");
        else                $display("[TEST_DEPTH_BND] ** %0d check(s) FAILED **", fail_cnt);
        $display("[TEST_DEPTH_BND] Done.");
    endtask

endclass
`endif
