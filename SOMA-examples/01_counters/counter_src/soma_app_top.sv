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

    server cntr1_0();
    server cntr1_1();
    server cntr2_0();
    server cntr2_1();

    logic start;
    logic finish;

    logic startLocal;
    logic finish_afuQ;
    logic finish_afuR;

    always_ff @(posedge clk) begin
        if (SoftReset) begin
            startLocal <= 0;
            finish <= 0;
        end else begin
            startLocal <= start;
            finish <= finish_afuQ && finish_afuR;
        end
    end

    logic [19:0] count_to_afuQ;
    logic [19:0] count_to_afuR;
    logic [63:0] setRd_addr_read_1;
    logic [63:0] setWr_addr_writeA;
    logic [63:0] setWr_addr_writeB;


    soma_csr csr (
        .clk(clk),
        .SoftReset(SoftReset),
        .csrs(csrs),
        .start(start),
        .finish(finish),
        .count_to_afuQ(count_to_afuQ),
        .count_to_afuR(count_to_afuR),
        .setRd_addr_read_1(setRd_addr_read_1),
        .setWr_addr_writeA(setWr_addr_writeA),
        .setWr_addr_writeB(setWr_addr_writeB)
    );

    app_afu_Q my_afuQ (
        .clk(clk),
        .rst(SoftReset),
        .counters_0(cntr1_0),
        .counters_1(cntr2_0),
        .start(startLocal),
        .done(finish_afuQ),
        .count_to(count_to_afuQ)
    );

    app_afu_R my_afuR (
        .clk(clk),
        .rst(SoftReset),
        .counters_2(cntr1_1),
        .counters_3(cntr2_1),
        .start(startLocal),
        .done(finish_afuR),
        .count_to(count_to_afuR)
    );

    servers_system system_top (
        .clk(clk),
        .SoftReset(SoftReset),
        .cntr1_0(cntr1_0),
        .cntr2_0(cntr2_0),
        .cntr1_1(cntr1_1),
        .cntr2_1(cntr2_1),
        .setRd_addr_read_1(setRd_addr_read_1),
        .setWr_addr_writeA(setWr_addr_writeA),
        .setWr_addr_writeB(setWr_addr_writeB),

        .cp2af_sRx(cp2af_sRx),
        .af2cp_sTx(af2cp_sTx)
    );

endmodule: soma_app_top
