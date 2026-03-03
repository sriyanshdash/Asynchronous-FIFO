//=============================================================================
// File        : test_basic.sv
// Description : Basic write-then-read test.
//               Writes NUM_TXNS random values, then reads them all back.
//               Verifies data integrity through the scoreboard.
//=============================================================================

`ifndef TEST_BASIC_SV
`define TEST_BASIC_SV

`timescale 1ns/1ps

class test_basic #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    localparam NUM_TXNS = 20;

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        $display("");
        $display("[TEST_BASIC] Writing %0d random values, then reading them back...", NUM_TXNS);

        write_n(NUM_TXNS);
        read_n(NUM_TXNS);
        wait_drain(10000);

        $display("[TEST_BASIC] Done.");
    endtask

endclass : test_basic

`endif // TEST_BASIC_SV