`ifndef TEST_DATA_INTEGRITY_PATTERNS_SV
`define TEST_DATA_INTEGRITY_PATTERNS_SV
`timescale 1ns/1ps

class test_data_integrity_patterns #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        bit [FIFO_WIDTH-1:0] pattern;
        $display("[TEST_DATA_PAT] Writing known data patterns...");

        // All zeros
        write_data({FIFO_WIDTH{1'b0}});

        // All ones
        write_data({FIFO_WIDTH{1'b1}});

        // Alternating 0xAA..
        write_data({(FIFO_WIDTH/8){8'hAA}});

        // Alternating 0x55..
        write_data({(FIFO_WIDTH/8){8'h55}});

        // Walking 1: bit 0
        pattern = '0; pattern[0] = 1'b1;
        write_data(pattern);

        // Walking 1: MSB
        pattern = '0; pattern[FIFO_WIDTH-1] = 1'b1;
        write_data(pattern);

        // Walking 0: bit 0
        pattern = '1; pattern[0] = 1'b0;
        write_data(pattern);

        // Walking 0: MSB
        pattern = '1; pattern[FIFO_WIDTH-1] = 1'b0;
        write_data(pattern);

        // Read all 8 entries back — scoreboard will verify each
        read_n(8);
        wait_drain(5000);

        $display("[TEST_DATA_PAT] Done.");
    endtask

endclass
`endif
