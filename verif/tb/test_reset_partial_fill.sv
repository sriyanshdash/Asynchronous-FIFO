`ifndef TEST_RESET_PARTIAL_FILL_SV
`define TEST_RESET_PARTIAL_FILL_SV
`timescale 1ns/1ps

class test_reset_partial_fill #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        $display("[TEST_RST_PARTIAL] Write partial data, reset, verify old data gone...");

        // Partially fill (not full, not empty)
        write_n(FIFO_DEPTH / 2);
        wait_drain(5000);

        // Reset
        reset_dut();
        env.reset();

        // Write new data — if old data leaked, scoreboard would catch mismatch
        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH);
        wait_drain(5000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[TEST_RST_PARTIAL] FAIL: fifo_empty not asserted after drain");
        else
            $display("[TEST_RST_PARTIAL] PASS: fifo_empty asserted, old data is gone");

        $display("[TEST_RST_PARTIAL] Done.");
    endtask

endclass
`endif
