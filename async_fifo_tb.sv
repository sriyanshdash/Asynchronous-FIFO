//=============================================================================
// File        : async_fifo_tb.sv
// Description : Complete Asynchronous FIFO Testbench — single-file compilation.
//               Contains all TB infrastructure + 28 test classes + tb_top.
//
//               Compile & run:
//                 xrun async_fifo_rtl.sv async_fifo_tb.sv +TEST_NAME=all
//                 xrun async_fifo_rtl.sv async_fifo_tb.sv +TEST_NAME=test_basic
//
//               Waveform dump:
//                 xrun ... +define+DUMP_ON
//                 xrun ... +define+DUMP_ON +define+CADENCE
//=============================================================================

`timescale 1ns/1ps

//=============================================================================
//  1. INTERFACE
//=============================================================================
interface fifo_if #(parameter FIFO_WIDTH = 64) (
    input logic wrclk,
    input logic rdclk
);
    logic                  wrst_n;
    logic                  wr_en;
    logic [FIFO_WIDTH-1:0] data_in;
    logic                  fifo_full;

    logic                  rrst_n;
    logic                  rd_en;
    logic [FIFO_WIDTH-1:0] data_out;
    logic                  fifo_empty;

    modport dut_mp (
        input  wrclk, wrst_n, wr_en, data_in,
        input  rdclk, rrst_n, rd_en,
        output fifo_full, output data_out, output fifo_empty
    );
    modport wr_tb_mp (
        input  wrclk, input  fifo_full,
        output wrst_n, output wr_en, output data_in
    );
    modport rd_tb_mp (
        input  rdclk, input  data_out, input  fifo_empty,
        output rrst_n, output rd_en
    );
    modport mon_mp (
        input wrclk, wrst_n, wr_en,  data_in,  fifo_full,
        input rdclk, rrst_n, rd_en,  data_out, fifo_empty
    );
endinterface : fifo_if

//=============================================================================
//  2. TRANSACTION
//=============================================================================
typedef enum logic [1:0] {
    FIFO_IDLE  = 2'b00,
    FIFO_WRITE = 2'b01,
    FIFO_READ  = 2'b10
} fifo_txn_type_e;

class fifo_transaction #(parameter FIFO_WIDTH = 64);
    rand bit                  wr_en;
    rand bit                  rd_en;
    rand bit [FIFO_WIDTH-1:0] data;

    bit [FIFO_WIDTH-1:0] data_out;
    bit                  fifo_full;
    bit                  fifo_empty;
    fifo_txn_type_e      txn_type;
    time                 capture_time;

    function void display(string tag = "TXN");
        $display("[%0t] [%-8s] type=%-6s  wr_en=%0b  rd_en=%0b  data=0x%016h | full=%0b  empty=%0b",
                 $time, tag, txn_type.name(),
                 wr_en, rd_en, data, fifo_full, fifo_empty);
    endfunction
endclass : fifo_transaction

class fifo_txn_log;
    static time wr_drv_times[$];
    static time rd_drv_times[$];
endclass

//=============================================================================
//  3. DRIVER
//=============================================================================
class fifo_driver #(parameter FIFO_WIDTH = 64);
    virtual fifo_if #(FIFO_WIDTH) vif;
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_mbx;
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_mbx;
    int wr_count;
    int rd_count;

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

    task drive_write();
        fifo_transaction #(FIFO_WIDTH) txn;
        forever begin
            wr_mbx.get(txn);
            if (txn.wr_en) begin
                while (vif.fifo_full) @(posedge vif.wrclk);
                @(posedge vif.wrclk); #1;
                vif.wr_en   = 1'b1;
                vif.data_in = txn.data;
                fifo_txn_log::wr_drv_times.push_back($time);
                wr_count++;

                while (wr_mbx.try_peek(txn)) begin
                    if (!txn.wr_en) break;
                    wr_mbx.get(txn);
                    if (vif.fifo_full) begin
                        vif.wr_en   = 1'b0;
                        vif.data_in = '0;
                        while (vif.fifo_full) @(posedge vif.wrclk);
                        @(posedge vif.wrclk); #1;
                        vif.wr_en   = 1'b1;
                        vif.data_in = txn.data;
                    end else begin
                        @(posedge vif.wrclk); #1;
                        vif.data_in = txn.data;
                    end
                    fifo_txn_log::wr_drv_times.push_back($time);
                    wr_count++;
                end

                @(posedge vif.wrclk); #1;
                vif.wr_en   = 1'b0;
                vif.data_in = '0;
            end
        end
    endtask

    task drive_read();
        fifo_transaction #(FIFO_WIDTH) txn;
        forever begin
            rd_mbx.get(txn);
            if (txn.rd_en) begin
                while (vif.fifo_empty) @(posedge vif.rdclk);
                @(posedge vif.rdclk); #1;
                vif.rd_en = 1'b1;
                fifo_txn_log::rd_drv_times.push_back($time);
                rd_count++;

                while (rd_mbx.try_peek(txn)) begin
                    if (!txn.rd_en) break;
                    rd_mbx.get(txn);
                    if (vif.fifo_empty) begin
                        vif.rd_en = 1'b0;
                        while (vif.fifo_empty) @(posedge vif.rdclk);
                        @(posedge vif.rdclk); #1;
                        vif.rd_en = 1'b1;
                    end else begin
                        @(posedge vif.rdclk); #1;
                    end
                    fifo_txn_log::rd_drv_times.push_back($time);
                    rd_count++;
                end

                @(posedge vif.rdclk); #1;
                vif.rd_en = 1'b0;
            end
        end
    endtask
endclass : fifo_driver

//=============================================================================
//  4. MONITOR
//=============================================================================
class fifo_monitor #(parameter FIFO_WIDTH = 64);
    virtual fifo_if #(FIFO_WIDTH) vif;
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx;
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx;

    function new(
        virtual fifo_if #(FIFO_WIDTH)             vif,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx
    );
        this.vif        = vif;
        this.wr_scb_mbx = wr_scb_mbx;
        this.rd_scb_mbx = rd_scb_mbx;
    endfunction

    task run();
        $display("[MONITOR] Starting at %0t", $time);
        fork
            monitor_write();
            monitor_read();
        join_none
    endtask

    task monitor_write();
        fifo_transaction #(FIFO_WIDTH) txn;
        forever begin
            @(posedge vif.wrclk);
            if (vif.wrst_n && vif.wr_en && !vif.fifo_full) begin
                txn              = new();
                txn.txn_type     = FIFO_WRITE;
                txn.wr_en        = vif.wr_en;
                txn.data         = vif.data_in;
                txn.fifo_full    = vif.fifo_full;
                txn.fifo_empty   = vif.fifo_empty;
                txn.capture_time = $time;
                wr_scb_mbx.put(txn);
            end
        end
    endtask

    task monitor_read();
        fifo_transaction #(FIFO_WIDTH) txn;
        bit rd_was_valid;
        rd_was_valid = 1'b0;
        forever begin
            @(posedge vif.rdclk);
            if (rd_was_valid) begin
                txn              = new();
                txn.txn_type     = FIFO_READ;
                txn.rd_en        = 1'b1;
                txn.data_out     = vif.data_out;
                txn.fifo_full    = vif.fifo_full;
                txn.fifo_empty   = vif.fifo_empty;
                txn.capture_time = $time;
                rd_scb_mbx.put(txn);
            end
            rd_was_valid = (vif.rrst_n && vif.rd_en && !vif.fifo_empty);
        end
    endtask
endclass : fifo_monitor

//=============================================================================
//  5. SCOREBOARD
//=============================================================================
class fifo_scoreboard #(parameter FIFO_WIDTH = 64);
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx;
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx;

    bit [FIFO_WIDTH-1:0] ref_q[$];

    bit [FIFO_WIDTH-1:0] wr_data_log[$];
    time                 wr_mon_times[$];
    time                 wr_scb_times[$];
    bit                  wr_full_log[$];
    bit                  wr_empty_log[$];
    int                  wr_depth_log[$];

    int wr_count, rd_count, pass_count, fail_count;

    function new(
        mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx,
        mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx
    );
        this.wr_scb_mbx = wr_scb_mbx;
        this.rd_scb_mbx = rd_scb_mbx;
        wr_count   = 0; rd_count   = 0;
        pass_count = 0; fail_count = 0;
    endfunction

    task run();
        $display("[SCB] Starting at %0t", $time);
        fork
            check_writes();
            check_reads();
        join_none
    endtask

    task check_writes();
        fifo_transaction #(FIFO_WIDTH) txn;
        forever begin
            wr_scb_mbx.get(txn);
            ref_q.push_back(txn.data);
            wr_count++;
            wr_data_log.push_back(txn.data);
            wr_mon_times.push_back(txn.capture_time);
            wr_scb_times.push_back($time);
            wr_full_log.push_back(txn.fifo_full);
            wr_empty_log.push_back(txn.fifo_empty);
            wr_depth_log.push_back(ref_q.size());
        end
    endtask

    task check_reads();
        fifo_transaction #(FIFO_WIDTH) txn;
        bit [FIFO_WIDTH-1:0] exp_data;
        bit [FIFO_WIDTH-1:0] wr_data;
        time wr_drv_t, wr_mon_t, wr_scb_t;
        bit  wr_full, wr_empty;
        int  wr_depth;
        time rd_drv_t, rd_mon_t, rd_scb_t;
        int  rd_depth;
        string result_str;
        bit    is_pass;

        forever begin
            rd_scb_mbx.get(txn);
            rd_count++;
            rd_scb_t = $time;
            rd_mon_t = txn.capture_time;

            if (fifo_txn_log::rd_drv_times.size() > 0)
                rd_drv_t = fifo_txn_log::rd_drv_times.pop_front();
            else rd_drv_t = 0;

            if (ref_q.size() == 0) begin
                fail_count++;
                display_error_block(rd_count, txn.data_out, rd_drv_t, rd_mon_t, rd_scb_t,
                                    txn.fifo_full, txn.fifo_empty);
            end else begin
                exp_data = ref_q.pop_front();
                rd_depth = ref_q.size();

                wr_data  = wr_data_log.pop_front();
                wr_mon_t = wr_mon_times.pop_front();
                wr_scb_t = wr_scb_times.pop_front();
                wr_full  = wr_full_log.pop_front();
                wr_empty = wr_empty_log.pop_front();
                wr_depth = wr_depth_log.pop_front();

                if (fifo_txn_log::wr_drv_times.size() > 0)
                    wr_drv_t = fifo_txn_log::wr_drv_times.pop_front();
                else wr_drv_t = 0;

                is_pass = (txn.data_out === exp_data);
                if (is_pass) begin pass_count++; result_str = "PASS"; end
                else         begin fail_count++; result_str = "FAIL"; end

                display_txn_block(
                    rd_count, result_str,
                    wr_data, wr_drv_t, wr_mon_t, wr_scb_t, wr_full, wr_empty, wr_depth,
                    txn.data_out, rd_drv_t, rd_mon_t, rd_scb_t, txn.fifo_full, txn.fifo_empty, rd_depth,
                    exp_data
                );
            end
        end
    endtask

    function void display_txn_block(
        int txn_num, string result,
        bit [FIFO_WIDTH-1:0] wr_data, time wr_drv_t, time wr_mon_t, time wr_scb_t,
        bit wr_full, bit wr_empty, int wr_depth,
        bit [FIFO_WIDTH-1:0] rd_data, time rd_drv_t, time rd_mon_t, time rd_scb_t,
        bit rd_full, bit rd_empty, int rd_depth,
        bit [FIFO_WIDTH-1:0] exp_data
    );
        string wd, wm, ws, rd, rm, rs;
        wd = $sformatf("@ %0t", wr_drv_t); wm = $sformatf("@ %0t", wr_mon_t); ws = $sformatf("@ %0t", wr_scb_t);
        rd = $sformatf("@ %0t", rd_drv_t); rm = $sformatf("@ %0t", rd_mon_t); rs = $sformatf("@ %0t", rd_scb_t);

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
        $display("    %-14s | %-24s | %-24s", "Driver",     wd, rd);
        $display("    %-14s | %-24s | %-24s", "Monitor",    wm, rm);
        $display("    %-14s | %-24s | %-24s", "Scoreboard", ws, rs);
        $display("  --------------------------------------------------------------------------");
        $display("    WR Flags : full=%0b  empty=%0b               RD Flags : full=%0b  empty=%0b",
                 wr_full, wr_empty, rd_full, rd_empty);
        $display("    Ref-Q after push : depth=%-3d                Ref-Q after pop  : depth=%-3d",
                 wr_depth, rd_depth);
        $display("  ==========================================================================");
    endfunction

    function void display_error_block(
        int txn_num, bit [FIFO_WIDTH-1:0] rd_data,
        time rd_drv_t, time rd_mon_t, time rd_scb_t,
        bit rd_full, bit rd_empty
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

    function void reset();
        ref_q.delete();
        wr_data_log.delete();  wr_mon_times.delete(); wr_scb_times.delete();
        wr_full_log.delete();  wr_empty_log.delete();  wr_depth_log.delete();
        wr_count = 0; rd_count = 0; pass_count = 0; fail_count = 0;
        fifo_txn_log::wr_drv_times.delete();
        fifo_txn_log::rd_drv_times.delete();
    endfunction

    function bit is_pass();
        return (fail_count == 0 && ref_q.size() == 0);
    endfunction

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

//=============================================================================
//  6. ENVIRONMENT
//=============================================================================
class fifo_env #(parameter FIFO_WIDTH = 64);
    fifo_driver     #(FIFO_WIDTH) drv;
    fifo_monitor    #(FIFO_WIDTH) mon;
    fifo_scoreboard #(FIFO_WIDTH) scb;

    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_mbx;
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_mbx;
    mailbox #(fifo_transaction #(FIFO_WIDTH)) wr_scb_mbx;
    mailbox #(fifo_transaction #(FIFO_WIDTH)) rd_scb_mbx;

    virtual fifo_if #(FIFO_WIDTH) vif;

    function new(virtual fifo_if #(FIFO_WIDTH) vif);
        this.vif   = vif;
        wr_mbx     = new(); rd_mbx     = new();
        wr_scb_mbx = new(); rd_scb_mbx = new();
        drv = new(vif, wr_mbx, rd_mbx);
        mon = new(vif, wr_scb_mbx, rd_scb_mbx);
        scb = new(wr_scb_mbx, rd_scb_mbx);
    endfunction

    function void reset();
        fifo_transaction #(FIFO_WIDTH) tmp;
        while (wr_mbx.try_get(tmp));
        while (rd_mbx.try_get(tmp));
        scb.reset();
    endfunction

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
//  7. TEST BASE
//=============================================================================
class fifo_test_base #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
);
    fifo_env #(FIFO_WIDTH) env;
    virtual fifo_if #(FIFO_WIDTH) vif;

    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        this.vif = vif;
        this.env = env;
    endfunction

    virtual task run();
        $fatal(1, "[TEST_BASE] run() not overridden by child test class");
    endtask

    task write_n(int n);
        fifo_transaction #(FIFO_WIDTH) txn;
        repeat (n) begin
            txn = new();
            if (!txn.randomize() with { wr_en == 1'b1; rd_en == 1'b0; })
                $fatal(1, "[TEST_BASE] Randomize failed for write transaction");
            txn.txn_type = FIFO_WRITE;
            env.wr_mbx.put(txn);
        end
    endtask

    task read_n(int n);
        fifo_transaction #(FIFO_WIDTH) txn;
        repeat (n) begin
            txn          = new();
            txn.wr_en    = 1'b0;
            txn.rd_en    = 1'b1;
            txn.txn_type = FIFO_READ;
            env.rd_mbx.put(txn);
        end
    endtask

    task write_data(bit [FIFO_WIDTH-1:0] data);
        fifo_transaction #(FIFO_WIDTH) txn;
        txn          = new();
        txn.wr_en    = 1'b1;
        txn.rd_en    = 1'b0;
        txn.data     = data;
        txn.txn_type = FIFO_WRITE;
        env.wr_mbx.put(txn);
    endtask

    task wait_drain(int timeout_ns = 5000);
        fork begin
            fork
                begin
                    wait (env.wr_mbx.num() == 0 && env.rd_mbx.num() == 0);
                    repeat (20) @(posedge vif.wrclk);
                    repeat (20) @(posedge vif.rdclk);
                end
                begin
                    #(timeout_ns * 1ns);
                    $display("[TEST_BASE] WARNING: wait_drain timed out after %0d ns", timeout_ns);
                end
            join_any
            disable fork;
        end join
    endtask

    task reset_dut();
        vif.wr_en   = 1'b0;
        vif.rd_en   = 1'b0;
        vif.data_in = '0;
        vif.wrst_n  = 1'b0;
        vif.rrst_n  = 1'b0;
        repeat (5) @(posedge vif.wrclk);
        @(posedge vif.wrclk); #1;
        vif.wrst_n = 1'b1;
        vif.rrst_n = 1'b1;
        @(posedge vif.wrclk); #1;
    endtask

    task reset_phase();
        reset_dut();
        env.reset();
    endtask
endclass : fifo_test_base

//=============================================================================
//  8. TEST CLASSES (28 tests)
//=============================================================================

// ---- Reset Tests (6) ----

class test_reset #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    int local_fail;
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env); local_fail = 0;
    endfunction
    virtual task run();
        $display("");
        $display("[TEST_RESET] Starting reset-with-data test...");
        $display("[TEST_RESET] Phase 1: Writing %0d entries...", FIFO_DEPTH / 2);
        write_n(FIFO_DEPTH / 2);
        wait_drain(5000);
        $display("[TEST_RESET] Phase 2: Asserting reset while FIFO contains data...");
        vif.wr_en = 1'b0; vif.rd_en = 1'b0; vif.data_in = '0;
        vif.wrst_n = 1'b0; vif.rrst_n = 1'b0;
        repeat (5) @(posedge vif.wrclk);
        if (vif.fifo_full)  begin $display("[TEST_RESET] FAIL: fifo_full should be 0 during reset");  local_fail++; end
        else                      $display("[TEST_RESET] PASS: fifo_full=0 during reset");
        if (!vif.fifo_empty) begin $display("[TEST_RESET] FAIL: fifo_empty should be 1 during reset"); local_fail++; end
        else                       $display("[TEST_RESET] PASS: fifo_empty=1 during reset");
        @(posedge vif.wrclk); #1;
        vif.wrst_n = 1'b1; vif.rrst_n = 1'b1;
        @(posedge vif.wrclk); #1;
        $display("[TEST_RESET] Reset deasserted.");
        env.reset();
        $display("[TEST_RESET] Phase 5: Writing %0d fresh entries after reset...", FIFO_DEPTH);
        write_n(FIFO_DEPTH); read_n(FIFO_DEPTH); wait_drain(10000);
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) begin $display("[TEST_RESET] FAIL: fifo_empty not asserted after post-reset drain"); local_fail++; end
        else                       $display("[TEST_RESET] PASS: fifo_empty asserted after post-reset drain");
        if (local_fail > 0) $display("[TEST_RESET] ** %0d check(s) FAILED **", local_fail);
        else                $display("[TEST_RESET] All checks passed.");
        $display("[TEST_RESET] Done.");
    endtask
endclass : test_reset

class test_reset_when_empty #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display("[TEST_RST_EMPTY] Assert reset on an already-empty FIFO...");
        reset_dut();
        if (!vif.fifo_empty) $display("[TEST_RST_EMPTY] FAIL: fifo_empty should be 1 after reset");
        else                 $display("[TEST_RST_EMPTY] PASS: fifo_empty=1 after reset");
        if (vif.fifo_full)   $display("[TEST_RST_EMPTY] FAIL: fifo_full should be 0 after reset");
        else                 $display("[TEST_RST_EMPTY] PASS: fifo_full=0 after reset");
        env.reset();
        write_n(FIFO_DEPTH); read_n(FIFO_DEPTH); wait_drain(5000);
        $display("[TEST_RST_EMPTY] Done.");
    endtask
endclass

class test_reset_when_full #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display("[TEST_RST_FULL] Fill FIFO to full, then assert reset...");
        write_n(FIFO_DEPTH); wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        if (!vif.fifo_full) $display("[TEST_RST_FULL] WARNING: FIFO not full before reset");
        reset_dut(); env.reset();
        if (!vif.fifo_empty) $display("[TEST_RST_FULL] FAIL: fifo_empty should be 1 after reset");
        else                 $display("[TEST_RST_FULL] PASS: fifo_empty=1 after reset");
        if (vif.fifo_full)   $display("[TEST_RST_FULL] FAIL: fifo_full should be 0 after reset");
        else                 $display("[TEST_RST_FULL] PASS: fifo_full=0 after reset");
        write_n(FIFO_DEPTH); read_n(FIFO_DEPTH); wait_drain(5000);
        $display("[TEST_RST_FULL] Done.");
    endtask
endclass

class test_reset_during_write #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display("[TEST_RST_WR] Assert reset while wr_en is active...");
        @(posedge vif.wrclk); #1;
        vif.wr_en = 1'b1; vif.data_in = 64'hDEAD_BEEF_CAFE_BABE;
        @(posedge vif.wrclk); #1;
        vif.wrst_n = 1'b0; vif.rrst_n = 1'b0;
        repeat (5) @(posedge vif.wrclk);
        @(posedge vif.wrclk); #1;
        vif.wr_en = 1'b0; vif.data_in = '0;
        vif.wrst_n = 1'b1; vif.rrst_n = 1'b1;
        @(posedge vif.wrclk); #1;
        env.reset();
        if (!vif.fifo_empty) $display("[TEST_RST_WR] FAIL: fifo_empty should be 1 after reset");
        else                 $display("[TEST_RST_WR] PASS: fifo_empty=1 after reset");
        write_n(4); read_n(4); wait_drain(5000);
        $display("[TEST_RST_WR] Done.");
    endtask
endclass

class test_reset_during_read #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display("[TEST_RST_RD] Write data, start read, assert reset mid-read...");
        write_n(4); wait_drain(5000);
        @(posedge vif.rdclk); #1; vif.rd_en = 1'b1;
        @(posedge vif.rdclk); #1;
        vif.wrst_n = 1'b0; vif.rrst_n = 1'b0;
        repeat (5) @(posedge vif.wrclk);
        @(posedge vif.wrclk); #1;
        vif.rd_en = 1'b0; vif.wrst_n = 1'b1; vif.rrst_n = 1'b1;
        @(posedge vif.wrclk); #1;
        env.reset();
        if (!vif.fifo_empty) $display("[TEST_RST_RD] FAIL: fifo_empty should be 1 after reset");
        else                 $display("[TEST_RST_RD] PASS: fifo_empty=1 after reset");
        write_n(4); read_n(4); wait_drain(5000);
        $display("[TEST_RST_RD] Done.");
    endtask
endclass

class test_reset_partial_fill #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display("[TEST_RST_PARTIAL] Write partial data, reset, verify old data gone...");
        write_n(FIFO_DEPTH / 2); wait_drain(5000);
        reset_dut(); env.reset();
        write_n(FIFO_DEPTH); read_n(FIFO_DEPTH); wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) $display("[TEST_RST_PARTIAL] FAIL: fifo_empty not asserted after drain");
        else                 $display("[TEST_RST_PARTIAL] PASS: fifo_empty asserted, old data is gone");
        $display("[TEST_RST_PARTIAL] Done.");
    endtask
endclass

// ---- Normal Operation Tests (15) ----

class test_basic #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    localparam NUM_TXNS = 20;
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display(""); $display("[TEST_BASIC] Writing %0d random values, then reading them back...", NUM_TXNS);
        write_n(NUM_TXNS); read_n(NUM_TXNS); wait_drain(10000);
        $display("[TEST_BASIC] Done.");
    endtask
endclass : test_basic

class test_fill_drain #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    int local_fail;
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env); local_fail = 0;
    endfunction
    virtual task run();
        $display(""); $display("[TEST_FILL_DRAIN] Starting fill/drain test (2 cycles)...");
        $display("[TEST_FILL_DRAIN] Cycle 1: Writing %0d entries (fill)...", FIFO_DEPTH);
        write_n(FIFO_DEPTH); wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        if (!vif.fifo_full) begin $display("[TEST_FILL_DRAIN] FAIL: fifo_full not asserted after %0d writes", FIFO_DEPTH); local_fail++; end
        else $display("[TEST_FILL_DRAIN] PASS: fifo_full asserted as expected");
        $display("[TEST_FILL_DRAIN] Cycle 1: Reading %0d entries (drain)...", FIFO_DEPTH);
        read_n(FIFO_DEPTH); wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) begin $display("[TEST_FILL_DRAIN] FAIL: fifo_empty not asserted after drain"); local_fail++; end
        else $display("[TEST_FILL_DRAIN] PASS: fifo_empty asserted as expected");
        $display("[TEST_FILL_DRAIN] Cycle 2: Fill/drain again (pointers wrap around)...");
        write_n(FIFO_DEPTH); wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        if (!vif.fifo_full) begin $display("[TEST_FILL_DRAIN] FAIL: fifo_full not asserted on 2nd fill"); local_fail++; end
        else $display("[TEST_FILL_DRAIN] PASS: fifo_full asserted on 2nd fill");
        read_n(FIFO_DEPTH); wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) begin $display("[TEST_FILL_DRAIN] FAIL: fifo_empty not asserted on 2nd drain"); local_fail++; end
        else $display("[TEST_FILL_DRAIN] PASS: fifo_empty asserted on 2nd drain");
        if (local_fail > 0) $display("[TEST_FILL_DRAIN] ** %0d flag check(s) FAILED **", local_fail);
        else $display("[TEST_FILL_DRAIN] All flag checks passed.");
        $display("[TEST_FILL_DRAIN] Done.");
    endtask
endclass : test_fill_drain

class test_simultaneous_rw #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        int half_depth = FIFO_DEPTH / 2;
        int concurrent_txns = FIFO_DEPTH * 2;
        $display(""); $display("[TEST_SIM_RW] Starting simultaneous read/write test...");
        $display("[TEST_SIM_RW] Phase 1: Writing %0d entries to half-fill...", half_depth);
        write_n(half_depth); wait_drain(5000);
        $display("[TEST_SIM_RW] Phase 2: Queuing %0d writes and %0d reads concurrently...",
                 concurrent_txns, half_depth + concurrent_txns);
        fork
            write_n(concurrent_txns);
            read_n(half_depth + concurrent_txns);
        join
        wait_drain(15000);
        $display("[TEST_SIM_RW] Done.");
    endtask
endclass : test_simultaneous_rw

class test_pointer_wrap #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    localparam NUM_CYCLES = 3;
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display(""); $display("[TEST_PTR_WRAP] Starting pointer wrap test (%0d fill-drain cycles)...", NUM_CYCLES);
        for (int cycle = 1; cycle <= NUM_CYCLES; cycle++) begin
            $display("[TEST_PTR_WRAP] Cycle %0d/%0d: writing %0d, reading %0d...", cycle, NUM_CYCLES, FIFO_DEPTH, FIFO_DEPTH);
            write_n(FIFO_DEPTH); read_n(FIFO_DEPTH); wait_drain(5000);
        end
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) $display("[TEST_PTR_WRAP] FAIL: fifo_empty not asserted after %0d cycles", NUM_CYCLES);
        else                 $display("[TEST_PTR_WRAP] PASS: fifo_empty asserted after all cycles");
        $display("[TEST_PTR_WRAP] Done.");
    endtask
endclass : test_pointer_wrap

class test_clock_ratio #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    localparam NUM_TXNS = 16;
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display(""); $display("[TEST_CLK_RATIO] Starting clock ratio test (3 scenarios)...");
        $display("[TEST_CLK_RATIO] Scenario 1: Write-FAST (200MHz) / Read-SLOW (50MHz)");
        set_clocks(2.5, 10.0); reset_phase(); run_fill_drain();
        $display("[TEST_CLK_RATIO] Scenario 2: Write-SLOW (50MHz) / Read-FAST (200MHz)");
        set_clocks(10.0, 2.5); reset_phase(); run_fill_drain();
        $display("[TEST_CLK_RATIO] Scenario 3: Equal frequency (100MHz / 100MHz)");
        set_clocks(5.0, 5.0); reset_phase(); run_fill_drain();
        $display("[TEST_CLK_RATIO] Restoring default clocks (100MHz / 77MHz)...");
        set_clocks(5.0, 6.5);
        $display("[TEST_CLK_RATIO] Done.");
    endtask
    task set_clocks(realtime wr_half, realtime rd_half);
        tb_top.wrclk_half = wr_half;
        tb_top.rdclk_half = rd_half;
        $display("[TEST_CLK_RATIO]   wrclk_half=%.1f ns (period=%.1f ns)  rdclk_half=%.1f ns (period=%.1f ns)",
                 wr_half, wr_half*2, rd_half, rd_half*2);
        repeat (4) @(posedge vif.wrclk);
    endtask
    task run_fill_drain();
        write_n(NUM_TXNS); read_n(NUM_TXNS); wait_drain(20000);
    endtask
endclass : test_clock_ratio

class test_single_entry #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display("[TEST_SINGLE] Write 1 entry, read 1 entry (minimum case)...");
        write_n(1); read_n(1); wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) $display("[TEST_SINGLE] FAIL: fifo_empty not asserted after single read");
        else                 $display("[TEST_SINGLE] PASS: fifo_empty asserted");
        $display("[TEST_SINGLE] Done.");
    endtask
endclass

class test_full_flag_timing #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        int fail_cnt = 0;
        $display("[TEST_FULL_FLAG] Write one-by-one, check fifo_full after each...");
        for (int i = 1; i <= FIFO_DEPTH; i++) begin
            write_n(1); wait_drain(3000);
            repeat (6) @(posedge vif.wrclk);
            if (i < FIFO_DEPTH) begin
                if (vif.fifo_full) begin $display("[TEST_FULL_FLAG] FAIL: fifo_full asserted early at entry %0d/%0d", i, FIFO_DEPTH); fail_cnt++; end
            end else begin
                if (!vif.fifo_full) begin $display("[TEST_FULL_FLAG] FAIL: fifo_full not asserted at entry %0d/%0d", i, FIFO_DEPTH); fail_cnt++; end
                else $display("[TEST_FULL_FLAG] PASS: fifo_full asserted at exactly FIFO_DEPTH=%0d", FIFO_DEPTH);
            end
        end
        read_n(1); wait_drain(3000);
        repeat (6) @(posedge vif.wrclk);
        if (vif.fifo_full) begin $display("[TEST_FULL_FLAG] FAIL: fifo_full still asserted after 1 read"); fail_cnt++; end
        else $display("[TEST_FULL_FLAG] PASS: fifo_full deasserted after 1 read");
        read_n(FIFO_DEPTH - 1); wait_drain(5000);
        if (fail_cnt == 0) $display("[TEST_FULL_FLAG] All checks passed.");
        else $display("[TEST_FULL_FLAG] ** %0d check(s) FAILED **", fail_cnt);
        $display("[TEST_FULL_FLAG] Done.");
    endtask
endclass

class test_empty_flag_timing #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        int fail_cnt = 0;
        $display("[TEST_EMPTY_FLAG] Fill FIFO, read one-by-one, check fifo_empty...");
        write_n(FIFO_DEPTH); wait_drain(5000);
        for (int i = 1; i <= FIFO_DEPTH; i++) begin
            read_n(1); wait_drain(3000);
            repeat (6) @(posedge vif.rdclk);
            if (i < FIFO_DEPTH) begin
                if (vif.fifo_empty) begin $display("[TEST_EMPTY_FLAG] FAIL: fifo_empty asserted early at read %0d/%0d", i, FIFO_DEPTH); fail_cnt++; end
            end else begin
                if (!vif.fifo_empty) begin $display("[TEST_EMPTY_FLAG] FAIL: fifo_empty not asserted at read %0d/%0d", i, FIFO_DEPTH); fail_cnt++; end
                else $display("[TEST_EMPTY_FLAG] PASS: fifo_empty asserted after last read");
            end
        end
        write_n(1); wait_drain(3000);
        repeat (6) @(posedge vif.rdclk);
        if (vif.fifo_empty) begin $display("[TEST_EMPTY_FLAG] FAIL: fifo_empty still asserted after 1 write"); fail_cnt++; end
        else $display("[TEST_EMPTY_FLAG] PASS: fifo_empty deasserted after 1 write");
        read_n(1); wait_drain(5000);
        if (fail_cnt == 0) $display("[TEST_EMPTY_FLAG] All checks passed.");
        else $display("[TEST_EMPTY_FLAG] ** %0d check(s) FAILED **", fail_cnt);
        $display("[TEST_EMPTY_FLAG] Done.");
    endtask
endclass

class test_almost_full #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        int fail_cnt = 0;
        $display("[TEST_ALMOST_FULL] Write DEPTH-1, check NOT full, write 1 more, check full...");
        write_n(FIFO_DEPTH - 1); wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        if (vif.fifo_full) begin $display("[TEST_ALMOST_FULL] FAIL: fifo_full asserted at DEPTH-1"); fail_cnt++; end
        else $display("[TEST_ALMOST_FULL] PASS: fifo_full NOT asserted at DEPTH-1");
        write_n(1); wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        if (!vif.fifo_full) begin $display("[TEST_ALMOST_FULL] FAIL: fifo_full not asserted at DEPTH"); fail_cnt++; end
        else $display("[TEST_ALMOST_FULL] PASS: fifo_full asserted at exactly DEPTH");
        read_n(FIFO_DEPTH); wait_drain(5000);
        if (fail_cnt == 0) $display("[TEST_ALMOST_FULL] All checks passed.");
        else $display("[TEST_ALMOST_FULL] ** %0d check(s) FAILED **", fail_cnt);
        $display("[TEST_ALMOST_FULL] Done.");
    endtask
endclass

class test_almost_empty #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        int fail_cnt = 0;
        $display("[TEST_ALMOST_EMPTY] Fill, drain to 1 left, check NOT empty, read last...");
        write_n(FIFO_DEPTH); read_n(FIFO_DEPTH - 1); wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);
        if (vif.fifo_empty) begin $display("[TEST_ALMOST_EMPTY] FAIL: fifo_empty asserted with 1 entry left"); fail_cnt++; end
        else $display("[TEST_ALMOST_EMPTY] PASS: fifo_empty NOT asserted with 1 entry left");
        read_n(1); wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) begin $display("[TEST_ALMOST_EMPTY] FAIL: fifo_empty not asserted after last read"); fail_cnt++; end
        else $display("[TEST_ALMOST_EMPTY] PASS: fifo_empty asserted after last read");
        if (fail_cnt == 0) $display("[TEST_ALMOST_EMPTY] All checks passed.");
        else $display("[TEST_ALMOST_EMPTY] ** %0d check(s) FAILED **", fail_cnt);
        $display("[TEST_ALMOST_EMPTY] Done.");
    endtask
endclass

class test_alternating_rw #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        int num_pairs = 20;
        $display("[TEST_ALT_RW] Alternating W-R-W-R for %0d pairs...", num_pairs);
        for (int i = 0; i < num_pairs; i++) begin
            write_n(1); wait_drain(3000);
            read_n(1);  wait_drain(3000);
        end
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) $display("[TEST_ALT_RW] FAIL: fifo_empty not asserted after equal W/R pairs");
        else                 $display("[TEST_ALT_RW] PASS: fifo_empty asserted");
        $display("[TEST_ALT_RW] Done.");
    endtask
endclass

class test_burst_write_burst_read #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display("[TEST_BURST] Burst-write %0d, then burst-read %0d...", FIFO_DEPTH, FIFO_DEPTH);
        write_n(FIFO_DEPTH); wait_drain(5000);
        read_n(FIFO_DEPTH);  wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) $display("[TEST_BURST] FAIL: fifo_empty not asserted after burst drain");
        else                 $display("[TEST_BURST] PASS: fifo_empty asserted after burst drain");
        $display("[TEST_BURST] Done.");
    endtask
endclass

class test_data_integrity_patterns #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        bit [FIFO_WIDTH-1:0] pattern;
        $display("[TEST_DATA_PAT] Writing known data patterns...");
        write_data({FIFO_WIDTH{1'b0}});
        write_data({FIFO_WIDTH{1'b1}});
        write_data({(FIFO_WIDTH/8){8'hAA}});
        write_data({(FIFO_WIDTH/8){8'h55}});
        pattern = '0; pattern[0] = 1'b1;            write_data(pattern);
        pattern = '0; pattern[FIFO_WIDTH-1] = 1'b1;  write_data(pattern);
        pattern = '1; pattern[0] = 1'b0;            write_data(pattern);
        pattern = '1; pattern[FIFO_WIDTH-1] = 1'b0;  write_data(pattern);
        read_n(8); wait_drain(5000);
        $display("[TEST_DATA_PAT] Done.");
    endtask
endclass

class test_fifo_depth_boundary #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        int fail_cnt = 0;
        $display("[TEST_DEPTH_BND] Interleaved operations at the full boundary...");
        write_n(FIFO_DEPTH - 1); wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        if (vif.fifo_full) begin $display("[TEST_DEPTH_BND] FAIL: fifo_full asserted at DEPTH-1"); fail_cnt++; end
        read_n(1); wait_drain(3000);
        write_n(2); wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        if (!vif.fifo_full) begin $display("[TEST_DEPTH_BND] FAIL: fifo_full not asserted after interleaved fill"); fail_cnt++; end
        else $display("[TEST_DEPTH_BND] PASS: fifo_full asserted correctly after interleaved ops");
        read_n(FIFO_DEPTH); wait_drain(5000);
        if (fail_cnt == 0) $display("[TEST_DEPTH_BND] All checks passed.");
        else $display("[TEST_DEPTH_BND] ** %0d check(s) FAILED **", fail_cnt);
        $display("[TEST_DEPTH_BND] Done.");
    endtask
endclass

class test_continuous_streaming #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        int num_txns = 100;
        $display("[TEST_STREAM] Continuous streaming: %0d write+read pairs concurrently...", num_txns);
        write_n(FIFO_DEPTH / 2); wait_drain(3000);
        fork
            write_n(num_txns);
            read_n((FIFO_DEPTH / 2) + num_txns);
        join
        wait_drain(20000);
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) $display("[TEST_STREAM] FAIL: fifo_empty not asserted after streaming");
        else                 $display("[TEST_STREAM] PASS: fifo_empty asserted after %0d transactions", num_txns);
        $display("[TEST_STREAM] Done.");
    endtask
endclass

// ---- Negative / Edge-Case Tests (7) ----

class test_overflow_underflow #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    int local_fail;
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env); local_fail = 0;
    endfunction
    virtual task run();
        $display(""); $display("[TEST_OVF_UNF] Starting overflow/underflow test...");
        test_overflow(); test_underflow();
        if (local_fail > 0) $display("[TEST_OVF_UNF] ** %0d check(s) FAILED **", local_fail);
        else                $display("[TEST_OVF_UNF] All checks passed.");
        $display("[TEST_OVF_UNF] Done.");
    endtask
    task test_overflow();
        bit [FIFO_WIDTH-1:0] overflow_data;
        $display("[TEST_OVF_UNF] --- Overflow Test ---");
        write_n(FIFO_DEPTH); wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        if (!vif.fifo_full) begin $display("[TEST_OVF_UNF] FAIL: FIFO not full after %0d writes", FIFO_DEPTH); local_fail++; return; end
        overflow_data = {FIFO_WIDTH{1'b1}};
        $display("[TEST_OVF_UNF] Forcing write of 0x%016h while fifo_full=1...", overflow_data);
        @(posedge vif.wrclk); #1; vif.wr_en = 1'b1; vif.data_in = overflow_data;
        @(posedge vif.wrclk); #1; vif.wr_en = 1'b0; vif.data_in = '0;
        read_n(FIFO_DEPTH); wait_drain(5000);
        $display("[TEST_OVF_UNF] Overflow test complete (scoreboard checks data integrity).");
    endtask
    task test_underflow();
        $display("[TEST_OVF_UNF] --- Underflow Test ---");
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) begin $display("[TEST_OVF_UNF] FAIL: FIFO not empty before underflow test"); local_fail++; return; end
        $display("[TEST_OVF_UNF] Forcing rd_en=1 while fifo_empty=1...");
        @(posedge vif.rdclk); #1; vif.rd_en = 1'b1;
        @(posedge vif.rdclk); #1; vif.rd_en = 1'b0;
        repeat (4) @(posedge vif.rdclk);
        $display("[TEST_OVF_UNF] Verifying FIFO still works after underflow attempt...");
        write_n(1); read_n(1); wait_drain(5000);
        $display("[TEST_OVF_UNF] Underflow test complete.");
    endtask
endclass : test_overflow_underflow

class test_write_when_full_data_check #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        bit [FIFO_WIDTH-1:0] bad_pattern;
        $display("[TEST_WR_FULL] Fill with pattern A, force writes of pattern B while full...");
        for (int i = 0; i < FIFO_DEPTH; i++) write_data({32'hAAAA_0000, 32'(i)});
        wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        bad_pattern = {FIFO_WIDTH{1'b1}};
        repeat (3) begin
            @(posedge vif.wrclk); #1; vif.wr_en = 1'b1; vif.data_in = bad_pattern;
        end
        @(posedge vif.wrclk); #1; vif.wr_en = 1'b0; vif.data_in = '0;
        read_n(FIFO_DEPTH); wait_drain(5000);
        $display("[TEST_WR_FULL] Done (scoreboard verifies pattern B is absent).");
    endtask
endclass

class test_read_when_empty_pointer_check #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display("[TEST_RD_EMPTY] Force multiple reads while empty, check pointer integrity...");
        repeat (5) begin @(posedge vif.rdclk); #1; vif.rd_en = 1'b1; end
        @(posedge vif.rdclk); #1; vif.rd_en = 1'b0;
        repeat (4) @(posedge vif.rdclk);
        write_n(FIFO_DEPTH); read_n(FIFO_DEPTH); wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) $display("[TEST_RD_EMPTY] FAIL: fifo_empty not asserted after normal drain");
        else                 $display("[TEST_RD_EMPTY] PASS: pointers intact after illegal reads");
        $display("[TEST_RD_EMPTY] Done.");
    endtask
endclass

class test_simultaneous_reset_write #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display("[TEST_RST_SIM_WR] Assert reset and wr_en simultaneously...");
        @(posedge vif.wrclk); #1;
        vif.wrst_n = 1'b0; vif.rrst_n = 1'b0;
        vif.wr_en = 1'b1; vif.data_in = 64'hDEAD_BEEF_DEAD_BEEF;
        repeat (5) @(posedge vif.wrclk);
        @(posedge vif.wrclk); #1;
        vif.wr_en = 1'b0; vif.data_in = '0;
        vif.wrst_n = 1'b1; vif.rrst_n = 1'b1;
        @(posedge vif.wrclk); #1;
        env.reset();
        if (!vif.fifo_empty) $display("[TEST_RST_SIM_WR] FAIL: fifo_empty should be 1 (reset wins over write)");
        else                 $display("[TEST_RST_SIM_WR] PASS: fifo_empty=1, reset took priority");
        write_n(4); read_n(4); wait_drain(5000);
        $display("[TEST_RST_SIM_WR] Done.");
    endtask
endclass

class test_simultaneous_reset_read #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display("[TEST_RST_SIM_RD] Write data, then assert reset and rd_en simultaneously...");
        write_n(4); wait_drain(5000);
        @(posedge vif.rdclk); #1;
        vif.wrst_n = 1'b0; vif.rrst_n = 1'b0; vif.rd_en = 1'b1;
        repeat (5) @(posedge vif.wrclk);
        @(posedge vif.wrclk); #1;
        vif.rd_en = 1'b0; vif.wrst_n = 1'b1; vif.rrst_n = 1'b1;
        @(posedge vif.wrclk); #1;
        env.reset();
        if (!vif.fifo_empty) $display("[TEST_RST_SIM_RD] FAIL: fifo_empty should be 1 (reset wins over read)");
        else                 $display("[TEST_RST_SIM_RD] PASS: fifo_empty=1, reset took priority");
        write_n(4); read_n(4); wait_drain(5000);
        $display("[TEST_RST_SIM_RD] Done.");
    endtask
endclass

class test_back_to_back_overflow #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display("[TEST_B2B_OVF] Fill FIFO, then force 10 consecutive writes while full...");
        write_n(FIFO_DEPTH); wait_drain(5000);
        repeat (6) @(posedge vif.wrclk);
        @(posedge vif.wrclk); #1;
        vif.wr_en = 1'b1; vif.data_in = {FIFO_WIDTH{1'b1}};
        repeat (10) begin
            @(posedge vif.wrclk); #1;
            vif.data_in = vif.data_in - 1;
        end
        vif.wr_en = 1'b0; vif.data_in = '0;
        read_n(FIFO_DEPTH); wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) $display("[TEST_B2B_OVF] FAIL: fifo_empty not asserted");
        else                 $display("[TEST_B2B_OVF] PASS: original data intact after 10 overflow writes");
        $display("[TEST_B2B_OVF] Done.");
    endtask
endclass

class test_back_to_back_underflow #(parameter FIFO_WIDTH = 64, parameter FIFO_DEPTH = 8
) extends fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH);
    function new(virtual fifo_if #(FIFO_WIDTH) vif, fifo_env #(FIFO_WIDTH) env);
        super.new(vif, env);
    endfunction
    virtual task run();
        $display("[TEST_B2B_UNF] Force 10 consecutive reads while empty...");
        @(posedge vif.rdclk); #1; vif.rd_en = 1'b1;
        repeat (10) @(posedge vif.rdclk);
        #1; vif.rd_en = 1'b0;
        repeat (4) @(posedge vif.rdclk);
        write_n(1); read_n(1); wait_drain(5000);
        repeat (6) @(posedge vif.rdclk);
        if (!vif.fifo_empty) $display("[TEST_B2B_UNF] FAIL: fifo_empty not asserted (pointer corrupted?)");
        else                 $display("[TEST_B2B_UNF] PASS: pointer intact after 10 underflow reads");
        $display("[TEST_B2B_UNF] Done.");
    endtask
endclass

//=============================================================================
//  9. TEST RUNNER
//=============================================================================
class fifo_test_runner #(
    parameter FIFO_WIDTH = 64,
    parameter FIFO_DEPTH = 8
);
    fifo_env #(FIFO_WIDTH)        env;
    virtual fifo_if #(FIFO_WIDTH) vif;

    string test_names[$];
    string test_results[$];

    string all_tests[$] = '{
        "test_reset", "test_reset_when_empty", "test_reset_when_full",
        "test_reset_during_write", "test_reset_during_read", "test_reset_partial_fill",
        "test_basic", "test_fill_drain", "test_simultaneous_rw",
        "test_pointer_wrap", "test_clock_ratio", "test_single_entry",
        "test_full_flag_timing", "test_empty_flag_timing",
        "test_almost_full", "test_almost_empty",
        "test_alternating_rw", "test_burst_write_burst_read",
        "test_data_integrity_patterns", "test_fifo_depth_boundary",
        "test_continuous_streaming",
        "test_overflow_underflow", "test_write_when_full_data_check",
        "test_read_when_empty_pointer_check",
        "test_simultaneous_reset_write", "test_simultaneous_reset_read",
        "test_back_to_back_overflow", "test_back_to_back_underflow"
    };

    function new(virtual fifo_if #(FIFO_WIDTH) vif);
        this.vif = vif;
        env      = new(vif);
    endfunction

    task run(string test_name);
        $display("");
        $display("  ##########################################################################");
        $display("    ASYNC FIFO TEST RUNNER");
        $display("    WIDTH=%0d  DEPTH=%0d  TEST=%s", FIFO_WIDTH, FIFO_DEPTH, test_name);
        $display("  ##########################################################################");
        $display("");
        env.run();
        if (test_name == "all") begin
            foreach (all_tests[i]) run_one_test(all_tests[i]);
        end else begin
            run_one_test(test_name);
        end
        print_final_summary();
        $finish;
    endtask

    function fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH) create_test(string name);
        case (name)
            "test_reset":                      begin test_reset                      #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_reset_when_empty":           begin test_reset_when_empty           #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_reset_when_full":            begin test_reset_when_full            #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_reset_during_write":         begin test_reset_during_write         #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_reset_during_read":          begin test_reset_during_read          #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_reset_partial_fill":         begin test_reset_partial_fill         #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_basic":                      begin test_basic                      #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_fill_drain":                 begin test_fill_drain                 #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_simultaneous_rw":            begin test_simultaneous_rw            #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_pointer_wrap":               begin test_pointer_wrap               #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_clock_ratio":                begin test_clock_ratio                #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_single_entry":               begin test_single_entry               #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_full_flag_timing":           begin test_full_flag_timing           #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_empty_flag_timing":          begin test_empty_flag_timing          #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_almost_full":                begin test_almost_full                #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_almost_empty":               begin test_almost_empty               #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_alternating_rw":             begin test_alternating_rw             #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_burst_write_burst_read":     begin test_burst_write_burst_read     #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_data_integrity_patterns":    begin test_data_integrity_patterns    #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_fifo_depth_boundary":        begin test_fifo_depth_boundary        #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_continuous_streaming":       begin test_continuous_streaming        #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_overflow_underflow":         begin test_overflow_underflow         #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_write_when_full_data_check": begin test_write_when_full_data_check #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_read_when_empty_pointer_check": begin test_read_when_empty_pointer_check #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_simultaneous_reset_write":   begin test_simultaneous_reset_write   #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_simultaneous_reset_read":    begin test_simultaneous_reset_read    #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_back_to_back_overflow":      begin test_back_to_back_overflow      #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            "test_back_to_back_underflow":     begin test_back_to_back_underflow     #(FIFO_WIDTH, FIFO_DEPTH) t = new(vif, env); return t; end
            default:                           return null;
        endcase
    endfunction

    task run_one_test(string name);
        fifo_test_base #(FIFO_WIDTH, FIFO_DEPTH) test;
        $display("");
        $display("  +------------------------------------------------------------------------+");
        $display("  |  STARTING: %-58s|", name);
        $display("  +------------------------------------------------------------------------+");
        test = create_test(name);
        if (test == null) begin
            $display("[RUNNER] ERROR: Unknown test name '%s'", name);
            $display("[RUNNER] Available tests:");
            foreach (all_tests[i]) $display("[RUNNER]   %s", all_tests[i]);
            test_names.push_back(name); test_results.push_back("UNKNOWN");
            return;
        end
        if (test_names.size() > 0) test.reset_phase();
        test.run();
        env.scb.report();
        test_names.push_back(name);
        if (env.scb.is_pass()) test_results.push_back("PASS");
        else                   test_results.push_back("FAIL");
        $display("  +------------------------------------------------------------------------+");
        $display("  |  FINISHED: %-54s [%4s] |", name, test_results[test_results.size()-1]);
        $display("  +------------------------------------------------------------------------+");
    endtask

    function void print_final_summary();
        int total_pass = 0, total_fail = 0;
        $display("");
        $display("");
        $display("  ##########################################################################");
        $display("                        FINAL TEST SUMMARY                                  ");
        $display("  ##########################################################################");
        $display("  %-4s  %-40s  %-6s", "#", "Test Name", "Result");
        $display("  %-4s  %-40s  %-6s", "----", "----------------------------------------", "------");
        for (int i = 0; i < test_names.size(); i++) begin
            $display("  %-4d  %-40s  %-6s", i+1, test_names[i], test_results[i]);
            if (test_results[i] == "PASS") total_pass++;
            else                           total_fail++;
        end
        $display("  --------------------------------------------------------------------------");
        $display("  Total: %0d tests | %0d PASSED | %0d FAILED", test_names.size(), total_pass, total_fail);
        $display("  --------------------------------------------------------------------------");
        if (total_fail == 0) $display("  OVERALL RESULT  >>  ** ALL TESTS PASSED **");
        else                 $display("  OVERALL RESULT  >>  ** SOME TESTS FAILED **");
        $display("  ##########################################################################");
        $display("");
    endfunction
endclass : fifo_test_runner

//=============================================================================
//  10. TB_TOP MODULE
//=============================================================================
module tb_top;

    localparam int FIFO_DEPTH = 8;
    localparam int FIFO_WIDTH = 64;
    localparam int NUM_TXNS   = 20;

    logic wrclk;
    logic rdclk;

    realtime wrclk_half = 5.0;    // 10 ns period = 100 MHz
    realtime rdclk_half = 6.5;    // 13 ns period = ~77 MHz

    initial wrclk = 1'b0;
    always  #(wrclk_half) wrclk = ~wrclk;

    initial rdclk = 1'b0;
    always  #(rdclk_half) rdclk = ~rdclk;

    fifo_if #(FIFO_WIDTH) dut_if (
        .wrclk (wrclk),
        .rdclk (rdclk)
    );

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

    initial begin
        string test_name;
        fifo_test_runner #(FIFO_WIDTH, FIFO_DEPTH) runner;
        if (!$value$plusargs("TEST_NAME=%s", test_name))
            test_name = "all";
        wait (dut_if.wrst_n === 1'b1 && dut_if.rrst_n === 1'b1);
        @(posedge wrclk); #1;
        runner = new(dut_if);
        runner.run(test_name);
    end

    initial begin
        `ifdef DUMP_ON
            $dumpfile("fifo_tb.vcd");
            $dumpvars(0, tb_top);
        `endif
    end

    initial begin
        `ifdef DUMP_ON
            `ifdef CADENCE
                $shm_open("./sig_cxl_amx_pm_top.shm");
                $shm_probe("ASM");
            `endif
        `endif
    end

endmodule : tb_top
