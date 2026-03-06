#!/bin/csh -f

mkdir ${1}

# Usage:
#   cad_run.cmd <dir>                     -> runs all tests
#   cad_run.cmd <dir> test_stress         -> runs only the stress test
#   cad_run.cmd <dir> test_basic          -> runs only test_basic
#   cad_run.cmd <dir> all                 -> runs all tests (explicit)

# Default TEST_NAME to "all" if $2 is not provided
if ( "$2" == "" ) then
    set TEST_NAME = "all"
else
    set TEST_NAME = "$2"
endif

xrun \
+define+DUMP_ON \
+define+CADENCE \
-incdir $SIG_FIFO_HOME/verif/tb/ \
-f $SIG_FIFO_HOME/rtl/sig_async_fifo_flst.f \
-f $SIG_FIFO_HOME/verif/tb/sig_async_fifo_tb_flst.f  \
-svseed 1234 \
+nowarn_AAMNSD \
+access+rw \
-disable_sem2009 \
+sv \
+timescale+1ns/1ps \
+TEST_NAME=${TEST_NAME}


