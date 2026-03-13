// =============================================================================
// File        : fifo_tb_top.sv
// Description : Top-level testbench module for the simplified Async FIFO TB.
//
//               Responsibilities:
//                 - Clock generation (wrclk, rdclk)
//                 - DUT instantiation via interface
//                 - Initial reset
//                 - Test runner: creates, runs, and reports on all 9 tests
//
// Usage:
//   Default       : runs all 9 tests
//   +TEST_NAME=test_basic_rw : runs only the named test
//
// Available tests:
//   test_basic_rw, test_fill_drain_wrap, test_burst_streaming,
//   test_flag_behavior, test_data_integrity, test_overflow_underflow,
//   test_reset_scenarios, test_clock_ratio, test_stress
// =============================================================================

`timescale 1ns/1ps

`include "fifo_interface.sv"
`include "fifo_transaction.sv"
`include "fifo_driver.sv"
`include "fifo_monitor.sv"
`include "fifo_scoreboard.sv"
`include "fifo_env.sv"
`include "fifo_tests.sv"

module fifo_tb_top;

    // =========================================================================
    //  PARAMETERS
    // =========================================================================
    localparam int FIFO_DEPTH = 8;
    localparam int FIFO_WIDTH = 64;

    // =========================================================================
    //  CLOCKS
    //  wrclk = 100 MHz (10 ns), rdclk ~ 77 MHz (13 ns)
    //  Half-periods are variables so test_clock_ratio can change them at runtime.
    // =========================================================================
    logic wrclk, rdclk;

    realtime wrclk_half = 5.0;    // ns (100 MHz)
    realtime rdclk_half = 6.5;    // ns (~77 MHz)

    initial wrclk = 0;
    always #(wrclk_half) wrclk = ~wrclk;

    initial rdclk = 0;
    always #(rdclk_half) rdclk = ~rdclk;

    // =========================================================================
    //  INTERFACE + DUT
    // =========================================================================
    fifo_if #(FIFO_WIDTH) dut_if (.wrclk(wrclk), .rdclk(rdclk));

    asynchronous_fifo #(
        .FIFO_DEPTH (FIFO_DEPTH),
        .FIFO_WIDTH (FIFO_WIDTH)
    ) dut (
        .wrclk      (dut_if.wrclk),
        .wrst_n     (dut_if.wrst_n),
        .rdclk      (dut_if.rdclk),
        .rrst_n     (dut_if.rrst_n),
        .wr_en      (dut_if.wr_en),
        .rd_en      (dut_if.rd_en),
        .data_in    (dut_if.data_in),
        .data_out   (dut_if.data_out),
        .fifo_full  (dut_if.fifo_full),
        .fifo_empty (dut_if.fifo_empty)
    );

    // =========================================================================
    //  INITIAL RESET
    // =========================================================================
    initial begin
        dut_if.wrst_n  = 0;
        dut_if.rrst_n  = 0;
        dut_if.wr_en   = 0;
        dut_if.rd_en   = 0;
        dut_if.data_in = '0;

        repeat (5) @(posedge wrclk);
        @(posedge wrclk); #1;
        dut_if.wrst_n = 1;
        dut_if.rrst_n = 1;
    end

    // =========================================================================
    //  TEST RUNNER
    // =========================================================================

    // Per-test result tracking
    string test_names[$];
    string test_results[$];

    // Environment (shared across all tests)
    fifo_env #(FIFO_WIDTH) env;

    // --- Run one test ---
    // Creates the test object, resets between tests, runs, and checks result.
    task run_one_test(string name);
        // Declare one handle per test type (avoids class specialization in case)
        test_basic_rw          #(FIFO_WIDTH, FIFO_DEPTH) t1;
        test_fill_drain_wrap   #(FIFO_WIDTH, FIFO_DEPTH) t2;
        test_burst_streaming   #(FIFO_WIDTH, FIFO_DEPTH) t3;
        test_flag_behavior     #(FIFO_WIDTH, FIFO_DEPTH) t4;
        test_data_integrity    #(FIFO_WIDTH, FIFO_DEPTH) t5;
        test_overflow_underflow#(FIFO_WIDTH, FIFO_DEPTH) t6;
        test_reset_scenarios   #(FIFO_WIDTH, FIFO_DEPTH) t7;
        test_clock_ratio       #(FIFO_WIDTH, FIFO_DEPTH) t8;
        test_stress            #(FIFO_WIDTH, FIFO_DEPTH) t9;
        fifo_test_base         #(FIFO_WIDTH, FIFO_DEPTH) test;
        bit found;

        $display("");
        $display("  +----------------------------------------------------------------------+");
        $display("  |  START: %-60s|", name);
        $display("  +----------------------------------------------------------------------+");

        // Factory: create the right test object based on name
        found = 1;
        if      (name == "test_basic_rw")           begin t1 = new(dut_if, env); test = t1; end
        else if (name == "test_fill_drain_wrap")     begin t2 = new(dut_if, env); test = t2; end
        else if (name == "test_burst_streaming")     begin t3 = new(dut_if, env); test = t3; end
        else if (name == "test_flag_behavior")       begin t4 = new(dut_if, env); test = t4; end
        else if (name == "test_data_integrity")      begin t5 = new(dut_if, env); test = t5; end
        else if (name == "test_overflow_underflow")  begin t6 = new(dut_if, env); test = t6; end
        else if (name == "test_reset_scenarios")     begin t7 = new(dut_if, env); test = t7; end
        else if (name == "test_clock_ratio")         begin t8 = new(dut_if, env); test = t8; end
        else if (name == "test_stress")              begin t9 = new(dut_if, env); test = t9; end
        else                                         found = 0;

        if (!found) begin
            $display("  ERROR: Unknown test '%s'", name);
            test_names.push_back(name);
            test_results.push_back("UNKNOWN");
            return;
        end

        // Reset between tests (skip for the very first one — initial reset handles it)
        if (test_names.size() > 0)
            test.reset_phase();

        test.run();
        env.scb.report(name);

        test_names.push_back(name);
        if (env.scb.is_pass())
            test_results.push_back("PASS");
        else
            test_results.push_back("FAIL");

        $display("  +----------------------------------------------------------------------+");
        $display("  |  DONE:  %-52s [%4s]  |", name, test_results[test_results.size()-1]);
        $display("  +----------------------------------------------------------------------+");
    endtask

    // --- Print final summary ---
    function void print_summary();
        int num_pass;
        int num_fail;
        num_pass = 0;
        num_fail = 0;

        $display("");
        $display("");
        $display("  ########################################################################");
        $display("                         FINAL TEST SUMMARY                               ");
        $display("  ########################################################################");
        $display("  %-4s  %-35s  %-6s", "#", "Test Name", "Result");
        $display("  %-4s  %-35s  %-6s", "----", "-----------------------------------", "------");

        for (int i = 0; i < test_names.size(); i++) begin
            $display("  %-4d  %-35s  %-6s", i+1, test_names[i], test_results[i]);
            if (test_results[i] == "PASS") num_pass++;
            else num_fail++;
        end

        $display("  ----------------------------------------------------------------------");
        $display("  Total: %0d tests  |  %0d PASSED  |  %0d FAILED",
                 test_names.size(), num_pass, num_fail);
        $display("  ----------------------------------------------------------------------");
        if (num_fail == 0)
            $display("  OVERALL RESULT  >>  ** ALL TESTS PASSED **");
        else
            $display("  OVERALL RESULT  >>  ** SOME TESTS FAILED **");
        $display("  ########################################################################");
        $display("");
    endfunction

    // --- Main execution ---
    initial begin
        string test_name;
        string all_tests[9];

        all_tests[0] = "test_basic_rw";
        all_tests[1] = "test_fill_drain_wrap";
        all_tests[2] = "test_burst_streaming";
        all_tests[3] = "test_flag_behavior";
        all_tests[4] = "test_data_integrity";
        all_tests[5] = "test_overflow_underflow";
        all_tests[6] = "test_reset_scenarios";
        all_tests[7] = "test_clock_ratio";
        all_tests[8] = "test_stress";

        $display("");
        $display("  ########################################################################");
        $display("    ASYNC FIFO - SIMPLIFIED TESTBENCH");
        $display("    WIDTH=%0d  DEPTH=%0d", FIFO_WIDTH, FIFO_DEPTH);
        $display("  ########################################################################");

        if (!$value$plusargs("TEST_NAME=%s", test_name))
            test_name = "all";

        // Wait for initial reset to complete
        wait (dut_if.wrst_n === 1 && dut_if.rrst_n === 1);
        @(posedge wrclk); #1;

        // Create environment and start components
        env = new(dut_if);
        env.run();

        $display("  Running: %s", test_name);

        if (test_name == "all") begin
            for (int i = 0; i < 9; i++)
                run_one_test(all_tests[i]);
        end else begin
            run_one_test(test_name);
        end

        print_summary();
        $finish;
    end

    // =========================================================================
    //  WAVEFORM DUMP
    // =========================================================================
    initial begin
        `ifdef DUMP_ON
            $dumpfile("fifo_tb_simple.vcd");
            $dumpvars(0, fifo_tb_top);
        `endif
    end

    `ifdef DUMP_ON
        `ifdef CADENCE
            initial begin
                $shm_open("./fifo_tb_simple.shm");
                $shm_probe("ASM");
            end
        `endif
    `endif

endmodule : fifo_tb_top
