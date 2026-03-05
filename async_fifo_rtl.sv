//=============================================================================
// File        : async_fifo_rtl.sv
// Description : Complete Asynchronous FIFO RTL — single-file compilation unit.
//               Contains all 5 RTL modules in dependency order:
//                 1. synchronizer
//                 2. fifo_mem
//                 3. wptr_handler
//                 4. rptr_handler
//                 5. asynchronous_fifo (top-level)
//
// Parameters  : FIFO_DEPTH = 8 (default), FIFO_WIDTH = 64 (default)
// Simulator   : Cadence Xcelium / any IEEE 1800-2017 compliant simulator
//=============================================================================

`timescale 1ns/1ps

//=============================================================================
// Module : synchronizer
// Description : 2-stage flip-flop synchronizer for safe clock domain crossing.
//               Parameterized width to handle Gray-coded pointer buses.
//=============================================================================
module synchronizer #(parameter WIDTH=3) (
    input clk, rst_n,
    input  [WIDTH:0] d_in,
    output reg [WIDTH:0] d_out
);
    reg [WIDTH:0] q1;

    always @(posedge clk) begin
        if (!rst_n) begin
            q1    <= 0;
            d_out <= 0;
        end else begin
            q1    <= d_in;
            d_out <= q1;
        end
    end
endmodule

//=============================================================================
// Module : fifo_mem
// Description : Dual-port register-file memory with independent read/write
//               clocks. Write is gated by wr_en & !fifo_full. Read output is
//               REGISTERED (1-cycle latency after rd_en assertion).
//=============================================================================
module fifo_mem #(
    parameter FIFO_DEPTH = 8,
    parameter FIFO_WIDTH = 16,
    parameter PTR_WIDTH  = 3
) (
    input wrclk, wr_en, rdclk, rd_en,
    input [PTR_WIDTH:0] b_wptr, b_rptr,
    input [FIFO_WIDTH-1:0] data_in,
    input fifo_full, fifo_empty,
    output reg [FIFO_WIDTH-1:0] data_out
);
    reg [FIFO_WIDTH-1:0] fifo [0:FIFO_DEPTH-1];

    always @(posedge wrclk) begin
        if (wr_en & !fifo_full) begin
            fifo[b_wptr[PTR_WIDTH-1:0]] <= data_in;
        end
    end

    always @(posedge rdclk) begin
        if (rd_en & !fifo_empty) begin
            data_out <= fifo[b_rptr[PTR_WIDTH-1:0]];
        end
    end
endmodule

//=============================================================================
// Module : wptr_handler
// Description : Write pointer manager and fifo_full flag generator.
//               Maintains binary and Gray-coded write pointers.
//               Full condition: top-2 Gray bits inverted vs sync'd read ptr,
//               remaining bits equal.
//=============================================================================
module wptr_handler #(parameter PTR_WIDTH=3) (
    input wrclk, wrst_n, wr_en,
    input  [PTR_WIDTH:0] g_rptr_sync,
    output reg [PTR_WIDTH:0] b_wptr, g_wptr,
    output reg fifo_full
);
    reg [PTR_WIDTH:0] b_wptr_next;
    reg [PTR_WIDTH:0] g_wptr_next;

    reg wrap_around;
    wire wfull;

    assign b_wptr_next = b_wptr + (wr_en & !fifo_full);
    assign g_wptr_next = (b_wptr_next >> 1) ^ b_wptr_next;

    always @(posedge wrclk or negedge wrst_n) begin
        if (!wrst_n) begin
            b_wptr <= 0;
            g_wptr <= 0;
        end else begin
            b_wptr <= b_wptr_next;
            g_wptr <= g_wptr_next;
        end
    end

    always @(posedge wrclk or negedge wrst_n) begin
        if (!wrst_n) fifo_full <= 0;
        else         fifo_full <= wfull;
    end

    assign wfull = (g_wptr_next == {~g_rptr_sync[PTR_WIDTH:PTR_WIDTH-1],
                                      g_rptr_sync[PTR_WIDTH-2:0]});
endmodule

//=============================================================================
// Module : rptr_handler
// Description : Read pointer manager and fifo_empty flag generator.
//               Maintains binary and Gray-coded read pointers.
//               Empty condition: Gray read pointer == sync'd Gray write pointer.
//=============================================================================
module rptr_handler #(parameter PTR_WIDTH=3) (
    input rdclk, rrst_n, rd_en,
    input  [PTR_WIDTH:0] g_wptr_sync,
    output reg [PTR_WIDTH:0] b_rptr, g_rptr,
    output reg fifo_empty
);
    reg [PTR_WIDTH:0] b_rptr_next;
    reg [PTR_WIDTH:0] g_rptr_next;

    assign b_rptr_next = b_rptr + (rd_en & !fifo_empty);
    assign g_rptr_next = (b_rptr_next >> 1) ^ b_rptr_next;
    assign rempty      = (g_wptr_sync == g_rptr_next);

    always @(posedge rdclk or negedge rrst_n) begin
        if (!rrst_n) begin
            b_rptr <= 0;
            g_rptr <= 0;
        end else begin
            b_rptr <= b_rptr_next;
            g_rptr <= g_rptr_next;
        end
    end

    always @(posedge rdclk or negedge rrst_n) begin
        if (!rrst_n) fifo_empty <= 1;
        else         fifo_empty <= rempty;
    end
endmodule

//=============================================================================
// Module : asynchronous_fifo (Top-Level)
// Description : Asynchronous FIFO with Gray-coded pointer CDC.
//               Integrates synchronizer, pointer handlers, and memory.
//=============================================================================
module asynchronous_fifo #(
    parameter FIFO_DEPTH = 8,
    parameter FIFO_WIDTH = 64
) (
    input wrclk, wrst_n,
    input rdclk, rrst_n,
    input wr_en, rd_en,
    input  [FIFO_WIDTH-1:0] data_in,
    output reg [FIFO_WIDTH-1:0] data_out,
    output reg fifo_full, fifo_empty
);

    parameter PTR_WIDTH = $clog2(FIFO_DEPTH);

    // Gray-coded synchronized pointers
    reg [PTR_WIDTH:0] g_wptr_sync, g_rptr_sync;
    reg [PTR_WIDTH:0] g_wptr, g_rptr;

    // Binary pointers
    reg [PTR_WIDTH:0] b_wptr, b_rptr;

    wire [PTR_WIDTH-1:0] waddr, raddr;

    //--- Write pointer to read clock domain ---
    synchronizer #(PTR_WIDTH) sync_wptr (
        .clk   (rdclk),
        .rst_n (rrst_n),
        .d_in  (g_wptr),
        .d_out (g_wptr_sync)
    );

    //--- Read pointer to write clock domain ---
    synchronizer #(PTR_WIDTH) sync_rptr (
        .clk   (wrclk),
        .rst_n (wrst_n),
        .d_in  (g_rptr),
        .d_out (g_rptr_sync)
    );

    //--- Write pointer handler ---
    wptr_handler #(PTR_WIDTH) wrptr_h (
        .wrclk      (wrclk),
        .wrst_n     (wrst_n),
        .wr_en      (wr_en),
        .g_rptr_sync(g_rptr_sync),
        .b_wptr     (b_wptr),
        .g_wptr     (g_wptr),
        .fifo_full  (fifo_full)
    );

    //--- Read pointer handler ---
    rptr_handler #(PTR_WIDTH) rdptr_h (
        .rdclk      (rdclk),
        .rrst_n     (rrst_n),
        .rd_en      (rd_en),
        .g_wptr_sync(g_wptr_sync),
        .b_rptr     (b_rptr),
        .g_rptr     (g_rptr),
        .fifo_empty (fifo_empty)
    );

    //--- FIFO Memory ---
    fifo_mem #(FIFO_DEPTH, FIFO_WIDTH, PTR_WIDTH) fifom (
        .wrclk     (wrclk),
        .wr_en     (wr_en),
        .rdclk     (rdclk),
        .rd_en     (rd_en),
        .b_wptr    (b_wptr),
        .b_rptr    (b_rptr),
        .data_in   (data_in),
        .fifo_full (fifo_full),
        .fifo_empty(fifo_empty),
        .data_out  (data_out)
    );

endmodule
