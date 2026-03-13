#!/bin/csh -f

mkdir ${1}

# Usage:
#   cad_run_simple.cmd <dir>                          -> runs all 9 tests
#   cad_run_simple.cmd <dir> test_basic_rw            -> runs only test_basic_rw
#   cad_run_simple.cmd <dir> test_stress              -> runs only test_stress
#   cad_run_simple.cmd <dir> all                      -> runs all tests (explicit)
#
# Available tests:
#   test_basic_rw, test_fill_drain_wrap, test_burst_streaming,
#   test_flag_behavior, test_data_integrity, test_overflow_underflow,
#   test_reset_scenarios, test_clock_ratio, test_stress

# Default TEST_NAME to "all" if $2 is not provided
if ( "$2" == "" ) then
    set TEST_NAME = "all"
else
    set TEST_NAME = "$2"
endif

xrun \
+define+DUMP_ON \
+define+CADENCE \
-incdir $SIG_FIFO_HOME/verif/tb_simple/ \
-f $SIG_FIFO_HOME/rtl/sig_async_fifo_flst.f \
-f $SIG_FIFO_HOME/verif/tb_simple/sig_async_fifo_simple_tb.f  \
-svseed 1234 \
+nowarn_AAMNSD \
+access+rw \
-disable_sem2009 \
+sv \
+timescale+1ns/1ps \
+TEST_NAME=${TEST_NAME}

