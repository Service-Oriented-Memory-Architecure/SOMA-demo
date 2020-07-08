`include "active_msg.vh"

//    
// Kernel module that sends requests to a counters service to increment counter idxs 5 and 33 by 1 'count_to' times.
//
module app_afu_Q
   (
    input  logic clk,
    input  logic rst,

    // Connections toward the server
    server.clt counters_0,
    server.clt counters_1,

    input  logic start,
    output logic done,

    input  logic [19:0] count_to
    );

   logic rst_n;
   assign rst_n = ~rst;

   logic EN_increment0, done0;
   logic EN_increment1, done1;
   logic [19:0] num0, num1;
   logic [15:0] cycle, idle_cy;
   assign EN_increment0 = start&&!done0&&!counters_0.txFull;
   assign EN_increment1 = start&&!done1&&!counters_1.txFull;
   assign done = done0 && done1 && (idle_cy>10000);
   assign done0 = num0 >= count_to;
   assign done1 = num1 >= count_to;

   always_ff @(posedge clk) begin    
       if(~rst_n) begin
           num0 <= 0;
           num1 <= 0;
           cycle <= 0;
           idle_cy <= 0;
       end else begin
           if (EN_increment0) num0 <= num0 + 1;
           if (EN_increment1) num1 <= num1 + 1;
           if (start) cycle <= cycle + 1;
           if (done1&&done0) idle_cy <= idle_cy + 1;
       end
   end

   always_ff @(posedge clk) begin
       if(~rst_n) begin
           counters_0.txP.tx <= 0;
       end else begin
           //if(start)$display("Counter 0 Full: %d Num: %d Tx: %d",counters_0.txFull,num0,EN_increment0);
           counters_0.txP.tx <= EN_increment0;
           counters_0.txP.tx_msg.head.srcid <=  0;
           counters_0.txP.tx_msg.head.dstid <=  0;
           counters_0.txP.tx_msg.head.arg0 <=  5;
           counters_0.txP.tx_msg.head.arg1 <=  1;
           counters_0.txP.tx_msg.head.arg2 <=  0;
       end
   end

   always_ff @(posedge clk) begin
       if(~rst_n) begin
           counters_1.txP.tx <= 0;
       end else begin
           //if(start)$display("Counter 1 Full: %d Num: %d Tx: %d",counters_1.txFull,num1,EN_increment1);
           counters_1.txP.tx <= EN_increment1;
           counters_1.txP.tx_msg.head.srcid <=  2;
           counters_1.txP.tx_msg.head.dstid <=  2;
           counters_1.txP.tx_msg.head.arg0 <=  33;
           counters_1.txP.tx_msg.head.arg1 <=  1;
           counters_1.txP.tx_msg.head.arg2 <=  0;
       end
   end
endmodule

//    
// Kernel module that sends requests to a counters service to increment counter idxs 1 by 2 and 18 by 1 'count_to' times.
//
module app_afu_R
   (
    input  logic clk,
    input  logic rst,

    // Connections toward the server
    server.clt counters_2,
    server.clt counters_3,

    input  logic start,
    output logic done,

    input  logic [19:0] count_to
    );

   logic rst_n;
   assign rst_n = ~rst;

   logic EN_increment2, done2;
   logic EN_increment3, done3;
   logic [19:0] num2, num3;
   logic [15:0] cycle, idle_cy;
   assign EN_increment2 = start&&!done2&&!counters_2.txFull;
   assign EN_increment3 = start&&!done3&&!counters_3.txFull;
   assign done = done2 && done3 && (idle_cy>10000);
   assign done2 = (num2 >= count_to);
   assign done3 = (num3 >= count_to);

   always_ff @(posedge clk) begin    
       if(~rst_n) begin
           num2 <= 0;
           num3 <= 0;
           cycle <= 0;
           idle_cy <= 0;
       end else begin
           if (EN_increment2) num2 <= num2 + 1;
           if (EN_increment3) num3 <= num3 + 1;
           if (done2&&done3) idle_cy <= idle_cy + 1;
       end
   end

   always_ff @(posedge clk) begin
       if(~rst_n) begin
           counters_2.txP.tx <= 0;
       end else begin
           //if(start)$display("Counter 2 Full: %d Num: %d Tx: %d",counters_2.txFull,num2,EN_increment2);
           counters_2.txP.tx <= EN_increment2;
           counters_2.txP.tx_msg.head.srcid <=  1;
           counters_2.txP.tx_msg.head.dstid <=  1;
           counters_2.txP.tx_msg.head.arg0 <=  0;
           counters_2.txP.tx_msg.head.arg1 <=  2;
           counters_2.txP.tx_msg.head.arg2 <=  0;
       end
   end

   always_ff @(posedge clk) begin
       if(~rst_n) begin
           counters_3.txP.tx <= 0;
       end else begin
           //if(start)$display("Counter 3 Full: %d Num: %d Tx: %d",counters_3.txFull,num3,EN_increment3);
           counters_3.txP.tx <= EN_increment3;
           counters_3.txP.tx_msg.head.srcid <=  3;
           counters_3.txP.tx_msg.head.dstid <=  3;
           counters_3.txP.tx_msg.head.arg0 <=  18;
           counters_3.txP.tx_msg.head.arg1 <=  1;
           counters_3.txP.tx_msg.head.arg2 <=  0;
       end
   end
endmodule
