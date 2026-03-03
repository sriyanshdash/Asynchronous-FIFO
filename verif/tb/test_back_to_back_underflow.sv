`ifndef TEST_BACK_TO_BACK_UNDERFLOW_SV
`define TEST_BACK_TO_BACK_UNDERFLOW_SV
`timescale 1ns/1ps

class test_back_to_back_underflow #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        $display("[TEST_B2B_UNF] Force 10 consecutive reads while empty...");

        // FIFO starts empty. Hold rd_en high for 10 cycles.
        @(posedge vif.rdclk); #1;
        vif.rd_en = 1'b1;
        repeat (10) @(posedge vif.rdclk);
        #1;
        vif.rd_en = 1'b0;

        repeat (4) @(posedge vif.rdclk);

        // Verify pointer integrity: write 1, read 1
        write_n(1);
        read_n(1);
        wait_drain(5000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[TEST_B2B_UNF] FAIL: fifo_empty not asserted (pointer corrupted?)");
        else
            $display("[TEST_B2B_UNF] PASS: pointer intact after 10 underflow reads");

        $display("[TEST_B2B_UNF] Done.");
    endtask

endclass
`endif
