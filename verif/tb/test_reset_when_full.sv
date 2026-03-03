`ifndef TEST_RESET_WHEN_FULL_SV
`define TEST_RESET_WHEN_FULL_SV
`timescale 1ns/1ps

class test_reset_when_full #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        $display("[TEST_RST_FULL] Fill FIFO to full, then assert reset...");

        // Fill to capacity
        write_n(FIFO_DEPTH);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);

        if (!vif.fifo_full)
            $display("[TEST_RST_FULL] WARNING: FIFO not full before reset");

        // Assert reset while full
        reset_dut();
        env.reset();

        // After reset, FIFO must be empty
        if (!vif.fifo_empty)
            $display("[TEST_RST_FULL] FAIL: fifo_empty should be 1 after reset");
        else
            $display("[TEST_RST_FULL] PASS: fifo_empty=1 after reset");

        if (vif.fifo_full)
            $display("[TEST_RST_FULL] FAIL: fifo_full should be 0 after reset");
        else
            $display("[TEST_RST_FULL] PASS: fifo_full=0 after reset");

        // Write fresh data and read back — old data must be gone
        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH);
        wait_drain(5000);

        $display("[TEST_RST_FULL] Done.");
    endtask

endclass
`endif
