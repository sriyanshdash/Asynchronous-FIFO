# Asynchronous FIFO - Design & Verification Documentation

**Project**: Asynchronous FIFO with Gray-Coded Pointer CDC
**Author**: sdash
**Organization**: Marquee Semiconductor Inc
**Created**: April 2024
**Design Language**: SystemVerilog
**Simulator**: Cadence Xcelium (xrun)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Design Specification](#2-design-specification)
3. [RTL Architecture](#3-rtl-architecture)
4. [Module Descriptions](#4-module-descriptions)
5. [Clock Domain Crossing Strategy](#5-clock-domain-crossing-strategy)
6. [Verification Architecture](#6-verification-architecture)
7. [Testbench Components](#7-testbench-components)
8. [Test Plan & Test Cases](#8-test-plan--test-cases)
9. [Simulation Infrastructure](#9-simulation-infrastructure)
10. [Known Issues & Status](#10-known-issues--status)
11. [References](#11-references)

---

## 1. Overview

This project implements an **Asynchronous FIFO** (First-In-First-Out) buffer designed for safe data transfer between two independent clock domains. The design uses the industry-standard **Gray-coded pointer synchronization** technique as described in Clifford Cummings' SNUG 2002 paper.

### Key Features

- Parameterizable depth (default: 8 entries) and width (default: 64 bits)
- Gray-coded read/write pointers for safe Clock Domain Crossing (CDC)
- 2-stage flip-flop synchronizers for metastability resolution
- Registered `fifo_full` and `fifo_empty` status flags
- Registered `data_out` (1-cycle read latency)
- Asynchronous active-low reset per clock domain
- Full SystemVerilog class-based verification environment (28 test cases)

---

## 2. Design Specification

### 2.1 Parameters

| Parameter     | Default | Description                              |
|---------------|---------|------------------------------------------|
| `FIFO_DEPTH`  | 8       | Number of entries in the FIFO            |
| `FIFO_WIDTH`  | 64      | Data bus width in bits                   |
| `PTR_WIDTH`   | 3       | Derived: `$clog2(FIFO_DEPTH)`           |

### 2.2 Port List (Top-Level: `asynchronous_fifo`)

| Port         | Direction | Width        | Clock Domain | Description                           |
|--------------|-----------|--------------|--------------|---------------------------------------|
| `wrclk`      | input     | 1            | -            | Write domain clock                    |
| `wrst_n`     | input     | 1            | Write        | Write domain reset (active-low)       |
| `wr_en`      | input     | 1            | Write        | Write enable                          |
| `data_in`    | input     | FIFO_WIDTH   | Write        | Write data bus                        |
| `fifo_full`  | output    | 1            | Write        | FIFO full flag (registered)           |
| `rdclk`      | input     | 1            | -            | Read domain clock                     |
| `rrst_n`     | input     | 1            | Read         | Read domain reset (active-low)        |
| `rd_en`      | input     | 1            | Read         | Read enable                           |
| `data_out`   | output    | FIFO_WIDTH   | Read         | Read data bus (registered, 1-cycle latency) |
| `fifo_empty` | output    | 1            | Read         | FIFO empty flag (registered)          |

### 2.3 Functional Behavior

- **Write Operation**: On `posedge wrclk`, if `wr_en=1` and `fifo_full=0`, data is written to the memory at the location indexed by the binary write pointer.
- **Read Operation**: On `posedge rdclk`, if `rd_en=1` and `fifo_empty=0`, data is read from the memory at the location indexed by the binary read pointer. The output is **registered**, meaning `data_out` is valid one `rdclk` cycle after the read is initiated.
- **Full Condition**: Asserted when the write pointer has wrapped around and caught up to the read pointer (Gray-coded MSB and MSB-1 differ, remaining bits match).
- **Empty Condition**: Asserted when the read pointer equals the synchronized write pointer in Gray code.
- **Reset**: Active-low, asynchronous. Clears all pointers to zero, sets `fifo_empty=1`, and `fifo_full=0`.

### 2.4 Timing Diagram (Conceptual)

```
Write Domain (wrclk):
        ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐
wrclk   ┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──
wr_en   ________╱‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾╲________
data_in --------< D0  >< D1  >< D2  >--------
fifo_full _____________________________________  (stays low until FIFO fills)

Read Domain (rdclk):
        ┌───┐  ┌───┐  ┌───┐  ┌───┐  ┌───┐
rdclk   ┘   └──┘   └──┘   └──┘   └──┘   └──
rd_en   ____________╱‾‾‾‾‾‾‾‾‾╲_______________
data_out -----------XXXXXXX< D0  >< D1  >-----   (1-cycle latency)
fifo_empty ‾‾‾‾‾‾‾‾╲__________________________
```

---

## 3. RTL Architecture

### 3.1 Block Diagram

```
                        asynchronous_fifo (fifo_top.sv)
  ┌─────────────────────────────────────────────────────────────────────┐
  │                                                                     │
  │  WRITE CLOCK DOMAIN (wrclk)        READ CLOCK DOMAIN (rdclk)       │
  │  ┌──────────────────────┐          ┌──────────────────────┐        │
  │  │   wptr_handler       │          │   rptr_handler       │        │
  │  │                      │          │                      │        │
  │  │  b_wptr (binary)     │          │  b_rptr (binary)     │        │
  │  │  g_wptr (gray)  ─────┼──┐  ┌───┼── g_rptr (gray)      │        │
  │  │  fifo_full           │  │  │   │  fifo_empty           │        │
  │  │                      │  │  │   │                      │        │
  │  │  g_rptr_sync ──┐     │  │  │   │  g_wptr_sync ──┐     │        │
  │  └────────────────┼─────┘  │  │   └────────────────┼─────┘        │
  │                   │        │  │                    │               │
  │           ┌───────┘        │  │            ┌──────┘               │
  │           │                │  │            │                      │
  │  ┌────────▼───────────┐    │  │   ┌────────▼───────────┐         │
  │  │  synchronizer      │    │  │   │  synchronizer      │         │
  │  │  (rdclk -> wrclk)  │    │  │   │  (wrclk -> rdclk)  │         │
  │  │  2-flop CDC        │◄───┼──┘   │  2-flop CDC        │◄────┐   │
  │  │  g_rptr -> g_rptr_ │    │      │  g_wptr -> g_wptr_ │     │   │
  │  │           sync     │    │      │           sync     │     │   │
  │  └────────────────────┘    │      └────────────────────┘     │   │
  │                            │                                 │   │
  │                            └─────────────────────────────────┘   │
  │                                                                   │
  │  ┌────────────────────────────────────────────────────────────┐   │
  │  │                    fifo_mem                                 │   │
  │  │    reg [FIFO_WIDTH-1:0] fifo [0:FIFO_DEPTH-1]             │   │
  │  │                                                             │   │
  │  │    Write Port (wrclk):                                      │   │
  │  │      if (wr_en & !fifo_full)                               │   │
  │  │        fifo[b_wptr[PTR_WIDTH-1:0]] <= data_in              │   │
  │  │                                                             │   │
  │  │    Read Port (rdclk):                                       │   │
  │  │      if (rd_en & !fifo_empty)                              │   │
  │  │        data_out <= fifo[b_rptr[PTR_WIDTH-1:0]]  (registered)│   │
  │  └────────────────────────────────────────────────────────────┘   │
  └─────────────────────────────────────────────────────────────────────┘
```

### 3.2 File Hierarchy

```
rtl/
├── fifo_top.sv          Top-level: instantiates all submodules
├── fifo_memory.sv       Dual-port register-file memory
├── synchronizer.sv      2-stage flip-flop CDC synchronizer
├── wrptr_handler.sv     Write pointer management + full flag
└── rdptr_handler.sv     Read pointer management + empty flag
```

---

## 4. Module Descriptions

### 4.1 `asynchronous_fifo` (fifo_top.sv)

The top-level module that integrates all submodules. It has no logic of its own -- it only wires the submodules together.

**Submodule Instantiations:**

| Instance    | Module          | Purpose                                          |
|-------------|-----------------|--------------------------------------------------|
| `sync_wptr` | `synchronizer`  | Synchronize Gray write pointer into read domain  |
| `sync_rptr` | `synchronizer`  | Synchronize Gray read pointer into write domain  |
| `wrptr_h`   | `wptr_handler`  | Write pointer logic + full flag generation       |
| `rdptr_h`   | `rptr_handler`  | Read pointer logic + empty flag generation       |
| `fifom`     | `fifo_mem`      | Dual-port memory array                           |

### 4.2 `synchronizer` (synchronizer.sv)

A parameterized 2-stage flip-flop synchronizer for safe clock domain crossing.

```
d_in ──► [ FF q1 ] ──► [ FF d_out ] ──► d_out
             clk            clk
```

- **Parameter**: `WIDTH` (default 3, set to `PTR_WIDTH` by parent)
- **Latency**: 2 cycles of the destination clock
- **Reset**: Synchronous to destination clock; clears both stages to 0
- **Width**: `WIDTH+1` bits (extra MSB for wrap-around detection)

### 4.3 `wptr_handler` (wrptr_handler.sv)

Manages the write pointer and generates the `fifo_full` flag.

**Internal Signals:**

| Signal         | Width      | Description                                        |
|----------------|------------|----------------------------------------------------|
| `b_wptr`       | PTR_WIDTH+1 | Binary write pointer (registered)                 |
| `g_wptr`       | PTR_WIDTH+1 | Gray-coded write pointer (registered)             |
| `b_wptr_next`  | PTR_WIDTH+1 | Combinational next binary pointer                 |
| `g_wptr_next`  | PTR_WIDTH+1 | Combinational next Gray pointer                   |

**Key Logic:**

```verilog
// Binary-to-Gray conversion
assign g_wptr_next = (b_wptr_next >> 1) ^ b_wptr_next;

// Pointer increment (gated by wr_en and !fifo_full)
assign b_wptr_next = b_wptr + (wr_en & !fifo_full);

// Full detection (compare next gray write pointer with synchronized gray read pointer)
assign wfull = (g_wptr_next == {~g_rptr_sync[PTR_WIDTH:PTR_WIDTH-1],
                                  g_rptr_sync[PTR_WIDTH-2:0]});
```

**Full Condition Explained**: The FIFO is full when the write pointer has wrapped around once relative to the read pointer. In Gray code, this means:
- The top 2 bits of the write pointer are the **complement** of the synchronized read pointer's top 2 bits
- All remaining bits are **equal**

### 4.4 `rptr_handler` (rdptr_handler.sv)

Manages the read pointer and generates the `fifo_empty` flag.

**Key Logic:**

```verilog
// Binary-to-Gray conversion
assign g_rptr_next = (b_rptr_next >> 1) ^ b_rptr_next;

// Pointer increment (gated by rd_en and !fifo_empty)
assign b_rptr_next = b_rptr + (rd_en & !fifo_empty);

// Empty detection (next gray read pointer == synchronized gray write pointer)
assign rempty = (g_wptr_sync == g_rptr_next);
```

**Empty Condition Explained**: The FIFO is empty when read and write pointers are equal in Gray code. Since the write pointer is synchronized to the read domain, this comparison is safe.

**Reset Behavior**: On reset, `fifo_empty` is initialized to `1` (FIFO starts empty), while `fifo_full` is initialized to `0`.

### 4.5 `fifo_mem` (fifo_memory.sv)

A true dual-port register-file memory with independent read and write clocks.

```
Memory Array: reg [FIFO_WIDTH-1:0] fifo [0:FIFO_DEPTH-1]

Write Path (wrclk domain):
  if (wr_en & !fifo_full)
    fifo[b_wptr[PTR_WIDTH-1:0]] <= data_in;

Read Path (rdclk domain):
  if (rd_en & !fifo_empty)
    data_out <= fifo[b_rptr[PTR_WIDTH-1:0]];    // REGISTERED output
```

**Note**: The read output is registered (`<=`), meaning `data_out` is valid **one rdclk cycle after** `rd_en` is asserted. The commented-out combinational assign (`assign data_out = ...`) was an alternative approach that was not used.

---

## 5. Clock Domain Crossing Strategy

### 5.1 Why Gray Code?

Binary counters can change multiple bits simultaneously during a single increment (e.g., `0111 -> 1000` changes all 4 bits). If these bits are sampled in a different clock domain mid-transition, a corrupted value could be captured.

Gray code guarantees that **only one bit changes per increment**, making it safe to synchronize across clock domains even if the sampling clock captures a metastable transition on that single bit -- the resolved value will be either the old or new (both valid) pointer value.

### 5.2 Synchronization Path

```
Write Domain                                    Read Domain
─────────────                                   ────────────
g_wptr (Gray)  ──► [ sync_wptr: 2-FF ] ──►  g_wptr_sync
                         (rdclk)                   │
                                                   ▼
                                            rptr_handler
                                            (empty detection)

g_rptr_sync  ◄── [ sync_rptr: 2-FF ] ◄──  g_rptr (Gray)
     │                  (wrclk)
     ▼
wptr_handler
(full detection)
```

### 5.3 Conservatism of Flag Generation

Due to synchronization latency (2 destination clock cycles), the status flags are **conservative**:

- **`fifo_full`**: May remain asserted for 2 extra `wrclk` cycles after a read frees a slot. This is safe -- it prevents writes but does not lose data.
- **`fifo_empty`**: May remain asserted for 2 extra `rdclk` cycles after a write adds data. This is safe -- it prevents reads but does not lose data.

This conservative behavior is a fundamental property of the async FIFO architecture and is **by design**.

---

## 6. Verification Architecture

### 6.1 Methodology

The testbench follows a **UVM-inspired class-based architecture** without requiring the UVM library. Key patterns adopted:

- **Transaction-Level Modeling (TLM)**: Stimulus and observations are modeled as transaction objects
- **Mailbox Communication**: Decoupled components communicate via SystemVerilog mailboxes
- **Virtual Interface**: DUT signals are accessed through a parameterized SV interface
- **Separation of Concerns**: Driver, Monitor, Scoreboard, and Test are independent classes
- **Factory Pattern**: Test runner creates test objects by name using a factory function

### 6.2 Testbench Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│  tb_top (module)                                                        │
│                                                                         │
│  ┌─────────────┐  ┌─────────────┐                                      │
│  │ wrclk       │  │ rdclk       │     Clock Generators                 │
│  │ 100MHz/10ns │  │ ~77MHz/13ns │     (runtime-adjustable half-period) │
│  └──────┬──────┘  └──────┬──────┘                                      │
│         │                │                                              │
│  ┌──────▼────────────────▼──────────────────────────────┐              │
│  │  fifo_if #(FIFO_WIDTH) dut_if                        │              │
│  │  Modports: dut_mp | wr_tb_mp | rd_tb_mp | mon_mp     │              │
│  └──────┬───────────────────────────────────┬───────────┘              │
│         │                                   │ virtual interface        │
│  ┌──────▼──────────────────┐    ┌───────────▼────────────────────┐    │
│  │  asynchronous_fifo DUT  │    │  fifo_test_runner              │    │
│  │  (fifo_top.sv)          │    │    ├── fifo_env                │    │
│  └─────────────────────────┘    │    │     ├── fifo_driver       │    │
│                                  │    │     ├── fifo_monitor      │    │
│                                  │    │     └── fifo_scoreboard   │    │
│                                  │    └── test_* (28 test classes)│    │
│                                  └───────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Data Flow

```
  test                                              scoreboard
  (stimulus gen)                                    (checking)
       │                                                 ▲
       │ wr_mbx / rd_mbx                                 │ wr_scb_mbx / rd_scb_mbx
       ▼                                                 │
  ┌─────────┐       ┌──────────────┐       ┌─────────────┐
  │ driver  │──────►│  DUT (via    │──────►│  monitor     │
  │         │ drive │  fifo_if)    │ sample│              │
  └─────────┘       └──────────────┘       └──────────────┘
```

1. **Test** generates `fifo_transaction` objects and puts them into driver mailboxes
2. **Driver** consumes transactions, drives DUT pins via virtual interface
3. **DUT** processes writes/reads across clock domains
4. **Monitor** passively observes DUT outputs, creates observation transactions
5. **Scoreboard** compares observations against a reference queue model

---

## 7. Testbench Components

### 7.1 `fifo_if` (fifo_interface.sv)

SystemVerilog interface bundling all FIFO signals with four modports:

| Modport    | Purpose                        | Access                            |
|------------|--------------------------------|-----------------------------------|
| `dut_mp`   | DUT connection                 | Full access to all signals        |
| `wr_tb_mp` | Write-side testbench access    | Drive: wrst_n, wr_en, data_in    |
| `rd_tb_mp` | Read-side testbench access     | Drive: rrst_n, rd_en             |
| `mon_mp`   | Monitor (passive observation)  | Read-only on all signals          |

### 7.2 `fifo_transaction` (fifo_transaction.sv)

Transaction class containing:

| Field         | Type          | Description                        |
|---------------|---------------|------------------------------------|
| `wr_en`       | rand bit      | Write enable (stimulus)            |
| `rd_en`       | rand bit      | Read enable (stimulus)             |
| `data`        | rand bit[63:0]| Write data (stimulus)              |
| `data_out`    | bit[63:0]     | Observed read data                 |
| `fifo_full`   | bit           | Observed full flag                 |
| `fifo_empty`  | bit           | Observed empty flag                |
| `capture_time`| time          | Timestamp of capture               |

Also includes `fifo_txn_type_e` enum: `{FIFO_IDLE, FIFO_WRITE, FIFO_READ}`

### 7.3 `fifo_driver` (fifo_driver.sv)

Two concurrent forever-loop tasks running in parallel:

**`drive_write()`** (wrclk domain):
1. Get transaction from `wr_mbx`
2. Wait while `fifo_full` is asserted
3. Align to `posedge wrclk` + 1ns skew
4. Assert `wr_en=1`, drive `data_in`
5. Next cycle: deassert `wr_en=0` (or sustain for burst)

**`drive_read()`** (rdclk domain):
1. Get transaction from `rd_mbx`
2. Wait while `fifo_empty` is asserted
3. Align to `posedge rdclk` + 1ns skew
4. Assert `rd_en=1`
5. Next cycle: deassert `rd_en=0` (or sustain for burst)

The 1ns post-edge skew prevents delta-cycle race conditions with the DUT sampling logic.

### 7.4 `fifo_monitor` (fifo_monitor.sv)

Two concurrent passive observation tasks:

**`monitor_write()`**: Captures on `posedge wrclk` when `wrst_n && wr_en && !fifo_full`

**`monitor_read()`**: Uses a **1-cycle delay compensation** mechanism:
- Cycle N: Detects `rd_en=1 && !fifo_empty` -> sets `rd_was_valid` flag
- Cycle N+1: `data_out` is stable -> captures the transaction

This compensates for the registered `data_out` in the RTL.

### 7.5 `fifo_scoreboard` (fifo_scoreboard.sv)

Reference model using a SystemVerilog queue (`ref_q[$]`):

- **On write observation**: `ref_q.push_back(txn.data)`
- **On read observation**: `expected = ref_q.pop_front()`, compare with `txn.data_out` using `===` (4-state equality, catches X/Z)
- **Report**: Prints write count, read count, pass count, fail count
- **Grouped display**: Shows full transaction lifecycle with timestamps from driver, monitor, and scoreboard

### 7.6 `fifo_env` (fifo_env.sv)

Environment aggregator that:
- Creates all 4 mailboxes (wr_mbx, rd_mbx, wr_scb_mbx, rd_scb_mbx)
- Instantiates driver, monitor, scoreboard
- Provides `run()` to start all components in parallel via `fork-join_none`
- Provides `reset()` to drain mailboxes and clear scoreboard state between tests

### 7.7 `fifo_test_base` (fifo_test_base.sv)

Base class providing reusable helper tasks:

| Task/Function     | Description                                              |
|-------------------|----------------------------------------------------------|
| `write_n(n)`      | Queue N random write transactions                        |
| `read_n(n)`       | Queue N read transactions                                |
| `write_data(d)`   | Queue a write with specific 64-bit data                  |
| `wait_drain(t)`   | Wait for mailboxes to empty + CDC settling time          |
| `reset_dut()`     | Assert/deassert both resets with proper timing           |
| `reset_phase()`   | Full reset: reset_dut() + env.reset()                    |

### 7.8 `fifo_test_runner` (fifo_test_runner.sv)

Test orchestrator with:
- **Factory function**: `create_test(name)` returns the appropriate test object
- **Test selection**: Via `+TEST_NAME=<name>` plusarg (default: `all`)
- **Sequential execution**: Runs each test with environment reset between tests
- **Summary report**: Per-test PASS/FAIL table at the end of simulation

---

## 8. Test Plan & Test Cases

### 8.1 Test Summary (28 Total)

#### Reset Tests (6)

| # | Test Name                    | Description                                  | Category |
|---|------------------------------|----------------------------------------------|----------|
| 1 | `test_reset`                 | Fill FIFO, reset, verify empty, write/read fresh data | Reset |
| 2 | `test_reset_when_empty`      | Reset on empty FIFO, verify correct state    | Reset    |
| 3 | `test_reset_when_full`       | Fill completely, reset, verify empty         | Reset    |
| 4 | `test_reset_during_write`    | Assert reset while write is in progress      | Reset    |
| 5 | `test_reset_during_read`     | Assert reset while read is in progress       | Reset    |
| 6 | `test_reset_partial_fill`    | Reset with partial fill, verify recovery     | Reset    |

#### Normal Operation Tests (15)

| #  | Test Name                      | Description                                        |
|----|--------------------------------|----------------------------------------------------|
| 7  | `test_basic`                   | Sequential write N, read N; verify data integrity  |
| 8  | `test_fill_drain`              | Fill to depth, check full, drain, check empty      |
| 9  | `test_simultaneous_rw`         | Half-fill, then concurrent writes and reads        |
| 10 | `test_pointer_wrap`            | Multiple fill-drain cycles for pointer wrap-around |
| 11 | `test_clock_ratio`             | Write-fast/read-slow, write-slow/read-fast, equal  |
| 12 | `test_single_entry`            | Write 1, read 1; minimal occupancy                 |
| 13 | `test_full_flag_timing`        | Verify full flag timing relative to writes         |
| 14 | `test_empty_flag_timing`       | Verify empty flag timing relative to reads         |
| 15 | `test_almost_full`             | Fill FIFO_DEPTH-1 entries; near-full boundary      |
| 16 | `test_almost_empty`            | Read down to 1 entry; near-empty boundary          |
| 17 | `test_alternating_rw`          | Interleaved single writes and reads                |
| 18 | `test_burst_write_burst_read`  | Back-to-back writes then back-to-back reads        |
| 19 | `test_data_integrity_patterns` | All-0s, all-1s, alternating bit patterns           |
| 20 | `test_fifo_depth_boundary`     | Operations at exact FIFO depth boundary            |
| 21 | `test_continuous_streaming`    | Sustained write/read stream to stress CDC          |

#### Negative / Edge-Case Tests (7)

| #  | Test Name                            | Description                                    |
|----|--------------------------------------|------------------------------------------------|
| 22 | `test_overflow_underflow`            | Write when full, read when empty; verify ignored|
| 23 | `test_write_when_full_data_check`    | Write on full FIFO; verify no data corruption  |
| 24 | `test_read_when_empty_pointer_check` | Read on empty FIFO; verify pointer stability   |
| 25 | `test_simultaneous_reset_write`      | Reset while write is active                    |
| 26 | `test_simultaneous_reset_read`       | Reset while read is active                     |
| 27 | `test_back_to_back_overflow`         | Multiple consecutive overflow attempts         |
| 28 | `test_back_to_back_underflow`        | Multiple consecutive underflow attempts        |

### 8.2 Coverage Areas

| Coverage Category         | Tests Covering It                                          |
|---------------------------|------------------------------------------------------------|
| Basic Data Integrity      | test_basic, test_data_integrity_patterns                   |
| Full Flag                 | test_fill_drain, test_full_flag_timing, test_almost_full   |
| Empty Flag                | test_fill_drain, test_empty_flag_timing, test_almost_empty |
| Pointer Wrap-Around       | test_pointer_wrap, test_fill_drain                         |
| CDC / Clock Ratios        | test_clock_ratio, test_continuous_streaming                |
| Concurrent R/W            | test_simultaneous_rw, test_alternating_rw                  |
| Overflow Protection       | test_overflow_underflow, test_write_when_full_data_check, test_back_to_back_overflow |
| Underflow Protection      | test_overflow_underflow, test_read_when_empty_pointer_check, test_back_to_back_underflow |
| Reset Scenarios           | All 6 reset tests                                          |
| Boundary Conditions       | test_single_entry, test_fifo_depth_boundary                |
| Burst Transfers           | test_burst_write_burst_read, test_continuous_streaming     |

---

## 9. Simulation Infrastructure

### 9.1 Directory Structure

```
Asynchronous-FIFO/
├── rtl/                              RTL source files
│   └── sig_async_fifo_flst.f         RTL filelist
├── verif/
│   ├── tb/                           Testbench source files
│   │   └── sig_async_fifo_tb_flst.f  TB filelist (compile-order aware)
│   └── run/                          Simulation working directory
│       ├── results/                  Timestamped result logs
│       └── xcelium.d/               Xcelium compilation artifacts
├── doc/                              Documentation & test plan
├── tb_architecture.md                Testbench architecture (ASCII diagrams)
├── sourcefile.csh                    Environment setup script
└── SNUG 2002 Cliffords.pdf          Reference paper
```

### 9.2 Environment Setup

```csh
# Set project root (required before simulation)
source sourcefile.csh
# This sets: SIG_FIFO_HOME = <project_root>
```

### 9.3 Running Simulations (Cadence Xcelium)

```bash
# Compile and run all tests
xrun -f $SIG_FIFO_HOME/rtl/sig_async_fifo_flst.f \
     -f $SIG_FIFO_HOME/verif/tb/sig_async_fifo_tb_flst.f \
     +TEST_NAME=all

# Run a specific test
xrun -f $SIG_FIFO_HOME/rtl/sig_async_fifo_flst.f \
     -f $SIG_FIFO_HOME/verif/tb/sig_async_fifo_tb_flst.f \
     +TEST_NAME=test_basic

# Enable waveform dumping (VCD)
xrun ... +define+DUMP_ON

# Enable SHM waveform dumping (Cadence SimVision)
xrun ... +define+DUMP_ON +define+CADENCE
```

### 9.4 Waveform Viewing

| Format | File                       | Viewer                  | Enable Flag             |
|--------|----------------------------|-------------------------|-------------------------|
| VCD    | `fifo_tb.vcd`              | Any VCD viewer          | `+define+DUMP_ON`       |
| SHM    | `sig_cxl_amx_pm_top.shm`  | Cadence SimVision       | `+define+DUMP_ON +define+CADENCE` |

### 9.5 Compile Order

The testbench filelist (`sig_async_fifo_tb_flst.f`) enforces strict compile order:

1. Interface definition (`fifo_interface.sv`)
2. Transaction class (`fifo_transaction.sv`)
3. Testbench components (driver, monitor, scoreboard, env)
4. Base test class (`fifo_test_base.sv`)
5. All test classes (28 files)
6. Test runner (`fifo_test_runner.sv`)
7. Top-level testbench (`tb_top.sv`)

---

## 10. Known Issues & Status

### 10.1 Current Test Results

As of the latest commit (`d9e6cd8`):

| Metric      | Count |
|-------------|-------|
| **Passed**  | 24    |
| **Failed**  | 4     |
| **Total**   | 28    |

### 10.2 Design Considerations

1. **Conservative Flag Behavior**: Due to the 2-stage synchronizer latency, `fifo_full` and `fifo_empty` may remain asserted for up to 2 extra destination clock cycles after the condition clears. This is inherent to the architecture and is safe (prevents data loss at the cost of slightly reduced throughput).

2. **Registered Data Output**: The 1-cycle read latency on `data_out` must be accounted for by any consumer logic. The testbench monitor handles this via the `rd_was_valid` delay mechanism.

3. **Single Reset Assertion**: Both `wrst_n` and `rrst_n` are asserted and deasserted together in the testbench. Independent reset testing per domain is not currently exercised.

---

## 11. References

1. Clifford E. Cummings, "Simulation and Synthesis Techniques for Asynchronous FIFO Design," SNUG 2002 (included in project as `SNUG 2002 Cliffords.pdf`)
2. Cadence Xcelium Simulator User Guide
3. IEEE Std 1800-2017 (SystemVerilog Language Reference Manual)

---

*Document generated: March 2026*
