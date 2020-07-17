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

`include "csr_mgr.vh"
`include "cci_mpf_if.vh"
`include "platform_if.vh"
`include "afu_json_info.vh"

module soma_csr
 (
  input	clk,
  input	SoftReset,

  app_csrs.app csrs,

  output logic		 start,
  input  logic		 finish,

  output logic [19:0]	 count_to_afuQ,
  output logic [19:0]	 count_to_afuR,
  output logic [63:0]	 setRd_addr_read_1,
  output logic [63:0]	 setWr_addr_writeA,
  output logic [63:0]	 setWr_addr_writeB
);

localparam CL_BYTE_IDX_BITS = 6;
typedef logic [$bits(t_cci_clAddr) + CL_BYTE_IDX_BITS - 1 : 0] t_byteAddr;

function automatic t_cci_clAddr byteAddrToClAddr(t_byteAddr addr);
    return addr[CL_BYTE_IDX_BITS +: $bits(t_cci_clAddr)];
endfunction

function automatic t_byteAddr clAddrToByteAddr(t_cci_clAddr addr);
    return {addr, CL_BYTE_IDX_BITS'(0)};
endfunction

localparam DATA_WIDTH		 = 64;

localparam SCRATCH_REG      = 6'h02;                // Scratch Register
localparam CTRL  	    = 6'h03;
localparam COUNT_TO         = 6'h04;
localparam BASE_ADDR        = 6'h05;
localparam STATUS           = 6'h09;

logic [63:0] scratch_reg;
logic [63:0] base_addr;
logic [19:0] count_to;
logic [6:0]  ctrl;

   assign count_to_afuQ = count_to;
   assign count_to_afuR = count_to;
   assign setRd_addr_read_1  = byteAddrToClAddr(base_addr);
   assign setWr_addr_writeA = byteAddrToClAddr(base_addr);
   assign setWr_addr_writeB = byteAddrToClAddr(base_addr);

always_ff @(posedge clk) begin
  if(SoftReset) begin
    scratch_reg    <= '0;
    ctrl	   <= '0;
    start	   <= '0;
    count_to   <= '0;
    base_addr        <= '0;
  end
  else begin
      start	<= ctrl[1];
      if(csrs.cpu_wr_csrs[SCRATCH_REG].en) begin
        scratch_reg <= csrs.cpu_wr_csrs[SCRATCH_REG].data[63:0];
      end
      if(csrs.cpu_wr_csrs[CTRL].en) begin
        ctrl <= csrs.cpu_wr_csrs[CTRL].data[6:0];
      end
      if(csrs.cpu_wr_csrs[COUNT_TO].en) begin
        count_to <= csrs.cpu_wr_csrs[COUNT_TO].data[31:0];
      end
      if(csrs.cpu_wr_csrs[BASE_ADDR].en) begin
        base_addr <= csrs.cpu_wr_csrs[BASE_ADDR].data[63:0];
      end
    end
end

always_comb
    begin
      csrs.afu_id = `AFU_ACCEL_UUID;
      // Default
      for (int i = 0; i < NUM_APP_CSRS; i = i + 1)
      begin
          csrs.cpu_rd_csrs[i].data = 64'(0);
      end

      csrs.cpu_rd_csrs[SCRATCH_REG].data = scratch_reg;
      csrs.cpu_rd_csrs[STATUS].data  = {61'd0,
                                            finish, //   2
                                            2'd0};    // 1:0
end
endmodule
