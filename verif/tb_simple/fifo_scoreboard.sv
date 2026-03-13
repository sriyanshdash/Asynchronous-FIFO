// =============================================================================
// File        : fifo_scoreboard.sv
// Description : Scoreboard — the "checker" of the testbench.
//
//               How it works:
//                 1. Write checker receives write transactions from the monitor
//                    and pushes the written data onto a reference queue.
//                 2. Read checker receives read transactions from the monitor,
//                    pops the expected data from the queue, and compares it
//                    with the actual data_out from the DUT.
//                 3. If they match → PASS. If not → FAIL.
//
//               The reference queue acts as a "golden model" of the FIFO.
// =============================================================================

`ifndef FIFO_SCOREBOARD_SIMPLE_SV
`define FIFO_SCOREBOARD_SIMPLE_SV

`timescale 1ns/1ps

class fifo_scoreboard #(parameter FIFO_WIDTH = 64);

    // Mailboxes from the monitor
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx;
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx;

    // Reference queue — our "golden model" of the FIFO
    // Write checker pushes data in, read checker pops and compares
    bit [FIFO_WIDTH-1:0] ref_queue[$];

    // Counters
    int wr_count   = 0;
    int rd_count   = 0;
    int pass_count = 0;
    int fail_count = 0;

    // Constructor
    function new(
        mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx
    );
        this.wr_scb_mbx = wr_scb_mbx;
        this.rd_scb_mbx = rd_scb_mbx;
    endfunction

    // Start both checkers
    task run();
        fork
            check_writes();
            check_reads();
        join_none
    endtask

    // ---- Write Checker ----
    // Every time the monitor sees a valid write, we push the data
    // into our reference queue. This is our expected read order.
    task check_writes();
        fifo_transaction #(FIFO_WIDTH) txn;

        forever begin
            wr_scb_mbx.get(txn);
            ref_queue.push_back(txn.data);
            wr_count++;
        end
    endtask

    // ---- Read Checker ----
    // Every time the monitor sees a valid read (with data_out),
    // we pop the expected value from the ref queue and compare.
    task check_reads();
        fifo_transaction #(FIFO_WIDTH) txn;
        bit [FIFO_WIDTH-1:0] expected;

        forever begin
            rd_scb_mbx.get(txn);
            rd_count++;

            if (ref_queue.size() == 0) begin
                // Read happened but we have no expected data — error!
                fail_count++;
                $display("[SCB] FAIL #%0d @ %0t: Read but ref queue EMPTY! Got=0x%016h",
                         rd_count, $time, txn.data_out);
            end else begin
                expected = ref_queue.pop_front();

                if (txn.data_out === expected) begin
                    pass_count++;
                    $display("[SCB] PASS #%0d @ %0t: Data=0x%016h",
                             rd_count, $time, txn.data_out);
                end else begin
                    fail_count++;
                    $display("[SCB] FAIL #%0d @ %0t: Expected=0x%016h  Got=0x%016h",
                             rd_count, $time, expected, txn.data_out);
                end
            end
        end
    endtask

    // ---- Reset ----
    // Clear all state between tests so they don't affect each other
    function void reset();
        ref_queue.delete();
        wr_count   = 0;
        rd_count   = 0;
        pass_count = 0;
        fail_count = 0;
    endfunction

    // ---- Did this test pass? ----
    function bit is_pass();
        return (fail_count == 0) && (ref_queue.size() == 0);
    endfunction

    // ---- Print report for one test ----
    function void report(string test_name = "");
        $display("");
        $display("  ==========================================================================");
        $display("    SCOREBOARD REPORT  %s", test_name);
        $display("  ==========================================================================");
        $display("    Writes seen   : %0d", wr_count);
        $display("    Reads seen    : %0d", rd_count);
        $display("    Queue residual: %0d  (should be 0)", ref_queue.size());
        $display("    PASSED        : %0d", pass_count);
        $display("    FAILED        : %0d", fail_count);
        $display("  --------------------------------------------------------------------------");
        if (is_pass())
            $display("    RESULT >> ** PASSED **");
        else
            $display("    RESULT >> ** FAILED **");
        $display("  ==========================================================================");
    endfunction

endclass : fifo_scoreboard

`endif
