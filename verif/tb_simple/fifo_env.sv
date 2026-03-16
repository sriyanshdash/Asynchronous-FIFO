// =============================================================================
// File        : fifo_env.sv
// Description : Environment — the "container" that creates and wires together
//               all testbench components (driver, monitor, scoreboard).
//
//               Data flow:
//                 Test → [wr_mbx] → Driver → DUT signals
//                 Test → [rd_mbx] → Driver → DUT signals
//                 DUT signals → Monitor → [wr_scb_mbx] → Scoreboard
//                 DUT signals → Monitor → [rd_scb_mbx] → Scoreboard
// =============================================================================

`ifndef FIFO_ENV_SIMPLE_SV
`define FIFO_ENV_SIMPLE_SV

`timescale 1ns/1ps

class fifo_env #(parameter FIFO_WIDTH = 64);

    // Components
    fifo_driver     #(FIFO_WIDTH) drv;
    fifo_monitor    #(FIFO_WIDTH) mon;
    fifo_scoreboard #(FIFO_WIDTH) scb;

    // Mailboxes (the "pipes" connecting components)
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_mbx;       // Test → Driver (writes)
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_mbx;       // Test → Driver (reads)
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx;   // Monitor → Scoreboard (writes)
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx;   // Monitor → Scoreboard (reads)

    // Virtual interface
    virtual fifo_if #(FIFO_WIDTH) vif;

    // Constructor — builds everything and wires it up
    function new(virtual fifo_if #(FIFO_WIDTH) vif);
        this.vif = vif;

        // Create mailboxes (unbounded)
        wr_mbx     = new();
        rd_mbx     = new();
        wr_scb_mbx = new();
        rd_scb_mbx = new();

        // Create components and inject their dependencies
        drv = new(vif, wr_mbx, rd_mbx);
        mon = new(vif, wr_scb_mbx, rd_scb_mbx);
        scb = new(wr_scb_mbx, rd_scb_mbx);
    endfunction

    // Start all components running
    task run();
        fork
            drv.run();
            mon.run();
            scb.run();
        join_none
    endtask

    // Reset between tests — drain ALL mailboxes and clear scoreboard
    function void reset();
        fifo_transaction #(FIFO_WIDTH) tmp;
        // Drain test → driver mailboxes
        while (wr_mbx.try_get(tmp));
        while (rd_mbx.try_get(tmp));
        // Drain monitor → scoreboard mailboxes (stale captures)
        while (wr_scb_mbx.try_get(tmp));
        while (rd_scb_mbx.try_get(tmp));
        scb.reset();
    endfunction

endclass : fifo_env

`endif
