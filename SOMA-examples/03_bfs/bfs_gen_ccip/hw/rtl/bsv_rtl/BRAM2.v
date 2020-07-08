// Copyright (c) 2000-2011 Bluespec, Inc.

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// $Revision$
// $Date$

`ifdef BSV_ASSIGNMENT_DELAY
`else
 `define BSV_ASSIGNMENT_DELAY
`endif

// Dual-Ported BRAM (WRITE FIRST)
module BRAM2(CLKA,
             ENA,
             WEA,
             ADDRA,
             DIA,
             DOA,
             CLKB,
             ENB,
             WEB,
             ADDRB,
             DIB,
             DOB
             );

   parameter                      PIPELINED  = 0;
   parameter                      ADDR_WIDTH = 1;
   parameter                      DATA_WIDTH = 1;
   parameter                      MEMSIZE    = 1;

   input                          CLKA;
   input                          ENA;
   input                          WEA;
   input [ADDR_WIDTH-1:0]         ADDRA;
   input [DATA_WIDTH-1:0]         DIA;
   output [DATA_WIDTH-1:0]        DOA;

   input                          CLKB;
   input                          ENB;
   input                          WEB;
   input [ADDR_WIDTH-1:0]         ADDRB;
   input [DATA_WIDTH-1:0]         DIB;
   output [DATA_WIDTH-1:0]        DOB;


   wire                           RENA = ENA & !WEA;
   wire                           WENA = ENA & WEA;
   wire                           RENB = ENB & !WEB;
   wire                           WENB = ENB & WEB;
   
       bram_true2port
       #(
         //.AWIDTH(ADDR_WIDTH),
         .AWIDTH($clog2(MEMSIZE)),
         .DWIDTH(DATA_WIDTH),
         .DEPTH(MEMSIZE)
       ) memory (
         .address_a(ADDRA),
         .address_b(ADDRB),
         .clock(CLKA),
         .data_a(DIA),
         .data_b(DIB),
         .rden_a(RENA),
         .rden_b(RENB),
         .wren_a(WENA),
         .wren_b(WENB),
         .q_a(DOA),
         .q_b(DOB)
       );

endmodule // BRAM2
