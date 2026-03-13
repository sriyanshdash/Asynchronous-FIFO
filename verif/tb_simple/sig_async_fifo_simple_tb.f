// =============================================================================
// File        : sig_async_fifo_simple_tb.f
// Description : Filelist for the Simplified Async FIFO Testbench.
//               Listed in compile order (dependencies before dependents).
//
// Usage       : xrun -f $SIG_FIFO_HOME/rtl/sig_async_fifo_flst.f \
//                    -f $SIG_FIFO_HOME/verif/tb_simple/sig_async_fifo_simple_tb.f
// =============================================================================

// ---- 1. Interface ----
${SIG_FIFO_HOME}/verif/tb_simple/fifo_interface.sv

// ---- 2. Transaction ----
${SIG_FIFO_HOME}/verif/tb_simple/fifo_transaction.sv

// ---- 3. Driver ----
${SIG_FIFO_HOME}/verif/tb_simple/fifo_driver.sv

// ---- 4. Monitor ----
${SIG_FIFO_HOME}/verif/tb_simple/fifo_monitor.sv

// ---- 5. Scoreboard ----
${SIG_FIFO_HOME}/verif/tb_simple/fifo_scoreboard.sv

// ---- 6. Environment ----
${SIG_FIFO_HOME}/verif/tb_simple/fifo_env.sv

// ---- 7. Tests (all 9 tests in one file) ----
${SIG_FIFO_HOME}/verif/tb_simple/fifo_tests.sv

// ---- 8. TB Top (clocks, DUT, test runner) ----
${SIG_FIFO_HOME}/verif/tb_simple/fifo_tb_top.sv
