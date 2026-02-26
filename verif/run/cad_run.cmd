#!/bin/csh -f

mkdir ${1}
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


