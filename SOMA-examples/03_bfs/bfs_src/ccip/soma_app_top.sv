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
    assign local_mem[0].read = 1'b0;
    assign local_mem[0].write = 1'b0;


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

    logic [0:0] start_afuBFS;
    logic [0:0] finish_afuBFS;
    logic [63:0] getNodesTchd_afuBFS;
    logic [0:0] start_worklistServiceMod;
    logic [31:0] setCapacity_worklistServiceMod;
    logic [63:0] setRd_addr_readNodes;
    logic [63:0] setRd_addr_readEdges;
    logic [63:0] setRd_addr_readDistance;
    logic [63:0] setWr_addr_writeDistance;
    logic [63:0] setRd_addr_readWorklist;
    logic [63:0] setWr_addr_writeWorklist;


    soma_csr csr (
        .clk(clk),
        .SoftReset(SoftReset),
        .csrs(csrs),
        .start(start),
        .finish(finish),
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
        .setWr_addr_writeWorklist(setWr_addr_writeWorklist)
    );

    servers_system system_top (
        .clk(clk),
        .SoftReset(SoftReset),
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

        .cp2af_sRx(cp2af_sRx),
        .af2cp_sTx(af2cp_sTx)
    );

endmodule: soma_app_top
