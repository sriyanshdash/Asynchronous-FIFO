`ifndef TEST_READ_WHEN_EMPTY_POINTER_CHECK_SV
`define TEST_READ_WHEN_EMPTY_POINTER_CHECK_SV
`timescale 1ns/1ps

class test_read_when_empty_pointer_check #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        $display("[TEST_RD_EMPTY] Force multiple reads while empty, check pointer integrity...");

        // FIFO is empty. Force rd_en=1 for 5 consecutive cycles
        repeat (5) begin
            @(posedge vif.rdclk); #1;
            vif.rd_en = 1'b1;
        end
        @(posedge vif.rdclk); #1;
        vif.rd_en = 1'b0;

        repeat (4) @(posedge vif.rdclk);

        // Now do a normal write+read — if pointers were corrupted,
        // scoreboard will catch a mismatch
        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH);
        wait_drain(5000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[TEST_RD_EMPTY] FAIL: fifo_empty not asserted after normal drain");
        else
            $display("[TEST_RD_EMPTY] PASS: pointers intact after illegal reads");

        $display("[TEST_RD_EMPTY] Done.");
    endtask

endclass
`endif
