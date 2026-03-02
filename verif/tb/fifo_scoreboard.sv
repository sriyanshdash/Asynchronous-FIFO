//=============================================================================
// File        : fifo_scoreboard.sv
// Description : Scoreboard (reference model) for the Async FIFO testbench.
//
//               Reference model : a SV built-in queue (FIFO order).
//               Write checker   : pushes observed write data onto the queue
//                                 and stores write-side records for display.
//               Read  checker   : pops the front entry, compares with data_out,
//                                 and prints a grouped transaction block showing
//                                 the full lifecycle (Driver/Monitor/Scoreboard
//                                 timestamps) for both write and read sides.
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
    // Write-side record logs  (parallel queues, popped by read checker)
    // These store the write-side info so the grouped display can show it
    // when the matching read completes.
    //-------------------------------------------------------------------------
    bit [FIFO_WIDTH-1:0] wr_data_log[$];
    time                 wr_mon_times[$];
    time                 wr_scb_times[$];
    bit                  wr_full_log[$];
    bit                  wr_empty_log[$];
    int                  wr_depth_log[$];  // ref_q depth AFTER push

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
    // run() - launch write and read checkers in parallel background threads
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
    // Receives a write transaction from the monitor, pushes data onto the
    // reference queue, and stores all write-side info for the grouped display.
    //=========================================================================
    task check_writes();
        fifo_transaction #(FIFO_WIDTH) txn;
        forever begin
            wr_scb_mbx.get(txn);
            ref_q.push_back(txn.data);
            wr_count++;

            // Store write-side record for grouped display later
            wr_data_log.push_back(txn.data);
            wr_mon_times.push_back(txn.capture_time);
            wr_scb_times.push_back($time);
            wr_full_log.push_back(txn.fifo_full);
            wr_empty_log.push_back(txn.fifo_empty);
            wr_depth_log.push_back(ref_q.size());
        end
    endtask

    //=========================================================================
    // Read checker
    // Receives a read transaction (with captured data_out) from the monitor,
    // pops the expected value from the reference queue, retrieves the matching
    // write-side record, and prints a grouped transaction block.
    //=========================================================================
    task check_reads();
        fifo_transaction #(FIFO_WIDTH) txn;
        bit [FIFO_WIDTH-1:0] exp_data;

        // Write-side record fields (popped from log queues)
        bit [FIFO_WIDTH-1:0] wr_data;
        time                 wr_drv_t, wr_mon_t, wr_scb_t;
        bit                  wr_full, wr_empty;
        int                  wr_depth;

        // Read-side fields
        time                 rd_drv_t, rd_mon_t, rd_scb_t;
        int                  rd_depth;

        string               result_str;
        bit                  is_pass;

        forever begin
            rd_scb_mbx.get(txn);
            rd_count++;
            rd_scb_t = $time;
            rd_mon_t = txn.capture_time;

            // Pop driver read timestamp
            if (fifo_txn_log::rd_drv_times.size() > 0)
                rd_drv_t = fifo_txn_log::rd_drv_times.pop_front();
            else
                rd_drv_t = 0;

            if (ref_q.size() == 0) begin
                // ERROR: ref queue empty
                fail_count++;
                display_error_block(rd_count, txn.data_out, rd_drv_t, rd_mon_t, rd_scb_t,
                                    txn.fifo_full, txn.fifo_empty);
            end else begin
                exp_data = ref_q.pop_front();
                rd_depth = ref_q.size();

                // Pop write-side record
                wr_data  = wr_data_log.pop_front();
                wr_mon_t = wr_mon_times.pop_front();
                wr_scb_t = wr_scb_times.pop_front();
                wr_full  = wr_full_log.pop_front();
                wr_empty = wr_empty_log.pop_front();
                wr_depth = wr_depth_log.pop_front();

                // Pop driver write timestamp
                if (fifo_txn_log::wr_drv_times.size() > 0)
                    wr_drv_t = fifo_txn_log::wr_drv_times.pop_front();
                else
                    wr_drv_t = 0;

                is_pass = (txn.data_out === exp_data);
                if (is_pass) begin
                    pass_count++;
                    result_str = "PASS";
                end else begin
                    fail_count++;
                    result_str = "FAIL";
                end

                display_txn_block(
                    rd_count, result_str,
                    wr_data, wr_drv_t, wr_mon_t, wr_scb_t, wr_full, wr_empty, wr_depth,
                    txn.data_out, rd_drv_t, rd_mon_t, rd_scb_t, txn.fifo_full, txn.fifo_empty, rd_depth,
                    exp_data
                );
            end
        end
    endtask

    //=========================================================================
    // display_txn_block() - print a grouped transaction block
    //=========================================================================
    function void display_txn_block(
        int                  txn_num,
        string               result,
        // Write side
        bit [FIFO_WIDTH-1:0] wr_data,
        time                 wr_drv_t,
        time                 wr_mon_t,
        time                 wr_scb_t,
        bit                  wr_full,
        bit                  wr_empty,
        int                  wr_depth,
        // Read side
        bit [FIFO_WIDTH-1:0] rd_data,
        time                 rd_drv_t,
        time                 rd_mon_t,
        time                 rd_scb_t,
        bit                  rd_full,
        bit                  rd_empty,
        int                  rd_depth,
        // Expected
        bit [FIFO_WIDTH-1:0] exp_data
    );
        string wd, wm, ws, rd, rm, rs;

        wd = $sformatf("@ %0t", wr_drv_t);
        wm = $sformatf("@ %0t", wr_mon_t);
        ws = $sformatf("@ %0t", wr_scb_t);
        rd = $sformatf("@ %0t", rd_drv_t);
        rm = $sformatf("@ %0t", rd_mon_t);
        rs = $sformatf("@ %0t", rd_scb_t);

        $display("");
        $display("  ==========================================================================");
        $display("    TXN #%-4d                                                      [%4s]", txn_num, result);
        $display("  ==========================================================================");
        $display("    Data Written  : 0x%016h", wr_data);
        $display("    Data Read Out : 0x%016h", rd_data);
        if (rd_data !== exp_data)
            $display("    Expected      : 0x%016h   << MISMATCH >>", exp_data);
        $display("  --------------------------------------------------------------------------");
        $display("    %-14s | %-24s | %-24s", "Component", "WRITE Side", "READ Side");
        $display("    %-14s-+-%-24s-+-%-24s", "--------------", "------------------------", "------------------------");
        $display("    %-14s | %-24s | %-24s", "Driver", wd, rd);
        $display("    %-14s | %-24s | %-24s", "Monitor", wm, rm);
        $display("    %-14s | %-24s | %-24s", "Scoreboard", ws, rs);
        $display("  --------------------------------------------------------------------------");
        $display("    WR Flags : full=%0b  empty=%0b               RD Flags : full=%0b  empty=%0b",
                 wr_full, wr_empty, rd_full, rd_empty);
        $display("    Ref-Q after push : depth=%-3d                Ref-Q after pop  : depth=%-3d",
                 wr_depth, rd_depth);
        $display("  ==========================================================================");
    endfunction

    //=========================================================================
    // display_error_block() - print an error block when ref queue is empty
    //=========================================================================
    function void display_error_block(
        int                  txn_num,
        bit [FIFO_WIDTH-1:0] rd_data,
        time                 rd_drv_t,
        time                 rd_mon_t,
        time                 rd_scb_t,
        bit                  rd_full,
        bit                  rd_empty
    );
        $display("");
        $display("  ==========================================================================");
        $display("    TXN #%-4d                                                      [FAIL]", txn_num);
        $display("  ==========================================================================");
        $display("    ERROR : Read received but reference queue is EMPTY!");
        $display("    Data Read Out : 0x%016h", rd_data);
        $display("  --------------------------------------------------------------------------");
        $display("    Read Driver    : @ %0t", rd_drv_t);
        $display("    Read Monitor   : @ %0t", rd_mon_t);
        $display("    Read Scoreboard: @ %0t", rd_scb_t);
        $display("    RD Flags : full=%0b  empty=%0b", rd_full, rd_empty);
        $display("  ==========================================================================");
    endfunction

    //=========================================================================
    // reset() - clear all state so the scoreboard can be reused across tests
    //=========================================================================
    function void reset();
        ref_q.delete();
        wr_data_log.delete();
        wr_mon_times.delete();
        wr_scb_times.delete();
        wr_full_log.delete();
        wr_empty_log.delete();
        wr_depth_log.delete();
        wr_count   = 0;
        rd_count   = 0;
        pass_count = 0;
        fail_count = 0;
        // Also clear the static driver timestamp logs
        fifo_txn_log::wr_drv_times.delete();
        fifo_txn_log::rd_drv_times.delete();
    endfunction

    //=========================================================================
    // is_pass() - returns 1 if no failures and ref_q is drained
    //=========================================================================
    function bit is_pass();
        return (fail_count == 0 && ref_q.size() == 0);
    endfunction

    //=========================================================================
    // report() - print final simulation summary; called from the test
    //=========================================================================
    function void report();
        $display("");
        $display("");
        $display("  ==========================================================================");
        $display("                  ASYNC FIFO SCOREBOARD - FINAL REPORT                      ");
        $display("  ==========================================================================");
        $display("    Write transactions seen  : %0d", wr_count);
        $display("    Read  transactions seen  : %0d", rd_count);
        $display("    Ref-queue residual       : %0d  (expect 0 if wr==rd count)", ref_q.size());
        $display("  --------------------------------------------------------------------------");
        $display("    Checks PASSED            : %0d", pass_count);
        $display("    Checks FAILED            : %0d", fail_count);
        $display("  --------------------------------------------------------------------------");
        if (fail_count == 0 && ref_q.size() == 0)
            $display("    RESULT  >>  ** SIMULATION PASSED **");
        else
            $display("    RESULT  >>  ** SIMULATION FAILED **");
        $display("  ==========================================================================");
        $display("");
    endfunction

endclass : fifo_scoreboard

`endif // FIFO_SCOREBOARD_SV
