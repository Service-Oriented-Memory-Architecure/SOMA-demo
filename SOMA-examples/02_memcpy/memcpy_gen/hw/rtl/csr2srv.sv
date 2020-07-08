`include "active_msg.vh"
`include "platform_if.vh"
`include "cci_mpf_if.vh"

module csr2srv
   (
    input  logic clk,
    input  logic rst,

    // Connections toward the server
    server.clt memcpy,

    input  logic start,
    input  logic clear,
    output logic done,

    input  logic [63:0] destination,
    input  logic [63:0] source,
    input  logic [63:0] mc_num
    );

   logic rst_n;
   assign rst_n = ~rst;

   logic EN_increment, done0, rdy;
   logic [15:0] cycle, idle_cy;
   assign EN_increment = start&&memcpy.rxP.rxEmpty&&!memcpy.txFull&&rdy;
   assign done = done0 && (idle_cy>500);

   always_ff @(posedge clk) begin    
       if(~rst_n) begin
           cycle <= 0;
           idle_cy <= 0;
       end else begin
           if (start) cycle <= cycle + 1;
           if (clear) idle_cy <= 0;
           else if (done0) idle_cy <= idle_cy + 1;
       end
   end

    //
    // Convert between byte addresses and line addresses.  The conversion
    // is simple: adding or removing low zero bits.
    //

    localparam CL_BYTE_IDX_BITS = 6;
    typedef logic [$bits(t_cci_clAddr) + CL_BYTE_IDX_BITS - 1 : 0] t_byteAddr;

    function automatic t_cci_clAddr byteAddrToClAddr(t_byteAddr addr);
        return addr[CL_BYTE_IDX_BITS +: $bits(t_cci_clAddr)];
    endfunction

    function automatic t_byteAddr clAddrToByteAddr(t_cci_clAddr addr);
        return {addr, CL_BYTE_IDX_BITS'(0)};
    endfunction

  // arg0 destination 
  // arg1 source
  // arg2 num (of data full CL)
  // arg3[1:0] direction: 0 = (A->B), 1 = (B->A), 2 = (A->A), 3 = (B->B) (Only 0 & 1 for now)
   always_ff @(posedge clk) begin
      if(~rst_n) begin
        memcpy.txP.tx <= 0;
        rdy <= 1;
      end else begin
        memcpy.txP.tx <= EN_increment;
        memcpy.txP.tx_msg.head.srcid <=  0;
        memcpy.txP.tx_msg.head.dstid <=  0;
        memcpy.txP.tx_msg.head.arg0 <=  mc_num[32] ? byteAddrToClAddr(destination) : destination;
        memcpy.txP.tx_msg.head.arg1 <=  mc_num[32] ? source : byteAddrToClAddr(source);
        memcpy.txP.tx_msg.head.arg2 <=  {32'd0,mc_num[31:0]};
        memcpy.txP.tx_msg.head.arg3 <=  {32'd0,mc_num[63:32]};
        if (EN_increment)
          $display("Send command - dst: %x, src: %x, num: %x, cmd: %x",destination,source,mc_num[31:0],mc_num[63:32]);
        if (clear) begin
          rdy <= 1;
          $display("RDY CLR");
        end else if (EN_increment) begin
          rdy <= 0;
          $display("Not RDY");
        end else begin
          rdy <= rdy;
        end
      end
   end

   assign memcpy.rxPop = !memcpy.rxP.rxEmpty;

   always_ff @(posedge clk) begin
      if(~rst_n) begin
        //memcpy.rxPop <= 0;
      end else begin
        done0 <= !rdy&&memcpy.rxP.rxEmpty&&!memcpy.txFull;
      end
   end
endmodule
