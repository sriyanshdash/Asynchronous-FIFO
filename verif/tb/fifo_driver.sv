//=============================================================================
// File        : fifo_driver.sv
// Description : Driver for the Async FIFO testbench.
//               Two independent tasks drive the write and read clock domains
//               concurrently via separate mailboxes.
//
//               Key timing note:
//               – Stimulus is applied #1ns AFTER a clock edge to avoid races
//                 with synchronous DUT logic and the monitor.
//               – The driver waits for fifo_full/fifo_empty to clear before
//                 asserting enables, so every transaction in the mailbox is
//                 guaranteed to actually execute on the DUT.
//=============================================================================

`ifndef FIFO_DRIVER_SV
`define FIFO_DRIVER_SV

`timescale 1ns/1ps

`include "fifo_interface.sv"
`include "fifo_transaction.sv"

class fifo_driver #(parameter FIFO_WIDTH = 64);

    //-------------------------------------------------------------------------
    // Virtual interface handle
    //-------------------------------------------------------------------------
    virtual fifo_if #(FIFO_WIDTH) vif;

    //-------------------------------------------------------------------------
    // Mailboxes  (populated by the test / generator)
    //-------------------------------------------------------------------------
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_mbx;  // Write-side transactions
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_mbx;  // Read-side  transactions

    //-------------------------------------------------------------------------
    // Statistics
    //-------------------------------------------------------------------------
    int wr_count;
    int rd_count;

    //-------------------------------------------------------------------------
    // Constructor
    //-------------------------------------------------------------------------
    function new(
        virtual fifo_if #(FIFO_WIDTH)             vif,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_mbx,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_mbx
    );
        this.vif    = vif;
        this.wr_mbx = wr_mbx;
        this.rd_mbx = rd_mbx;
        wr_count    = 0;
        rd_count    = 0;
    endfunction

    //-------------------------------------------------------------------------
    // run() – initialise outputs then launch both domain drivers in parallel
    //-------------------------------------------------------------------------
    task run();
        $display("[DRIVER] Starting at %0t", $time);
        // Safe defaults before any transaction is driven
        vif.wr_en   = 1'b0;
        vif.data_in = '0;
        vif.rd_en   = 1'b0;

        fork
            drive_write();
            drive_read();
        join_none
    endtask
/*
    //=========================================================================
    // Write-domain driver  (clocked on wrclk)
    //=========================================================================
    task drive_write();
        fifo_transaction #(FIFO_WIDTH) txn;
        forever begin
            wr_mbx.get(txn);             // block until a transaction is ready

            if (txn.wr_en) begin
                // Wait until the FIFO has at least one empty slot.
                // fifo_full is registered on wrclk so it may lag the actual
                // state by one cycle – the while loop handles this safely.
                while (vif.fifo_full) @(posedge vif.wrclk);

                // Align to clock edge, then apply stimulus #1 after edge
                // to satisfy setup time and avoid delta races with monitor.
                @(posedge vif.wrclk); #1;
                vif.wr_en   = 1'b1;
                vif.data_in = txn.data;
                $display("[DRIVER-WR] @%0t  wr_en=1  data=0x%016h", $time, txn.data);
                wr_count++;

                // Hold for exactly one write-clock period, then deassert
                @(posedge vif.wrclk); #1;
                vif.wr_en   = 1'b0;
                vif.data_in = '0;
            end
        end
    endtask

    //=========================================================================
    // Read-domain driver  (clocked on rdclk)
    //=========================================================================
    task drive_read();
        fifo_transaction #(FIFO_WIDTH) txn;
        forever begin
            rd_mbx.get(txn);             // block until a transaction is ready

            if (txn.rd_en) begin
                // Wait until the FIFO has data to read.
                // fifo_empty is registered on rdclk so the loop is safe.
                while (vif.fifo_empty) @(posedge vif.rdclk);

                // Align to clock edge, apply stimulus #1 after edge
                @(posedge vif.rdclk); #1;
                vif.rd_en = 1'b1;
                $display("[DRIVER-RD] @%0t  rd_en=1", $time);
                rd_count++;

                // Hold for exactly one read-clock period, then deassert
                @(posedge vif.rdclk); #1;
                vif.rd_en = 1'b0;
            end
        end
    endtask
*/

    //=========================================================================
    // Write-domain driver  (clocked on wrclk)
    //=========================================================================
    task drive_write();
        fifo_transaction #(FIFO_WIDTH) txn;
        forever begin
            wr_mbx.get(txn);

            if (txn.wr_en) begin
                // Wait until the FIFO has at least one empty slot
                while (vif.fifo_full) @(posedge vif.wrclk);

                // Apply stimulus #1ns after edge to avoid delta races
                @(posedge vif.wrclk); #1;
                vif.wr_en   = 1'b1;
                vif.data_in = txn.data;
                fifo_txn_log::wr_drv_times.push_back($time);
                wr_count++;

                // Sustain wr_en for back-to-back writes (burst)
                while (wr_mbx.try_peek(txn)) begin
                    if (!txn.wr_en) break;
                    wr_mbx.get(txn);
                    while (vif.fifo_full) @(posedge vif.wrclk);
                    @(posedge vif.wrclk); #1;
                    vif.data_in = txn.data;
                    fifo_txn_log::wr_drv_times.push_back($time);
                    wr_count++;
                end

                // Deassert only when no more consecutive writes are queued
                @(posedge vif.wrclk); #1;
                vif.wr_en   = 1'b0;
                vif.data_in = '0;
            end
        end
    endtask

    //=========================================================================
    // Read-domain driver  (clocked on rdclk)
    //=========================================================================
    task drive_read();
        fifo_transaction #(FIFO_WIDTH) txn;
        forever begin
            rd_mbx.get(txn);

            if (txn.rd_en) begin
                // Wait until the FIFO has data to read
                while (vif.fifo_empty) @(posedge vif.rdclk);

                // Apply stimulus #1ns after edge to avoid delta races
                @(posedge vif.rdclk); #1;
                vif.rd_en = 1'b1;
                fifo_txn_log::rd_drv_times.push_back($time);
                rd_count++;

                // Sustain rd_en for back-to-back reads (burst)
                while (rd_mbx.try_peek(txn)) begin
                    if (!txn.rd_en) break;
                    rd_mbx.get(txn);
                    while (vif.fifo_empty) @(posedge vif.rdclk);
                    @(posedge vif.rdclk); #1;
                    fifo_txn_log::rd_drv_times.push_back($time);
                    rd_count++;
                end

                // Deassert only when no more consecutive reads are queued
                @(posedge vif.rdclk); #1;
                vif.rd_en = 1'b0;
            end
        end
    endtask

endclass : fifo_driver

`endif // FIFO_DRIVER_SV
