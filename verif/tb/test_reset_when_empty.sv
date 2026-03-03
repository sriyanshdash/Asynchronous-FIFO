`ifndef TEST_RESET_WHEN_EMPTY_SV
`define TEST_RESET_WHEN_EMPTY_SV
`timescale 1ns/1ps

class test_reset_when_empty #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        $display("[TEST_RST_EMPTY] Assert reset on an already-empty FIFO...");

        // FIFO starts empty after initial reset. Assert reset again.
        reset_dut();

        // Check flags
        if (!vif.fifo_empty)
            $display("[TEST_RST_EMPTY] FAIL: fifo_empty should be 1 after reset");
        else
            $display("[TEST_RST_EMPTY] PASS: fifo_empty=1 after reset");

        if (vif.fifo_full)
            $display("[TEST_RST_EMPTY] FAIL: fifo_full should be 0 after reset");
        else
            $display("[TEST_RST_EMPTY] PASS: fifo_full=0 after reset");

        // Clear scoreboard (reset_dut doesn't clear env)
        env.reset();

        // Verify FIFO still works
        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH);
        wait_drain(5000);

        $display("[TEST_RST_EMPTY] Done.");
    endtask

endclass
`endif
