`ifndef TEST_BURST_WRITE_BURST_READ_SV
`define TEST_BURST_WRITE_BURST_READ_SV
`timescale 1ns/1ps

class test_burst_write_burst_read #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        $display("[TEST_BURST] Burst-write %0d, then burst-read %0d...", FIFO_DEPTH, FIFO_DEPTH);

        // Queue all writes at once — driver will hold wr_en high for the burst
        write_n(FIFO_DEPTH);
        wait_drain(5000);

        // Queue all reads at once — driver will hold rd_en high for the burst
        read_n(FIFO_DEPTH);
        wait_drain(5000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[TEST_BURST] FAIL: fifo_empty not asserted after burst drain");
        else
            $display("[TEST_BURST] PASS: fifo_empty asserted after burst drain");

        $display("[TEST_BURST] Done.");
    endtask

endclass
`endif
