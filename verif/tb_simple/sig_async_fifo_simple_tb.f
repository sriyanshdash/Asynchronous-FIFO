// =============================================================================
// File        : sig_async_fifo_simple_tb.f
// Description : Filelist for the Simplified Async FIFO Testbench.
//
//               Only the top-level file is listed here because fifo_tb_top.sv
//               `include's all other TB files (interface, transaction, driver,
//               monitor, scoreboard, env, tests). Listing them separately
//               would cause double-compilation and $unit scope errors.
//
// Usage       : xrun -f $SIG_FIFO_HOME/rtl/sig_async_fifo_flst.f \
//                    -f $SIG_FIFO_HOME/verif/tb_simple/sig_async_fifo_simple_tb.f
// =============================================================================

// ---- TB Top (includes all other TB files) ----
${SIG_FIFO_HOME}/verif/tb_simple/fifo_tb_top.sv
