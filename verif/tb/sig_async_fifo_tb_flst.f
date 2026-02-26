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

// ---- 1. Interface : must be first (defines fifo_if and its modports) --------
${SIG_FIFO_HOME}/verif/tb/fifo_interface.sv

// ---- 2. Transaction : defines fifo_txn_type_e enum + fifo_transaction class -
${SIG_FIFO_HOME}/verif/tb/fifo_transaction.sv

// ---- 3. Driver : depends on fifo_if and fifo_transaction --------------------
${SIG_FIFO_HOME}/verif/tb/fifo_driver.sv

// ---- 4. Monitor : depends on fifo_if and fifo_transaction -------------------
${SIG_FIFO_HOME}/verif/tb/fifo_monitor.sv

// ---- 5. Scoreboard : depends on fifo_transaction ----------------------------
${SIG_FIFO_HOME}/verif/tb/fifo_scoreboard.sv

// ---- 6. Environment : depends on driver, monitor, scoreboard ----------------
${SIG_FIFO_HOME}/verif/tb/fifo_env.sv

// ---- 7. Test : depends on fifo_env ------------------------------------------
${SIG_FIFO_HOME}/verif/tb/fifo_test.sv

// ---- 8. TB Top : top-level module, depends on fifo_if + fifo_test -----------
${SIG_FIFO_HOME}/verif/tb/tb_top.sv
