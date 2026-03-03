`ifndef TEST_SIMULTANEOUS_RESET_READ_SV
`define TEST_SIMULTANEOUS_RESET_READ_SV
`timescale 1ns/1ps

class test_simultaneous_reset_read #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        $display("[TEST_RST_SIM_RD] Write data, then assert reset and rd_en simultaneously...");

        // Put some data in
        write_n(4);
        wait_drain(5000);

        // Assert reset AND rd_en at the same time
        @(posedge vif.rdclk); #1;
        vif.wrst_n = 1'b0;
        vif.rrst_n = 1'b0;
        vif.rd_en  = 1'b1;

        repeat (5) @(posedge vif.wrclk);

        // Deassert
        @(posedge vif.wrclk); #1;
        vif.rd_en  = 1'b0;
        vif.wrst_n = 1'b1;
        vif.rrst_n = 1'b1;
        @(posedge vif.wrclk); #1;

        env.reset();

        // Reset should win — FIFO must be empty
        if (!vif.fifo_empty)
            $display("[TEST_RST_SIM_RD] FAIL: fifo_empty should be 1 (reset wins over read)");
        else
            $display("[TEST_RST_SIM_RD] PASS: fifo_empty=1, reset took priority");

        // Verify normal operation
        write_n(4);
        read_n(4);
        wait_drain(5000);

        $display("[TEST_RST_SIM_RD] Done.");
    endtask

endclass
`endif
