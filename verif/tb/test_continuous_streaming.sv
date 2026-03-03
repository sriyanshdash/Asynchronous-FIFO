`ifndef TEST_CONTINUOUS_STREAMING_SV
`define TEST_CONTINUOUS_STREAMING_SV
`timescale 1ns/1ps

class test_continuous_streaming #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        int num_txns = 100;
        $display("[TEST_STREAM] Continuous streaming: %0d write+read pairs concurrently...", num_txns);

        // Half-fill first so neither side stalls immediately
        write_n(FIFO_DEPTH / 2);
        wait_drain(3000);

        // Stream both sides concurrently
        fork
            write_n(num_txns);
            read_n((FIFO_DEPTH / 2) + num_txns);
        join

        wait_drain(20000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[TEST_STREAM] FAIL: fifo_empty not asserted after streaming");
        else
            $display("[TEST_STREAM] PASS: fifo_empty asserted after %0d transactions", num_txns);

        $display("[TEST_STREAM] Done.");
    endtask

endclass
`endif
