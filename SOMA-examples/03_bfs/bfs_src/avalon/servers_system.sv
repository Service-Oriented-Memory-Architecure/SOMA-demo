`include "platform_if.vh"
`include "active_msg.vh"

module servers_system (
    input logic clk,
    input logic SoftReset,

    server.svr mcS,

    input logic start_afuBFS,
    output logic finish_afuBFS,
    output logic [63:0] getNodesTchd_afuBFS,
    input logic start_worklistServiceMod,
    input logic [31:0] setCapacity_worklistServiceMod,
    input logic [63:0] setRd_addr_readNodes,
    input logic [63:0] setRd_addr_readEdges,
    input logic [63:0] setRd_addr_readDistance,
    input logic [63:0] setWr_addr_writeDistance,
    input logic [63:0] setRd_addr_readWorklist,
    input logic [63:0] setWr_addr_writeWorklist,
    input logic [63:0] setRd_addr_readAVL,
    input logic [63:0] setRd_addr_readCCI,
    input logic [63:0] setWr_addr_writeAVL,
    input logic [63:0] setWr_addr_writeCCI,

    input t_if_ccip_Rx cp2af_sRx,
    output t_if_ccip_Tx af2cp_sTx,

    output logic topA_read,
    output logic topA_write,
    output logic [63:0] topA_address,
    output logic [511:0] topA_writedata,
    input logic [511:0] topA_readdata,
    input logic topA_waitrequest,
    input logic topA_readdatavalid,
    output logic [10:0] topA_burstcount,
    output logic [63:0] topA_byteenable
);
    assign af2cp_sTx.c2.mmioRdValid = 1'b0;

    wire c0valid;
    wire [15:0] rd_mdata;
    wire [63:0] rd_addr;
    t_ccip_c0_ReqMemHdr rd_hdr;
    always_comb begin
        rd_hdr = t_ccip_c0_ReqMemHdr'(0);
        rd_hdr.req_type = eREQ_RDLINE_I;
        rd_hdr.address = rd_addr;
        rd_hdr.vc_sel = eVC_VA;
        rd_hdr.cl_len = eCL_LEN_1;
        rd_hdr.mdata = '0;
        rd_hdr.mdata = rd_mdata;
    end

    always_ff @(posedge clk) begin
        if(SoftReset) begin
            af2cp_sTx.c0.valid <= 1'b0;
        end else begin
            af2cp_sTx.c0.valid <= c0valid;
            af2cp_sTx.c0.hdr   <= rd_hdr;
        end
    end
	
    wire c1valid;
    wire [15:0] wr_mdata;
    wire [63:0] wr_addr;
    wire [511:0] wr_data;
    t_ccip_c1_ReqMemHdr wr_hdr;
    always_comb begin
        wr_hdr = t_ccip_c1_ReqMemHdr'(0);
        wr_hdr.req_type = eREQ_WRLINE_I;
        wr_hdr.address = wr_addr;
        wr_hdr.vc_sel = eVC_VA;
        wr_hdr.cl_len = eCL_LEN_1;
        wr_hdr.mdata = '0;
        wr_hdr.mdata = wr_mdata;
        wr_hdr.sop = 1'b1;
    end

    always_ff @(posedge clk) begin
        if(SoftReset) begin
            af2cp_sTx.c1.valid <= 1'b0;
        end else begin
            af2cp_sTx.c1.valid <= c1valid;
            af2cp_sTx.c1.hdr   <= wr_hdr;
            af2cp_sTx.c1.data <= t_ccip_clData'(wr_data);
            if (c1valid) $display("WR HDR %h",wr_hdr);
        end
    end



    mkServerSys my_sys (
        .CLK(clk),
        .RST_N(~SoftReset),

        .topC_rdReqAddr(rd_addr),
        .topC_rdReqMdata(rd_mdata),
        .topC_rdReqEN(c0valid),
        .topC_rdReqSent_b(!cp2af_sRx.c0TxAlmFull),
        .topC_rdRspMdata_m(cp2af_sRx.c0.hdr.mdata),
        .topC_rdRspData_d(cp2af_sRx.c0.data),
        .topC_rdRspValid_b(cp2af_sRx.c0.rspValid && !cp2af_sRx.c0.mmioRdValid && !cp2af_sRx.c0.mmioWrValid),
        .topC_wrReqAddr(wr_addr),
        .topC_wrReqMdata(wr_mdata),
        .topC_wrReqData(wr_data),
        .topC_wrReqEN(c1valid),
        .topC_wrReqSent_b(!cp2af_sRx.c1TxAlmFull),
        .topC_wrRspMdata_m(cp2af_sRx.c1.hdr.mdata),
        .topC_wrRspValid_b(cp2af_sRx.c1.rspValid),

        .topA_read(topA_read),
        .topA_write(topA_write),
        .topA_address(topA_address),
        .topA_writedata(topA_writedata),
        .topA_readdata(topA_readdata),
        .topA_waitrequest(topA_waitrequest),
        .topA_readdatavalid(topA_readdatavalid),
        .topA_burstcount(topA_burstcount),
        .topA_byteenable(topA_byteenable),


        .mcS_txFull(mcS.txFull),
        .mcS_tx_msg(mcS.txP.tx_msg),
        .EN_mcS_tx(mcS.txP.tx),
        .mcS_rxEmpty(mcS.rxP.rxEmpty),
        .EN_mcS_rxPop(mcS.rxPop),
        .mcS_rx_msg(mcS.rxP.rx_msg),

        .start_afuBFS(start_afuBFS),
        .finish_afuBFS(finish_afuBFS),
        .getNodesTchd_afuBFS(getNodesTchd_afuBFS),
        .start_worklistServiceMod(start_worklistServiceMod),
        .setCapacity_worklistServiceMod(setCapacity_worklistServiceMod),
        .setRd_addr_readNodes(setRd_addr_readNodes),
        .setRd_addr_readEdges(setRd_addr_readEdges),
        .setRd_addr_readDistance(setRd_addr_readDistance),
        .setWr_addr_writeDistance(setWr_addr_writeDistance),
        .setRd_addr_readWorklist(setRd_addr_readWorklist),
        .setWr_addr_writeWorklist(setWr_addr_writeWorklist),
        .setRd_addr_readAVL(setRd_addr_readAVL),
        .setRd_addr_readCCI(setRd_addr_readCCI),
        .setWr_addr_writeAVL(setWr_addr_writeAVL),
        .setWr_addr_writeCCI(setWr_addr_writeCCI)
    );

endmodule: servers_system
