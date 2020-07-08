// (C) 2001-2018 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.



// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module  bram_true2port_dual 
   #(
      parameter AWIDTH=9,
      parameter DWIDTH=16,
      parameter DEPTH=512
    ) (
    address_a,
    address_b,
    clock,
    data_a,
    data_b,
    rden_a,
    rden_b,
    wren_a,
    wren_b,
    q_a,
    q_b
    );

    input  [AWIDTH-1:0]  address_a;
    input  [AWIDTH-1:0]  address_b;
    input    clock;
    input  [DWIDTH-1:0]  data_a;
    input  [DWIDTH-1:0]  data_b;
    input    rden_a;
    input    rden_b;
    input    wren_a;
    input    wren_b;
    output [DWIDTH-1:0]  q_a;
    output [DWIDTH-1:0]  q_b;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
    tri1     clock;
    tri1     rden_a;
    tri1     rden_b;
    tri0     wren_a;
    tri0     wren_b;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

    reg [AWIDTH-1:0]  address_a_reg;
    reg [AWIDTH-1:0]  address_b_reg;

    wire [DWIDTH-1:0] sub_wire0_0;
    wire [DWIDTH-1:0] sub_wire1_0;
    wire [DWIDTH-1:0] sub_wire0_1;
    wire [DWIDTH-1:0] sub_wire1_1;
    wire [DWIDTH-1:0] q_a = (address_a[0]) ? sub_wire0_0[DWIDTH-1:0] : sub_wire0_1[DWIDTH-1:0];
    wire [DWIDTH-1:0] q_b = (address_b[0]) ? sub_wire1_0[DWIDTH-1:0] : sub_wire1_1[DWIDTH-1:0];

    wire   [AWIDTH-1:0]  address_a_0 = address_a[AWIDTH-1:1];
    wire   [AWIDTH-1:0]  address_b_0 = address_b[AWIDTH-1:1];
    wire   [AWIDTH-1:0]  address_a_1 = address_a[AWIDTH-1:1];
    wire   [AWIDTH-1:0]  address_b_1 = address_b[AWIDTH-1:1];
  
    wire   wren_a_0 = wren_a && (address_a[0]);
    wire   wren_a_1 = wren_a && (~address_a[0]);
    wire   wren_b_0 = wren_b && (address_a[0]);
    wire   wren_b_1 = wren_b && (~address_a[0]);

    always @(posedge clock) begin
	address_a_reg <= address_a;
	address_b_reg <= address_b;
    end

    altsyncram  altera_syncram_component_0 (
                .address_a (address_a_0),
                .address_b (address_b_0),
                .clock0 (clock),
                .data_a (data_a),
                .data_b (data_b),
                .rden_a (),
                .rden_b (),
                .wren_a (wren_a_0),
                .wren_b (wren_b_0),
                .q_a (sub_wire0_0),
                .q_b (sub_wire1_0),
                .aclr0 (),
                .aclr1 (),
                .addressstall_a (),
                .addressstall_b (),
                .byteena_a (),
                .byteena_b (),
                .clock1 (),
                .clocken0 (),
                .clocken1 (),
                .clocken2 (),
                .clocken3 (),
                //.eccencbypass (1'b0),
                //.eccencparity (8'b0),
                .eccstatus ()
                );
    defparam
        altera_syncram_component_0.rdcontrol_reg_b  = "CLOCK0",
        altera_syncram_component_0.address_reg_b  = "CLOCK0",
        altera_syncram_component_0.indata_reg_b  = "CLOCK0",
        altera_syncram_component_0.wrcontrol_wraddress_reg_b  = "CLOCK0",
        altera_syncram_component_0.byteena_reg_b  = "CLOCK0",
        altera_syncram_component_0.clock_enable_input_a  = "BYPASS",
        altera_syncram_component_0.clock_enable_input_b  = "BYPASS",
        altera_syncram_component_0.clock_enable_output_a  = "BYPASS",
        altera_syncram_component_0.clock_enable_output_b  = "BYPASS",
        altera_syncram_component_0.indata_reg_b  = "CLOCK0",
        altera_syncram_component_0.intended_device_family  = "Stratix 10",
        altera_syncram_component_0.lpm_type  = "altsyncram",
        altera_syncram_component_0.numwords_a  = DEPTH/2,
        altera_syncram_component_0.numwords_b  = DEPTH/2,
        altera_syncram_component_0.operation_mode  = "BIDIR_DUAL_PORT",
        //altera_syncram_component.outdata_aclr_a  = "NONE",
        //altera_syncram_component.outdata_sclr_a  = "NONE",
        //altera_syncram_component.outdata_aclr_b  = "NONE",
        //altera_syncram_component.outdata_sclr_b  = "NONE",
        altera_syncram_component_0.outdata_reg_a  = "UNREGISTERED",
        altera_syncram_component_0.outdata_reg_b  = "UNREGISTERED",
        altera_syncram_component_0.power_up_uninitialized  = "FALSE",
        altera_syncram_component_0.ram_block_type  = "AUTO",
        altera_syncram_component_0.read_during_write_mode_mixed_ports  = "DONT_CARE",
        altera_syncram_component_0.read_during_write_mode_port_a  = "NEW_DATA_NO_NBE_READ",
        altera_syncram_component_0.read_during_write_mode_port_b  = "NEW_DATA_NO_NBE_READ",
        altera_syncram_component_0.widthad_a  = AWIDTH,
        altera_syncram_component_0.widthad_b  = AWIDTH,
        altera_syncram_component_0.width_a  = DWIDTH,
        altera_syncram_component_0.width_b  = DWIDTH;
        //altera_syncram_component.width_byteena_a  = 1,
        //altera_syncram_component.width_byteena_b  = 1;

    altsyncram  altera_syncram_component_1 (
                .address_a (address_a_1),
                .address_b (address_b_1),
                .clock0 (clock),
                .data_a (data_a),
                .data_b (data_b),
                .rden_a (),
                .rden_b (),
                .wren_a (wren_a_1),
                .wren_b (wren_b_1),
                .q_a (sub_wire0_1),
                .q_b (sub_wire1_1),
                .aclr0 (),
                .aclr1 (),
                .addressstall_a (),
                .addressstall_b (),
                .byteena_a (),
                .byteena_b (),
                .clock1 (),
                .clocken0 (),
                .clocken1 (),
                .clocken2 (),
                .clocken3 (),
                //.eccencbypass (1'b0),
                //.eccencparity (8'b0),
                .eccstatus ()
                );
    defparam
        altera_syncram_component_1.rdcontrol_reg_b  = "CLOCK0",
        altera_syncram_component_1.address_reg_b  = "CLOCK0",
        altera_syncram_component_1.indata_reg_b  = "CLOCK0",
        altera_syncram_component_1.wrcontrol_wraddress_reg_b  = "CLOCK0",
        altera_syncram_component_1.byteena_reg_b  = "CLOCK0",
        altera_syncram_component_1.clock_enable_input_a  = "BYPASS",
        altera_syncram_component_1.clock_enable_input_b  = "BYPASS",
        altera_syncram_component_1.clock_enable_output_a  = "BYPASS",
        altera_syncram_component_1.clock_enable_output_b  = "BYPASS",
        altera_syncram_component_1.indata_reg_b  = "CLOCK0",
        altera_syncram_component_1.intended_device_family  = "Stratix 10",
        altera_syncram_component_1.lpm_type  = "altsyncram",
        altera_syncram_component_1.numwords_a  = DEPTH/2,
        altera_syncram_component_1.numwords_b  = DEPTH/2,
        altera_syncram_component_1.operation_mode  = "BIDIR_DUAL_PORT",
        //altera_syncram_component.outdata_aclr_a  = "NONE",
        //altera_syncram_component.outdata_sclr_a  = "NONE",
        //altera_syncram_component.outdata_aclr_b  = "NONE",
        //altera_syncram_component.outdata_sclr_b  = "NONE",
        altera_syncram_component_1.outdata_reg_a  = "UNREGISTERED",
        altera_syncram_component_1.outdata_reg_b  = "UNREGISTERED",
        altera_syncram_component_1.power_up_uninitialized  = "FALSE",
        altera_syncram_component_1.ram_block_type  = "AUTO",
        altera_syncram_component_1.read_during_write_mode_mixed_ports  = "DONT_CARE",
        altera_syncram_component_1.read_during_write_mode_port_a  = "NEW_DATA_NO_NBE_READ",
        altera_syncram_component_1.read_during_write_mode_port_b  = "NEW_DATA_NO_NBE_READ",
        altera_syncram_component_1.widthad_a  = AWIDTH,
        altera_syncram_component_1.widthad_b  = AWIDTH,
        altera_syncram_component_1.width_a  = DWIDTH,
        altera_syncram_component_1.width_b  = DWIDTH;
        //altera_syncram_component.width_byteena_a  = 1,
        //altera_syncram_component.width_byteena_b  = 1;












endmodule


