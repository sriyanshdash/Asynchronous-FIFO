`ifndef TEST_SINGLE_ENTRY_SV
`define TEST_SINGLE_ENTRY_SV
`timescale 1ns/1ps

class test_single_entry #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        $display("[TEST_SINGLE] Write 1 entry, read 1 entry (minimum case)...");

        write_n(1);
        read_n(1);
        wait_drain(5000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[TEST_SINGLE] FAIL: fifo_empty not asserted after single read");
        else
            $display("[TEST_SINGLE] PASS: fifo_empty asserted");

        $display("[TEST_SINGLE] Done.");
    endtask

endclass
`endif
