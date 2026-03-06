// =============================================================================
// File        : sig_async_fifo_tb_flst.f
// Description : Filelist for the Asynchronous FIFO SystemVerilog Testbench.
//               Listed in strict compile-order (dependencies before dependents).
//
// Usage       : Referenced via -f flag in cad_run.cmd / vcs_run.cmd.
//               Requires $SIG_FIFO_HOME to be set before invocation:
//                   source $SIG_FIFO_HOME/sourcefile.csh   (from project root)
//
// Environment : $SIG_FIFO_HOME = /scratch/users/sdash/ASSIGNMENT/ASYNC_FIFO_E
// =============================================================================

// ---- 1. Interface ----
${SIG_FIFO_HOME}/verif/tb/fifo_interface.sv

// ---- 2. Transaction ----
${SIG_FIFO_HOME}/verif/tb/fifo_transaction.sv

// ---- 3. Driver ----
${SIG_FIFO_HOME}/verif/tb/fifo_driver.sv

// ---- 4. Monitor ----
${SIG_FIFO_HOME}/verif/tb/fifo_monitor.sv

// ---- 5. Scoreboard ----
${SIG_FIFO_HOME}/verif/tb/fifo_scoreboard.sv

// ---- 6. Environment ----
${SIG_FIFO_HOME}/verif/tb/fifo_env.sv

// ---- 7. Test base ----
${SIG_FIFO_HOME}/verif/tb/fifo_test_base.sv

// ---- 8. Reset tests ----
${SIG_FIFO_HOME}/verif/tb/test_reset.sv
${SIG_FIFO_HOME}/verif/tb/test_reset_when_empty.sv
${SIG_FIFO_HOME}/verif/tb/test_reset_when_full.sv
${SIG_FIFO_HOME}/verif/tb/test_reset_during_write.sv
${SIG_FIFO_HOME}/verif/tb/test_reset_during_read.sv
${SIG_FIFO_HOME}/verif/tb/test_reset_partial_fill.sv

// ---- 9. Normal tests ----
${SIG_FIFO_HOME}/verif/tb/test_basic.sv
${SIG_FIFO_HOME}/verif/tb/test_fill_drain.sv
${SIG_FIFO_HOME}/verif/tb/test_simultaneous_rw.sv
${SIG_FIFO_HOME}/verif/tb/test_pointer_wrap.sv
${SIG_FIFO_HOME}/verif/tb/test_clock_ratio.sv
${SIG_FIFO_HOME}/verif/tb/test_single_entry.sv
${SIG_FIFO_HOME}/verif/tb/test_full_flag_timing.sv
${SIG_FIFO_HOME}/verif/tb/test_empty_flag_timing.sv
${SIG_FIFO_HOME}/verif/tb/test_almost_full.sv
${SIG_FIFO_HOME}/verif/tb/test_almost_empty.sv
${SIG_FIFO_HOME}/verif/tb/test_alternating_rw.sv
${SIG_FIFO_HOME}/verif/tb/test_burst_write_burst_read.sv
${SIG_FIFO_HOME}/verif/tb/test_data_integrity_patterns.sv
${SIG_FIFO_HOME}/verif/tb/test_fifo_depth_boundary.sv
${SIG_FIFO_HOME}/verif/tb/test_continuous_streaming.sv

// ---- 10. Negative tests ----
${SIG_FIFO_HOME}/verif/tb/test_overflow_underflow.sv
${SIG_FIFO_HOME}/verif/tb/test_write_when_full_data_check.sv
${SIG_FIFO_HOME}/verif/tb/test_read_when_empty_pointer_check.sv
${SIG_FIFO_HOME}/verif/tb/test_simultaneous_reset_write.sv
${SIG_FIFO_HOME}/verif/tb/test_simultaneous_reset_read.sv
${SIG_FIFO_HOME}/verif/tb/test_back_to_back_overflow.sv
${SIG_FIFO_HOME}/verif/tb/test_back_to_back_underflow.sv

// ---- 11. Stress test ----
${SIG_FIFO_HOME}/verif/tb/test_stress.sv

// ---- 12. Test runner ----
${SIG_FIFO_HOME}/verif/tb/fifo_test_runner.sv

// ---- 13. TB Top ----
${SIG_FIFO_HOME}/verif/tb/tb_top.sv
