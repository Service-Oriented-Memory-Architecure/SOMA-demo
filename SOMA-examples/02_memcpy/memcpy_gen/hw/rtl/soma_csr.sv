`include "csr_mgr.vh"
`include "platform_if.vh"
`include "afu_json_info.vh"

module soma_csr
 (
  input clk,
  input SoftReset,

  app_csrs.app csrs,
  output start,
  input  finish,

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

logic [63:0]    mcp_src;
logic [63:0]    mcp_dst;
logic [63:0]    mcp_num;
logic          mcp_go;
logic           mcp_clear;
logic           mcp_done;

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
assign start = 1'b1;

localparam DATA_WIDTH       = 64;
localparam SCRATCH_REG      = 6'h02;                // Scratch Register
localparam BFS_CTRL         = 6'h03;
localparam BFS_STATUS       = 6'h09;
localparam MCP_DST          = 6'h0C;
localparam MCP_SRC          = 6'h0D;
localparam MCP_NUM          = 6'h0E;

logic [63:0] scratch_reg;
logic [6:0]  bfs_ctrl;

always_ff @(posedge clk) begin
  if(SoftReset) begin
    scratch_reg    <= '0;
    bfs_ctrl     <= '0;
    mcp_src         <= '0;
    mcp_dst         <= '0;
    mcp_num         <= '0;
    mcp_go     <= '0;
    mcp_clear    <= '0;
  end
  else begin
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
                                            1'b0, //   2
                                            2'd0};    // 1:0
end

endmodule
