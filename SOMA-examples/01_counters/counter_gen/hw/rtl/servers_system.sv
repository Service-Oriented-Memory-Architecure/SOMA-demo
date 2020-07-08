`include "platform_if.vh"
`include "active_msg.vh"

module servers_system (
    input logic clk,
    input logic SoftReset,

    server.svr cntr1_0,
    server.svr cntr2_0,
    server.svr cntr1_1,
    server.svr cntr2_1,

    input logic [63:0] setRd_addr_read_1,
    input logic [63:0] setWr_addr_writeA,
    input logic [63:0] setWr_addr_writeB,

    input t_if_ccip_Rx cp2af_sRx,
    output t_if_ccip_Tx af2cp_sTx
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


        .cntr1_0_txFull(cntr1_0.txFull),
        .cntr1_0_tx_msg(cntr1_0.txP.tx_msg),
        .EN_cntr1_0_tx(cntr1_0.txP.tx),
        .cntr1_0_rxEmpty(cntr1_0.rxP.rxEmpty),
        .EN_cntr1_0_rxPop(cntr1_0.rxPop),
        .cntr1_0_rx_msg(cntr1_0.rxP.rx_msg),

        .cntr2_0_txFull(cntr2_0.txFull),
        .cntr2_0_tx_msg(cntr2_0.txP.tx_msg),
        .EN_cntr2_0_tx(cntr2_0.txP.tx),
        .cntr2_0_rxEmpty(cntr2_0.rxP.rxEmpty),
        .EN_cntr2_0_rxPop(cntr2_0.rxPop),
        .cntr2_0_rx_msg(cntr2_0.rxP.rx_msg),

        .cntr1_1_txFull(cntr1_1.txFull),
        .cntr1_1_tx_msg(cntr1_1.txP.tx_msg),
        .EN_cntr1_1_tx(cntr1_1.txP.tx),
        .cntr1_1_rxEmpty(cntr1_1.rxP.rxEmpty),
        .EN_cntr1_1_rxPop(cntr1_1.rxPop),
        .cntr1_1_rx_msg(cntr1_1.rxP.rx_msg),

        .cntr2_1_txFull(cntr2_1.txFull),
        .cntr2_1_tx_msg(cntr2_1.txP.tx_msg),
        .EN_cntr2_1_tx(cntr2_1.txP.tx),
        .cntr2_1_rxEmpty(cntr2_1.rxP.rxEmpty),
        .EN_cntr2_1_rxPop(cntr2_1.rxPop),
        .cntr2_1_rx_msg(cntr2_1.rxP.rx_msg),

        .setRd_addr_read_1(setRd_addr_read_1),
        .setWr_addr_writeA(setWr_addr_writeA),
        .setWr_addr_writeB(setWr_addr_writeB)
    );

endmodule: servers_system
