// MIT License
// 
// Copyright (c) 2020 by Joseph Melber, Carnegie Mellon University
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// Service module that generates messages to services from software MMIO CSR writes.
//

`include "active_msg.vh"
`include "platform_if.vh"
`include "cci_mpf_if.vh"

module csr2membuf
   (
    input  logic clk,
    input  logic rst,

    // Connections toward the server
    server.clt write_0,

    input  logic new_go,
    input  logic [255:0] data,

    input  logic [63:0] capacity,
    output logic [63:0] tail
    );

   logic rst_n;
   assign rst_n = ~rst;

   logic [63:0] cycle;

   always_ff @(posedge clk) begin    
       if(~rst_n) begin
           cycle <= 0;
       end else begin
           cycle <= cycle + 1;
       end
   end

   logic [63:0] serial, offset;

   logic full_n, empty_n;
   logic [255:0] data_buf;

  // arg0 ? 
  // arg1 address
  // arg2 ?
  // arg3 ?
   always_ff @(posedge clk) begin
      if(~rst_n) begin
        write_0.txP.tx <= 0;

        serial <= 64'd1; 
        offset <= '0;
      end else begin
        write_0.txP.tx <= new_go && !write_0.txFull;
        if (new_go && !write_0.txFull) begin
          write_0.txP.tx_msg.head.srcid <=  '0;
          write_0.txP.tx_msg.head.dstid <=  '0;
          write_0.txP.tx_msg.head.arg0 <=  '0;
          write_0.txP.tx_msg.head.arg1 <=  offset;
          write_0.txP.tx_msg.head.arg2 <=  '0;
          write_0.txP.tx_msg.head.arg3 <=  '0;
          write_0.txP.tx_msg.data <= {64'hfeedface,serial,offset,64'd0,data};
          offset <= ((offset+64'd1)<capacity) ? offset + 64'd1 : 64'd0;
          serial <= serial + 64'd1;
          $display("Send data to host buffer - cnt: %x, ptr: %x, data: %x",serial,offset,data);
        end else if (write_0.txFull&&new_go)
          $display("ERROR dropped data: %x",data);
      end
   end

   assign write_0.rxPop = !write_0.rxP.rxEmpty;

   always_ff @(posedge clk) begin
     if(~rst_n) begin
      tail <= 0;
     end else begin
       if (!write_0.rxP.rxEmpty) begin
         tail <= write_0.rxP.rx_msg.head.arg1;
         $display("Tail pointer updated - tail: %x",tail);
       end
     end
   end

endmodule
