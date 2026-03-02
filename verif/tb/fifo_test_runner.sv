//=============================================================================
// File        : fifo_test_runner.sv
// Description : Test runner / orchestrator for the Async FIFO testbench.
//               Dispatches tests by name, runs all by default, prints a
//               per-test and overall summary.
//
// Usage       : +TEST_NAME=all          (default – run all tests)
//               +TEST_NAME=test_basic   (run only the named test)
//=============================================================================

`ifndef FIFO_TEST_RUNNER_SV
`define FIFO_TEST_RUNNER_SV

`timescale 1ns/1ps

`include "fifo_test_base.sv"
`include "test_basic.sv"
`include "test_fill_drain.sv"
`include "test_simultaneous_rw.sv"
`include "test_overflow_underflow.sv"
`include "test_reset.sv"
`include "test_pointer_wrap.sv"
`include "test_clock_ratio.sv"

class fifo_test_runner #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
);

    //-------------------------------------------------------------------------
    // Handles
    //-------------------------------------------------------------------------
    fifo_env       #(FIFO_WIDTH)              env;
    fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH)  base;
    virtual fifo_if #(FIFO_WIDTH)             vif;

    //-------------------------------------------------------------------------
    // Per-test results tracking
    //-------------------------------------------------------------------------
    string  test_names[$];
    string  test_results[$];

    //-------------------------------------------------------------------------
    // Constructor – creates the environment and base test
    //-------------------------------------------------------------------------
    function new(virtual fifo_if #(FIFO_WIDTH) vif);
        this.vif = vif;
        env      = new(vif);
        base     = new(vif, env);
    endfunction

    //-------------------------------------------------------------------------
    // run() – entry point called from tb_top
    //-------------------------------------------------------------------------
    task run(string test_name);
        $display("");
        $display("  ##########################################################################");
        $display("    ASYNC FIFO TEST RUNNER");
        $display("    WIDTH=%0d  DEPTH=%0d  TEST=%s", FIFO_WIDTH, FIFO_DEPTH, test_name);
        $display("  ##########################################################################");
        $display("");

        // Start environment threads once (driver/monitor/scoreboard)
        env.run();

        if (test_name == "all") begin
            run_one_test("test_basic");
            run_one_test("test_fill_drain");
            run_one_test("test_simultaneous_rw");
            run_one_test("test_overflow_underflow");
            run_one_test("test_reset");
            run_one_test("test_pointer_wrap");
            run_one_test("test_clock_ratio");
        end else begin
            run_one_test(test_name);
        end

        print_final_summary();
        $finish;
    endtask

    //-------------------------------------------------------------------------
    // run_one_test() – dispatch, record result, reset between tests
    //-------------------------------------------------------------------------
    task run_one_test(string name);
        bit pass_before;

        $display("");
        $display("  +------------------------------------------------------------------------+");
        $display("  |  STARTING: %-58s|", name);
        $display("  +------------------------------------------------------------------------+");

        // Reset between tests (except the very first one – DUT is already reset)
        if (test_names.size() > 0)
            base.reset_phase();

        // Record scoreboard state before test
        pass_before = env.scb.is_pass();

        case (name)
            "test_basic": begin
                test_basic #(FIFO_WIDTH, FIFO_DEPTH) t = new(base);
                t.run();
            end
            "test_fill_drain": begin
                test_fill_drain #(FIFO_WIDTH, FIFO_DEPTH) t = new(base);
                t.run();
            end
            "test_simultaneous_rw": begin
                test_simultaneous_rw #(FIFO_WIDTH, FIFO_DEPTH) t = new(base);
                t.run();
            end
            "test_overflow_underflow": begin
                test_overflow_underflow #(FIFO_WIDTH, FIFO_DEPTH) t = new(base);
                t.run();
            end
            "test_reset": begin
                test_reset #(FIFO_WIDTH, FIFO_DEPTH) t = new(base);
                t.run();
            end
            "test_pointer_wrap": begin
                test_pointer_wrap #(FIFO_WIDTH, FIFO_DEPTH) t = new(base);
                t.run();
            end
            "test_clock_ratio": begin
                test_clock_ratio #(FIFO_WIDTH, FIFO_DEPTH) t = new(base);
                t.run();
            end
            default: begin
                $display("[RUNNER] ERROR: Unknown test name '%s'", name);
                $display("[RUNNER] Available tests:");
                $display("[RUNNER]   test_basic");
                $display("[RUNNER]   test_fill_drain");
                $display("[RUNNER]   test_simultaneous_rw");
                $display("[RUNNER]   test_overflow_underflow");
                $display("[RUNNER]   test_reset");
                $display("[RUNNER]   test_pointer_wrap");
                $display("[RUNNER]   test_clock_ratio");
                test_names.push_back(name);
                test_results.push_back("UNKNOWN");
                return;
            end
        endcase

        // Print scoreboard report for this test
        env.scb.report();

        // Record result
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
    // print_final_summary() – table of all test results
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
