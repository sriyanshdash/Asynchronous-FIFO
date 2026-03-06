//=============================================================================
// File        : test_stress.sv
// Description : Stress test – a hardcore randomised marathon that executes
//               every individual test scenario as a task in a randomly
//               shuffled order. Between each task the DUT is reset and
//               the scoreboard/env state is cleared, so every scenario
//               starts from a clean slate. This catches subtle state
//               leakage, pointer corruption, and flag glitches that only
//               appear when many different traffic patterns hit the FIFO
//               back-to-back.
//
//               The test is self-contained: it does NOT instantiate any
//               other test class. Each scenario's logic is inlined as a
//               local task so there are no cross-class dependencies.
//=============================================================================

`ifndef TEST_STRESS_SV
`define TEST_STRESS_SV

`timescale 1ns/1ps

class test_stress #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);

    //-------------------------------------------------------------------------
    // Scenario book-keeping
    //-------------------------------------------------------------------------
    typedef enum int {
        SC_BASIC,
        SC_FILL_DRAIN,
        SC_SIMULTANEOUS_RW,
        SC_OVERFLOW_UNDERFLOW,
        SC_RESET,
        SC_POINTER_WRAP,
        SC_RESET_WHEN_EMPTY,
        SC_RESET_WHEN_FULL,
        SC_RESET_DURING_WRITE,
        SC_RESET_DURING_READ,
        SC_RESET_PARTIAL_FILL,
        SC_SINGLE_ENTRY,
        SC_FULL_FLAG_TIMING,
        SC_EMPTY_FLAG_TIMING,
        SC_ALMOST_FULL,
        SC_ALMOST_EMPTY,
        SC_ALTERNATING_RW,
        SC_BURST_WRITE_BURST_READ,
        SC_DATA_INTEGRITY_PATTERNS,
        SC_FIFO_DEPTH_BOUNDARY,
        SC_CONTINUOUS_STREAMING,
        SC_WRITE_WHEN_FULL_DATA_CHECK,
        SC_READ_WHEN_EMPTY_POINTER_CHECK,
        SC_SIMULTANEOUS_RESET_WRITE,
        SC_SIMULTANEOUS_RESET_READ,
        SC_BACK_TO_BACK_OVERFLOW,
        SC_BACK_TO_BACK_UNDERFLOW,
        SC_CLOCK_RATIO
    } scenario_e;

    localparam int NUM_SCENARIOS = 28;

    int scenario_pass;
    int scenario_fail;

    //-------------------------------------------------------------------------
    // Constructor
    //-------------------------------------------------------------------------
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
        scenario_pass = 0;
        scenario_fail = 0;
    endfunction

    //-------------------------------------------------------------------------
    // run() – shuffle scenarios, execute each with reset in between
    //-------------------------------------------------------------------------
    virtual task run();
        int order[$];
        int temp;
        int rand_idx;
        string sc_name;

        $display("");
        $display("  ╔════════════════════════════════════════════════════════════════════╗");
        $display("  ║              S T R E S S   T E S T   B E G I N S                  ║");
        $display("  ║  %0d scenarios will run in random order with reset between each    ║", NUM_SCENARIOS);
        $display("  ╚════════════════════════════════════════════════════════════════════╝");
        $display("");

        // Build ordered list
        for (int i = 0; i < NUM_SCENARIOS; i++)
            order.push_back(i);

        // Fisher-Yates shuffle
        for (int i = NUM_SCENARIOS - 1; i > 0; i--) begin
            rand_idx = $urandom_range(0, i);
            temp = order[i];
            order[i] = order[rand_idx];
            order[rand_idx] = temp;
        end

        // Execute each scenario
        for (int i = 0; i < NUM_SCENARIOS; i++) begin
            sc_name = scenario_name(scenario_e'(order[i]));

            $display("");
            $display("  ┌──────────────────────────────────────────────────────────────────┐");
            $display("  │  STRESS [%0d/%0d] Running: %-42s│", i+1, NUM_SCENARIOS, sc_name);
            $display("  └──────────────────────────────────────────────────────────────────┘");

            // Reset DUT + env before each scenario
            reset_phase();

            // Run the scenario
            run_scenario(scenario_e'(order[i]));

            // Check scoreboard result
            env.scb.report();
            if (env.scb.is_pass()) begin
                scenario_pass++;
                $display("  >> STRESS [%0d/%0d] %s => PASS", i+1, NUM_SCENARIOS, sc_name);
            end else begin
                scenario_fail++;
                $display("  >> STRESS [%0d/%0d] %s => FAIL", i+1, NUM_SCENARIOS, sc_name);
            end
        end

        // Final summary
        $display("");
        $display("  ╔════════════════════════════════════════════════════════════════════╗");
        $display("  ║              S T R E S S   T E S T   S U M M A R Y                ║");
        $display("  ╠════════════════════════════════════════════════════════════════════╣");
        $display("  ║  Total scenarios : %0d                                             ", NUM_SCENARIOS);
        $display("  ║  Passed          : %0d                                             ", scenario_pass);
        $display("  ║  Failed          : %0d                                             ", scenario_fail);
        if (scenario_fail == 0)
            $display("  ║  Result          : ** ALL SCENARIOS PASSED **                      ");
        else
            $display("  ║  Result          : ** SOME SCENARIOS FAILED **                     ");
        $display("  ╚════════════════════════════════════════════════════════════════════╝");
        $display("");
    endtask

    //-------------------------------------------------------------------------
    // scenario_name() – human-readable name for each scenario
    //-------------------------------------------------------------------------
    function string scenario_name(scenario_e sc);
        case (sc)
            SC_BASIC:                          return "basic";
            SC_FILL_DRAIN:                     return "fill_drain";
            SC_SIMULTANEOUS_RW:                return "simultaneous_rw";
            SC_OVERFLOW_UNDERFLOW:             return "overflow_underflow";
            SC_RESET:                          return "reset";
            SC_POINTER_WRAP:                   return "pointer_wrap";
            SC_RESET_WHEN_EMPTY:               return "reset_when_empty";
            SC_RESET_WHEN_FULL:                return "reset_when_full";
            SC_RESET_DURING_WRITE:             return "reset_during_write";
            SC_RESET_DURING_READ:              return "reset_during_read";
            SC_RESET_PARTIAL_FILL:             return "reset_partial_fill";
            SC_SINGLE_ENTRY:                   return "single_entry";
            SC_FULL_FLAG_TIMING:               return "full_flag_timing";
            SC_EMPTY_FLAG_TIMING:              return "empty_flag_timing";
            SC_ALMOST_FULL:                    return "almost_full";
            SC_ALMOST_EMPTY:                   return "almost_empty";
            SC_ALTERNATING_RW:                 return "alternating_rw";
            SC_BURST_WRITE_BURST_READ:         return "burst_write_burst_read";
            SC_DATA_INTEGRITY_PATTERNS:        return "data_integrity_patterns";
            SC_FIFO_DEPTH_BOUNDARY:            return "fifo_depth_boundary";
            SC_CONTINUOUS_STREAMING:            return "continuous_streaming";
            SC_WRITE_WHEN_FULL_DATA_CHECK:     return "write_when_full_data_check";
            SC_READ_WHEN_EMPTY_POINTER_CHECK:  return "read_when_empty_pointer_check";
            SC_SIMULTANEOUS_RESET_WRITE:       return "simultaneous_reset_write";
            SC_SIMULTANEOUS_RESET_READ:        return "simultaneous_reset_read";
            SC_BACK_TO_BACK_OVERFLOW:          return "back_to_back_overflow";
            SC_BACK_TO_BACK_UNDERFLOW:         return "back_to_back_underflow";
            SC_CLOCK_RATIO:                    return "clock_ratio";
            default:                           return "UNKNOWN";
        endcase
    endfunction

    //-------------------------------------------------------------------------
    // run_scenario() – dispatch to the appropriate task
    //-------------------------------------------------------------------------
    task run_scenario(scenario_e sc);
        case (sc)
            SC_BASIC:                          sc_basic();
            SC_FILL_DRAIN:                     sc_fill_drain();
            SC_SIMULTANEOUS_RW:                sc_simultaneous_rw();
            SC_OVERFLOW_UNDERFLOW:             sc_overflow_underflow();
            SC_RESET:                          sc_reset();
            SC_POINTER_WRAP:                   sc_pointer_wrap();
            SC_RESET_WHEN_EMPTY:               sc_reset_when_empty();
            SC_RESET_WHEN_FULL:                sc_reset_when_full();
            SC_RESET_DURING_WRITE:             sc_reset_during_write();
            SC_RESET_DURING_READ:              sc_reset_during_read();
            SC_RESET_PARTIAL_FILL:             sc_reset_partial_fill();
            SC_SINGLE_ENTRY:                   sc_single_entry();
            SC_FULL_FLAG_TIMING:               sc_full_flag_timing();
            SC_EMPTY_FLAG_TIMING:              sc_empty_flag_timing();
            SC_ALMOST_FULL:                    sc_almost_full();
            SC_ALMOST_EMPTY:                   sc_almost_empty();
            SC_ALTERNATING_RW:                 sc_alternating_rw();
            SC_BURST_WRITE_BURST_READ:         sc_burst_write_burst_read();
            SC_DATA_INTEGRITY_PATTERNS:        sc_data_integrity_patterns();
            SC_FIFO_DEPTH_BOUNDARY:            sc_fifo_depth_boundary();
            SC_CONTINUOUS_STREAMING:            sc_continuous_streaming();
            SC_WRITE_WHEN_FULL_DATA_CHECK:     sc_write_when_full_data_check();
            SC_READ_WHEN_EMPTY_POINTER_CHECK:  sc_read_when_empty_pointer_check();
            SC_SIMULTANEOUS_RESET_WRITE:       sc_simultaneous_reset_write();
            SC_SIMULTANEOUS_RESET_READ:        sc_simultaneous_reset_read();
            SC_BACK_TO_BACK_OVERFLOW:          sc_back_to_back_overflow();
            SC_BACK_TO_BACK_UNDERFLOW:         sc_back_to_back_underflow();
            SC_CLOCK_RATIO:                    sc_clock_ratio();
            default: $display("[STRESS] ERROR: Unknown scenario %0d", sc);
        endcase
    endtask

    //=========================================================================
    //  S C E N A R I O   T A S K S
    //=========================================================================

    // 1. Basic write-then-read
    task sc_basic();
        localparam NUM_TXNS = 20;
        $display("[STRESS:BASIC] Writing %0d random values, then reading them back...", NUM_TXNS);
        write_n(NUM_TXNS);
        read_n(NUM_TXNS);
        wait_drain(10000);
        $display("[STRESS:BASIC] Done.");
    endtask

    // 2. Fill / drain (2 cycles)
    task sc_fill_drain();
        $display("[STRESS:FILL_DRAIN] Starting fill/drain test (2 cycles)...");

        // Cycle 1
        write_n(FIFO_DEPTH);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        if (!vif.fifo_full)
            $display("[STRESS:FILL_DRAIN] WARN: fifo_full not asserted after %0d writes", FIFO_DEPTH);

        read_n(FIFO_DEPTH);
        wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[STRESS:FILL_DRAIN] WARN: fifo_empty not asserted after drain");

        // Cycle 2 (pointer wrap)
        write_n(FIFO_DEPTH);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        if (!vif.fifo_full)
            $display("[STRESS:FILL_DRAIN] WARN: fifo_full not asserted on 2nd fill");

        read_n(FIFO_DEPTH);
        wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[STRESS:FILL_DRAIN] WARN: fifo_empty not asserted on 2nd drain");

        $display("[STRESS:FILL_DRAIN] Done.");
    endtask

    // 3. Simultaneous read/write
    task sc_simultaneous_rw();
        int half_depth      = FIFO_DEPTH / 2;
        int concurrent_txns = FIFO_DEPTH * 2;

        $display("[STRESS:SIM_RW] Simultaneous read/write...");
        write_n(half_depth);
        wait_drain(5000);

        fork
            write_n(concurrent_txns);
            read_n(half_depth + concurrent_txns);
        join
        wait_drain(15000);
        $display("[STRESS:SIM_RW] Done.");
    endtask

    // 4. Overflow / underflow
    task sc_overflow_underflow();
        bit [FIFO_WIDTH-1:0] overflow_data;

        $display("[STRESS:OVF_UNF] Overflow test...");
        write_n(FIFO_DEPTH);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);

        // Force write while full
        overflow_data = {FIFO_WIDTH{1'b1}};
        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1'b1;
        vif.data_in = overflow_data;
        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1'b0;
        vif.data_in = '0;

        read_n(FIFO_DEPTH);
        wait_drain(5000);

        $display("[STRESS:OVF_UNF] Underflow test...");
        repeat (6) @(posedge vif.rdclk);

        // Force read while empty
        @(posedge vif.rdclk); #1;
        vif.rd_en = 1'b1;
        @(posedge vif.rdclk); #1;
        vif.rd_en = 1'b0;
        repeat (4) @(posedge vif.rdclk);

        // Verify FIFO still works
        write_n(1);
        read_n(1);
        wait_drain(5000);
        $display("[STRESS:OVF_UNF] Done.");
    endtask

    // 5. Reset with data
    task sc_reset();
        $display("[STRESS:RESET] Reset while FIFO contains data...");

        write_n(FIFO_DEPTH / 2);
        wait_drain(5000);

        vif.wr_en   = 1'b0;
        vif.rd_en   = 1'b0;
        vif.data_in = '0;
        vif.wrst_n  = 1'b0;
        vif.rrst_n  = 1'b0;
        repeat (5) @(posedge vif.wrclk);

        if (vif.fifo_full)
            $display("[STRESS:RESET] WARN: fifo_full should be 0 during reset");
        if (!vif.fifo_empty)
            $display("[STRESS:RESET] WARN: fifo_empty should be 1 during reset");

        @(posedge vif.wrclk); #1;
        vif.wrst_n = 1'b1;
        vif.rrst_n = 1'b1;
        @(posedge vif.wrclk); #1;

        env.reset();

        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH);
        wait_drain(10000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[STRESS:RESET] WARN: fifo_empty not asserted after post-reset drain");

        $display("[STRESS:RESET] Done.");
    endtask

    // 6. Pointer wrap
    task sc_pointer_wrap();
        $display("[STRESS:PTR_WRAP] 3 fill-drain cycles...");
        for (int cycle = 1; cycle <= 3; cycle++) begin
            write_n(FIFO_DEPTH);
            read_n(FIFO_DEPTH);
            wait_drain(5000);
        end
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[STRESS:PTR_WRAP] WARN: fifo_empty not asserted");
        $display("[STRESS:PTR_WRAP] Done.");
    endtask

    // 7. Reset when empty
    task sc_reset_when_empty();
        $display("[STRESS:RST_EMPTY] Reset on already-empty FIFO...");
        reset_dut();

        if (!vif.fifo_empty)
            $display("[STRESS:RST_EMPTY] WARN: fifo_empty should be 1");
        if (vif.fifo_full)
            $display("[STRESS:RST_EMPTY] WARN: fifo_full should be 0");

        env.reset();

        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH);
        wait_drain(5000);
        $display("[STRESS:RST_EMPTY] Done.");
    endtask

    // 8. Reset when full
    task sc_reset_when_full();
        $display("[STRESS:RST_FULL] Fill FIFO, then reset...");
        write_n(FIFO_DEPTH);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);

        reset_dut();
        env.reset();

        if (!vif.fifo_empty)
            $display("[STRESS:RST_FULL] WARN: fifo_empty should be 1 after reset");
        if (vif.fifo_full)
            $display("[STRESS:RST_FULL] WARN: fifo_full should be 0 after reset");

        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH);
        wait_drain(5000);
        $display("[STRESS:RST_FULL] Done.");
    endtask

    // 9. Reset during write
    task sc_reset_during_write();
        $display("[STRESS:RST_WR] Reset while wr_en is active...");

        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1'b1;
        vif.data_in = 64'hDEAD_BEEF_CAFE_BABE;

        @(posedge vif.wrclk); #1;
        vif.wrst_n = 1'b0;
        vif.rrst_n = 1'b0;
        repeat (5) @(posedge vif.wrclk);

        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1'b0;
        vif.data_in = '0;
        vif.wrst_n  = 1'b1;
        vif.rrst_n  = 1'b1;
        @(posedge vif.wrclk); #1;

        env.reset();

        if (!vif.fifo_empty)
            $display("[STRESS:RST_WR] WARN: fifo_empty should be 1 after reset");

        write_n(4);
        read_n(4);
        wait_drain(5000);
        $display("[STRESS:RST_WR] Done.");
    endtask

    // 10. Reset during read
    task sc_reset_during_read();
        $display("[STRESS:RST_RD] Reset while rd_en is active...");

        write_n(4);
        wait_drain(5000);

        @(posedge vif.rdclk); #1;
        vif.rd_en = 1'b1;
        @(posedge vif.rdclk); #1;

        vif.wrst_n = 1'b0;
        vif.rrst_n = 1'b0;
        repeat (5) @(posedge vif.wrclk);

        @(posedge vif.wrclk); #1;
        vif.rd_en  = 1'b0;
        vif.wrst_n = 1'b1;
        vif.rrst_n = 1'b1;
        @(posedge vif.wrclk); #1;

        env.reset();

        if (!vif.fifo_empty)
            $display("[STRESS:RST_RD] WARN: fifo_empty should be 1 after reset");

        write_n(4);
        read_n(4);
        wait_drain(5000);
        $display("[STRESS:RST_RD] Done.");
    endtask

    // 11. Reset partial fill
    task sc_reset_partial_fill();
        $display("[STRESS:RST_PARTIAL] Partial fill, reset, verify old data gone...");

        write_n(FIFO_DEPTH / 2);
        wait_drain(5000);

        reset_dut();
        env.reset();

        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH);
        wait_drain(5000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[STRESS:RST_PARTIAL] WARN: fifo_empty not asserted after drain");

        $display("[STRESS:RST_PARTIAL] Done.");
    endtask

    // 12. Single entry
    task sc_single_entry();
        $display("[STRESS:SINGLE] Write 1, read 1 (minimum case)...");

        write_n(1);
        read_n(1);
        wait_drain(5000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[STRESS:SINGLE] WARN: fifo_empty not asserted");

        $display("[STRESS:SINGLE] Done.");
    endtask

    // 13. Full flag timing
    task sc_full_flag_timing();
        $display("[STRESS:FULL_FLAG] Write one-by-one, check fifo_full...");

        for (int i = 1; i <= FIFO_DEPTH; i++) begin
            write_n(1);
            wait_drain(3000);
            repeat (6) @(posedge vif.wrclk);

            if (i < FIFO_DEPTH) begin
                if (vif.fifo_full)
                    $display("[STRESS:FULL_FLAG] WARN: fifo_full asserted early at %0d/%0d", i, FIFO_DEPTH);
            end else begin
                if (!vif.fifo_full)
                    $display("[STRESS:FULL_FLAG] WARN: fifo_full not asserted at %0d/%0d", i, FIFO_DEPTH);
            end
        end

        read_n(1);
        wait_drain(3000);
        repeat (6) @(posedge vif.wrclk);
        if (vif.fifo_full)
            $display("[STRESS:FULL_FLAG] WARN: fifo_full still asserted after 1 read");

        read_n(FIFO_DEPTH - 1);
        wait_drain(5000);
        $display("[STRESS:FULL_FLAG] Done.");
    endtask

    // 14. Empty flag timing
    task sc_empty_flag_timing();
        $display("[STRESS:EMPTY_FLAG] Fill, read one-by-one, check fifo_empty...");

        write_n(FIFO_DEPTH);
        wait_drain(5000);

        for (int i = 1; i <= FIFO_DEPTH; i++) begin
            read_n(1);
            wait_drain(3000);
            repeat (6) @(posedge vif.rdclk);

            if (i < FIFO_DEPTH) begin
                if (vif.fifo_empty)
                    $display("[STRESS:EMPTY_FLAG] WARN: fifo_empty asserted early at %0d/%0d", i, FIFO_DEPTH);
            end else begin
                if (!vif.fifo_empty)
                    $display("[STRESS:EMPTY_FLAG] WARN: fifo_empty not asserted at %0d/%0d", i, FIFO_DEPTH);
            end
        end

        write_n(1);
        wait_drain(3000);
        repeat (6) @(posedge vif.rdclk);
        if (vif.fifo_empty)
            $display("[STRESS:EMPTY_FLAG] WARN: fifo_empty still asserted after 1 write");

        read_n(1);
        wait_drain(5000);
        $display("[STRESS:EMPTY_FLAG] Done.");
    endtask

    // 15. Almost full
    task sc_almost_full();
        $display("[STRESS:ALMOST_FULL] Write DEPTH-1, check NOT full, write 1 more...");

        write_n(FIFO_DEPTH - 1);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        if (vif.fifo_full)
            $display("[STRESS:ALMOST_FULL] WARN: fifo_full asserted at DEPTH-1");

        write_n(1);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        if (!vif.fifo_full)
            $display("[STRESS:ALMOST_FULL] WARN: fifo_full not asserted at DEPTH");

        read_n(FIFO_DEPTH);
        wait_drain(5000);
        $display("[STRESS:ALMOST_FULL] Done.");
    endtask

    // 16. Almost empty
    task sc_almost_empty();
        $display("[STRESS:ALMOST_EMPTY] Fill, drain to 1 left, check NOT empty, read last...");

        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH - 1);
        wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);
        if (vif.fifo_empty)
            $display("[STRESS:ALMOST_EMPTY] WARN: fifo_empty asserted with 1 entry left");

        read_n(1);
        wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[STRESS:ALMOST_EMPTY] WARN: fifo_empty not asserted after last read");

        $display("[STRESS:ALMOST_EMPTY] Done.");
    endtask

    // 17. Alternating read/write
    task sc_alternating_rw();
        int num_pairs = 20;
        $display("[STRESS:ALT_RW] Alternating W-R for %0d pairs...", num_pairs);

        for (int i = 0; i < num_pairs; i++) begin
            write_n(1);
            wait_drain(3000);
            read_n(1);
            wait_drain(3000);
        end

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[STRESS:ALT_RW] WARN: fifo_empty not asserted");

        $display("[STRESS:ALT_RW] Done.");
    endtask

    // 18. Burst write / burst read
    task sc_burst_write_burst_read();
        $display("[STRESS:BURST] Burst-write %0d, burst-read %0d...", FIFO_DEPTH, FIFO_DEPTH);

        write_n(FIFO_DEPTH);
        wait_drain(5000);
        read_n(FIFO_DEPTH);
        wait_drain(5000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[STRESS:BURST] WARN: fifo_empty not asserted");

        $display("[STRESS:BURST] Done.");
    endtask

    // 19. Data integrity patterns
    task sc_data_integrity_patterns();
        bit [FIFO_WIDTH-1:0] pattern;
        $display("[STRESS:DATA_PAT] Writing known data patterns...");

        write_data({FIFO_WIDTH{1'b0}});
        write_data({FIFO_WIDTH{1'b1}});
        write_data({(FIFO_WIDTH/8){8'hAA}});
        write_data({(FIFO_WIDTH/8){8'h55}});

        pattern = '0; pattern[0] = 1'b1;
        write_data(pattern);
        pattern = '0; pattern[FIFO_WIDTH-1] = 1'b1;
        write_data(pattern);
        pattern = '1; pattern[0] = 1'b0;
        write_data(pattern);
        pattern = '1; pattern[FIFO_WIDTH-1] = 1'b0;
        write_data(pattern);

        read_n(8);
        wait_drain(5000);
        $display("[STRESS:DATA_PAT] Done.");
    endtask

    // 20. FIFO depth boundary
    task sc_fifo_depth_boundary();
        $display("[STRESS:DEPTH_BND] Interleaved operations at full boundary...");

        write_n(FIFO_DEPTH - 1);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        if (vif.fifo_full)
            $display("[STRESS:DEPTH_BND] WARN: fifo_full asserted at DEPTH-1");

        read_n(1);
        wait_drain(3000);

        write_n(2);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        if (!vif.fifo_full)
            $display("[STRESS:DEPTH_BND] WARN: fifo_full not asserted after interleaved fill");

        read_n(FIFO_DEPTH);
        wait_drain(5000);
        $display("[STRESS:DEPTH_BND] Done.");
    endtask

    // 21. Continuous streaming
    task sc_continuous_streaming();
        int num_txns = 100;
        $display("[STRESS:STREAM] Continuous streaming: %0d pairs...", num_txns);

        write_n(FIFO_DEPTH / 2);
        wait_drain(3000);

        fork
            write_n(num_txns);
            read_n((FIFO_DEPTH / 2) + num_txns);
        join
        wait_drain(20000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[STRESS:STREAM] WARN: fifo_empty not asserted");

        $display("[STRESS:STREAM] Done.");
    endtask

    // 22. Write when full data check
    task sc_write_when_full_data_check();
        bit [FIFO_WIDTH-1:0] bad_pattern;
        $display("[STRESS:WR_FULL] Fill with pattern A, force writes of pattern B while full...");

        for (int i = 0; i < FIFO_DEPTH; i++)
            write_data({32'hAAAA_0000, 32'(i)});
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);

        bad_pattern = {FIFO_WIDTH{1'b1}};
        repeat (3) begin
            @(posedge vif.wrclk); #1;
            vif.wr_en   = 1'b1;
            vif.data_in = bad_pattern;
        end
        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1'b0;
        vif.data_in = '0;

        read_n(FIFO_DEPTH);
        wait_drain(5000);
        $display("[STRESS:WR_FULL] Done.");
    endtask

    // 23. Read when empty pointer check
    task sc_read_when_empty_pointer_check();
        $display("[STRESS:RD_EMPTY] Force multiple reads while empty...");

        repeat (5) begin
            @(posedge vif.rdclk); #1;
            vif.rd_en = 1'b1;
        end
        @(posedge vif.rdclk); #1;
        vif.rd_en = 1'b0;
        repeat (4) @(posedge vif.rdclk);

        write_n(FIFO_DEPTH);
        read_n(FIFO_DEPTH);
        wait_drain(5000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[STRESS:RD_EMPTY] WARN: fifo_empty not asserted");

        $display("[STRESS:RD_EMPTY] Done.");
    endtask

    // 24. Simultaneous reset + write
    task sc_simultaneous_reset_write();
        $display("[STRESS:RST_SIM_WR] Assert reset and wr_en simultaneously...");

        @(posedge vif.wrclk); #1;
        vif.wrst_n  = 1'b0;
        vif.rrst_n  = 1'b0;
        vif.wr_en   = 1'b1;
        vif.data_in = 64'hDEAD_BEEF_DEAD_BEEF;
        repeat (5) @(posedge vif.wrclk);

        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1'b0;
        vif.data_in = '0;
        vif.wrst_n  = 1'b1;
        vif.rrst_n  = 1'b1;
        @(posedge vif.wrclk); #1;

        env.reset();

        if (!vif.fifo_empty)
            $display("[STRESS:RST_SIM_WR] WARN: reset should win over write");

        write_n(4);
        read_n(4);
        wait_drain(5000);
        $display("[STRESS:RST_SIM_WR] Done.");
    endtask

    // 25. Simultaneous reset + read
    task sc_simultaneous_reset_read();
        $display("[STRESS:RST_SIM_RD] Write data, then assert reset and rd_en simultaneously...");

        write_n(4);
        wait_drain(5000);

        @(posedge vif.rdclk); #1;
        vif.wrst_n = 1'b0;
        vif.rrst_n = 1'b0;
        vif.rd_en  = 1'b1;
        repeat (5) @(posedge vif.wrclk);

        @(posedge vif.wrclk); #1;
        vif.rd_en  = 1'b0;
        vif.wrst_n = 1'b1;
        vif.rrst_n = 1'b1;
        @(posedge vif.wrclk); #1;

        env.reset();

        if (!vif.fifo_empty)
            $display("[STRESS:RST_SIM_RD] WARN: reset should win over read");

        write_n(4);
        read_n(4);
        wait_drain(5000);
        $display("[STRESS:RST_SIM_RD] Done.");
    endtask

    // 26. Back-to-back overflow
    task sc_back_to_back_overflow();
        $display("[STRESS:B2B_OVF] Fill, then force 10 consecutive writes while full...");

        write_n(FIFO_DEPTH);
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);

        @(posedge vif.wrclk); #1;
        vif.wr_en   = 1'b1;
        vif.data_in = {FIFO_WIDTH{1'b1}};
        repeat (10) begin
            @(posedge vif.wrclk); #1;
            vif.data_in = vif.data_in - 1;
        end
        vif.wr_en   = 1'b0;
        vif.data_in = '0;

        read_n(FIFO_DEPTH);
        wait_drain(5000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[STRESS:B2B_OVF] WARN: fifo_empty not asserted");

        $display("[STRESS:B2B_OVF] Done.");
    endtask

    // 27. Back-to-back underflow
    task sc_back_to_back_underflow();
        $display("[STRESS:B2B_UNF] Force 10 consecutive reads while empty...");

        @(posedge vif.rdclk); #1;
        vif.rd_en = 1'b1;
        repeat (10) @(posedge vif.rdclk);
        #1;
        vif.rd_en = 1'b0;
        repeat (4) @(posedge vif.rdclk);

        write_n(1);
        read_n(1);
        wait_drain(5000);

        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty)
            $display("[STRESS:B2B_UNF] WARN: fifo_empty not asserted");

        $display("[STRESS:B2B_UNF] Done.");
    endtask

    // 28. Clock ratio
    task sc_clock_ratio();
        localparam NUM_TXNS = 16;
        $display("[STRESS:CLK_RATIO] Testing 3 clock ratio scenarios...");

        // Scenario 1: Write-fast / Read-slow
        $display("[STRESS:CLK_RATIO] Scenario 1: Write-FAST (200MHz) / Read-SLOW (50MHz)");
        tb_top.wrclk_half = 2.5;
        tb_top.rdclk_half = 10.0;
        repeat (4) @(posedge vif.wrclk);
        reset_phase();
        write_n(NUM_TXNS);
        read_n(NUM_TXNS);
        wait_drain(20000);

        // Scenario 2: Read-fast / Write-slow
        $display("[STRESS:CLK_RATIO] Scenario 2: Write-SLOW (50MHz) / Read-FAST (200MHz)");
        tb_top.wrclk_half = 10.0;
        tb_top.rdclk_half = 2.5;
        repeat (4) @(posedge vif.wrclk);
        reset_phase();
        write_n(NUM_TXNS);
        read_n(NUM_TXNS);
        wait_drain(20000);

        // Scenario 3: Equal frequency
        $display("[STRESS:CLK_RATIO] Scenario 3: Equal frequency (100MHz / 100MHz)");
        tb_top.wrclk_half = 5.0;
        tb_top.rdclk_half = 5.0;
        repeat (4) @(posedge vif.wrclk);
        reset_phase();
        write_n(NUM_TXNS);
        read_n(NUM_TXNS);
        wait_drain(20000);

        // Restore default clocks
        $display("[STRESS:CLK_RATIO] Restoring default clocks (100MHz / 77MHz)...");
        tb_top.wrclk_half = 5.0;
        tb_top.rdclk_half = 6.5;

        $display("[STRESS:CLK_RATIO] Done.");
    endtask

endclass : test_stress

`endif // TEST_STRESS_SV
