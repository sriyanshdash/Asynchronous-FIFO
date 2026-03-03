`ifndef TEST_ALMOST_FULL_SV
`define TEST_ALMOST_FULL_SV
`timescale 1ns/1ps

class test_almost_full #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        int fail_cnt = 0;
        $display("[TEST_ALMOST_FULL] Write DEPTH-1, check NOT full, write 1 more, check full...");

        // Write DEPTH-1 entries
        write_n(FIFO_DEPTH - 1);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);

        if (vif.fifo_full) begin
            $display("[TEST_ALMOST_FULL] FAIL: fifo_full asserted at DEPTH-1");
            fail_cnt++;
        end else begin
            $display("[TEST_ALMOST_FULL] PASS: fifo_full NOT asserted at DEPTH-1");
        end

        // Write 1 more — now it should be full
        write_n(1);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);

        if (!vif.fifo_full) begin
            $display("[TEST_ALMOST_FULL] FAIL: fifo_full not asserted at DEPTH");
            fail_cnt++;
        end else begin
            $display("[TEST_ALMOST_FULL] PASS: fifo_full asserted at exactly DEPTH");
        end

        // Drain
        read_n(FIFO_DEPTH);
        wait_drain(5000);

        if (fail_cnt == 0) $display("[TEST_ALMOST_FULL] All checks passed.");
        else                $display("[TEST_ALMOST_FULL] ** %0d check(s) FAILED **", fail_cnt);
        $display("[TEST_ALMOST_FULL] Done.");
    endtask

endclass
`endif
