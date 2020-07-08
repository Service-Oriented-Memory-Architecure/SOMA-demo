package Scratchpad;

import MessagePack::*;
import CBuffer::*;
import BRAM::*;
import BRAMCore::*;
import FIFO::*;
import FIFOF::*;
import FIFOFA::*;
import SpecialFIFOs::*;
import Vector::*;
import Channels::*;


// Scratchpad service with a single RW port. Write requests do return a response. 
module mkScratchpad#(Integer size)
                    (Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
              provisos(Bits#(data,d_),
                      Bits#(sdarg,s_),
		                  Literal#(sdarg),
                      Log#(threshold,e_),
                      Add#(b__, e_, s_)/*,
                      Log#(threshold,t_),
                      Log#(size,t_a),
                      Add#(t_a,1,ta_),
                      Add#(b_,s_,ta_),
                      Bits#(t_addr,ta_)*/);

  Integer vth = valueOf(threshold);
  Bit#(TAdd#(s_,1)) sz = fromInteger(vth);

  FIFOF#(AM_FULL#(sdarg,data))  inF <- mkUGSizedFIFOF(vth); 
  FIFOF#(AM_FULL#(sdarg,data))  outF <- mkUGSizedFIFOF(vth);  
  FIFOF#(AM_HEAD#(sdarg))  waitF <- mkUGSizedFIFOF(vth);  
 
  COUNTER#(TAdd#(s_,1)) cnt <- mkLCounter(0);

    function isNotFull() = ((cnt.value != sz)&&(inF.notFull));
    function isNotEmpty() = ((cnt.value != 0)&&(outF.notEmpty));

  function BRAMRequest#(sdarg, data) makeRequest(Bool w, sdarg a, data d); 
      return BRAMRequest{
                  write: w,
                  responseOnWrite:True,
                  address: a,
                  datain: d
                };
  endfunction

  BRAM_Configure cfg = defaultValue; 
  cfg.memorySize = size;
  cfg.allowWriteResponseBypass = False;
  BRAM1Port#(sdarg,data) scratch <- mkBRAM1Server(cfg);

  // arg0 read/write = 0/1 
  // arg1 index
  // arg2 
  // arg3

  rule process_request(inF.notEmpty&&waitF.notFull);
    let req = inF.first;
    Bool write = unpack(pack(req.head.arg0)[0]);
    //t_addr adr = unpack(truncate(pack(req.head.arg1)));
    sdarg adr = req.head.arg1;
    scratch.portA.request.put(makeRequest(write,adr,req.data.payload));
    //if (!write) begin
      waitF.enq(req.head);
    //end
    inF.deq;
  endrule
  rule return_response(outF.notFull&&waitF.notEmpty);
    let d <- scratch.portA.response.get;
    let dd = AM_DATA { payload: d };
    let rsp = AM_FULL { head: waitF.first, data: dd };
    outF.enq(rsp);
    waitF.deq;
  endrule

    let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      return !isNotFull;
    endmethod
    method Action tx(AM_FULL#(sdarg,data) r);
      $display("Scratchpad Server Req Tx.");
      inF.enq(r);
      cnt.up;      
    endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return !isNotEmpty;
    endmethod
    method Action rxPop();
      $display("Scratchpad Server Rsp Rx.");
      outF.deq();
      cnt.down;
    endmethod
    method AM_FULL#(sdarg,data) rx();
      return outF.first;
    endmethod
    endinterface;

  interface txPort = tx_ifc;
  interface rxPort = rx_ifc;

endmodule

// Scratchpad service with a dual RW ports. Write requests do return a response. 
module mkScratchpad2#(Integer size)
                    (Server2#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
              provisos(Bits#(data,d_),
                      Bits#(sdarg,s_),
                      Literal#(sdarg),
                      Log#(threshold,e_),
                      Add#(b__, e_, s_)/*,
                      Log#(threshold,t_),
                      Log#(size,t_a),
                      Add#(t_a,1,ta_),
                      Add#(b_,s_,ta_),
                      Bits#(t_addr,ta_)*/);

  Integer vth = valueOf(threshold);
  Bit#(TAdd#(s_,1)) sz = fromInteger(vth); 

  FIFOF#(AM_FULL#(sdarg,data))  inFa <- mkUGSizedFIFOF(vth); 
  FIFOF#(AM_FULL#(sdarg,data))  outFa <- mkUGSizedFIFOF(vth);  
  FIFOF#(AM_HEAD#(sdarg))  waitFa <- mkUGSizedFIFOF(vth);  
  FIFOF#(AM_FULL#(sdarg,data))  inFb <- mkUGSizedFIFOF(vth); 
  FIFOF#(AM_FULL#(sdarg,data))  outFb <- mkUGSizedFIFOF(vth);  
  FIFOF#(AM_HEAD#(sdarg))  waitFb <- mkUGSizedFIFOF(vth);  
 
  COUNTER#(TAdd#(s_,1)) cntA <- mkLCounter(0);
  COUNTER#(TAdd#(s_,1)) cntB <- mkLCounter(0);

    function isNotFullA() = ((cntA.value != sz)&&(inFa.notFull));
    function isNotEmptyA() = ((cntA.value != 0)&&(outFa.notEmpty));
    function isNotFullB() = ((cntB.value != sz)&&(inFb.notFull));
    function isNotEmptyB() = ((cntB.value != 0)&&(outFb.notEmpty));

  function BRAMRequest#(sdarg, data) makeRequest(Bool w, sdarg a, data d); 
      return BRAMRequest{
                  write: w,
                  responseOnWrite:True,
                  address: a,
                  datain: d
                };
  endfunction

  BRAM_Configure cfg = defaultValue; 
  cfg.memorySize = size;
  cfg.allowWriteResponseBypass = True;
  BRAM2Port#(sdarg,data) scratch <- mkBRAM2Server(cfg);

  // arg0 read/write = 0/1 
  // arg1 index
  // arg2 
  // arg3

  rule process_requestA(inFa.notEmpty&&waitFa.notFull);
    let req = inFa.first;
    Bool write = unpack(pack(req.head.arg0)[0]);
    //t_addr adr = unpack(truncate(pack(req.head.arg1)));
    sdarg adr = req.head.arg1;
    scratch.portA.request.put(makeRequest(write,adr,req.data.payload));
      $display("Scratchpad Req A %d %d %x",req.head.arg0,req.head.arg1,req.data.payload);
    //if (!write) begin
      waitFa.enq(req.head);
    //end
    inFa.deq;
  endrule
  rule return_responseA(outFa.notFull&&waitFa.notEmpty);
    let d <- scratch.portA.response.get;
    let dd = AM_DATA { payload: d };
    let rsp = AM_FULL { head: waitFa.first, data: dd };
      $display("Scratchpad Return Rsp A %d %d %x",waitFa.first.arg0,waitFa.first.arg1,d);
    outFa.enq(rsp);
    waitFa.deq;
  endrule
  rule process_requestB(inFb.notEmpty&&waitFb.notFull);
    let req = inFb.first;
    Bool write = unpack(pack(req.head.arg0)[0]);
    //t_addr adr = unpack(truncate(pack(req.head.arg1)));
    sdarg adr = req.head.arg1;
      $display("Scratchpad Req B %d %d %x",req.head.arg0,req.head.arg1,req.data.payload);
    scratch.portB.request.put(makeRequest(write,adr,req.data.payload));
    //if (!write) begin
      waitFb.enq(req.head);
    //end
    inFb.deq;
  endrule
  rule return_responseB(outFb.notFull&&waitFb.notEmpty);
    let d <- scratch.portB.response.get;
    let dd = AM_DATA { payload: d };
    let rsp = AM_FULL { head: waitFb.first, data: dd };
      $display("Scratchpad Return Rsp B %d %d %x",waitFb.first.arg0,waitFb.first.arg1,d);
    outFb.enq(rsp);
    waitFb.deq;
  endrule

    let tx_ifc_a = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      return !isNotFullA;
    endmethod
    method Action tx(AM_FULL#(sdarg,data) r);
      $display("Scratchpad Server Req Tx. A %d %x",r.head.arg1,r.data.payload);
      inFa.enq(r);
      cntA.up;      
    endmethod
    endinterface;

    let rx_ifc_a = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return !isNotEmptyA;
    endmethod
    method Action rxPop();
      $display("Scratchpad Server Rsp Rx. A");
      outFa.deq();
      cntA.down;
    endmethod
    method AM_FULL#(sdarg,data) rx();
      return outFa.first;
    endmethod
    endinterface;

    let tx_ifc_b = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      return !isNotFullB;
    endmethod
    method Action tx(AM_FULL#(sdarg,data) r);
      $display("Scratchpad Server Req Tx. B %d %x",r.head.arg1,r.data.payload);
      inFb.enq(r);
      cntB.up;      
    endmethod
    endinterface;

    let rx_ifc_b = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return !isNotEmptyB;
    endmethod
    method Action rxPop();
      $display("Scratchpad Server Rsp Rx. B");
      outFb.deq();
      cntB.down;
    endmethod
    method AM_FULL#(sdarg,data) rx();
      return outFb.first;
    endmethod
    endinterface;
  
  let loc_ServiceA = interface Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold);
    interface txPort = tx_ifc_a;
    interface rxPort = rx_ifc_b;
  endinterface;
  let loc_ServiceB = interface Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold);
    interface txPort = tx_ifc_a;
    interface rxPort = rx_ifc_b;
  endinterface;

  interface serverA = loc_ServiceA;
  interface serverB = loc_ServiceB;
endmodule

endpackage
