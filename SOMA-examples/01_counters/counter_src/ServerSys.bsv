import MessagePack::*;
import Vector::*;
import Channels::*;
import CountersServer::*;

interface ServerSys;
    interface ChannelsTopHARP#(Bit#(64), Bit#(14), Bit#(512)) topC;
    interface Vector#(2, Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 16)) cntr1;
    interface Vector#(2, Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 16)) cntr2;
    (* always_ready, always_enabled, prefix = "" *) method Action setRd_addr_read_1((* port = "setRd_addr_read_1" *) Bit#(64) x);
    (* always_ready, always_enabled, prefix = "" *) method Action setWr_addr_writeA((* port = "setWr_addr_writeA" *) Bit#(64) x);
    (* always_ready, always_enabled, prefix = "" *) method Action setWr_addr_writeB((* port = "setWr_addr_writeB" *) Bit#(64) x);
endinterface

(* synthesize *)
module mkServerSys(ServerSys);
    TopConvertHARP#(Bit#(4), Bit#(5), Bit#(64), Bit#(14), Bit#(512), 2, 16) topC_convert <- mkTopConvertHARP();
    RdChannel#(Bit#(64), Bit#(4), Bit#(512), 2, 16) memR_topC = topC_convert.rdch;
    WrChannel#(Bit#(64), Bit#(5), Bit#(512), 2, 16) memW_topC = topC_convert.wrch;
    WrY#(2, Bit#(64), Bit#(4), Bit#(512), 2, 16) memWY_topC <- mkWrY(True, memW_topC);


    Reg#(Bit#(64)) regsetRd_addr_read_1 <- mkReg(0);
    Reg#(Bit#(64)) regsetWr_addr_writeA <- mkReg(0);
    Reg#(Bit#(64)) regsetWr_addr_writeB <- mkReg(0);


    Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 16) srvread_1 <- mkReadServer(memR_topC, truncate(regsetRd_addr_read_1));
    TxMsgChannelMux#(2, AM_FULL#(Bit#(32), Bit#(512))) srvread_1TxY <- mkTxMuxAuto(True, srvread_1.txPort);
    RxMsgChannelDemux#(2, AM_FULL#(Bit#(32), Bit#(512))) srvread_1RxY <- mkRxDemux(True, srvread_1.rxPort);
    Vector#(2, Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 16)) srvread_1Y;
    for(Integer i=0; i < 2; i=i+1) begin
        let sv = interface Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 16);
            interface txPort = srvread_1TxY.txPort[i];
            interface rxPort = srvread_1RxY.rxPort[i];
        endinterface;
        srvread_1Y[i] = sv;
    end

    Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 16) srvwriteA <- mkWriteServer(memWY_topC.wrch[0], truncate(regsetWr_addr_writeA));

    Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 16) srvwriteB <- mkWriteServer(memWY_topC.wrch[1], truncate(regsetWr_addr_writeB));

    Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 16) srvcntr1 <- mkCountersServer(srvread_1Y[0], srvwriteA);
    TxMsgChannelMux#(2, AM_FULL#(Bit#(32), Bit#(512))) srvcntr1TxY <- mkTxMuxAuto(True, srvcntr1.txPort);
    RxMsgChannelDemux#(2, AM_FULL#(Bit#(32), Bit#(512))) srvcntr1RxY <- mkRxDemux(True, srvcntr1.rxPort);
    Vector#(2, Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 16)) srvcntr1Y;
    for(Integer i=0; i < 2; i=i+1) begin
        let sv = interface Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 16);
            interface txPort = srvcntr1TxY.txPort[i];
            interface rxPort = srvcntr1RxY.rxPort[i];
        endinterface;
        srvcntr1Y[i] = sv;
    end

    Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 16) srvcntr2 <- mkCountersServer(srvread_1Y[1], srvwriteB);
    TxMsgChannelMux#(2, AM_FULL#(Bit#(32), Bit#(512))) srvcntr2TxY <- mkTxMuxAuto(True, srvcntr2.txPort);
    RxMsgChannelDemux#(2, AM_FULL#(Bit#(32), Bit#(512))) srvcntr2RxY <- mkRxDemux(True, srvcntr2.rxPort);
    Vector#(2, Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 16)) srvcntr2Y;
    for(Integer i=0; i < 2; i=i+1) begin
        let sv = interface Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 16);
            interface txPort = srvcntr2TxY.txPort[i];
            interface rxPort = srvcntr2RxY.rxPort[i];
        endinterface;
        srvcntr2Y[i] = sv;
    end

    interface topC = topC_convert.top;
    interface cntr1 = srvcntr1Y;
    interface cntr2 = srvcntr2Y;

    method Action setRd_addr_read_1(Bit#(64) x);
        regsetRd_addr_read_1 <= x;
    endmethod
    method Action setWr_addr_writeA(Bit#(64) x);
        regsetWr_addr_writeA <= x;
    endmethod
    method Action setWr_addr_writeB(Bit#(64) x);
        regsetWr_addr_writeB <= x;
    endmethod

endmodule
