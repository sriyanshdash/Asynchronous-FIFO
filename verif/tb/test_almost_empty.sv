`ifndef TEST_ALMOST_EMPTY_SV
`define TEST_ALMOST_EMPTY_SV
`timescale 1ns/1ps

class test_almost_empty #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        int fail_cnt = 0;
        $display("[TEST_ALMOST_EMPTY] Fill, drain to 1 left, check NOT empty, read last...");

        // Fill and drain to 1 remaining
        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH - 1);
        wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);

        if (vif.fifo_empty) begin
            $display("[TEST_ALMOST_EMPTY] FAIL: fifo_empty asserted with 1 entry left");
            fail_cnt++;
        end else begin
            $display("[TEST_ALMOST_EMPTY] PASS: fifo_empty NOT asserted with 1 entry left");
        end

        // Read the last entry
        read_n(1);
        wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);

        if (!vif.fifo_empty) begin
            $display("[TEST_ALMOST_EMPTY] FAIL: fifo_empty not asserted after last read");
            fail_cnt++;
        end else begin
            $display("[TEST_ALMOST_EMPTY] PASS: fifo_empty asserted after last read");
        end

        if (fail_cnt == 0) $display("[TEST_ALMOST_EMPTY] All checks passed.");
        else                $display("[TEST_ALMOST_EMPTY] ** %0d check(s) FAILED **", fail_cnt);
        $display("[TEST_ALMOST_EMPTY] Done.");
    endtask

endclass
`endif
