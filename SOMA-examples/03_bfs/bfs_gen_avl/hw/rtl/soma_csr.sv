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

  output logic start,
  input logic finish,

  app_csrs.app csrs,

  output logic start_afuBFS,
  input logic finish_afuBFS,
  input logic [63:0] getNodesTchd_afuBFS,
  output logic start_worklistServiceMod,
  output logic [31:0] setCapacity_worklistServiceMod,
  output logic [63:0] setRd_addr_readNodes,
  output logic [63:0] setRd_addr_readEdges,
  output logic [63:0] setRd_addr_readDistance,
  output logic [63:0] setWr_addr_writeDistance,
  output logic [31:0] setBase_addr_distanceCache,
  output logic [63:0] setRd_addr_readWorklist,
  output logic [63:0] setWr_addr_writeWorklist,

  output logic [63:0] setRd_addr_readAVL,
  output logic [63:0] setRd_addr_readCCI,
  output logic [63:0] setWr_addr_writeAVL,
  output logic [63:0] setWr_addr_writeCCI,

  output logic [63:0]    source_csr2CA,
  output logic [63:0]    destination_csr2CA,
  output logic [63:0]    mc_num_csr2CA,
  output logic           start_csr2CA,
  output logic           clear_csr2CA,
  input  logic           done_csr2CA
);

localparam CL_BYTE_IDX_BITS = 6;

typedef logic [$bits(t_cci_clAddr) + CL_BYTE_IDX_BITS - 1 : 0] t_byteAddr;

function automatic t_cci_clAddr byteAddrToClAddr(t_byteAddr addr);
    return addr[CL_BYTE_IDX_BITS +: $bits(t_cci_clAddr)];
endfunction

function automatic t_byteAddr clAddrToByteAddr(t_cci_clAddr addr);
    return {addr, CL_BYTE_IDX_BITS'(0)};
endfunction

logic		 bfs_go;
logic		 bfs_done;
logic [31:0]	 bfs_numlines;
logic [63:0]	 bfs_work;
logic [63:0]	 bfs_src;
logic [63:0]	 bfs_edg;
logic [63:0]	 bfs_dst;
logic [63:0]    bfs_cap;
logic [63:0]    bfs_nds;

logic [63:0]    mcp_src;
logic [63:0]    mcp_dst;
logic [63:0]    mcp_num;
logic          mcp_go;
logic           mcp_clear;
logic           mcp_done;

assign start_afuBFS = bfs_go;
assign start_worklistServiceMod = bfs_go;

assign setRd_addr_readNodes = bfs_src;
assign setRd_addr_readEdges = bfs_edg;
assign setRd_addr_readDistance = bfs_dst;
assign setWr_addr_writeDistance = bfs_dst;
assign setBase_addr_distanceCache = bfs_dst;
assign setRd_addr_readWorklist = bfs_work;
assign setWr_addr_writeWorklist = bfs_work;
assign setCapacity_worklistServiceMod = bfs_cap;

assign bfs_done = finish_afuBFS;
assign bfs_nds = getNodesTchd_afuBFS;

assign setRd_addr_readAVL = 64'b0;
assign setRd_addr_readCCI = 64'b0;
assign setWr_addr_writeAVL = 64'b0;
assign setWr_addr_writeCCI = 64'b0;

assign source_csr2CA = mcp_src;
assign destination_csr2CA = mcp_dst;
assign mc_num_csr2CA = mcp_num;
assign start_csr2CA = mcp_go;
assign clear_csr2CA = mcp_clear;
assign mcp_done = done_csr2CA;

localparam DATA_WIDTH		 = 64;
localparam SCRATCH_REG      = 6'h02;                // Scratch Register
localparam BFS_CTRL	    = 6'h03;
localparam BFS_NUMLINES     = 6'h04;
localparam BFS_WORK         = 6'h05;
localparam BFS_SRC          = 6'h06;
localparam BFS_EDG          = 6'h07;
localparam BFS_DST          = 6'h08;
localparam BFS_STATUS       = 6'h09;
localparam BFS_NDS          = 6'h0A;
localparam BFS_CAP          = 6'h0B;
localparam MCP_DST          = 6'h0C;
localparam MCP_SRC          = 6'h0D;
localparam MCP_NUM          = 6'h0E;

logic [63:0] scratch_reg;
logic [6:0]  bfs_ctrl;

always_ff @(posedge clk) begin
  if(SoftReset) begin
    scratch_reg    <= '0;
    bfs_ctrl	   <= '0;
    bfs_go	   <= '0;
    bfs_numlines   <= '0;
    bfs_work       <= '0;
    bfs_src        <= '0;
    bfs_edg        <= '0;
    bfs_dst        <= '0;
    bfs_cap         <= 64'd16384;
    mcp_src         <= '0;
    mcp_dst         <= '0;
    mcp_num         <= '0;
    mcp_go	   <= '0;
    mcp_clear	   <= '0;
  end
  else begin
      //bfs_en	<= bfs_ctrl[0];
      bfs_go	<= bfs_ctrl[1];
      mcp_go   <= bfs_ctrl[3];
      mcp_clear   <= bfs_ctrl[4];
      //mcp1_go   <= bfs_ctrl[5];
      //mcp1_clear   <= bfs_ctrl[6];
      if(csrs.cpu_wr_csrs[SCRATCH_REG].en) begin
        scratch_reg <= csrs.cpu_wr_csrs[SCRATCH_REG].data[63:0];
      end
      if(csrs.cpu_wr_csrs[BFS_CTRL].en) begin
        bfs_ctrl <= csrs.cpu_wr_csrs[BFS_CTRL].data[6:0];
      end
      if(csrs.cpu_wr_csrs[BFS_NUMLINES].en) begin
        bfs_numlines <= csrs.cpu_wr_csrs[BFS_NUMLINES].data[31:0];
      end
      if(csrs.cpu_wr_csrs[BFS_WORK].en) begin
        bfs_work <= csrs.cpu_wr_csrs[BFS_WORK].data[63:0];
      end
      if(csrs.cpu_wr_csrs[BFS_SRC].en) begin
        bfs_src <= csrs.cpu_wr_csrs[BFS_SRC].data[63:0];
      end
      if(csrs.cpu_wr_csrs[BFS_EDG].en) begin
        bfs_edg <= (csrs.cpu_wr_csrs[BFS_EDG].data[63:0]);
      end
      if(csrs.cpu_wr_csrs[BFS_DST].en) begin
        bfs_dst <= csrs.cpu_wr_csrs[BFS_DST].data[63:0];
      end
      if(csrs.cpu_wr_csrs[MCP_SRC].en) begin
        mcp_src <= csrs.cpu_wr_csrs[MCP_SRC].data[63:0];
      end
      if(csrs.cpu_wr_csrs[MCP_DST].en) begin
        mcp_dst <= csrs.cpu_wr_csrs[MCP_DST].data[63:0];
      end
      if(csrs.cpu_wr_csrs[MCP_NUM].en) begin
        mcp_num <= csrs.cpu_wr_csrs[MCP_NUM].data[63:0];
        $display("NUM CSR",csrs.cpu_wr_csrs[MCP_NUM].data[63:0]);
      end
      if(csrs.cpu_wr_csrs[BFS_CAP].en) begin
        bfs_cap <= csrs.cpu_wr_csrs[BFS_CAP].data[63:0];
        $display("BFS_CAP",csrs.cpu_wr_csrs[BFS_CAP].data[63:0]);
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
      csrs.cpu_rd_csrs[BFS_STATUS].data  = {57'd0,
                                            mcp_done, //   6                                            3'd0,     // 5:3
                                            3'd0,     // 5:3
                                            bfs_done, //   2
                                            2'd0};    // 1:0
      csrs.cpu_rd_csrs[BFS_NDS].data = bfs_nds; 
end

endmodule
