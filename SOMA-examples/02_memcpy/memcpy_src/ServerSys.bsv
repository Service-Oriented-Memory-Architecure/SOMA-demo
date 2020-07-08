import MessagePack::*;
import Vector::*;
import Channels::*;
import MemCopy::*;

interface ServerSys;
    interface ChannelsTopHARP#(Bit#(64), Bit#(14), Bit#(512)) topC;
    interface AVALON_MASTER#(Bit#(32), Bit#(14), Bit#(512)) topA;
    interface Server#(AM_FULL#(Bit#(64), Bit#(512)), AM_FULL#(Bit#(64), Bit#(512)), 1) mcS;
    (* always_ready, always_enabled, prefix = "" *) method Action setRd_addr_readAVL((* port = "setRd_addr_readAVL" *) Bit#(64) x);
    (* always_ready, always_enabled, prefix = "" *) method Action setRd_addr_readCCI((* port = "setRd_addr_readCCI" *) Bit#(64) x);
    (* always_ready, always_enabled, prefix = "" *) method Action setWr_addr_writeAVL((* port = "setWr_addr_writeAVL" *) Bit#(64) x);
    (* always_ready, always_enabled, prefix = "" *) method Action setWr_addr_writeCCI((* port = "setWr_addr_writeCCI" *) Bit#(64) x);
endinterface

(* synthesize *)
module mkServerSys(ServerSys);
    TopConvertHARP#(Bit#(5), Bit#(5), Bit#(64), Bit#(14), Bit#(512), 2, 32) topC_convert <- mkTopConvertHARP();
    RdChannel#(Bit#(64), Bit#(5), Bit#(512), 2, 32) memR_topC = topC_convert.rdch;
    WrChannel#(Bit#(64), Bit#(5), Bit#(512), 2, 32) memW_topC = topC_convert.wrch;

    TopConvertAvalon#(Bit#(5), Bit#(5), Bit#(32), Bit#(14), Bit#(512), 2, 32) topA_convert <- mkTopConvertAvalon();
    RdChannel#(Bit#(32), Bit#(5), Bit#(512), 2, 32) memR_topA = topA_convert.rdch;
    WrChannel#(Bit#(32), Bit#(5), Bit#(512), 2, 32) memW_topA = topA_convert.wrch;


    Reg#(Bit#(64)) regsetRd_addr_readAVL <- mkReg(0);
    Reg#(Bit#(64)) regsetRd_addr_readCCI <- mkReg(0);
    Reg#(Bit#(64)) regsetWr_addr_writeAVL <- mkReg(0);
    Reg#(Bit#(64)) regsetWr_addr_writeCCI <- mkReg(0);


    Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 32) srvreadAVL <- mkReadServer(memR_topA, truncate(regsetRd_addr_readAVL));

    Server#(AM_FULL#(Bit#(64), Bit#(512)), AM_FULL#(Bit#(64), Bit#(512)), 32) srvreadCCI <- mkReadServer(memR_topC, regsetRd_addr_readCCI);

    Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 32) srvwriteAVL <- mkWriteServer(memW_topA, truncate(regsetWr_addr_writeAVL));

    Server#(AM_FULL#(Bit#(64), Bit#(512)), AM_FULL#(Bit#(64), Bit#(512)), 32) srvwriteCCI <- mkWriteServer(memW_topC, regsetWr_addr_writeCCI);

    Server#(AM_FULL#(Bit#(64), Bit#(512)), AM_FULL#(Bit#(64), Bit#(512)), 1) srvmcS <- mkMemCopyDual(srvreadCCI, srvwriteCCI, srvreadAVL, srvwriteAVL);

    interface topC = topC_convert.top;
    interface topA = topA_convert.top;
    interface mcS = srvmcS;

    method Action setRd_addr_readAVL(Bit#(64) x);
        regsetRd_addr_readAVL <= x;
    endmethod
    method Action setRd_addr_readCCI(Bit#(64) x);
        regsetRd_addr_readCCI <= x;
    endmethod
    method Action setWr_addr_writeAVL(Bit#(64) x);
        regsetWr_addr_writeAVL <= x;
    endmethod
    method Action setWr_addr_writeCCI(Bit#(64) x);
        regsetWr_addr_writeCCI <= x;
    endmethod

endmodule
