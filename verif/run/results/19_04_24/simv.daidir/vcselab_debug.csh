#!/bin/csh -f

cd /data-sipc/users/smishra/workspace/ASYNC_FIFO_24/verif/run/results/19_04_24

#This ENV is used to avoid overriding current script in next vcselab run 
setenv SNPS_VCSELAB_SCRIPT_NO_OVERRIDE  1

/tools/SYNOPSYS/Products/vcs/T-2022.06/linux64/bin/vcselab $* \
    -o \
    simv \
    -nobanner \
    +vcs+lic+wait \

cd -

