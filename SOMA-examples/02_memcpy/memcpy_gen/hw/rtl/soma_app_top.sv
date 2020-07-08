`include "csr_mgr.vh"
`include "platform_if.vh"
`include "active_msg.vh"

import local_mem_cfg_pkg::*;

module soma_app_top
    #(parameter NUM_LOCAL_MEM_BANKS = 2)
(
    input logic clk,
    input logic SoftReset,

    avalon_mem_if.to_fiu local_mem[NUM_LOCAL_MEM_BANKS],
    input t_if_ccip_Rx cp2af_sRx,
    output t_if_ccip_Tx af2cp_sTx,

    app_csrs.app csrs
);

    assign local_mem[1].read = 1'b0;
    assign local_mem[1].write = 1'b0;

    server#(.SDARG_BITS(64)) mcS();

    logic start;
    logic finish;

    logic startLocal;

    always_ff @(posedge clk) begin
        if (SoftReset) begin
            startLocal <= 0;
            finish <= 0;
        end else begin
            startLocal <= start;
            finish <= 0;
        end
    end

    logic [63:0] setRd_addr_readAVL;
    logic [63:0] setRd_addr_readCCI;
    logic [63:0] setWr_addr_writeAVL;
    logic [63:0] setWr_addr_writeCCI;

    logic [0:0] start_csr2CA;
    logic [0:0] done_csr2CA;
    logic [0:0] clear_csr2CA;
    logic [63:0] destination_csr2CA;
    logic [63:0] source_csr2CA;
    logic [63:0] mc_num_csr2CA;

    soma_csr csr (
        .clk(clk),
        .SoftReset(SoftReset),
        .csrs(csrs),
        .start(start),
        .finish(finish),
        .setRd_addr_readAVL(setRd_addr_readAVL),
        .setRd_addr_readCCI(setRd_addr_readCCI),
        .setWr_addr_writeAVL(setWr_addr_writeAVL),
        .setWr_addr_writeCCI(setWr_addr_writeCCI),
        .start_csr2CA(start_csr2CA),
        .done_csr2CA(done_csr2CA),
        .clear_csr2CA(clear_csr2CA),
        .destination_csr2CA(destination_csr2CA),
        .source_csr2CA(source_csr2CA),
        .mc_num_csr2CA(mc_num_csr2CA)
    );

    csr2srv my_csr2CA (
        .clk(clk),
        .rst(SoftReset),
        .memcpy(mcS),
        .start(start_csr2CA),
        .done(done_csr2CA),
        .clear(clear_csr2CA),
        .destination(destination_csr2CA),
        .source(source_csr2CA),
        .mc_num(mc_num_csr2CA)
    );

    servers_system system_top (
        .clk(clk),
        .SoftReset(SoftReset),
        .mcS(mcS),
        .setRd_addr_readAVL(setRd_addr_readAVL),
        .setRd_addr_readCCI(setRd_addr_readCCI),
        .setWr_addr_writeAVL(setWr_addr_writeAVL),
        .setWr_addr_writeCCI(setWr_addr_writeCCI),

        .cp2af_sRx(cp2af_sRx),
        .af2cp_sTx(af2cp_sTx),

        .topA_read(local_mem[0].read),
        .topA_write(local_mem[0].write),
        .topA_address(local_mem[0].address),
        .topA_writedata(local_mem[0].writedata),
        .topA_readdata(local_mem[0].readdata),
        .topA_waitrequest(local_mem[0].waitrequest),
        .topA_readdatavalid(local_mem[0].readdatavalid),
        .topA_burstcount(local_mem[0].burstcount),
        .topA_byteenable(local_mem[0].byteenable)
    );

endmodule: soma_app_top
