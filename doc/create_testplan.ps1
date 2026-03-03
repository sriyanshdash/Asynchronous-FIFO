# create_testplan.ps1 - Generate async FIFO testplan Excel file
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$workbook = $excel.Workbooks.Add()
$sheet = $workbook.Worksheets.Item(1)
$sheet.Name = "FIFO Testplan"

# --- Headers ---
$headers = @("Category", "Test Name", "File Name", "Description", "Status")
for ($c = 1; $c -le $headers.Length; $c++) {
    $sheet.Cells.Item(1, $c) = $headers[$c-1]
    $sheet.Cells.Item(1, $c).Font.Bold = $true
    $sheet.Cells.Item(1, $c).Font.Size = 11
    $sheet.Cells.Item(1, $c).Interior.Color = 0x8B4513
    $sheet.Cells.Item(1, $c).Font.Color = 0x00FFFFFF
    $sheet.Cells.Item(1, $c).HorizontalAlignment = -4108
}

# --- Test data ---
$data = @(
    # ===== RESET =====
    @("Reset", "test_reset", "test_reset.sv",
      "Fill FIFO with data, assert reset mid-operation, verify fifo_empty=1 and fifo_full=0 during reset, deassert reset, write+read new data to verify clean recovery",
      "Implemented"),
    @("Reset", "test_reset_when_empty", "test_reset_when_empty.sv",
      "Assert reset when FIFO is already empty. Verify flags remain correct (fifo_empty=1, fifo_full=0) and FIFO is functional after deassertion",
      "Implemented"),
    @("Reset", "test_reset_when_full", "test_reset_when_full.sv",
      "Fill FIFO to capacity (fifo_full=1), assert reset, verify all pointers clear and fifo_empty=1 after reset. Write fresh data and read back",
      "Implemented"),
    @("Reset", "test_reset_during_write", "test_reset_during_write.sv",
      "Assert reset while wr_en=1 and a write is actively in progress. Verify no partial write corrupts memory, FIFO resets cleanly",
      "Implemented"),
    @("Reset", "test_reset_during_read", "test_reset_during_read.sv",
      "Assert reset while rd_en=1 and a read is actively in progress. Verify no spurious data_out, FIFO resets cleanly",
      "Implemented"),
    @("Reset", "test_reset_partial_fill", "test_reset_partial_fill.sv",
      "Write a few entries (not full, not empty), assert reset. Verify old data is gone: write new data after reset and read back only new data",
      "Implemented"),

    # ===== NORMAL =====
    @("Normal", "test_basic", "test_basic.sv",
      "Write 20 random values then read 20 values back. Verifies basic FIFO data integrity and ordering through scoreboard comparison",
      "Implemented"),
    @("Normal", "test_fill_drain", "test_fill_drain.sv",
      "Write exactly FIFO_DEPTH entries, check fifo_full asserts. Read FIFO_DEPTH entries, check fifo_empty asserts. Repeat 2nd cycle for pointer wrap-around",
      "Implemented"),
    @("Normal", "test_simultaneous_rw", "test_simultaneous_rw.sv",
      "Half-fill FIFO, then queue writes and reads concurrently so both clock domains are active simultaneously on a non-full non-empty FIFO",
      "Implemented"),
    @("Normal", "test_pointer_wrap", "test_pointer_wrap.sv",
      "3 full fill-drain cycles (3 x FIFO_DEPTH) to force Gray-code pointers to wrap around multiple times. Verifies MSB-based full/empty detection across wrap boundaries",
      "Implemented"),
    @("Normal", "test_clock_ratio", "test_clock_ratio.sv",
      "Tests 3 clock scenarios at runtime: write-fast/read-slow (200/50 MHz), write-slow/read-fast (50/200 MHz), equal frequency (100/100 MHz). Verifies CDC under all ratios",
      "Implemented"),
    @("Normal", "test_single_entry", "test_single_entry.sv",
      "Write exactly 1 entry, read exactly 1 entry. Minimum-case test verifying the simplest possible FIFO transaction works correctly",
      "Implemented"),
    @("Normal", "test_full_flag_timing", "test_full_flag_timing.sv",
      "Write entries one-by-one, checking fifo_full after each write. Verify fifo_full asserts after exactly FIFO_DEPTH writes and NOT before. Verify it deasserts after 1 read",
      "Implemented"),
    @("Normal", "test_empty_flag_timing", "test_empty_flag_timing.sv",
      "Fill FIFO, then read one-by-one checking fifo_empty after each read. Verify fifo_empty asserts after the last read and NOT before. Verify it deasserts after 1 write",
      "Implemented"),
    @("Normal", "test_almost_full", "test_almost_full.sv",
      "Fill to FIFO_DEPTH-1 entries. Verify fifo_full is NOT asserted. Write 1 more, verify fifo_full IS now asserted. Tests the exact full boundary condition",
      "Implemented"),
    @("Normal", "test_almost_empty", "test_almost_empty.sv",
      "Fill FIFO, drain to 1 entry remaining. Verify fifo_empty is NOT asserted. Read the last entry, verify fifo_empty IS now asserted. Tests the exact empty boundary",
      "Implemented"),
    @("Normal", "test_alternating_rw", "test_alternating_rw.sv",
      "Alternate single write and single read operations: W-R-W-R-W-R for 20 cycles. FIFO never has more than 1 entry. Stresses continuous flag toggling across CDC",
      "Implemented"),
    @("Normal", "test_burst_write_burst_read", "test_burst_write_burst_read.sv",
      "Write FIFO_DEPTH entries in a continuous burst (wr_en held high), then read FIFO_DEPTH in a continuous burst (rd_en held high). Tests back-to-back pipeline throughput",
      "Implemented"),
    @("Normal", "test_data_integrity_patterns", "test_data_integrity_patterns.sv",
      "Write known data patterns: all-zeros (0x0), all-ones (0xFFF...F), 0xAAA...A, 0x555...5, walking-1, walking-0. Read back and verify each. Catches stuck-bit or bus-wiring errors",
      "Implemented"),
    @("Normal", "test_fifo_depth_boundary", "test_fifo_depth_boundary.sv",
      "Write FIFO_DEPTH-1 entries (almost full), read 1 (make space), write 2 more (should fill). Verifies flag logic at the full boundary with interleaved operations",
      "Implemented"),
    @("Normal", "test_continuous_streaming", "test_continuous_streaming.sv",
      "Continuous write+read at matched rates for 100+ transactions. FIFO stays partially filled throughout. Tests sustained steady-state throughput and long-running pointer arithmetic",
      "Implemented"),

    # ===== NEGATIVE =====
    @("Negative", "test_overflow_underflow", "test_overflow_underflow.sv",
      "Overflow: fill FIFO, force wr_en=1 while fifo_full=1 via direct VIF drive, verify write is ignored and existing data intact. Underflow: force rd_en=1 while fifo_empty=1, verify no spurious data",
      "Implemented"),
    @("Negative", "test_write_when_full_data_check", "test_write_when_full_data_check.sv",
      "Fill FIFO with known pattern A, force multiple writes of pattern B while full. Read all entries back, verify only pattern A appears and pattern B is completely absent",
      "Implemented"),
    @("Negative", "test_read_when_empty_pointer_check", "test_read_when_empty_pointer_check.sv",
      "Empty FIFO, force rd_en=1 for multiple consecutive cycles while fifo_empty=1. Then write+read normally, verify read pointer was not corrupted by the illegal reads",
      "Implemented"),
    @("Negative", "test_simultaneous_reset_write", "test_simultaneous_reset_write.sv",
      "Assert wrst_n=0 and wr_en=1 at the same time. Verify reset takes priority: no data is written, FIFO comes out of reset empty and clean",
      "Implemented"),
    @("Negative", "test_simultaneous_reset_read", "test_simultaneous_reset_read.sv",
      "Assert rrst_n=0 and rd_en=1 at the same time. Verify reset takes priority: no data is read, no spurious data_out, FIFO resets cleanly",
      "Implemented"),
    @("Negative", "test_back_to_back_overflow", "test_back_to_back_overflow.sv",
      "Fill FIFO, then force 10 consecutive writes while full (wr_en held high for 10 cycles with fifo_full=1). Verify none corrupt the FIFO. Drain and check all original data intact",
      "Implemented"),
    @("Negative", "test_back_to_back_underflow", "test_back_to_back_underflow.sv",
      "Empty FIFO, then force 10 consecutive reads while empty (rd_en held high for 10 cycles with fifo_empty=1). Verify read pointer does not advance. Write+read 1 entry to confirm FIFO still works",
      "Implemented")
)

# --- Write data ---
for ($r = 0; $r -lt $data.Length; $r++) {
    for ($c = 0; $c -lt $data[$r].Length; $c++) {
        $sheet.Cells.Item($r + 2, $c + 1) = $data[$r][$c]
    }
}

# --- Row coloring by category + status ---
for ($r = 0; $r -lt $data.Length; $r++) {
    $cat = $data[$r][0]
    $status = $data[$r][4]

    # Category colors (BGR format)
    switch ($cat) {
        "Reset"    { $color = 0xFFE0CC }   # light blue
        "Normal"   { $color = 0xCCFFCC }   # light green
        "Negative" { $color = 0xCCCCFF }   # light salmon/red
    }

    for ($c = 1; $c -le 5; $c++) {
        $sheet.Cells.Item($r + 2, $c).Interior.Color = $color
    }

    # Status column styling
    if ($status -eq "Implemented") {
        $sheet.Cells.Item($r + 2, 5).Font.Color = 0x008000
        $sheet.Cells.Item($r + 2, 5).Font.Bold = $true
    } else {
        $sheet.Cells.Item($r + 2, 5).Font.Color = 0x0000CC
    }
}

# --- Formatting ---
$sheet.Columns.Item(1).ColumnWidth = 12
$sheet.Columns.Item(2).ColumnWidth = 38
$sheet.Columns.Item(3).ColumnWidth = 40
$sheet.Columns.Item(4).ColumnWidth = 80
$sheet.Columns.Item(5).ColumnWidth = 16
$sheet.Columns.Item(4).WrapText = $true

$usedRange = $sheet.UsedRange
$usedRange.Borders.LineStyle = 1
$usedRange.Borders.Weight = 2
$usedRange.VerticalAlignment = -4160  # top-align

# Header row: freeze panes
$sheet.Rows.Item(1).Font.Size = 11
$sheet.Application.ActiveWindow.SplitRow = 1
$sheet.Application.ActiveWindow.FreezePanes = $true

# Auto-filter
$usedRange.AutoFilter() | Out-Null

# --- Save ---
$path = "C:\Users\sriyansh\Asynchronous-FIFO\doc\async_fifo_testplan.xlsx"
$workbook.SaveAs($path, 51)
$workbook.Close()
$excel.Quit()

[System.Runtime.InteropServices.Marshal]::ReleaseComObject($sheet) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null

Write-Host "Testplan created: $path"
