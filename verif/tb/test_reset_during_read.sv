`ifndef TEST_RESET_DURING_READ_SV
`define TEST_RESET_DURING_READ_SV
`timescale 1ns/1ps

class test_reset_during_read #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        $display("[TEST_RST_RD] Write data, start read, assert reset mid-read...");

        // Write a few entries
        write_n(4);
        wait_drain(5000);

        // Start a read via direct VIF
        @(posedge vif.rdclk); #1;
        vif.rd_en = 1'b1;
        @(posedge vif.rdclk); #1;

        // Assert reset while rd_en=1
        vif.wrst_n = 1'b0;
        vif.rrst_n = 1'b0;
        repeat (5) @(posedge vif.wrclk);

        // Deassert everything
        @(posedge vif.wrclk); #1;
        vif.rd_en  = 1'b0;
        vif.wrst_n = 1'b1;
        vif.rrst_n = 1'b1;
        @(posedge vif.wrclk); #1;

        env.reset();

        if (!vif.fifo_empty)
            $display("[TEST_RST_RD] FAIL: fifo_empty should be 1 after reset");
        else
            $display("[TEST_RST_RD] PASS: fifo_empty=1 after reset");

        // Verify FIFO works after mid-read reset
        write_n(4);
        read_n(4);
        wait_drain(5000);

        $display("[TEST_RST_RD] Done.");
    endtask

endclass
`endif
