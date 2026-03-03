`ifndef TEST_BACK_TO_BACK_OVERFLOW_SV
`define TEST_BACK_TO_BACK_OVERFLOW_SV
`timescale 1ns/1ps

class test_back_to_back_overflow #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        $display("[TEST_B2B_OVF] Fill FIFO, then force 10 consecutive writes while full...");

        // Fill to capacity
        write_n(FIFO_DEPTH);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);

        // Force 10 consecutive writes while full (wr_en held high)
        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1'b1;
        vif.data_in = {FIFO_WIDTH{1'b1}};
        repeat (10) begin
            @(posedge vif.wrclk); #1;
            vif.data_in = vif.data_in - 1;  // changing pattern each cycle
        end
        vif.wr_en   = 1'b0;
        vif.data_in = '0;

        // Read back and verify original data via scoreboard
        read_n(FIFO_DEPTH);
        wait_drain(5000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[TEST_B2B_OVF] FAIL: fifo_empty not asserted");
        else
            $display("[TEST_B2B_OVF] PASS: original data intact after 10 overflow writes");

        $display("[TEST_B2B_OVF] Done.");
    endtask

endclass
`endif
