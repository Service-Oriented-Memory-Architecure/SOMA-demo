
// Copyright (c) 2000-2009 Bluespec, Inc.

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
// $Revision: 24080 $
// $Date: 2011-05-18 15:32:52 -0400 (Wed, 18 May 2011) $


//
// There are two main differences in the Altera-specific RegFile from the
// standard version:
//
// 1. Quartus doesn't construct more read ports automatically by replicating
//    RAMs.  The five memories are constructed independently here.  Quartus
//    does eliminate unused copies.
//
// 2. Altera doesn't guarantee read/write order of MLAB/LUTRAM.  To
//    guarantee read-before-write RegFile semantics, writes are delayed
//    a cycle and bypassed to the read during the write cycle.
//
//    While more expensive, this has the advantage of being correct.
//


`ifdef  BSV_WARN_REGFILE_ADDR_RANGE
`else
`define BSV_WARN_REGFILE_ADDR_RANGE 0 
`endif


`ifdef BSV_ASSIGNMENT_DELAY
`else
`define BSV_ASSIGNMENT_DELAY
`endif


// Multi-ported Register File
module RegFile(CLK,
               ADDR_IN, D_IN, WE,
               ADDR_1, D_OUT_1,
               ADDR_2, D_OUT_2,
               ADDR_3, D_OUT_3,
               ADDR_4, D_OUT_4,
               ADDR_5, D_OUT_5
               );
   parameter                   addr_width = 1;
   parameter                   data_width = 1;
   parameter                   lo = 0;
   parameter                   hi = 1;

   input                       CLK;
   input [addr_width - 1 : 0]  ADDR_IN;
   input [data_width - 1 : 0]  D_IN;
   input                       WE;

   input [addr_width - 1 : 0]  ADDR_1;
   output [data_width - 1 : 0] D_OUT_1;

   input [addr_width - 1 : 0]  ADDR_2;
   output [data_width - 1 : 0] D_OUT_2;

   input [addr_width - 1 : 0]  ADDR_3;
   output [data_width - 1 : 0] D_OUT_3;

   input [addr_width - 1 : 0]  ADDR_4;
   output [data_width - 1 : 0] D_OUT_4;

   input [addr_width - 1 : 0]  ADDR_5;
   output [data_width - 1 : 0] D_OUT_5;

   // Buffers for delaying writes one cycle
   reg [addr_width - 1 : 0] wAddr;
   reg [data_width - 1 : 0] wData;
   reg                      wEN;

   //
   // Timing of read vs. write to the same address must be DONT_CARE for
   // MLAB.  Conflicts are handled with bypasses below.
   //
   wire [addr_width - 1 : 0] addr[0 : 4];
   wire [data_width - 1 : 0] data_out[0 : 4];

   assign addr[0] = ADDR_1;
   assign addr[1] = ADDR_2;
   assign addr[2] = ADDR_3;
   assign addr[3] = ADDR_4;
   assign addr[4] = ADDR_5;

   genvar i;
   generate
      for (i = 0; i < 5; i = i + 1)
      begin : r
       altdpram
       #(
         .width(data_width),
         .widthad(addr_width),
         .ram_block_type("MLAB"),
         .numwords(hi + 1 - lo),
         .wraddress_aclr("OFF"),
         .wrcontrol_aclr("OFF"),
         .rdaddress_aclr("OFF"),
         .rdaddress_reg("UNREGISTERED"),
         .rdcontrol_reg("UNREGISTERED"),
         .rdcontrol_aclr("OFF"),
         .indata_aclr("OFF"),
         .outdata_reg("UNREGISTERED"),
         .outdata_aclr("OFF")
         )
       arr
        (
         .inclock(CLK),
         .inclocken(1'b1),
         .data(wData),
         .wraddress(wAddr - lo),
         .wren(wEN),
         .rdaddress(addr[i] - lo),
         .rden(1'b1),
         .q(data_out[i]),

         // No connection required
         .outclock(),
         .outclocken(),
         .wraddressstall(),
         .rdaddressstall(),
         .byteena(),
         .aclr(),
         .sclr()
         );
      end
   endgenerate

   assign D_OUT_1 = (wEN && (wAddr == ADDR_1)) ? wData : data_out[0];
   assign D_OUT_2 = (wEN && (wAddr == ADDR_2)) ? wData : data_out[1];
   assign D_OUT_3 = (wEN && (wAddr == ADDR_3)) ? wData : data_out[2];
   assign D_OUT_4 = (wEN && (wAddr == ADDR_4)) ? wData : data_out[3];
   assign D_OUT_5 = (wEN && (wAddr == ADDR_5)) ? wData : data_out[4];

   // Hold off doing the write until next cycle.
   always@(posedge CLK)
     begin
        wAddr <= `BSV_ASSIGNMENT_DELAY ADDR_IN;
        wData <= `BSV_ASSIGNMENT_DELAY D_IN;
        wEN <= `BSV_ASSIGNMENT_DELAY WE;
     end // always@ (posedge CLK)

   // synopsys translate_off
   always@(posedge CLK)
     begin : runtime_check
        reg enable_check;
        enable_check = `BSV_WARN_REGFILE_ADDR_RANGE ;
        if ( enable_check )
           begin
              if (( ADDR_1 < lo ) || (ADDR_1 > hi) )
                $display( "Warning: RegFile: %m -- Address port 1 is out of bounds: %h", ADDR_1 ) ;
              if (( ADDR_2 < lo ) || (ADDR_2 > hi) )
                $display( "Warning: RegFile: %m -- Address port 2 is out of bounds: %h", ADDR_2 ) ;
              if (( ADDR_3 < lo ) || (ADDR_3 > hi) )
                $display( "Warning: RegFile: %m -- Address port 3 is out of bounds: %h", ADDR_3 ) ;
              if (( ADDR_4 < lo ) || (ADDR_4 > hi) )
                $display( "Warning: RegFile: %m -- Address port 4 is out of bounds: %h", ADDR_4 ) ;
              if (( ADDR_5 < lo ) || (ADDR_5 > hi) )
                $display( "Warning: RegFile: %m -- Address port 5 is out of bounds: %h", ADDR_5 ) ;
              if ( WE && ( ADDR_IN < lo ) || (ADDR_IN > hi) )
                $display( "Warning: RegFile: %m -- Write Address port is out of bounds: %h", ADDR_IN ) ;
           end
     end
   // synopsys translate_on

endmodule
