`ifndef TEST_EMPTY_FLAG_TIMING_SV
`define TEST_EMPTY_FLAG_TIMING_SV
`timescale 1ns/1ps

class test_empty_flag_timing #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        int fail_cnt = 0;
        $display("[TEST_EMPTY_FLAG] Fill FIFO, read one-by-one, check fifo_empty...");

        // Fill completely
        write_n(FIFO_DEPTH);
        wait_drain(5000);

        for (int i = 1; i <= FIFO_DEPTH; i++) begin
            read_n(1);
            wait_drain(3000);
            repeat (6) @(posedge vif.rdclk);

            if (i < FIFO_DEPTH) begin
                if (vif.fifo_empty) begin
                    $display("[TEST_EMPTY_FLAG] FAIL: fifo_empty asserted early at read %0d/%0d", i, FIFO_DEPTH);
                    fail_cnt++;
                end
            end else begin
                if (!vif.fifo_empty) begin
                    $display("[TEST_EMPTY_FLAG] FAIL: fifo_empty not asserted at read %0d/%0d", i, FIFO_DEPTH);
                    fail_cnt++;
                end else begin
                    $display("[TEST_EMPTY_FLAG] PASS: fifo_empty asserted after last read");
                end
            end
        end

        // Write 1 entry — fifo_empty should deassert
        write_n(1);
        wait_drain(3000);
        repeat (6) @(posedge vif.rdclk);
        if (vif.fifo_empty) begin
            $display("[TEST_EMPTY_FLAG] FAIL: fifo_empty still asserted after 1 write");
            fail_cnt++;
        end else begin
            $display("[TEST_EMPTY_FLAG] PASS: fifo_empty deasserted after 1 write");
        end

        // Drain
        read_n(1);
        wait_drain(5000);

        if (fail_cnt == 0) $display("[TEST_EMPTY_FLAG] All checks passed.");
        else                $display("[TEST_EMPTY_FLAG] ** %0d check(s) FAILED **", fail_cnt);
        $display("[TEST_EMPTY_FLAG] Done.");
    endtask

endclass
`endif
