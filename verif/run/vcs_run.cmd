vcs -full64 \
+define+DUMP_ON \
+define+SYNOPSYS \
-l vcs_compile.log \
+vcs+lic+wait \
-sverilog \
-timescale=1ns/1ps \
+incdir+$SIG_FIFO_HOME/verif/tb \
-f $SIG_FIFO_HOME/rtl/sig_async_fifo_flst.f \
#-f $SIG_FIFO_HOME/verif/tb/sig_async_fifo_tb_flst.f \
-debug_access+all

./simv \
+ntb_random_seed=777 -l vcs.log \
