//=============================================================================
// File        : fifo_tb_single.sv
// Description : Single-file testbench for the Asynchronous FIFO.
//               All components are contained here in strict compile order:
//                 1. Interface
//                 2. Transaction (enum + class)
//                 3. Driver
//                 4. Monitor
//                 5. Scoreboard
//                 6. Environment
//                 7. Test
//                 8. TB Top module
//=============================================================================

`timescale 1ns/1ps

//=============================================================================
// 1. INTERFACE
//=============================================================================
interface fifo_if #(parameter FIFO_WIDTH = 64) (
    input logic wrclk,   // Write-domain clock  (driven from tb_top)
    input logic rdclk    // Read-domain  clock  (driven from tb_top)
);
    //-------------------------------------------------------------------------
    // Write-domain signals
    //-------------------------------------------------------------------------
    logic                  wrst_n;     // Active-low write-domain reset
    logic                  wr_en;      // Write enable
    logic [FIFO_WIDTH-1:0] data_in;    // Write data bus

    logic                  fifo_full;  // Full flag  (output from DUT)
    //-------------------------------------------------------------------------
    // Read-domain signals
    //-------------------------------------------------------------------------
    logic                  rrst_n;     // Active-low read-domain reset
    logic                  rd_en;      // Read enable
    logic [FIFO_WIDTH-1:0] data_out;   // Read data bus – registered in DUT
                                       // (valid 1 rdclk after rd_en assertion)
    logic                  fifo_empty; // Empty flag (output from DUT)

    modport dut_mp (
        input  wrclk, wrst_n, wr_en, data_in,
        input  rdclk, rrst_n, rd_en,
        output fifo_full,
        output data_out,
        output fifo_empty
    );

        input  wrclk,
        input  fifo_full,
        output wrst_n,
        output wr_en,
        output data_in
    );

    modport rd_tb_mp (
        input  rdclk,
        input  data_out,
        input  fifo_empty,
        output rrst_n,
        output rd_en
    );

    modport mon_mp (
        input wrclk, wrst_n, wr_en,  data_in,  fifo_full,
        input rdclk, rrst_n, rd_en,  data_out, fifo_empty
    );

endinterface : fifo_if


//=============================================================================
// 2. TRANSACTION
//=============================================================================
typedef enum logic [1:0] {
    FIFO_IDLE  = 2'b00,
    FIFO_WRITE = 2'b01,
    FIFO_READ  = 2'b10
} fifo_txn_type_e;

//-----------------------------------------------------------------------------
// Class : fifo_transaction
//-----------------------------------------------------------------------------
class fifo_transaction #(parameter FIFO_WIDTH = 64);

    rand bit                  wr_en;   // Write enable
    rand bit                  rd_en;   // Read  enable
    rand bit [FIFO_WIDTH-1:0] data;    // Write data (ignored on pure reads)

    bit [FIFO_WIDTH-1:0] data_out;    // Read data captured by monitor
    bit                  fifo_full;   // Full  flag observed at sample time
    bit                  fifo_empty;  // Empty flag observed at sample time

    // Set by monitor or test to classify the transaction
    fifo_txn_type_e txn_type;

    //-------------------------------------------------------------------------
    // Constraints
    //-------------------------------------------------------------------------


    //-------------------------------------------------------------------------
    // display() – print transaction contents to transcript
    //-------------------------------------------------------------------------
    function void display(string tag = "TXN");
        $display("[%0t] [%-8s] type=%-6s  wr_en=%0b  rd_en=%0b  data=0x%016h | full=%0b  empty=%0b",
                 $time, tag, txn_type.name(),
                 wr_en, rd_en, data, fifo_full, fifo_empty);
    endfunction

    //-------------------------------------------------------------------------
    // copy() – return a deep copy of this transaction
    //-------------------------------------------------------------------------
    function fifo_transaction #(FIFO_WIDTH) copy();
        fifo_transaction #(FIFO_WIDTH) t = new();
        t.wr_en      = this.wr_en;
        t.rd_en      = this.rd_en;
        t.data       = this.data;
        t.data_out   = this.data_out;
        t.fifo_full  = this.fifo_full;
        t.fifo_empty = this.fifo_empty;
        t.txn_type   = this.txn_type;
        return t;
    endfunction

endclass : fifo_transaction


//=============================================================================
// 3. DRIVER
//=============================================================================

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
        vif.wr_en   = 1'b0;
        vif.data_in = '0;
        vif.rd_en   = 1'b0;

        fork
            drive_write();
            drive_read();
        join_none
    endtask

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
                $display("[DRIVER-WR] @%0t  wr_en=1  data=0x%016h", $time, txn.data);
                wr_count++;

                // Sustain wr_en for back-to-back writes (burst)
                while (wr_mbx.try_peek(txn)) begin
                    if (!txn.wr_en) break;
                    wr_mbx.get(txn);
                    while (vif.fifo_full) @(posedge vif.wrclk);
                    @(posedge vif.wrclk); #1;
                    vif.data_in = txn.data;
                    $display("[DRIVER-WR] @%0t  wr_en=1  data=0x%016h (burst)", $time, txn.data);
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
                $display("[DRIVER-RD] @%0t  rd_en=1", $time);
                rd_count++;

                // Sustain rd_en for back-to-back reads (burst)
                while (rd_mbx.try_peek(txn)) begin
                    if (!txn.rd_en) break;
                    rd_mbx.get(txn);
                    while (vif.fifo_empty) @(posedge vif.rdclk);
                    @(posedge vif.rdclk); #1;
                    $display("[DRIVER-RD] @%0t  rd_en=1 (burst)", $time);
                    rd_count++;
                end

                // Deassert only when no more consecutive reads are queued
                @(posedge vif.rdclk); #1;
                vif.rd_en = 1'b0;
            end
        end
    endtask

endclass : fifo_driver


//=============================================================================
// 4. MONITOR
//=============================================================================

class fifo_monitor #(parameter FIFO_WIDTH = 64);

    //-------------------------------------------------------------------------
    // Virtual interface handle
    //-------------------------------------------------------------------------
    virtual fifo_if #(FIFO_WIDTH) vif;

    //-------------------------------------------------------------------------
    // Mailboxes to scoreboard
    //-------------------------------------------------------------------------
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx;  // write observations
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx;  // read  observations

    //-------------------------------------------------------------------------
    // Constructor
    //-------------------------------------------------------------------------
    function new(
        virtual fifo_if #(FIFO_WIDTH)             vif,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx
    );
        this.vif        = vif;
        this.wr_scb_mbx = wr_scb_mbx;
        this.rd_scb_mbx = rd_scb_mbx;
    endfunction

    //-------------------------------------------------------------------------
    // run() – launch both domain monitors in parallel background threads
    //-------------------------------------------------------------------------
    task run();
        $display("[MONITOR] Starting at %0t", $time);
        fork
            monitor_write();
            monitor_read();
        join_none
    endtask

    //=========================================================================
    // Write-domain monitor  (samples on posedge wrclk)
    //=========================================================================
    task monitor_write();
        fifo_transaction #(FIFO_WIDTH) txn;
        forever begin
            @(posedge vif.wrclk);
            if (vif.wrst_n && vif.wr_en && !vif.fifo_full) begin
                txn            = new();
                txn.txn_type   = FIFO_WRITE;
                txn.wr_en      = vif.wr_en;
                txn.data       = vif.data_in;
                txn.fifo_full  = vif.fifo_full;
                txn.fifo_empty = vif.fifo_empty;
                wr_scb_mbx.put(txn);
                txn.display("MON-WR");
            end
        end
    endtask

    //=========================================================================
    // Read-domain monitor  (samples on posedge rdclk)
    //
    // Cycle N  : rd_en=1 & fifo_empty=0  → valid read request
    // Cycle N+1: data_out holds the read data  ← capture here
    //=========================================================================
    task monitor_read();
        fifo_transaction #(FIFO_WIDTH) txn;
        bit rd_was_valid;
        rd_was_valid = 1'b0;

        forever begin
            @(posedge vif.rdclk);

            // If the previous cycle was a valid read, data_out is stable now
            if (rd_was_valid) begin
                txn            = new();
                txn.txn_type   = FIFO_READ;
                txn.rd_en      = 1'b1;
                txn.data_out   = vif.data_out;
                txn.fifo_full  = vif.fifo_full;
                txn.fifo_empty = vif.fifo_empty;
                rd_scb_mbx.put(txn);
                txn.display("MON-RD");
            end

            // Update flag: was this clock cycle a valid read initiation?
            rd_was_valid = (vif.rrst_n && vif.rd_en && !vif.fifo_empty);
        end
    endtask

endclass : fifo_monitor


//=============================================================================
// 5. SCOREBOARD
//=============================================================================

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
    // Write checker – pushes observed write data onto the reference queue
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
    // Read checker – pops expected value and compares with captured data_out
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


//=============================================================================
// 6. ENVIRONMENT
//=============================================================================

class fifo_env #(parameter FIFO_WIDTH = 64);

    //-------------------------------------------------------------------------
    // Component handles
    //-------------------------------------------------------------------------
    fifo_driver     #(FIFO_WIDTH) drv;
    fifo_monitor    #(FIFO_WIDTH) mon;
    fifo_scoreboard #(FIFO_WIDTH) scb;

    //-------------------------------------------------------------------------
    // Mailboxes
    //   wr_mbx     : test     → driver     (write transactions)
    //   rd_mbx     : test     → driver     (read  transactions)
    //   wr_scb_mbx : monitor  → scoreboard (write observations)
    //   rd_scb_mbx : monitor  → scoreboard (read  observations)
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

        wr_mbx     = new();
        rd_mbx     = new();
        wr_scb_mbx = new();
        rd_scb_mbx = new();

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


//=============================================================================
// 7. TEST
//    Generates 20 writes then 20 reads; waits for drain; reports result.
//=============================================================================

class fifo_test #(
    parameter FIFO_WIDTH = 64,
    parameter NUM_TXNS   = 20
);

    //-------------------------------------------------------------------------
    // Handles
    //-------------------------------------------------------------------------
    fifo_env        #(FIFO_WIDTH) env;
    virtual fifo_if #(FIFO_WIDTH) vif;

    //-------------------------------------------------------------------------
    // Constructor
    //-------------------------------------------------------------------------
    function new(virtual fifo_if #(FIFO_WIDTH) vif);
        this.vif = vif;
        env      = new(vif);
    endfunction

    //-------------------------------------------------------------------------
    // run() – top-level test task
    //-------------------------------------------------------------------------
    task run();
        fifo_transaction #(FIFO_WIDTH) txn;

        $display("");
        $display("[TEST] ============================================");
        $display("[TEST]   Async FIFO – Basic Functional Test START  ");
        $display("[TEST]   WIDTH=%0d  NUM_TXNS=%0d", FIFO_WIDTH, NUM_TXNS);
        $display("[TEST] ============================================");

        // Start driver / monitor / scoreboard background threads
        env.run();

        //---------------------------------------------------------------------
        // Phase 1 : generate WRITE transactions
        //---------------------------------------------------------------------
        $display("[TEST] Phase 1: Generating %0d WRITE transactions...", NUM_TXNS);
        repeat(NUM_TXNS) begin
            txn = new();
            if (!txn.randomize() with { wr_en == 1'b1; rd_en == 1'b0; })
                $fatal(1, "[TEST] Randomize failed for write transaction");
            txn.txn_type = FIFO_WRITE;
            env.wr_mbx.put(txn);
        end
        $display("[TEST] All WRITE transactions queued.");

        //---------------------------------------------------------------------
        // Phase 2 : generate READ transactions
        //---------------------------------------------------------------------
        $display("[TEST] Phase 2: Generating %0d READ transactions...", NUM_TXNS);
        repeat(NUM_TXNS) begin
            txn          = new();
            txn.wr_en    = 1'b0;
            txn.rd_en    = 1'b1;
            txn.txn_type = FIFO_READ;
            env.rd_mbx.put(txn);
        end
        $display("[TEST] All READ transactions queued.");

        //---------------------------------------------------------------------
        // Phase 3 : Wait for all transactions to drain
        //---------------------------------------------------------------------
        $display("[TEST] Waiting for transactions to drain (10000 ns)...");
        #10000;

        //---------------------------------------------------------------------
        // Phase 4 : Report and finish
        //---------------------------------------------------------------------
        env.scb.report();
        $display("[TEST] ============================================");
        $display("[TEST]   Async FIFO – Basic Functional Test END    ");
        $display("[TEST] ============================================");
        $display("");
        $finish;
    endtask

endclass : fifo_test


//=============================================================================
// 8. TB TOP MODULE
//=============================================================================

module tb_top;

    //-------------------------------------------------------------------------
    // Parameters – match DUT defaults; override here if needed
    //-------------------------------------------------------------------------
    localparam int FIFO_DEPTH = 8;
    localparam int FIFO_WIDTH = 64;
    localparam int NUM_TXNS   = 20;   // transactions per direction in the test

    //-------------------------------------------------------------------------
    // Clock signals
    //   wrclk : 10 ns period  (100 MHz) – write domain
    //   rdclk : 13 ns period  (~77 MHz) – read domain (intentionally async)
    //-------------------------------------------------------------------------
    logic wrclk;
    logic rdclk;

    initial wrclk = 1'b0;
    always  #5   wrclk = ~wrclk;   // 10 ns period

    initial rdclk = 1'b0;
    always  #6.5 rdclk = ~rdclk;   // 13 ns period

    //-------------------------------------------------------------------------
    // Interface instantiation
    //-------------------------------------------------------------------------
    fifo_if #(FIFO_WIDTH) dut_if (
        .wrclk (wrclk),
        .rdclk (rdclk)
    );

    //-------------------------------------------------------------------------
    // DUT instantiation
    //-------------------------------------------------------------------------
    asynchronous_fifo #(
        .FIFO_DEPTH (FIFO_DEPTH),
        .FIFO_WIDTH (FIFO_WIDTH)
    ) dut (
        .wrclk      (dut_if.wrclk),
        .wrst_n     (dut_if.wrst_n),
        .rdclk      (dut_if.rdclk),
        .rrst_n     (dut_if.rrst_n),
        .wr_en      (dut_if.wr_en),
        .rd_en      (dut_if.rd_en),
        .data_in    (dut_if.data_in),
        .data_out   (dut_if.data_out),
        .fifo_full  (dut_if.fifo_full),
        .fifo_empty (dut_if.fifo_empty)
    );

    //-------------------------------------------------------------------------
    // Reset generation
    // Both resets held LOW for 5 write-clock cycles, then released together.
    //-------------------------------------------------------------------------
    initial begin
        dut_if.wrst_n  = 1'b0;
        dut_if.rrst_n  = 1'b0;
        dut_if.wr_en   = 1'b0;
        dut_if.rd_en   = 1'b0;
        dut_if.data_in = '0;

        repeat(5) @(posedge wrclk);
        @(posedge wrclk); #1;
        dut_if.wrst_n = 1'b1;
        dut_if.rrst_n = 1'b1;
        $display("[TB_TOP] Reset deasserted at %0t  (wrst_n=1, rrst_n=1)", $time);
    end

    //-------------------------------------------------------------------------
    // Test execution
    //-------------------------------------------------------------------------
    initial begin
        fifo_test #(FIFO_WIDTH, NUM_TXNS) test_h;

        wait (dut_if.wrst_n === 1'b1 && dut_if.rrst_n === 1'b1);
        @(posedge wrclk); #1;

        test_h = new(dut_if);
        test_h.run();
    end

    //-------------------------------------------------------------------------
    // Watchdog timer – prevents infinite hangs (100 µs ceiling)
    //-------------------------------------------------------------------------
    initial begin
        #100_000;
        $display("[TB_TOP] WATCHDOG: Simulation exceeded 100 µs – forcing $finish");
        $finish;
    end

    //-------------------------------------------------------------------------
    // Waveform dump (VCD)
    // Enable with +define+DUMP_ON on the xrun command line.
    // Open in SimVision: File -> Open Database -> filter "VCD Files (*.vcd)"
    //-------------------------------------------------------------------------
    initial begin
        `ifdef DUMP_ON
            $dumpfile("fifo_tb.vcd");
            $dumpvars(0, tb_top);
        `endif
    end

endmodule : tb_top
