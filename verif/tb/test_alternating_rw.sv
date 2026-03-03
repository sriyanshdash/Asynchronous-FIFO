`ifndef TEST_ALTERNATING_RW_SV
`define TEST_ALTERNATING_RW_SV
`timescale 1ns/1ps

class test_alternating_rw #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        int num_pairs = 20;
        $display("[TEST_ALT_RW] Alternating W-R-W-R for %0d pairs...", num_pairs);

        for (int i = 0; i < num_pairs; i++) begin
            write_n(1);
            wait_drain(3000);
            read_n(1);
            wait_drain(3000);
        end

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[TEST_ALT_RW] FAIL: fifo_empty not asserted after equal W/R pairs");
        else
            $display("[TEST_ALT_RW] PASS: fifo_empty asserted");

        $display("[TEST_ALT_RW] Done.");
    endtask

endclass
`endif
