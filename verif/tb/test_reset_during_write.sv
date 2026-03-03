`ifndef TEST_RESET_DURING_WRITE_SV
`define TEST_RESET_DURING_WRITE_SV
`timescale 1ns/1ps

class test_reset_during_write #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        $display("[TEST_RST_WR] Assert reset while wr_en is active...");

        // Start a write via direct VIF
        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1'b1;
        vif.data_in = 64'hDEAD_BEEF_CAFE_BABE;

        // Assert reset while wr_en=1
        @(posedge vif.wrclk); #1;
        vif.wrst_n = 1'b0;
        vif.rrst_n = 1'b0;
        repeat (5) @(posedge vif.wrclk);

        // Deassert everything
        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1'b0;
        vif.data_in = '0;
        vif.wrst_n  = 1'b1;
        vif.rrst_n  = 1'b1;
        @(posedge vif.wrclk); #1;

        env.reset();

        // Verify clean state
        if (!vif.fifo_empty)
            $display("[TEST_RST_WR] FAIL: fifo_empty should be 1 after reset");
        else
            $display("[TEST_RST_WR] PASS: fifo_empty=1 after reset");

        // Verify FIFO works after mid-write reset
        write_n(4);
        read_n(4);
        wait_drain(5000);

        $display("[TEST_RST_WR] Done.");
    endtask

endclass
`endif
