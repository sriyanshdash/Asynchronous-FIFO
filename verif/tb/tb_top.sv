//=============================================================================
// File        : tb_top.sv
// Description : Top-level testbench module for the Async FIFO.
//
//               Responsibilities:
//               – Clock generation : wrclk = 100 MHz (10 ns), rdclk ≈ 77 MHz (13 ns)
//               – Reset generation : both active-low resets held for 5 wrclk cycles
//               – DUT instantiation with interface connections
//               – Passing virtual interface handle to the test object
//               – Watchdog timer to guard against simulation hangs
//               – Optional VCD waveform dump
//=============================================================================

`timescale 1ns/1ps

`include "fifo_interface.sv"
`include "fifo_test_runner.sv"

module tb_top;

    //-------------------------------------------------------------------------
    // Parameters – match DUT defaults; override here if needed
    //-------------------------------------------------------------------------
    localparam int FIFO_DEPTH = 8;
    localparam int FIFO_WIDTH = 64;
    localparam int NUM_TXNS   = 20;   // transactions per direction in the test

    //-------------------------------------------------------------------------
    // Clock signals
    //   wrclk : default 10 ns period  (100 MHz) – write domain
    //   rdclk : default 13 ns period  (~77 MHz) – read domain
    //
    //   Half-periods are stored in realtime variables so tests can change
    //   the clock ratio at runtime (e.g. for fast-write / fast-read scenarios).
    //-------------------------------------------------------------------------
    logic wrclk;
    logic rdclk;

    realtime wrclk_half = 5.0;    // 10 ns period = 100 MHz
    realtime rdclk_half = 6.5;    // 13 ns period ≈  77 MHz

    initial wrclk = 1'b0;
    always  #(wrclk_half) wrclk = ~wrclk;

    initial rdclk = 1'b0;
    always  #(rdclk_half) rdclk = ~rdclk;

    //-------------------------------------------------------------------------
    // Interface instantiation
    // Both clocks are ports of the interface – driven directly from tb_top.
    //-------------------------------------------------------------------------
    fifo_if #(FIFO_WIDTH) dut_if (
        .wrclk (wrclk),
        .rdclk (rdclk)
    );

    //-------------------------------------------------------------------------
    // DUT instantiation
    // Signals are connected individually (not via modport) for clarity.
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
    // Both resets (wrst_n, rrst_n) are held LOW for 5 write-clock cycles,
    // then released together. Driven before the test object is created so
    // the DUT starts in a known state.
    //-------------------------------------------------------------------------
    initial begin
        // Initialise all driven interface signals to safe defaults
        dut_if.wrst_n  = 1'b0;
        dut_if.rrst_n  = 1'b0;
        dut_if.wr_en   = 1'b0;
        dut_if.rd_en   = 1'b0;
        dut_if.data_in = '0;

        // Hold reset for 5 wrclk cycles
        repeat(5) @(posedge wrclk);
        @(posedge wrclk); #1;   // one extra edge + skew
        dut_if.wrst_n = 1'b1;
        dut_if.rrst_n = 1'b1;
        $display("[TB_TOP] Reset deasserted at %0t  (wrst_n=1, rrst_n=1)", $time);
    end

    //-------------------------------------------------------------------------
    // Test execution
    // Use +TEST_NAME=<name> to run a specific test, or omit for all tests.
    // Available tests: test_basic, test_fill_drain, test_simultaneous_rw,
    //                  test_overflow_underflow, test_reset, test_pointer_wrap,
    //                  test_clock_ratio
    //-------------------------------------------------------------------------
    initial begin
        string test_name;
        fifo_test_runner #(FIFO_WIDTH, FIFO_DEPTH) runner;

        // Read test selection from plusarg; default to "all"
        if (!$value$plusargs("TEST_NAME=%s", test_name))
            test_name = "all";

        // Wait until both resets have been deasserted
        wait (dut_if.wrst_n === 1'b1 && dut_if.rrst_n === 1'b1);

        // Allow one extra write-clock cycle for the DUT to settle
        @(posedge wrclk); #1;

        // Construct the runner and execute
        runner = new(dut_if);
        runner.run(test_name);   // run() calls $finish when done
    end
/*
    //-------------------------------------------------------------------------
    // Watchdog timer – prevents infinite hangs (100 µs ceiling)
    //-------------------------------------------------------------------------
    initial begin
        #100_000;
        $display("[TB_TOP] WATCHDOG: Simulation exceeded 100 µs – forcing $finish");
        $finish;
    end
*/
    //-------------------------------------------------------------------------
    // Waveform dump
    // Generates a standard VCD file readable by SimVision and any other viewer.
    // Enabled only when +define+DUMP_ON is passed on the xrun command line.
    // Open in SimVision: File -> Open Database -> set type to "VCD (*.vcd)"
    //-------------------------------------------------------------------------
    initial begin
        `ifdef DUMP_ON
            $dumpfile("fifo_tb.vcd");   // VCD output file name
            $dumpvars(0, tb_top);       // dump ALL signals under tb_top hierarchy
        `endif
    end
//.shm file dump 
initial begin
  `ifdef DUMP_ON
    `ifdef CADENCE
      $shm_open("./sig_cxl_amx_pm_top.shm"); 
      $shm_probe("ASM");
   `endif
 `endif
end

  
endmodule : tb_top
