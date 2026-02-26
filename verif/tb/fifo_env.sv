//=============================================================================
// File        : fifo_env.sv
// Description : Testbench environment for the Async FIFO.
//               Instantiates driver, monitor, and scoreboard; creates and
//               wires up all shared mailboxes; provides a single run() entry
//               point used by the test.
//=============================================================================

`ifndef FIFO_ENV_SV
`define FIFO_ENV_SV

`timescale 1ns/1ps

`include "fifo_interface.sv"
`include "fifo_transaction.sv"
`include "fifo_driver.sv"
`include "fifo_monitor.sv"
`include "fifo_scoreboard.sv"

class fifo_env #(parameter FIFO_WIDTH = 64);

    //-------------------------------------------------------------------------
    // Component handles
    //-------------------------------------------------------------------------
    fifo_driver     #(FIFO_WIDTH) drv;
    fifo_monitor    #(FIFO_WIDTH) mon;
    fifo_scoreboard #(FIFO_WIDTH) scb;

    //-------------------------------------------------------------------------
    // Mailboxes
    //   wr_mbx     : test  → driver  (write transactions)
    //   rd_mbx     : test  → driver  (read  transactions)
    //   wr_scb_mbx : monitor → scoreboard (write observations)
    //   rd_scb_mbx : monitor → scoreboard (read  observations)
    //-------------------------------------------------------------------------
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_mbx;
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_mbx;
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx;
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx;

    //-------------------------------------------------------------------------
    // Virtual interface handle
    //-------------------------------------------------------------------------
    virtual fifo_if #(FIFO_WIDTH) vif;

    //-------------------------------------------------------------------------
    // Constructor – builds mailboxes and all components, wires them together
    //-------------------------------------------------------------------------
    function new(virtual fifo_if #(FIFO_WIDTH) vif);
        this.vif = vif;

        // Create unbounded mailboxes
        wr_mbx     = new();
        rd_mbx     = new();
        wr_scb_mbx = new();
        rd_scb_mbx = new();

        // Instantiate components and inject their dependencies
        drv = new(vif, wr_mbx, rd_mbx);
        mon = new(vif, wr_scb_mbx, rd_scb_mbx);
        scb = new(wr_scb_mbx, rd_scb_mbx);
    endfunction

    //-------------------------------------------------------------------------
    // run() – start all components; each launches its own background threads
    //-------------------------------------------------------------------------
    task run();
        $display("[ENV] Building and starting environment at %0t", $time);
        fork
            drv.run();
            mon.run();
            scb.run();
        join_none
        $display("[ENV] All components running.");
    endtask

endclass : fifo_env

`endif // FIFO_ENV_SV
