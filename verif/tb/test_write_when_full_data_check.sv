`ifndef TEST_WRITE_WHEN_FULL_DATA_CHECK_SV
`define TEST_WRITE_WHEN_FULL_DATA_CHECK_SV
`timescale 1ns/1ps

class test_write_when_full_data_check #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        bit [FIFO_WIDTH-1:0] bad_pattern;
        $display("[TEST_WR_FULL] Fill with pattern A, force writes of pattern B while full...");

        // Fill FIFO with known data via normal driver
        for (int i = 0; i < FIFO_DEPTH; i++)
            write_data({32'hAAAA_0000, 32'(i)});
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);

        // Force 3 writes of bad pattern B while full
        bad_pattern = {FIFO_WIDTH{1'b1}};
        repeat (3) begin
            @(posedge vif.wrclk); #1;
            vif.wr_en   = 1'b1;
            vif.data_in = bad_pattern;
        end
        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1'b0;
        vif.data_in = '0;

        // Read back — scoreboard verifies only pattern A comes out
        read_n(FIFO_DEPTH);
        wait_drain(5000);

        $display("[TEST_WR_FULL] Done (scoreboard verifies pattern B is absent).");
    endtask

endclass
`endif
