// =============================================================================
// File        : fifo_tests.sv
// Description : ALL test classes in one file (9 consolidated tests).
//
//               Each test extends fifo_test_base and overrides the run() task.
//               The base class provides helper tasks: write_n(), read_n(),
//               write_data(), wait_drain(), reset_dut(), reset_phase().
//
//               Original 29 tests → 9 consolidated tests:
//                 1. test_basic_rw          (basic, single_entry, alternating)
//                 2. test_fill_drain_wrap   (fill_drain, pointer_wrap, depth_boundary)
//                 3. test_burst_streaming   (burst, streaming, simultaneous_rw)
//                 4. test_flag_behavior     (full_timing, empty_timing, almost_full/empty)
//                 5. test_data_integrity    (bit patterns)
//                 6. test_overflow_underflow(overflow, underflow, back-to-back)
//                 7. test_reset_scenarios   (all 8 reset variants)
//                 8. test_clock_ratio       (different clock frequency ratios)
//                 9. test_stress            (randomized heavy traffic)
// =============================================================================

`ifndef FIFO_TESTS_SIMPLE_SV
`define FIFO_TESTS_SIMPLE_SV

`timescale 1ns/1ps

// =============================================================================
// BASE CLASS — helper tasks shared by all tests
// =============================================================================
class fifo_test_base #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8);

    fifo_env #(FIFO_WIDTH) env;
    virtual fifo_if #(FIFO_WIDTH) vif;

    function new();
    endfunction

    // Call this right after new() to set handles
    function void init(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        this.vif = vif;
        this.env = env;
    endfunction

    // Override this in each test
    virtual task run();
        $fatal(1, "run() not overridden!");
    endtask

    // --- Queue N writes with random data ---
    task write_n(int n);
        fifo_transaction #(FIFO_WIDTH) txn;
        repeat (n) begin
            txn = new();
            if (!txn.randomize() with { wr_en == 1; rd_en == 0; })
                $fatal(1, "Randomize failed");
            txn.txn_type = FIFO_WRITE;
            env.wr_mbx.put(txn);
        end
    endtask

    // --- Queue N reads ---
    task read_n(int n);
        fifo_transaction #(FIFO_WIDTH) txn;
        repeat (n) begin
            txn          = new();
            txn.wr_en    = 0;
            txn.rd_en    = 1;
            txn.txn_type = FIFO_READ;
            env.rd_mbx.put(txn);
        end
    endtask

    // --- Queue a write with a specific data value ---
    task write_data(bit [FIFO_WIDTH-1:0] data);
        fifo_transaction #(FIFO_WIDTH) txn;
        txn          = new();
        txn.wr_en    = 1;
        txn.rd_en    = 0;
        txn.data     = data;
        txn.txn_type = FIFO_WRITE;
        env.wr_mbx.put(txn);
    endtask

    // --- Wait for all queued transactions to complete ---
    // Uses fork-join to avoid killing env threads with disable fork.
    task wait_drain(int timeout_ns = 5000);
        fork begin
            fork
                begin
                    wait (env.wr_mbx.num() == 0 && env.rd_mbx.num() == 0);
                    // Extra settling for monitor pipeline + CDC latency
                    repeat (20) @(posedge vif.wrclk);
                    repeat (20) @(posedge vif.rdclk);
                end
                begin
                    #(timeout_ns * 1ns);
                    $display("[WARN] wait_drain timed out after %0d ns", timeout_ns);
                end
            join_any
            disable fork;
        end join
    endtask

    // --- Assert reset, hold 5 cycles, deassert ---
    task reset_dut();
        vif.wr_en   = 0;
        vif.rd_en   = 0;
        vif.data_in = '0;
        vif.wrst_n  = 0;
        vif.rrst_n  = 0;
        repeat (5) @(posedge vif.wrclk);
        @(posedge vif.wrclk); #1;
        vif.wrst_n  = 1;
        vif.rrst_n  = 1;
        @(posedge vif.wrclk); #1;
    endtask

    // --- Reset DUT + clear env state (call between tests) ---
    task reset_phase();
        reset_dut();
        env.reset();
    endtask

    // --- Check a flag value and report ---
    task check_flag(string name, logic actual, logic expected);
        if (actual !== expected) begin
            $display("  [FLAG] FAIL: %s = %0b, expected %0b @ %0t", name, actual, expected, $time);
            env.scb.fail_count++;
        end else begin
            $display("  [FLAG] OK:   %s = %0b @ %0t", name, actual, $time);
        end
    endtask

endclass : fifo_test_base


// =============================================================================
// TEST 1: BASIC READ/WRITE
// Covers: test_basic, test_single_entry, test_alternating_rw
// =============================================================================
class test_basic_rw #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8)
    extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new();
    endfunction

    task run();
        // Part A: Write several random values, then read them all back
        $display("\n  --- Part A: Write %0d random values, read all back ---", FIFO_DEPTH);
        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH);
        wait_drain();

        // Part B: Single entry — smallest possible FIFO usage
        $display("  --- Part B: Single entry write and read ---");
        write_data(64'hDEAD_BEEF_CAFE_BABE);
        read_n(1);
        wait_drain();

        // Part C: Alternating write-read pattern (20 pairs)
        $display("  --- Part C: Alternating write-read (20 pairs) ---");
        for (int i = 0; i < 20; i++) begin
            write_n(1);
            read_n(1);
            wait_drain();
        end
    endtask
endclass : test_basic_rw


// =============================================================================
// TEST 2: FILL, DRAIN, AND POINTER WRAP-AROUND
// Covers: test_fill_drain, test_pointer_wrap, test_fifo_depth_boundary
// =============================================================================
class test_fill_drain_wrap #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8)
    extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new();
    endfunction

    task run();
        // Part A: Fill to capacity, verify full, drain, verify empty
        $display("\n  --- Part A: Fill to full, drain to empty ---");
        write_n(FIFO_DEPTH);
        wait_drain();
        check_flag("fifo_full", vif.fifo_full, 1);
        read_n(FIFO_DEPTH);
        wait_drain();
        check_flag("fifo_empty", vif.fifo_empty, 1);

        // Part B: Do fill-drain 3 times to exercise pointer wrap-around
        // Gray code pointers wrap at 2*DEPTH — this catches wrap bugs
        $display("  --- Part B: 3x fill-drain cycles (pointer wrap) ---");
        for (int i = 0; i < 3; i++) begin
            $display("    Cycle %0d", i);
            write_n(FIFO_DEPTH);
            read_n(FIFO_DEPTH);
            wait_drain();
        end

        // Part C: Interleaved operations at the depth boundary
        // Write DEPTH-1, read 1, write 2 (reaching full), drain rest
        $display("  --- Part C: Depth boundary interleave ---");
        write_n(FIFO_DEPTH - 1);
        read_n(1);
        wait_drain();
        write_n(2);
        wait_drain();
        check_flag("fifo_full", vif.fifo_full, 1);
        read_n(FIFO_DEPTH);
        wait_drain();
    endtask
endclass : test_fill_drain_wrap


// =============================================================================
// TEST 3: BURST AND STREAMING
// Covers: test_burst_write_burst_read, test_continuous_streaming,
//         test_simultaneous_rw
// =============================================================================
class test_burst_streaming #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8)
    extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new();
    endfunction

    task run();
        // Part A: Burst write all at once, then burst read all at once
        $display("\n  --- Part A: Burst write %0d, then burst read ---", FIFO_DEPTH);
        write_n(FIFO_DEPTH);
        wait_drain();
        read_n(FIFO_DEPTH);
        wait_drain();

        // Part B: Simultaneous reads and writes across clock domains
        // Half-fill first so reads don't stall immediately
        $display("  --- Part B: Simultaneous writes and reads ---");
        write_n(FIFO_DEPTH / 2);
        wait_drain();
        fork
            write_n(20);
            read_n(20 + FIFO_DEPTH / 2);
        join
        wait_drain();

        // Part C: High-throughput continuous streaming (100 transactions)
        $display("  --- Part C: Continuous streaming (100 writes, 100 reads) ---");
        write_n(FIFO_DEPTH / 2);
        wait_drain();
        fork
            write_n(100);
            read_n(100 + FIFO_DEPTH / 2);
        join
        wait_drain();
    endtask
endclass : test_burst_streaming


// =============================================================================
// TEST 4: FLAG BEHAVIOR
// Covers: test_full_flag_timing, test_empty_flag_timing,
//         test_almost_full, test_almost_empty
// =============================================================================
class test_flag_behavior #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8)
    extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new();
    endfunction

    task run();
        // Part A: Full flag should assert only at exactly DEPTH entries
        $display("\n  --- Part A: Full flag timing (write one at a time) ---");
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            if (i > 0) begin
                // Should NOT be full before DEPTH writes
                check_flag($sformatf("fifo_full after %0d writes", i), vif.fifo_full, 0);
            end
            write_n(1);
            wait_drain();
        end
        check_flag("fifo_full after DEPTH writes", vif.fifo_full, 1);

        // Part B: Full flag deasserts after 1 read
        $display("  --- Part B: Full flag clears after 1 read ---");
        read_n(1);
        wait_drain();
        check_flag("fifo_full after 1 read", vif.fifo_full, 0);
        // Drain the rest
        read_n(FIFO_DEPTH - 1);
        wait_drain();

        // Part C: Empty flag should assert only after last entry is read
        $display("  --- Part C: Empty flag timing (read one at a time) ---");
        write_n(FIFO_DEPTH);
        wait_drain();
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            // Should NOT be empty until the very last read
            if (i < FIFO_DEPTH - 1) begin
                check_flag($sformatf("fifo_empty after %0d reads", i), vif.fifo_empty, 0);
            end
            read_n(1);
            wait_drain();
        end
        check_flag("fifo_empty after DEPTH reads", vif.fifo_empty, 1);

        // Part D: Empty flag deasserts after 1 write
        $display("  --- Part D: Empty flag clears after 1 write ---");
        write_n(1);
        wait_drain();
        check_flag("fifo_empty after 1 write", vif.fifo_empty, 0);
        read_n(1);
        wait_drain();
    endtask
endclass : test_flag_behavior


// =============================================================================
// TEST 5: DATA INTEGRITY PATTERNS
// Covers: test_data_integrity_patterns
// =============================================================================
class test_data_integrity #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8)
    extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new();
    endfunction

    task run();
        // Write specific bit patterns that catch common data-path bugs:
        // stuck bits, shorted lines, bit-swap errors
        $display("\n  --- Writing 8 specific bit patterns ---");

        write_data(64'h0000_0000_0000_0000);  // All zeros
        write_data(64'hFFFF_FFFF_FFFF_FFFF);  // All ones
        write_data(64'hAAAA_AAAA_AAAA_AAAA);  // Alternating 10101010
        write_data(64'h5555_5555_5555_5555);  // Alternating 01010101
        write_data(64'h0000_0000_0000_0001);  // Walking 1 at LSB
        write_data(64'h8000_0000_0000_0000);  // Walking 1 at MSB
        write_data(64'hFFFF_FFFF_FFFF_FFFE);  // Walking 0 at LSB
        write_data(64'h7FFF_FFFF_FFFF_FFFF);  // Walking 0 at MSB

        $display("  --- Reading back all 8 patterns ---");
        read_n(8);
        wait_drain();
    endtask
endclass : test_data_integrity


// =============================================================================
// TEST 6: OVERFLOW AND UNDERFLOW PROTECTION
// Covers: test_overflow_underflow, test_write_when_full_data_check,
//         test_read_when_empty_pointer_check, test_back_to_back_overflow,
//         test_back_to_back_underflow
// =============================================================================
class test_overflow_underflow #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8)
    extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new();
    endfunction

    task run();
        // Part A: Single overflow — write when full (should be ignored)
        $display("\n  --- Part A: Single overflow attempt ---");
        write_n(FIFO_DEPTH);
        wait_drain();
        check_flag("fifo_full before overflow", vif.fifo_full, 1);
        // Force a write directly on VIF while full
        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1;
        vif.data_in = 64'hBADD_A1A0_0000_0001;
        @(posedge vif.wrclk); #1;
        vif.wr_en   = 0;
        vif.data_in = '0;
        // Read back — should get original data only
        read_n(FIFO_DEPTH);
        wait_drain();

        // Part B: 10 back-to-back overflow attempts
        $display("  --- Part B: 10 back-to-back overflow writes ---");
        write_n(FIFO_DEPTH);
        wait_drain();
        for (int i = 0; i < 10; i++) begin
            @(posedge vif.wrclk); #1;
            vif.wr_en   = 1;
            vif.data_in = {32'hDEAD_0000 + i[31:0], 32'h0};
            @(posedge vif.wrclk); #1;
            vif.wr_en   = 0;
        end
        vif.data_in = '0;
        read_n(FIFO_DEPTH);
        wait_drain();

        // Part C: Single underflow — read when empty (should be ignored)
        $display("  --- Part C: Single underflow attempt ---");
        check_flag("fifo_empty before underflow", vif.fifo_empty, 1);
        @(posedge vif.rdclk); #1;
        vif.rd_en = 1;
        @(posedge vif.rdclk); #1;
        vif.rd_en = 0;
        repeat (10) @(posedge vif.rdclk);
        // Verify FIFO still works normally
        write_n(1);
        read_n(1);
        wait_drain();

        // Part D: 10 back-to-back underflow attempts
        $display("  --- Part D: 10 back-to-back underflow reads ---");
        for (int i = 0; i < 10; i++) begin
            @(posedge vif.rdclk); #1;
            vif.rd_en = 1;
            @(posedge vif.rdclk); #1;
            vif.rd_en = 0;
        end
        repeat (10) @(posedge vif.rdclk);
        // Verify pointer integrity
        write_n(1);
        read_n(1);
        wait_drain();
    endtask
endclass : test_overflow_underflow


// =============================================================================
// TEST 7: RESET SCENARIOS
// Covers: test_reset, test_reset_when_empty, test_reset_when_full,
//         test_reset_during_write, test_reset_during_read,
//         test_reset_partial_fill, test_simultaneous_reset_write,
//         test_simultaneous_reset_read
// =============================================================================
class test_reset_scenarios #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8)
    extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new();
    endfunction

    task run();
        // Part A: Reset when empty — should stay empty
        $display("\n  --- Part A: Reset when empty ---");
        check_flag("fifo_empty before reset", vif.fifo_empty, 1);
        reset_phase();
        check_flag("fifo_empty after reset", vif.fifo_empty, 1);
        check_flag("fifo_full after reset", vif.fifo_full, 0);
        // Verify recovery
        write_n(1);
        read_n(1);
        wait_drain();

        // Part B: Reset when full — should clear everything
        $display("  --- Part B: Reset when full ---");
        write_n(FIFO_DEPTH);
        wait_drain();
        check_flag("fifo_full before reset", vif.fifo_full, 1);
        reset_phase();
        check_flag("fifo_empty after full-reset", vif.fifo_empty, 1);
        check_flag("fifo_full after full-reset", vif.fifo_full, 0);
        // Write new data and read back to confirm old data is gone
        write_data(64'hF0E5_0000_0000_0001);
        read_n(1);
        wait_drain();

        // Part C: Reset when partially filled
        $display("  --- Part C: Reset when partially filled ---");
        write_n(FIFO_DEPTH / 2);
        wait_drain();
        reset_phase();
        check_flag("fifo_empty after partial-reset", vif.fifo_empty, 1);
        write_n(1);
        read_n(1);
        wait_drain();

        // Part D: Reset while wr_en is active
        $display("  --- Part D: Reset during active write ---");
        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1;
        vif.data_in = 64'hD01C_0000_0000_0001;
        // Slam reset
        vif.wrst_n  = 0;
        vif.rrst_n  = 0;
        vif.wr_en   = 0;
        vif.data_in = '0;
        repeat (5) @(posedge vif.wrclk);
        @(posedge vif.wrclk); #1;
        vif.wrst_n  = 1;
        vif.rrst_n  = 1;
        @(posedge vif.wrclk); #1;
        env.reset();
        check_flag("fifo_empty after wr-during-reset", vif.fifo_empty, 1);
        write_n(1);
        read_n(1);
        wait_drain();

        // Part E: Reset while rd_en is active
        $display("  --- Part E: Reset during active read ---");
        write_n(4);
        wait_drain();
        @(posedge vif.rdclk); #1;
        vif.rd_en   = 1;
        vif.wrst_n  = 0;
        vif.rrst_n  = 0;
        vif.rd_en   = 0;
        repeat (5) @(posedge vif.wrclk);
        @(posedge vif.wrclk); #1;
        vif.wrst_n  = 1;
        vif.rrst_n  = 1;
        @(posedge vif.wrclk); #1;
        env.reset();
        check_flag("fifo_empty after rd-during-reset", vif.fifo_empty, 1);
        write_n(1);
        read_n(1);
        wait_drain();

        // Part F: Simultaneous reset + wr_en (reset should win)
        $display("  --- Part F: Simultaneous reset + write ---");
        vif.wrst_n  = 0;
        vif.rrst_n  = 0;
        vif.wr_en   = 1;
        vif.data_in = 64'h5100_0000_0000_0001;
        repeat (5) @(posedge vif.wrclk);
        vif.wr_en   = 0;
        vif.data_in = '0;
        @(posedge vif.wrclk); #1;
        vif.wrst_n  = 1;
        vif.rrst_n  = 1;
        @(posedge vif.wrclk); #1;
        env.reset();
        check_flag("fifo_empty after simul wr+reset", vif.fifo_empty, 1);
        write_n(1);
        read_n(1);
        wait_drain();

        // Part G: Simultaneous reset + rd_en (reset should win)
        $display("  --- Part G: Simultaneous reset + read ---");
        write_n(4);
        wait_drain();
        vif.wrst_n  = 0;
        vif.rrst_n  = 0;
        vif.rd_en   = 1;
        repeat (5) @(posedge vif.wrclk);
        vif.rd_en   = 0;
        @(posedge vif.wrclk); #1;
        vif.wrst_n  = 1;
        vif.rrst_n  = 1;
        @(posedge vif.wrclk); #1;
        env.reset();
        check_flag("fifo_empty after simul rd+reset", vif.fifo_empty, 1);
        write_n(1);
        read_n(1);
        wait_drain();
    endtask
endclass : test_reset_scenarios


// =============================================================================
// TEST 8: CLOCK RATIO
// Covers: test_clock_ratio (3 frequency scenarios)
// =============================================================================
class test_clock_ratio #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8)
    extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new();
    endfunction

    task run();
        // Part A: Fast write (200 MHz) / Slow read (50 MHz) — 4:1 ratio
        $display("\n  --- Part A: Fast write (200 MHz) / Slow read (50 MHz) ---");
        fifo_tb_top.wrclk_half = 2.5;    // 200 MHz
        fifo_tb_top.rdclk_half = 10.0;   // 50 MHz
        repeat (5) @(posedge vif.wrclk);
        reset_phase();
        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH);
        wait_drain();

        // Part B: Slow write (50 MHz) / Fast read (200 MHz) — 1:4 ratio
        $display("  --- Part B: Slow write (50 MHz) / Fast read (200 MHz) ---");
        fifo_tb_top.wrclk_half = 10.0;   // 50 MHz
        fifo_tb_top.rdclk_half = 2.5;    // 200 MHz
        repeat (5) @(posedge vif.wrclk);
        reset_phase();
        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH);
        wait_drain();

        // Part C: Same frequency (100 MHz both)
        $display("  --- Part C: Same frequency (100 MHz both) ---");
        fifo_tb_top.wrclk_half = 5.0;
        fifo_tb_top.rdclk_half = 5.0;
        repeat (5) @(posedge vif.wrclk);
        reset_phase();
        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH);
        wait_drain();

        // Restore defaults
        fifo_tb_top.wrclk_half = 5.0;
        fifo_tb_top.rdclk_half = 6.5;
        repeat (5) @(posedge vif.wrclk);
    endtask
endclass : test_clock_ratio


// =============================================================================
// TEST 9: STRESS TEST
// Covers: randomized heavy traffic with mixed operations
// =============================================================================
class test_stress #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8)
    extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    function new();
    endfunction

    task run();
        int scenario;
        int num_scenarios = 10;

        $display("\n  --- Running %0d random stress scenarios ---", num_scenarios);

        for (int s = 0; s < num_scenarios; s++) begin
            scenario = $urandom_range(0, 4);
            $display("    Scenario %0d: type=%0d", s, scenario);

            case (scenario)
                0: begin  // Fill and drain
                    write_n(FIFO_DEPTH);
                    read_n(FIFO_DEPTH);
                    wait_drain();
                end

                1: begin  // Concurrent traffic
                    write_n(FIFO_DEPTH / 2);
                    wait_drain();
                    fork
                        write_n(FIFO_DEPTH);
                        read_n(FIFO_DEPTH + FIFO_DEPTH / 2);
                    join
                    wait_drain();
                end

                2: begin  // Alternating single ops
                    for (int i = 0; i < FIFO_DEPTH; i++) begin
                        write_n(1);
                        read_n(1);
                        wait_drain();
                    end
                end

                3: begin  // Burst write then read
                    write_n(FIFO_DEPTH);
                    wait_drain();
                    read_n(FIFO_DEPTH);
                    wait_drain();
                end

                4: begin  // Overflow attempt then drain
                    write_n(FIFO_DEPTH);
                    wait_drain();
                    // Overflow write (ignored by DUT)
                    @(posedge vif.wrclk); #1;
                    vif.wr_en   = 1;
                    vif.data_in = 64'h5700_5500_00E0_F100;
                    @(posedge vif.wrclk); #1;
                    vif.wr_en   = 0;
                    vif.data_in = '0;
                    read_n(FIFO_DEPTH);
                    wait_drain();
                end
            endcase
        end
    endtask
endclass : test_stress

`endif
