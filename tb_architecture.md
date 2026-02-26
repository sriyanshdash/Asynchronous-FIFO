# Async FIFO — SystemVerilog Testbench Architecture
================================================================================

## 1. COMPONENT HIERARCHY
================================================================================

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║  tb_top  (module)                                                                ║
║                                                                                  ║
║   ┌─────────────────┐   ┌─────────────────┐                                    ║
║   │  wrclk 100 MHz  │   │  rdclk  77 MHz  │   < clock generators               ║
║   │  always #5      │   │  always #6.5    │                                    ║
║   └────────┬────────┘   └────────┬────────┘                                    ║
║            │ input                │ input                                        ║
║   ┌────────▼────────────────────▼──────────────────────────────────────────┐   ║
║   │  fifo_if  (interface)          FIFO_WIDTH = 64                          │   ║
║   │                                                                          │   ║
║   │  Write Domain :  wrclk  wrst_n  wr_en  data_in[63:0]  fifo_full        │   ║
║   │  Read  Domain :  rdclk  rrst_n  rd_en  data_out[63:0] fifo_empty       │   ║
║   │                                                                          │   ║
║   │  modports :  dut_mp  |  wr_tb_mp  |  rd_tb_mp  |  mon_mp (read-only)  │   ║
║   └──────────┬─────────────────────────────────────────────┬───────────────┘   ║
║              │ connected directly                           │ virtual fifo_if   ║
║              │                                              │                   ║
║   ┌──────────▼──────────────────────────┐      ┌───────────▼──────────────┐   ║
║   │  asynchronous_fifo  (DUT)            │      │  fifo_test               │   ║
║   │  FIFO_DEPTH=8  FIFO_WIDTH=64        │      │                          │   ║
║   │                                     │      │  ┌────────────────────┐  │   ║
║   │  wrclk ──► wrptr_handler            │      │  │  fifo_env          │  │   ║
║   │            synchronizer (2-flop CDC)│      │  │                    │  │   ║
║   │  rdclk ──► rdptr_handler            │      │  │  fifo_driver       │  │   ║
║   │            fifo_memory              │      │  │  fifo_monitor      │  │   ║
║   │            (registered data_out)   │      │  │  fifo_scoreboard   │  │   ║
║   └─────────────────────────────────────┘      │  └────────────────────┘  │   ║
║                                                 └──────────────────────────┘   ║
╚══════════════════════════════════════════════════════════════════════════════════╝
```


## 2. DATA FLOW — MAILBOXES & VIRTUAL INTERFACE
================================================================================

```
                 ┌───────────────────────────────────────────────────┐
                 │                   fifo_test                        │
                 │                                                    │
                 │  Phase 1 : generate 20 WRITE txns (randomized)    │
                 │  Phase 2 : generate 20 READ  txns                  │
                 │  Phase 3 : #10000 (wait for drain)                 │
                 │  Phase 4 : scb.report()  →  $finish               │
                 └──────────────────┬──────────────┬─────────────────┘
                                    │              │
                    ┌───────────────▼──┐      ┌───▼──────────────┐
                    │     wr_mbx       │      │     rd_mbx        │
                    │ (write txns)     │      │  (read  txns)     │
                    └───────┬──────────┘      └──────────┬────────┘
                            │  mailbox.get()             │  mailbox.get()
                            │                            │
               ┌────────────▼────────────────────────────▼──────────────┐
               │                    fifo_driver                          │
               │                                                         │
               │   ┌───────────────────────┐  ┌───────────────────────┐ │
               │   │    drive_write()       │  │    drive_read()        │ │
               │   │    (wrclk domain)      │  │    (rdclk domain)      │ │
               │   │                       │  │                        │ │
               │   │  while(fifo_full)wait  │  │  while(fifo_empty)wait │ │
               │   │  @posedge wrclk; #1ns │  │  @posedge rdclk; #1ns  │ │
               │   │  wr_en=1, data_in=... │  │  rd_en=1               │ │
               │   │  @posedge wrclk; #1ns │  │  @posedge rdclk; #1ns  │ │
               │   │  wr_en=0              │  │  rd_en=0               │ │
               │   └──────────┬────────────┘  └────────────┬───────────┘ │
               └──────────────┼────────────────────────────┼─────────────┘
                              │  drives                     │  drives
                              ▼                             ▼
               ╔══════════════════════════════════════════════════════╗
               ║           fifo_if  virtual interface                  ║
               ║  wr_en  data_in  wrclk  │  rd_en  rdclk  data_out    ║
               ╚═══════════════════════╤══════════════╤═══════════════╝
                                       │  connected   │
                              ┌────────▼──────────────▼────────┐
                              │   asynchronous_fifo   (DUT)     │
                              │                                 │
                              │  [Write side]   [Read side]     │
                              │  wrptr_handler  rdptr_handler   │
                              │  synchronizer   fifo_memory     │
                              │  fifo_full ──►  fifo_empty ──►  │
                              │  data_out valid 1 rdclk later   │
                              └────────┬──────────────┬─────────┘
                                       │  observed    │
               ╔═══════════════════════▼══════════════▼═══════════════╗
               ║           fifo_if  virtual interface                  ║
               ║  (monitor reads same signals — observe only)          ║
               ╚═══════════════════╤══════════════════╤═══════════════╝
                                   │                  │
               ┌───────────────────▼──────────────────▼───────────────┐
               │                  fifo_monitor                         │
               │                                                        │
               │  ┌──────────────────────────┐  ┌───────────────────┐ │
               │  │   monitor_write()         │  │  monitor_read()   │ │
               │  │   (wrclk domain)          │  │  (rdclk domain)   │ │
               │  │                          │  │                   │ │
               │  │  @posedge wrclk          │  │  rd_was_valid flag │ │
               │  │  if wrst_n & wr_en       │  │  Cycle N:  detect │ │
               │  │     & !fifo_full:        │  │    rd_en & !empty  │ │
               │  │  capture data_in         │  │  Cycle N+1: latch │ │
               │  │  → wr_scb_mbx.put(txn)   │  │    data_out       │ │
               │  │                          │  │  → rd_scb_mbx     │ │
               │  └──────────────┬───────────┘  └────────┬──────────┘ │
               └─────────────────┼────────────────────────┼────────────┘
                                 │  mailbox.put()          │  mailbox.put()
                    ┌────────────▼──┐                 ┌───▼──────────────┐
                    │  wr_scb_mbx   │                 │  rd_scb_mbx      │
                    │ (write obs.)  │                 │  (read  obs.)    │
                    └───────┬───────┘                 └────────┬─────────┘
                            │  mailbox.get()                   │  mailbox.get()
               ┌────────────▼──────────────────────────────────▼────────────┐
               │                    fifo_scoreboard                           │
               │                                                               │
               │   ref_q[$]  — SystemVerilog queue (software FIFO model)      │
               │                                                               │
               │   check_writes() :  ref_q.push_back(txn.data)               │
               │                                                               │
               │   check_reads()  :  exp = ref_q.pop_front()                 │
               │                     txn.data_out === exp  →  PASS            │
               │                     txn.data_out !== exp  →  FAIL            │
               │                                                               │
               │   report()  :  print totals, PASS/FAIL verdict               │
               └───────────────────────────────────────────────────────────────┘
```


## 3. CLOCK DOMAIN PARTITIONING
================================================================================

```
  ┌──────────────────────────────────────────────────────────────────────────┐
  │                      wrclk DOMAIN  (100 MHz / 10 ns)                     │
  │                                                                           │
  │   tb_top:  reset logic (wrst_n)                                          │
  │   DUT   :  wrptr_handler,  synchronizer input,  fifo_full generation     │
  │   Driver:  drive_write()   — @posedge wrclk; #1ns                        │
  │   Monitor: monitor_write() — @posedge wrclk                              │
  └──────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────────┐
  │                      rdclk DOMAIN  (~77 MHz / 13 ns)                     │
  │                                                                           │
  │   tb_top:  reset logic (rrst_n)                                          │
  │   DUT   :  rdptr_handler,  synchronizer output,  fifo_empty generation   │
  │            fifo_memory — registered data_out (1-cycle latency)           │
  │   Driver:  drive_read()    — @posedge rdclk; #1ns                        │
  │   Monitor: monitor_read()  — @posedge rdclk  (rd_was_valid lag fix)      │
  └──────────────────────────────────────────────────────────────────────────┘

  Key CDC detail:
  ┌──────────────────────────────────────────────────────────────────────────┐
  │  wrptr (Gray-coded)  ──► [2-flop synchronizer] ──► rdclk domain         │
  │  rptr  (Gray-coded)  ──► [2-flop synchronizer] ──► wrclk domain         │
  │                                                                           │
  │  Because flags are registered, the driver polls with a while() loop:     │
  │    while (vif.fifo_full)  @(posedge wrclk);   // safe flag sampling      │
  │    while (vif.fifo_empty) @(posedge rdclk);   // safe flag sampling      │
  └──────────────────────────────────────────────────────────────────────────┘
```


## 4. MAILBOX CONNECTIVITY SUMMARY
================================================================================

```
  ┌──────────┐  wr_mbx     ┌──────────┐  wr_scb_mbx  ┌─────────────┐
  │          │ ──────────► │          │ ────────────► │             │
  │fifo_test │             │fifo_drv  │               │fifo_scorebrd│
  │          │ ──────────► │          │               │             │
  └──────────┘  rd_mbx     └──────────┘               │             │
                                                        │             │
  ┌────────────────────────────────────┐  rd_scb_mbx  │             │
  │           fifo_monitor             │ ────────────► │             │
  │  (passive — no mailbox from test)  │               └─────────────┘
  └────────────────────────────────────┘

  Mailbox         Direction             Content
  ──────────────────────────────────────────────────────────────────
  wr_mbx          test      → driver    WRITE transactions (wr_en=1)
  rd_mbx          test      → driver    READ  transactions (rd_en=1)
  wr_scb_mbx      monitor   → scorebrd  Observed write captures
  rd_scb_mbx      monitor   → scorebrd  Observed read  captures (data_out)
```


## 5. TRANSACTION LIFECYCLE
================================================================================

```
  ① STIMULUS GENERATION  (fifo_test)
  ────────────────────────────────────────────────────────────────────────────
  fifo_transaction created  →  txn.randomize()  →  mailbox.put(txn)


  ② STIMULUS DRIVING  (fifo_driver)
  ────────────────────────────────────────────────────────────────────────────
  mailbox.get(txn)  →  wait flag clear  →  align to clock  →  drive DUT pins
                                           #1ns skew prevents delta races


  ③ OBSERVATION  (fifo_monitor)
  ────────────────────────────────────────────────────────────────────────────
  sample DUT pins  →  build new txn  →  mailbox.put(txn)  →  scoreboard
  [write] : wr_en & !fifo_full captured immediately
  [read]  : rd_was_valid used — data_out sampled ONE rdclk cycle after rd_en


  ④ CHECKING  (fifo_scoreboard)
  ────────────────────────────────────────────────────────────────────────────
  WRITE : push  txn.data       →  ref_q[$]
  READ  : pop   ref_q.front()  vs  txn.data_out
          using  ===  (4-state equality — catches X/Z mismatches)
          ✔ PASS : values match
          ✘ FAIL : mismatch printed, fail_count++


  ⑤ REPORT  (fifo_scoreboard.report)
  ────────────────────────────────────────────────────────────────────────────
  Prints total writes seen / reads seen / PASS count / FAIL count
  If fail_count==0 and ref_q empty  →  "** SIMULATION PASSED **"
```
