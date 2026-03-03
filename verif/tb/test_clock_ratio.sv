//=============================================================================
// File        : test_clock_ratio.sv
// Description : Tests FIFO correctness under different clock frequency ratios.
//               Modifies tb_top's clock half-period variables at runtime to
//               exercise three scenarios:
//                 1. Write-fast / Read-slow  (wrclk >> rdclk)
//                 2. Read-fast  / Write-slow (rdclk >> wrclk)
//                 3. Equal frequencies, different phase
//
//               Each scenario does a full fill-drain cycle and checks data
//               integrity through the scoreboard.
//
//               Uses hierarchical reference tb_top.wrclk_half / rdclk_half
//               to change clock periods at runtime.
//=============================================================================

`ifndef TEST_CLOCK_RATIO_SV
`define TEST_CLOCK_RATIO_SV

`timescale 1ns/1ps

class test_clock_ratio #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    localparam NUM_TXNS = 16;  // 2 full FIFO cycles per scenario

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction

    virtual task run();
        $display("");
        $display("[TEST_CLK_RATIO] Starting clock ratio test (3 scenarios)...");

        //---------------------------------------------------------------------
        // Scenario 1: Write-fast / Read-slow
        //   wrclk = 200 MHz (2.5 ns half), rdclk = 50 MHz (10 ns half)
        //   Write side is 4x faster than read side.
        //   Stresses: fifo_full staying asserted while reads are slow,
        //             CDC sync from fast→slow domain.
        //---------------------------------------------------------------------
        $display("[TEST_CLK_RATIO] Scenario 1: Write-FAST (200MHz) / Read-SLOW (50MHz)");
        set_clocks(2.5, 10.0);
        reset_phase();
        run_fill_drain();

        //---------------------------------------------------------------------
        // Scenario 2: Read-fast / Write-slow
        //   wrclk = 50 MHz (10 ns half), rdclk = 200 MHz (2.5 ns half)
        //   Read side is 4x faster than write side.
        //   Stresses: fifo_empty staying asserted while writes are slow,
        //             CDC sync from slow→fast domain.
        //---------------------------------------------------------------------
        $display("[TEST_CLK_RATIO] Scenario 2: Write-SLOW (50MHz) / Read-FAST (200MHz)");
        set_clocks(10.0, 2.5);
        reset_phase();
        run_fill_drain();

        //---------------------------------------------------------------------
        // Scenario 3: Equal frequency, different phase
        //   Both clocks at 100 MHz (5 ns half) but rdclk starts with a
        //   slight offset. The offset comes naturally from the reset_phase()
        //   timing – the key is that both clocks run at the same rate.
        //   Stresses: near-simultaneous pointer comparisons across domains.
        //---------------------------------------------------------------------
        $display("[TEST_CLK_RATIO] Scenario 3: Equal frequency (100MHz / 100MHz)");
        set_clocks(5.0, 5.0);
        reset_phase();
        run_fill_drain();

        //---------------------------------------------------------------------
        // Restore default clock ratios (runner handles DUT reset before next test)
        //---------------------------------------------------------------------
        $display("[TEST_CLK_RATIO] Restoring default clocks (100MHz / 77MHz)...");
        set_clocks(5.0, 6.5);

        $display("[TEST_CLK_RATIO] Done.");
    endtask

    //=========================================================================
    // set_clocks() – change clock half-periods via hierarchical reference
    //=========================================================================
    task set_clocks(realtime wr_half, realtime rd_half);
        tb_top.wrclk_half = wr_half;
        tb_top.rdclk_half = rd_half;
        $display("[TEST_CLK_RATIO]   wrclk_half=%.1f ns (period=%.1f ns)  rdclk_half=%.1f ns (period=%.1f ns)",
                 wr_half, wr_half*2, rd_half, rd_half*2);
        // Let new clock periods take effect for a few cycles
        repeat (4) @(posedge vif.wrclk);
    endtask

    //=========================================================================
    // run_fill_drain() – write NUM_TXNS, read NUM_TXNS, verify via scoreboard
    //=========================================================================
    task run_fill_drain();
        write_n(NUM_TXNS);
        read_n(NUM_TXNS);
        wait_drain(20000);
    endtask

endclass : test_clock_ratio

`endif // TEST_CLOCK_RATIO_SV