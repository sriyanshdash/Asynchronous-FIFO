// =============================================================================
// File        : fifo_driver.sv
// Description : Driver — takes transactions from mailboxes and drives them
//               onto the DUT interface signals.
//
//               Two independent tasks run in parallel:
//                 drive_write() — handles write-domain (wrclk)
//                 drive_read()  — handles read-domain  (rdclk)
//
//               IMPORTANT TIMING: All signals are applied #1ns AFTER the clock
//               edge to avoid delta-cycle races with the DUT and monitor.
// =============================================================================

`ifndef FIFO_DRIVER_SIMPLE_SV
`define FIFO_DRIVER_SIMPLE_SV

`timescale 1ns/1ps

class fifo_driver #(parameter FIFO_WIDTH = 64);

    // Virtual interface — our connection to the DUT signals
    virtual fifo_if #(FIFO_WIDTH) vif;

    // Mailboxes — tests put transactions here, driver pulls them out
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_mbx;   // Write transactions
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_mbx;   // Read transactions

    // Count how many operations we drove
    int wr_count = 0;
    int rd_count = 0;

    // Constructor — takes interface and mailbox handles
    function new(
        virtual fifo_if #(FIFO_WIDTH)             vif,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_mbx,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_mbx
    );
        this.vif    = vif;
        this.wr_mbx = wr_mbx;
        this.rd_mbx = rd_mbx;
    endfunction

    // Start the driver — launches write and read drivers in parallel
    task run();
        // Set safe defaults
        vif.wr_en   = 0;
        vif.data_in = '0;
        vif.rd_en   = 0;

        // Launch both domain drivers as parallel threads
        fork
            drive_write();
            drive_read();
        join_none
    endtask

    // ---- Write-domain driver (runs on wrclk) ----
    // Pulls write transactions from wr_mbx and drives them onto the interface.
    // If FIFO is full, waits until space is available before driving.
    task drive_write();
        fifo_transaction #(FIFO_WIDTH) txn;

        forever begin
            // Wait for a transaction from the test
            wr_mbx.get(txn);

            if (txn.wr_en) begin
                // Wait until FIFO has space
                while (vif.fifo_full) @(posedge vif.wrclk);

                // Drive the write: #1 after edge avoids delta races
                @(posedge vif.wrclk); #1;
                vif.wr_en   = 1;
                vif.data_in = txn.data;
                wr_count++;

                // Check for back-to-back writes (burst mode)
                // Keep wr_en high if next transaction is also a write
                while (wr_mbx.try_peek(txn)) begin
                    if (!txn.wr_en) break;   // Next one isn't a write, stop burst
                    wr_mbx.get(txn);         // Consume it

                    if (vif.fifo_full) begin
                        // FIFO became full mid-burst — deassert immediately
                        // to prevent stale data from being written
                        vif.wr_en   = 0;
                        vif.data_in = '0;
                        while (vif.fifo_full) @(posedge vif.wrclk);
                        @(posedge vif.wrclk); #1;
                        vif.wr_en   = 1;
                        vif.data_in = txn.data;
                    end else begin
                        @(posedge vif.wrclk); #1;
                        vif.data_in = txn.data;
                    end
                    wr_count++;
                end

                // End of burst — deassert write enable
                @(posedge vif.wrclk); #1;
                vif.wr_en   = 0;
                vif.data_in = '0;
            end
        end
    endtask

    // ---- Read-domain driver (runs on rdclk) ----
    // Pulls read transactions from rd_mbx and asserts rd_en.
    // If FIFO is empty, waits until data is available before reading.
    task drive_read();
        fifo_transaction #(FIFO_WIDTH) txn;

        forever begin
            rd_mbx.get(txn);

            if (txn.rd_en) begin
                // Wait until FIFO has data
                while (vif.fifo_empty) @(posedge vif.rdclk);

                @(posedge vif.rdclk); #1;
                vif.rd_en = 1;
                rd_count++;

                // Check for back-to-back reads (burst mode)
                while (rd_mbx.try_peek(txn)) begin
                    if (!txn.rd_en) break;
                    rd_mbx.get(txn);

                    if (vif.fifo_empty) begin
                        vif.rd_en = 0;
                        while (vif.fifo_empty) @(posedge vif.rdclk);
                        @(posedge vif.rdclk); #1;
                        vif.rd_en = 1;
                    end else begin
                        @(posedge vif.rdclk); #1;
                    end
                    rd_count++;
                end

                @(posedge vif.rdclk); #1;
                vif.rd_en = 0;
            end
        end
    endtask

endclass : fifo_driver

`endif
