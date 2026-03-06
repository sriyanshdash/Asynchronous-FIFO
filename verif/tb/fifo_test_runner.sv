//=============================================================================
// File        : fifo_test_runner.sv
// Description : Test runner / orchestrator for the Async FIFO testbench.
//               Dispatches tests by name, runs all by default, prints a
//               per-test and overall summary.
//
//               Each test is a child class of fifo_test_base. The runner
//               creates the test via create_test(), then calls test.run()
//               polymorphically.
//
// Usage       : +TEST_NAME=all          (default - run all tests)
//               +TEST_NAME=test_basic   (run only the named test)
//=============================================================================

`ifndef FIFO_TEST_RUNNER_SV
`define FIFO_TEST_RUNNER_SV

`timescale 1ns/1ps

`include "fifo_test_base.sv"

// --- Reset tests ---
`include "test_reset.sv"
`include "test_reset_when_empty.sv"
`include "test_reset_when_full.sv"
`include "test_reset_during_write.sv"
`include "test_reset_during_read.sv"
`include "test_reset_partial_fill.sv"

// --- Normal tests ---
`include "test_basic.sv"
`include "test_fill_drain.sv"
`include "test_simultaneous_rw.sv"
`include "test_pointer_wrap.sv"
`include "test_clock_ratio.sv"
`include "test_single_entry.sv"
`include "test_full_flag_timing.sv"
`include "test_empty_flag_timing.sv"
`include "test_almost_full.sv"
`include "test_almost_empty.sv"
`include "test_alternating_rw.sv"
`include "test_burst_write_burst_read.sv"
`include "test_data_integrity_patterns.sv"
`include "test_fifo_depth_boundary.sv"
`include "test_continuous_streaming.sv"

// --- Negative tests ---
`include "test_overflow_underflow.sv"
`include "test_write_when_full_data_check.sv"
`include "test_read_when_empty_pointer_check.sv"
`include "test_simultaneous_reset_write.sv"
`include "test_simultaneous_reset_read.sv"
`include "test_back_to_back_overflow.sv"
`include "test_back_to_back_underflow.sv"

// --- Stress test ---
`include "test_stress.sv"

class fifo_test_runner #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
);

    //-------------------------------------------------------------------------
    // Handles
    //-------------------------------------------------------------------------
    fifo_env #(FIFO_WIDTH)           env;
    virtual fifo_if #(FIFO_WIDTH)    vif;

    //-------------------------------------------------------------------------
    // Per-test results tracking
    //-------------------------------------------------------------------------
    string  test_names[$];
    string  test_results[$];

    //-------------------------------------------------------------------------
    // List of all available test names
    //-------------------------------------------------------------------------
    string all_tests[$] = '{
        // Reset
        "test_reset",
        "test_reset_when_empty",
        "test_reset_when_full",
        "test_reset_during_write",
        "test_reset_during_read",
        "test_reset_partial_fill",
        // Normal
        "test_basic",
        "test_fill_drain",
        "test_simultaneous_rw",
        "test_pointer_wrap",
        "test_clock_ratio",
        "test_single_entry",
        "test_full_flag_timing",
        "test_empty_flag_timing",
        "test_almost_full",
        "test_almost_empty",
        "test_alternating_rw",
        "test_burst_write_burst_read",
        "test_data_integrity_patterns",
        "test_fifo_depth_boundary",
        "test_continuous_streaming",
        // Negative
        "test_overflow_underflow",
        "test_write_when_full_data_check",
        "test_read_when_empty_pointer_check",
        "test_simultaneous_reset_write",
        "test_simultaneous_reset_read",
        "test_back_to_back_overflow",
        "test_back_to_back_underflow",
        // Stress
        "test_stress"
    };

    //-------------------------------------------------------------------------
    // Constructor
    //-------------------------------------------------------------------------
    function new(virtual fifo_if #(FIFO_WIDTH) vif);
        this.vif = vif;
        env      = new(vif);
    endfunction

    //-------------------------------------------------------------------------
    // run() - entry point called from tb_top
    //-------------------------------------------------------------------------
    task run(string test_name);
        $display("");
        $display("  ##########################################################################");
        $display("    ASYNC FIFO TEST RUNNER");
        $display("    WIDTH=%0d  DEPTH=%0d  TEST=%s", FIFO_WIDTH, FIFO_DEPTH, test_name);
        $display("  ##########################################################################");
        $display("");

        env.run();

        if (test_name == "all") begin
            foreach (all_tests[i])
                run_one_test(all_tests[i]);
        end else begin
            run_one_test(test_name);
        end

        print_final_summary();
        $finish;
    endtask

    //-------------------------------------------------------------------------
    // create_test() - factory
    //-------------------------------------------------------------------------
    function fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH) create_test(string name);
        case (name)
            // Reset
            "test_reset":                      begin test_reset                      #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_reset_when_empty":           begin test_reset_when_empty           #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_reset_when_full":            begin test_reset_when_full            #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_reset_during_write":         begin test_reset_during_write         #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_reset_during_read":          begin test_reset_during_read          #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_reset_partial_fill":         begin test_reset_partial_fill         #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            // Normal
            "test_basic":                      begin test_basic                      #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_fill_drain":                 begin test_fill_drain                 #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_simultaneous_rw":            begin test_simultaneous_rw            #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_pointer_wrap":               begin test_pointer_wrap               #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_clock_ratio":                begin test_clock_ratio                #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_single_entry":               begin test_single_entry               #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_full_flag_timing":           begin test_full_flag_timing           #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_empty_flag_timing":          begin test_empty_flag_timing          #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_almost_full":                begin test_almost_full                #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_almost_empty":               begin test_almost_empty               #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_alternating_rw":             begin test_alternating_rw             #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_burst_write_burst_read":     begin test_burst_write_burst_read     #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_data_integrity_patterns":    begin test_data_integrity_patterns    #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_fifo_depth_boundary":        begin test_fifo_depth_boundary        #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_continuous_streaming":       begin test_continuous_streaming        #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            // Negative
            "test_overflow_underflow":         begin test_overflow_underflow         #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_write_when_full_data_check": begin test_write_when_full_data_check #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_read_when_empty_pointer_check": begin test_read_when_empty_pointer_check #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_simultaneous_reset_write":   begin test_simultaneous_reset_write   #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_simultaneous_reset_read":    begin test_simultaneous_reset_read    #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_back_to_back_overflow":      begin test_back_to_back_overflow      #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_back_to_back_underflow":     begin test_back_to_back_underflow     #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            // Stress
            "test_stress":                     begin test_stress                     #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            default:                           return null;
        endcase
    endfunction

    //-------------------------------------------------------------------------
    // run_one_test()
    //-------------------------------------------------------------------------
    task run_one_test(string name);
        fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH) test;

        $display("");
        $display("  +------------------------------------------------------------------------+");
        $display("  |  STARTING: %-58s|", name);
        $display("  +------------------------------------------------------------------------+");

        test = create_test(name);

        if (test == null) begin
            $display("[RUNNER] ERROR: Unknown test name '%s'", name);
            $display("[RUNNER] Available tests:");
            foreach (all_tests[i])
                $display("[RUNNER]   %s", all_tests[i]);
            test_names.push_back(name);
            test_results.push_back("UNKNOWN");
            return;
        end

        if (test_names.size() > 0)
            test.reset_phase();

        test.run();
        env.scb.report();

        test_names.push_back(name);
        if (env.scb.is_pass())
            test_results.push_back("PASS");
        else
            test_results.push_back("FAIL");

        $display("  +------------------------------------------------------------------------+");
        $display("  |  FINISHED: %-54s [%4s] |", name, test_results[test_results.size()-1]);
        $display("  +------------------------------------------------------------------------+");
    endtask

    //-------------------------------------------------------------------------
    // print_final_summary()
    //-------------------------------------------------------------------------
    function void print_final_summary();
        int total_pass, total_fail;
        total_pass = 0;
        total_fail = 0;

        $display("");
        $display("");
        $display("  ##########################################################################");
        $display("                        FINAL TEST SUMMARY                                  ");
        $display("  ##########################################################################");
        $display("  %-4s  %-40s  %-6s", "#", "Test Name", "Result");
        $display("  %-4s  %-40s  %-6s", "----", "----------------------------------------", "------");

        for (int i = 0; i < test_names.size(); i++) begin
            $display("  %-4d  %-40s  %-6s", i+1, test_names[i], test_results[i]);
            if (test_results[i] == "PASS")
                total_pass++;
            else
                total_fail++;
        end

        $display("  --------------------------------------------------------------------------");
        $display("  Total: %0d tests | %0d PASSED | %0d FAILED",
                 test_names.size(), total_pass, total_fail);
        $display("  --------------------------------------------------------------------------");
        if (total_fail == 0)
            $display("  OVERALL RESULT  >>  ** ALL TESTS PASSED **");
        else
            $display("  OVERALL RESULT  >>  ** SOME TESTS FAILED **");
        $display("  ##########################################################################");
        $display("");
    endfunction

endclass : fifo_test_runner

`endif // FIFO_TEST_RUNNER_SV
