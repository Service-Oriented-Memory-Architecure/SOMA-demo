import MessagePack::*;
import Vector::*;
import Channels::*;
import MemCopy::*;
import Cache::*;
import Worklist::*;
import BFS::*;
import BFSafuPipeline::*;

interface ServerSys;
    interface ChannelsTopHARP#(Bit#(64), Bit#(14), Bit#(512)) topC;
    (* always_ready, always_enabled, prefix = "" *) method Action start_afuBFS((* port = "start_afuBFS" *) Bool x);
    (* always_ready, always_enabled, prefix = "" *) method Bool finish_afuBFS();
    (* always_ready, always_enabled, prefix = "" *) method Bit#(64) getNodesTchd_afuBFS();
    (* always_ready, always_enabled, prefix = "" *) method Action start_worklistServiceMod((* port = "start_worklistServiceMod" *) Bool x);
    (* always_ready, always_enabled, prefix = "" *) method Action setCapacity_worklistServiceMod((* port = "setCapacity_worklistServiceMod" *) Bit#(32) x);
    (* always_ready, always_enabled, prefix = "" *) method Action setRd_addr_readNodes((* port = "setRd_addr_readNodes" *) Bit#(64) x);
    (* always_ready, always_enabled, prefix = "" *) method Action setRd_addr_readEdges((* port = "setRd_addr_readEdges" *) Bit#(64) x);
    (* always_ready, always_enabled, prefix = "" *) method Action setRd_addr_readDistance((* port = "setRd_addr_readDistance" *) Bit#(64) x);
    (* always_ready, always_enabled, prefix = "" *) method Action setWr_addr_writeDistance((* port = "setWr_addr_writeDistance" *) Bit#(64) x);
    (* always_ready, always_enabled, prefix = "" *) method Action setRd_addr_readWorklist((* port = "setRd_addr_readWorklist" *) Bit#(64) x);
    (* always_ready, always_enabled, prefix = "" *) method Action setWr_addr_writeWorklist((* port = "setWr_addr_writeWorklist" *) Bit#(64) x);
endinterface

(* synthesize *)
module mkServerSys(ServerSys);
    TopConvertHARP#(Bit#(7), Bit#(6), Bit#(64), Bit#(14), Bit#(512), 2, 32) topC_convert <- mkTopConvertHARP();
    RdChannel#(Bit#(64), Bit#(7), Bit#(512), 2, 32) memR_topC = topC_convert.rdch;
    WrChannel#(Bit#(64), Bit#(6), Bit#(512), 2, 32) memW_topC = topC_convert.wrch;
    RdY#(4, Bit#(64), Bit#(5), Bit#(512), 2, 32) memRY_topC <- mkRdY(True, memR_topC);
    WrY#(2, Bit#(64), Bit#(5), Bit#(512), 2, 32) memWY_topC <- mkWrY(True, memW_topC);


    Reg#(Bit#(64)) regsetRd_addr_readNodes <- mkReg(0);
    Reg#(Bit#(64)) regsetRd_addr_readEdges <- mkReg(0);
    Reg#(Bit#(64)) regsetRd_addr_readDistance <- mkReg(0);
    Reg#(Bit#(64)) regsetWr_addr_writeDistance <- mkReg(0);
    Reg#(Bit#(64)) regsetRd_addr_readWorklist <- mkReg(0);
    Reg#(Bit#(64)) regsetWr_addr_writeWorklist <- mkReg(0);


    Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 32) srvreadNodes <- mkReadServer(memRY_topC.rdch[0], truncate(regsetRd_addr_readNodes));

    Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 32) srvreadEdges <- mkReadServer(memRY_topC.rdch[1], truncate(regsetRd_addr_readEdges));

    Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 32) srvreadDistance <- mkReadServer(memRY_topC.rdch[2], truncate(regsetRd_addr_readDistance));

    Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 32) srvwriteDistance <- mkWriteServer(memWY_topC.wrch[0], truncate(regsetWr_addr_writeDistance));

    Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 32) srvreadWorklist <- mkReadServer(memRY_topC.rdch[3], truncate(regsetRd_addr_readWorklist));

    Server#(AM_FULL#(Bit#(32), Bit#(512)), AM_FULL#(Bit#(32), Bit#(512)), 32) srvwriteWorklist <- mkWriteServer(memWY_topC.wrch[1], truncate(regsetWr_addr_writeWorklist));

    Worklist srvworklistServiceMod <- mkWorklist(srvreadWorklist, srvwriteWorklist);

    Server2#(AM_FULL#(Bit#(32), Bit#(32)), AM_FULL#(Bit#(32), Bit#(32)), 32) srvgraphServiceMod <- mkGraphServer(srvreadNodes, srvreadEdges, srvreadDistance, srvwriteDistance);

    BFSafuPipeline srvafuBFS <- mkBFSafuPipeline(srvworklistServiceMod.workQ, srvgraphServiceMod.serverA, srvgraphServiceMod.serverB);

    interface topC = topC_convert.top;

    method Action start_afuBFS(Bool x);
        srvafuBFS.start(x);
    endmethod
    method Bool finish_afuBFS();
        return srvafuBFS.finish();
    endmethod
    method Bit#(64) getNodesTchd_afuBFS();
        return srvafuBFS.getNodesTchd();
    endmethod
    method Action start_worklistServiceMod(Bool x);
        srvworklistServiceMod.start(x);
    endmethod
    method Action setCapacity_worklistServiceMod(Bit#(32) x);
        srvworklistServiceMod.setCapacity(x);
    endmethod
    method Action setRd_addr_readNodes(Bit#(64) x);
        regsetRd_addr_readNodes <= x;
    endmethod
    method Action setRd_addr_readEdges(Bit#(64) x);
        regsetRd_addr_readEdges <= x;
    endmethod
    method Action setRd_addr_readDistance(Bit#(64) x);
        regsetRd_addr_readDistance <= x;
    endmethod
    method Action setWr_addr_writeDistance(Bit#(64) x);
        regsetWr_addr_writeDistance <= x;
    endmethod
    method Action setRd_addr_readWorklist(Bit#(64) x);
        regsetRd_addr_readWorklist <= x;
    endmethod
    method Action setWr_addr_writeWorklist(Bit#(64) x);
        regsetWr_addr_writeWorklist <= x;
    endmethod

endmodule
