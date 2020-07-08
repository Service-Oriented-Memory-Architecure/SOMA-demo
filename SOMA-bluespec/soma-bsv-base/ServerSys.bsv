import MessagePack::*;
import Vector::*;
import Channels::*;
import MemCopy::*;
import Cache::*;
import Worklist::*;
import BFS::*;
import BFSafuPipeline::*;

interface ServerSys#(type addrC, type mdataC, type data);
      interface ChannelsTopHARP#(addrC,mdataC,data) topC;
      (* always_ready, always_enabled *) method Action start(Bool strt);
      (* always_ready, always_enabled *) method Bool finish();
      (* always_ready, always_enabled *) method Action setWk(addrC wk);
      (* always_ready, always_enabled *) method Action setSrc(addrC src);
      (* always_ready, always_enabled *) method Action setEdg(addrC edg);
      (* always_ready, always_enabled *) method Action setDst(addrC dst);
      (* always_ready, always_enabled *) method Action setCapacity(Bit#(32) wc);
      (* always_ready, always_enabled *) method Bit#(64) getNodesTchd();
endinterface

(* synthesize *)
module mkServerSys(ServerSys#(Bit#(64),Bit#(14),Bit#(512)));

  TopConvertHARP#(Bit#(7),Bit#(6),Bit#(64),Bit#(14),Bit#(512),2,32) tcC <- mkTopConvertHARP();
  WrChannel#(Bit#(64),Bit#(6),Bit#(512),2,32) wrMem = tcC.wrch;
  RdChannel#(Bit#(64),Bit#(7),Bit#(512),2,32) rdMem = tcC.rdch;
  WrY#(2,Bit#(64),Bit#(5),Bit#(512),2,32) spWrY <- mkWrY(True,wrMem);
  RdY#(4,Bit#(64),Bit#(5),Bit#(512),2,32) spRdY <- mkRdY(True,rdMem);
  Vector#(2,WrChannel#(Bit#(64),Bit#(5),Bit#(512),2,32)) splitWr = spWrY.wrch;
  Vector#(4,RdChannel#(Bit#(64),Bit#(5),Bit#(512),2,32)) splitRd = spRdY.rdch;

  RdChannel#(Bit#(64),Bit#(5),Bit#(512),2,32) readWorklist_mem = splitRd[3];
  RdChannel#(Bit#(64),Bit#(5),Bit#(512),2,32) readNodes_mem = splitRd[2];
  RdChannel#(Bit#(64),Bit#(5),Bit#(512),2,32) readEdges_mem = splitRd[1];
  RdChannel#(Bit#(64),Bit#(5),Bit#(512),2,32) readDistance_mem = splitRd[0];
  WrChannel#(Bit#(64),Bit#(5),Bit#(512),2,32) writeDistance_mem = splitWr[1];
  WrChannel#(Bit#(64),Bit#(5),Bit#(512),2,32) writeWorklist_mem = splitWr[0];

  Reg#(Bit#(64)) ofstWk   <- mkReg(0);
  Reg#(Bit#(64)) ofstSrc  <- mkReg(0);
  Reg#(Bit#(64)) ofstEdge <- mkReg(0);
  Reg#(Bit#(64)) ofstDst  <- mkReg(0);
  Reg#(Bit#(32)) num_nodes <- mkReg(0);
  //Reg#(Bit#(32)) wl_cap <- mkReg(16384);

    //Reg#(Bool) started <- mkReg(False);
    //Reg#(Bool) start_in <- mkReg(False);

    Server#(AM_FULL#(Bit#(32),Bit#(512)),AM_FULL#(Bit#(32),Bit#(512)),32) readWorklist <- mkReadServer(readWorklist_mem,ofstWk);
    Server#(AM_FULL#(Bit#(32),Bit#(512)),AM_FULL#(Bit#(32),Bit#(512)),32) readNodes <- mkReadServer(readNodes_mem,ofstSrc);
    Server#(AM_FULL#(Bit#(32),Bit#(512)),AM_FULL#(Bit#(32),Bit#(512)),32) readEdges <- mkReadServer(readEdges_mem,ofstEdge);
    Server#(AM_FULL#(Bit#(32),Bit#(512)),AM_FULL#(Bit#(32),Bit#(512)),32) readDistance <- mkReadServer(readDistance_mem,ofstDst);
    Server#(AM_FULL#(Bit#(32),Bit#(512)),AM_FULL#(Bit#(32),Bit#(512)),32) writeDistance <- mkWriteServer(writeDistance_mem,ofstDst);
    Server#(AM_FULL#(Bit#(32),Bit#(512)),AM_FULL#(Bit#(32),Bit#(512)),32) writeWorklist <- mkWriteServer(writeWorklist_mem,ofstWk);

  Worklist/*#(Bit#(32),32)*/ worklist <- mkWorklist(readWorklist,writeWorklist);
  Server#(AM_FULL#(Bit#(32),Bit#(32)),AM_FULL#(Bit#(32),Bit#(32)),32) worklistServiceMod = worklist.workQ;// <- mkWorklistCircular(readWorklist,writeWorklist,started,wl_cap);

  Server2#(AM_FULL#(Bit#(32),Bit#(32)),AM_FULL#(Bit#(32),Bit#(32)),32) graphServiceMod <- mkGraphServer(readNodes,readEdges,readDistance,writeDistance); // FIXME this ordering is a sticking point
                                                                                                                                                         // Will be changing to hidden interface in the future
  Server#(AM_FULL#(Bit#(32),Bit#(32)),AM_FULL#(Bit#(32),Bit#(32)),32) neighborService = graphServiceMod.serverA; 
  Server#(AM_FULL#(Bit#(32),Bit#(32)),AM_FULL#(Bit#(32),Bit#(32)),32) updateService = graphServiceMod.serverB;

  BFSafuPipeline afuBFS <- mkBFSafuPipeline(worklistServiceMod,neighborService,updateService);

  /*rule starter;
    if (start_in) begin
      afuBFS.start(start_in);
      started <= True;
    end 
  endrule*/
  
  interface topC = tcC.top;

  method Action start(Bool strt);
      afuBFS.start(strt);
      worklist.start(strt);
      //start_in <= strt;
  endmethod

  method Bool finish();
      return afuBFS.finish();
  endmethod

  method Action setWk(Bit#(64) wk); // this is a bit ambiguous from the registry as it's shared
      ofstWk <= extend(wk);
  endmethod
  method Action setSrc(Bit#(64) src);
      ofstSrc <= extend(src);
  endmethod
  method Action setEdg(Bit#(64) edg);
      ofstEdge <= extend(edg);
  endmethod
  method Action setDst(Bit#(64) dst); // this is a bit ambiguous from the registry as it's shared
      ofstDst <= extend(dst);
  endmethod
  method Action setCapacity(Bit#(32) wc);
      worklist.setCapacity(wc);
      //wl_cap <= wc;
  endmethod
  method Bit#(64) getNodesTchd();
      return afuBFS.getNodesTchd();
  endmethod

endmodule
