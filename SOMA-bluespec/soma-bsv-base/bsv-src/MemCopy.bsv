package MemCopy;

import MessagePack::*;
import FIFO::*;
import FIFOF::*;
import FIFOFA::*;
import SpecialFIFOs::*;
import Vector::*;
import Channels::*;

module mkMemCopy#(Server#(AM_FULL#(sdargA,data),AM_FULL#(sdargA,data),thA) rdA, Server#(AM_FULL#(sdargB,data),AM_FULL#(sdargB,data),thB) wrA)
                    (Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
              provisos(Bits#(data,ca_),
                   Bits#(sdargA,da_),
                   Bits#(sdargB,db_),
                   Bits#(sdarg,d_),
                   Add#(a__, da_, d_),
                   Add#(b__, db_, d_),
                   Add#(e__, 1, da_),
                   Add#(f__, 1, db_),
		   Literal#(sdargA),
		   Literal#(sdargB),
		   Literal#(sdarg));

  FIFOF#(AM_FULL#(sdarg,data))  inF <- mkUGSizedFIFOF(4); 
  FIFOF#(AM_FULL#(sdarg,data))  outF <- mkUGSizedFIFOF(4+2);  

  Reg#(Bool)    lock <- mkReg(False);
  Reg#(Bool)    busy    <- mkReg(False);
  Reg#(Bit#(d_))   dataCntR <- mkReg(0);
  Reg#(Bit#(d_))   dataCntW <- mkReg(0);
  Reg#(Bit#(d_))   dataCpCnt <- mkReg(0);
  Reg#(AM_HEAD#(sdarg))   outHead <- mkReg(?);

  RWire#(AM_HEAD#(sdarg)) txInHead <- mkRWire(); 
  //PulseWire txIn <- mkPulseWire();
  PulseWire rxIn <- mkPulseWire();

  PulseWire rxWr <- mkPulseWire();
  PulseWire txWr <- mkPulseWire();
  PulseWire txRd <- mkPulseWire();
  PulseWire txRsp <- mkPulseWire();

  // arg0 destination 
  // arg1 source
  // arg2 num (of data full CL)

  rule send_response(busy&&lock&&(dataCntR>=pack(outHead.arg2))&&(dataCntW>=pack(outHead.arg2))&&(dataCpCnt>=pack(outHead.arg2)));
    AM_FULL#(sdarg,data) rsp = AM_FULL { head: outHead, data: ? };
    outF.enq(rsp);
    txRsp.send();
    //busy <= False;
    //$display("MemCopy Server Resp.");
  endrule

  rule pop_write(!wrA.rxPort.rxEmpty);
    //$display("MemCopy WR Rsp. CNT %d",dataCpCnt);
    wrA.rxPort.rxPop;
    rxWr.send();
  endrule

  // FIXME read server empty coming back too soon...
  rule get_put_copier(!rdA.rxPort.rxEmpty&&!wrA.txPort.txFull&&(dataCntW<pack(outHead.arg2))); //Maybe move dataCntW for Wr responses??
    sdargB adr = unpack(truncate(pack(outHead.arg0)+dataCntW));
    let hd = AM_HEAD { srcid:0 , dstid:0 , arg0:unpack(extend(pack(True))) , arg1:adr
                       , arg2:? , arg3:? }; 
    let ad = rdA.rxPort.rx.data;
    let req = AM_FULL { head: hd, data: ad };
    wrA.txPort.tx(req);
    rdA.rxPort.rxPop;
    txWr.send();
    //$display("MemCopy WR Copy Req. Adr %x CNT %d",adr,dataCntW);
  endrule

  rule put_read(lock&&(!rdA.txPort.txFull)&&(dataCntR<pack(outHead.arg2)));
    sdargA adr = unpack(truncate(pack(outHead.arg1)+dataCntR));
    let hd = AM_HEAD { srcid:0 , dstid:0 , arg0:unpack(extend(pack(False))) , arg1:adr
                       , arg2:? , arg3:? }; //arg0=? arg1=addr
    let req = AM_FULL { head: hd, data: ? };
    rdA.txPort.tx(req);
    txRd.send();
    //$display("MemCopy RD Server Req. Adr %x CNT %d MAX %d",adr,dataCntR,pack(outHead.arg2));
  endrule

  rule do_busy_n(txRsp &&& txInHead.wget() matches tagged Invalid);
      busy <= False;
  endrule
  rule do_busy(!txRsp &&& txInHead.wget() matches tagged Valid .in_head);
      busy <= True;
  endrule
  rule do_lock_rx(rxIn &&& txInHead.wget() matches tagged Invalid);
      lock <= False;
      //$display("UNLOCK MemCopy");
  endrule
  rule do_lock_tx(!rxIn &&& txInHead.wget() matches tagged Valid .in_head);
      lock <= True;
      //$display("~~~LOCK MemCopy");
  endrule
  rule zero_init(txInHead.wget() matches tagged Valid .in_head);
    dataCntR <= 0;//pack(in_head.arg2);
    dataCntW <= 0;//pack(in_head.arg2);
    dataCpCnt <= 0;//pack(in_head.arg2);
    //$display("Send command - dst: %x, src: %x, num: %x, cmd: %x",in_head.arg0,in_head.arg1,in_head.arg2,in_head.arg3);
    outHead <= in_head;
  endrule
  rule cntCp_inc(rxWr &&& txInHead.wget() matches tagged Invalid);
    dataCpCnt <= dataCpCnt + 1;
  endrule
  rule cntW_inc(txWr &&& txInHead.wget() matches tagged Invalid);
    dataCntW <= dataCntW + 1;
  endrule
  rule cntR_inc(txRd &&& txInHead.wget() matches tagged Invalid);
    dataCntR <= dataCntR + 1;
  endrule

    let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      //return inF.isGreaterThan(valueOf(threshold)) || rdC.txFull();
      return lock;
    endmethod
    method Action tx(AM_FULL#(sdarg,data) r);
      $display("MC Server Req Tx.");
      txInHead.wset(r.head);
      //txIn.send();      
    endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return !outF.notEmpty();
    endmethod
    method Action rxPop();
      //$display("MC Server Rsp Rx.");
      rxIn.send();
      outF.deq();
    endmethod
    method AM_FULL#(sdarg,data) rx();
      return outF.first;
    endmethod
    endinterface;

  interface txPort = tx_ifc;
  interface rxPort = rx_ifc;

endmodule

module mkMemCopyDual#(Server#(AM_FULL#(sdargA,data),AM_FULL#(sdargA,data),thA) rdA, Server#(AM_FULL#(sdargA,data),AM_FULL#(sdargA,data),thA) wrA,
                      Server#(AM_FULL#(sdargB,data),AM_FULL#(sdargB,data),thB) rdB, Server#(AM_FULL#(sdargB,data),AM_FULL#(sdargB,data),thB) wrB)
                    (Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
              provisos(Bits#(data,ca_),
                   Bits#(sdargA,da_),
                   Bits#(sdargB,db_),
                   Bits#(sdarg,d_),
                   Add#(a__, da_, d_),
                   Add#(b__, db_, d_),
                   Add#(e__, 1, da_),
                   Add#(f__, 1, db_),
                   Ord#(sdarg),
                   Literal#(sdargA),
                   Literal#(sdargB),
                   Literal#(sdarg));

  FIFOF#(AM_FULL#(sdarg,data))  inF <- mkUGSizedFIFOF(4); 
  FIFOF#(AM_FULL#(sdarg,data))  outF <- mkUGSizedFIFOF(4+2);  

  Reg#(Bool)    lock <- mkReg(False);
  Reg#(Bool)    busy    <- mkReg(False);
  Reg#(Bool)    ready    <- mkReg(True);
  Reg#(AM_HEAD#(sdarg))   outHead <- mkReg(?);

  PulseWire txIn <- mkPulseWire();
  PulseWire rxIn <- mkPulseWire();

  // arg0 destination 
  // arg1 source
  // arg2 num 
  // arg3[1:0] direction: 0 = (A->B), 1 = (B->A), 2 = (A->A), 3 = (B->B)

  Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold) mcAB <- mkMemCopy(rdA,wrB);
  Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold) mcBA <- mkMemCopy(rdB,wrA);
  // Needs Y to do these...not doing this for now
  //Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold) mcAA <- mkMemCopy(rdA,wrA);
  //Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold) mcBB <- mkMemCopy(rdB,wrB);

  rule send_response(lock&&busy);
    if (!mcAB.rxPort.rxEmpty) begin
      let rsp = AM_FULL { head: outHead, data: ? };
      outF.enq(rsp);
      busy <= False;
      mcAB.rxPort.rxPop;
      //$display("MC Dual Resp. AB");
    end else if (!mcBA.rxPort.rxEmpty) begin
      let rsp = AM_FULL { head: outHead, data: ? };
      outF.enq(rsp);
      busy <= False;
      mcBA.rxPort.rxPop;
      //$display("MC Dual Resp. BA");
    end 
    /*if (!mcAA.rxEmpty) begin
      let rsp = AM_FULL { head: outHead, data: ? };
      outF.enq(rsp);
      busy <= False;
      mcAA.rxPop;
      //$display("MemCopy Server Resp.");
    end 
    if (!mcBB.rxEmpty) begin
      let rsp = AM_FULL { head: outHead, data: ? };
      outF.enq(rsp);
      busy <= False;
      mcBB.rxPop;
      //$display("MemCopy Server Resp.");
    end*/ 
  endrule

  rule send_request(lock&&!busy&&ready); 
      if ((pack(outHead.arg3)[1:0]==0)&&(!mcAB.txPort.txFull)) begin
        let r = AM_FULL { head: outHead, data: ? };
        mcAB.txPort.tx(r);
        busy <= True;
        ready <= False;
        //$display("MC send to AB");
    //$display("MC command - dst: %x, src: %x, num: %x, cmd: %x",outHead.arg0,outHead.arg1,outHead.arg2,outHead.arg3);
      end else if ((pack(outHead.arg3)[1:0]==1)&&(!mcBA.txPort.txFull)) begin
        let r = AM_FULL { head: outHead, data: ? };
        mcBA.txPort.tx(r);
        busy <= True;
        ready <= False;
        //$display("MC send to BA");
    //$display("MC command - dst: %x, src: %x, num: %x, cmd: %x",outHead.arg0,outHead.arg1,outHead.arg2,outHead.arg3);
      end /*else if ((pack(outHead.arg3)[1:0]==2)&&(!mcAA.txFull)) begin
        mcAA.tx(r);
        busy <= True;
      end else if ((pack(outHead.arg3)[1:0]==3)&&(!mcBB.txFull)) begin
        mcBB.tx(r);
        busy <= True;
      end*/
  endrule

  rule do_lock_rx(rxIn && !txIn);
      //$display("MC Lock False");
      lock <= False;
      ready <= True;
  endrule
  rule do_lock_tx(!rxIn && txIn);
      //$display("MC Lock True");
      lock <= True;
  endrule

    let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      return lock || busy || !ready;
    endmethod
    method Action tx(AM_FULL#(sdarg,data) r);
      //$display("MC Dual Req Tx.");
      outHead <= r.head;
      //lock <= True;
      txIn.send();    
    endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return !outF.notEmpty();
    endmethod
    method Action rxPop();
      //$display("MC Dual Rsp Rx.");
      //lock <= False;
      rxIn.send();
      outF.deq();
    endmethod
    method AM_FULL#(sdarg,data) rx();
      return outF.first;
    endmethod
    endinterface;

  interface txPort = tx_ifc;
  interface rxPort = rx_ifc;

endmodule

endpackage
