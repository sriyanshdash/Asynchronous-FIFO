//=============================================================================
// File        : fifo_scoreboard.sv
// Description : Scoreboard (reference model) for the Async FIFO testbench.
//
//               Reference model : a SV built-in queue (FIFO order).
//               Write checker   : pushes observed write data onto the queue.
//               Read  checker   : pops the front entry and compares it with
//                                 the data_out captured by the monitor.
//
//               Limitations (first-stage testbench):
//               – No overflow / underflow assertion checking.
//               – No fifo_full / fifo_empty flag cross-checking.
//               – Simple pass/fail compare only.
//=============================================================================

`ifndef FIFO_SCOREBOARD_SV
`define FIFO_SCOREBOARD_SV

`timescale 1ns/1ps

`include "fifo_transaction.sv"

class fifo_scoreboard #(parameter FIFO_WIDTH = 64);

    //-------------------------------------------------------------------------
    // Mailboxes from the monitor
    //-------------------------------------------------------------------------
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx;
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx;

    //-------------------------------------------------------------------------
    // Reference model : FIFO-ordered queue of expected read data
    //-------------------------------------------------------------------------
    bit [FIFO_WIDTH-1:0] ref_q[$];

    //-------------------------------------------------------------------------
    // Statistics counters
    //-------------------------------------------------------------------------
    int wr_count;
    int rd_count;
    int pass_count;
    int fail_count;

    //-------------------------------------------------------------------------
    // Constructor
    //-------------------------------------------------------------------------
    function new(
        mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx
    );
        this.wr_scb_mbx = wr_scb_mbx;
        this.rd_scb_mbx = rd_scb_mbx;
        wr_count        = 0;
        rd_count        = 0;
        pass_count      = 0;
        fail_count      = 0;
    endfunction

    //-------------------------------------------------------------------------
    // run() – launch write and read checkers in parallel background threads
    //-------------------------------------------------------------------------
    task run();
        $display("[SCB] Starting at %0t", $time);
        fork
            check_writes();
            check_reads();
        join_none
    endtask

    //=========================================================================
    // Write checker
    // Receives a write transaction from the monitor and pushes the data
    // onto the reference queue.
    //=========================================================================
    task check_writes();
        fifo_transaction #(FIFO_WIDTH) txn;
        forever begin
            wr_scb_mbx.get(txn);
            ref_q.push_back(txn.data);
            wr_count++;
            $display("[SCB-WR] @%0t  PUSH  data=0x%016h   ref_q depth=%0d",
                     $time, txn.data, ref_q.size());
        end
    endtask

    //=========================================================================
    // Read checker
    // Receives a read transaction (with captured data_out) from the monitor,
    // pops the expected value from the reference queue, and compares.
    //=========================================================================
    task check_reads();
        fifo_transaction #(FIFO_WIDTH) txn;
        bit [FIFO_WIDTH-1:0] exp_data;
        forever begin
            rd_scb_mbx.get(txn);
            rd_count++;

            if (ref_q.size() == 0) begin
                $display("[SCB-RD] @%0t  ERROR : Read received but ref_q is EMPTY  (data_out=0x%016h)",
                         $time, txn.data_out);
                fail_count++;
            end else begin
                exp_data = ref_q.pop_front();
                if (txn.data_out === exp_data) begin
                    $display("[SCB-RD] @%0t  PASS  : data_out=0x%016h  ==  exp=0x%016h",
                             $time, txn.data_out, exp_data);
                    pass_count++;
                end else begin
                    $display("[SCB-RD] @%0t  FAIL  : data_out=0x%016h  !=  exp=0x%016h",
                             $time, txn.data_out, exp_data);
                    fail_count++;
                end
            end
        end
    endtask

    //=========================================================================
    // report() – print final simulation summary; called from the test
    //=========================================================================
    function void report();
        $display("");
        $display("==============================================================");
        $display("             ASYNC FIFO SCOREBOARD – FINAL REPORT             ");
        $display("==============================================================");
        $display("  Write transactions seen  : %0d", wr_count);
        $display("  Read  transactions seen  : %0d", rd_count);
        $display("  Ref-queue residual       : %0d  (expect 0 if wr==rd count)",
                 ref_q.size());
        $display("  Checks PASSED            : %0d", pass_count);
        $display("  Checks FAILED            : %0d", fail_count);
        $display("--------------------------------------------------------------");
        if (fail_count == 0 && ref_q.size() == 0)
            $display("  RESULT  >>  ** SIMULATION PASSED **");
        else
            $display("  RESULT  >>  ** SIMULATION FAILED **");
        $display("==============================================================");
        $display("");
    endfunction

endclass : fifo_scoreboard

`endif // FIFO_SCOREBOARD_SV
