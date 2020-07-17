// MIT License
// 
// Copyright (c) 2020 by Joseph Melber, Carnegie Mellon University
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// Service module for a write through, write allocate cache.
//

package Cache;

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

typedef Bit#(n) NumTypeParam#(numeric type n);

typedef struct
  {
    Maybe#(t_DATA) data;
    t_ADDR addr;
  }
  CACHE_LINE#(type t_ADDR, type t_DATA)
    deriving(Bits,Eq);

module mkReadWriteServer2Cache#(Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold) cache)
                    (Server2#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
              provisos(Bits#(data,c_),
                       Bits#(sdarg,d_),
                       Alias#(marg,Bit#(a_)),
                       Add#(a__, 1, d_),
                       Add#(b__, a_, d_),
                       Log#(threshold, a_));

  Bool order = True;
  CBuffer#(AM_HEAD#(sdarg),AM_DATA#(data),marg,2,threshold) cBufWr; 
  if (order) begin
    cBufWr <- mkCompletionBufferBypass;
  end else begin
    cBufWr <- mkCompletionBufferU;
  end
  CBuffer#(AM_HEAD#(sdarg),AM_DATA#(data),marg,2,threshold) cBufRd; 
  if (order) begin
    cBufRd <- mkCompletionBufferBypass;
  end else begin
    cBufRd <- mkCompletionBufferU;
  end


  FIFOF#(AM_FULL#(sdarg,data)) readReqQ  <- mkUGSizedFIFOF(fromInteger(valueOf(threshold)));
  FIFOF#(AM_FULL#(sdarg,data)) writeReqQ <- mkUGSizedFIFOF(fromInteger(valueOf(threshold)));

  rule request_picker((readReqQ.notEmpty||writeReqQ.notEmpty)&&(!cache.txPort.txFull()));
    if (writeReqQ.notEmpty) begin
      cache.txPort.tx(writeReqQ.first);
      writeReqQ.deq;
      $display("[ADAPT $] send wr req");
    end else begin
      cache.txPort.tx(readReqQ.first);
      readReqQ.deq;
      $display("[ADAPT $] send read req");
    end
  endrule

  rule response_fetch(!cache.rxPort.rxEmpty());
    let rsp = cache.rxPort.rx;
    Bool write = unpack(truncate(pack(rsp.head.arg0)));
    sdarg tag = rsp.head.arg2;
    marg tg = unpack(truncate(pack(tag)));
    if (write) begin
      cBufWr.complete(tg,?);
      $display("[ADAPT $] complete write");
    end else begin
      cBufRd.complete(tg,rsp.data);
      $display("[ADAPT $] complete read");
    end
    cache.rxPort.rxPop;
  endrule

    // Rd Ifc
    let tx_ifc_a = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      return !cBufRd.canReserve() || !readReqQ.notFull();
    endmethod
    method Action tx(AM_FULL#(sdarg,data) r);
      let tg <- cBufRd.reserve(r.head);      
      sdarg write = unpack(extend(pack(False)));
      sdarg tag = unpack(extend(pack(tg)));
      let hd = AM_HEAD { srcid:? , dstid:? , arg0:write , arg1:r.head.arg1 
                               , arg2:tag , arg3:? }; 
      let req = AM_FULL { head: hd, data: ? };
      readReqQ.enq(req);
    endmethod
    endinterface;

    // Rd Ifc
    let rx_ifc_a = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return !cBufRd.notEmpty();
    endmethod
    method Action rxPop();      
      cBufRd.deq();
    endmethod
    method AM_FULL#(sdarg,data) rx();
       let rsp = AM_FULL { head: cBufRd.firstMeta, data: cBufRd.firstData };
      return rsp;
    endmethod
    endinterface;

    // Wr Ifc
    let tx_ifc_b = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      return !cBufWr.canReserve() || !writeReqQ.notFull();
    endmethod
    method Action tx(AM_FULL#(sdarg,data) w);
      let tg <- cBufWr.reserve(w.head);
      sdarg write = unpack(extend(pack(True)));
      sdarg tag = unpack(extend(pack(tg)));
      let hd = AM_HEAD { srcid:? , dstid:? , arg0:write , arg1:w.head.arg1 
                               , arg2:tag , arg3:? }; 
      let req = AM_FULL { head: hd, data: w.data };
      writeReqQ.enq(req);
    endmethod
    endinterface;

    // Wr Ifc
    let rx_ifc_b = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return !cBufWr.notEmpty();
    endmethod
    method Action rxPop();
      cBufWr.deq();
    endmethod
    method AM_FULL#(sdarg,data) rx();
      let rsp = AM_FULL { head: cBufWr.firstMeta, data: cBufWr.firstData };
      return rsp;
    endmethod
    endinterface;

    let rdsv = interface Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold);
      interface txPort = tx_ifc_a;
      interface rxPort = rx_ifc_a;
    endinterface;
    let wrsv = interface Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold);
      interface txPort = tx_ifc_b;
      interface rxPort = rx_ifc_b;
    endinterface;	

  interface serverA = rdsv;
  interface serverB = wrsv;
endmodule


module mkReadServer2Cache#(Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold) cache)
                    (Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
              provisos(Bits#(data,c_),
                       Bits#(sdarg,d_),
                       Alias#(marg,Bit#(a_)),
                       Add#(a__, 1, d_),
                       Add#(b__, a_, d_),
                       Log#(threshold, a_));

  Bool order = True;
  CBuffer#(AM_HEAD#(sdarg),AM_DATA#(data),marg,2,threshold) cBufRd; 
  if (order) begin
    cBufRd <- mkCompletionBufferBypass;
  end else begin
    cBufRd <- mkCompletionBufferU;
  end

  FIFOF#(AM_FULL#(sdarg,data)) readReqQ  <- mkUGSizedFIFOF(fromInteger(valueOf(threshold)));

  rule request_picker((readReqQ.notEmpty)&&(!cache.txPort.txFull()));
      cache.txPort.tx(readReqQ.first);
      readReqQ.deq;
      //$display("[ADAPT $] send read req");
  endrule

  rule response_fetch(!cache.rxPort.rxEmpty());
    let rsp = cache.rxPort.rx;
    sdarg tag = rsp.head.arg2;
    marg tg = unpack(truncate(pack(tag)));
    cBufRd.complete(tg,rsp.data);
    //$display("[ADAPT $] complete read");
    cache.rxPort.rxPop;
  endrule

    // Rd Ifc
    let tx_ifc_a = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      return !cBufRd.canReserve() || !readReqQ.notFull();
    endmethod
    method Action tx(AM_FULL#(sdarg,data) r);
      let tg <- cBufRd.reserve(r.head);      
      sdarg write = unpack(extend(pack(False)));
      sdarg tag = unpack(extend(pack(tg)));
      let hd = AM_HEAD { srcid:? , dstid:? , arg0:write , arg1:r.head.arg1 
                               , arg2:tag , arg3:? }; 
      let req = AM_FULL { head: hd, data: ? };
      readReqQ.enq(req);
    endmethod
    endinterface;

    // Rd Ifc
    let rx_ifc_a = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return !cBufRd.notEmpty();
    endmethod
    method Action rxPop();      
      cBufRd.deq();
    endmethod
    method AM_FULL#(sdarg,data) rx();
       let rsp = AM_FULL { head: cBufRd.firstMeta, data: cBufRd.firstData };
      return rsp;
    endmethod
    endinterface;

  interface txPort = tx_ifc_a;
  interface rxPort = rx_ifc_a;

endmodule

module mkWriteServer2Cache#(Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold) cache)
                    (Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
              provisos(Bits#(data,c_),
                       Bits#(sdarg,d_),
                       Alias#(marg,Bit#(a_)),
                       Add#(a__, 1, d_),
                       Add#(b__, a_, d_),
                       Log#(threshold, a_));

  Bool order = True;
  CBuffer#(AM_HEAD#(sdarg),AM_DATA#(data),marg,2,threshold) cBufWr; 
  if (order) begin
    cBufWr <- mkCompletionBufferBypass;
  end else begin
    cBufWr <- mkCompletionBufferU;
  end
  CBuffer#(AM_HEAD#(sdarg),AM_DATA#(data),marg,2,threshold) cBufRd; 
  if (order) begin
    cBufRd <- mkCompletionBufferBypass;
  end else begin
    cBufRd <- mkCompletionBufferU;
  end


  FIFOF#(AM_FULL#(sdarg,data)) readReqQ  <- mkUGSizedFIFOF(fromInteger(valueOf(threshold)));
  FIFOF#(AM_FULL#(sdarg,data)) writeReqQ <- mkUGSizedFIFOF(fromInteger(valueOf(threshold)));

  rule request_picker((writeReqQ.notEmpty)&&(!cache.txPort.txFull()));
      cache.txPort.tx(writeReqQ.first);
      writeReqQ.deq;
      //$display("[ADAPT $] send wr req");
  endrule

  rule response_fetch(!cache.rxPort.rxEmpty());
    let rsp = cache.rxPort.rx;
    sdarg tag = rsp.head.arg2;
    marg tg = unpack(truncate(pack(tag)));
      cBufWr.complete(tg,?);
      //$display("[ADAPT $] complete write");
    cache.rxPort.rxPop;
  endrule

    // Wr Ifc
    let tx_ifc_b = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      return !cBufWr.canReserve() || !writeReqQ.notFull();
    endmethod
    method Action tx(AM_FULL#(sdarg,data) w);
      let tg <- cBufWr.reserve(w.head);
      sdarg write = unpack(extend(pack(True)));
      sdarg tag = unpack(extend(pack(tg)));
      let hd = AM_HEAD { srcid:? , dstid:? , arg0:write , arg1:w.head.arg1 
                               , arg2:tag , arg3:? }; 
      let req = AM_FULL { head: hd, data: w.data };
      writeReqQ.enq(req);
    endmethod
    endinterface;

    // Wr Ifc
    let rx_ifc_b = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return !cBufWr.notEmpty();
    endmethod
    method Action rxPop();
      cBufWr.deq();
    endmethod
    method AM_FULL#(sdarg,data) rx();
      let rsp = AM_FULL { head: cBufWr.firstMeta, data: cBufWr.firstData };
      return rsp;
    endmethod
    endinterface;

  interface txPort = tx_ifc_b;
  interface rxPort = rx_ifc_b;

endmodule

module mkCacheServer#(RdChannel#(addr,marg,data,thresh,n_out_mem) rdC, WrChannel#(addr,marg,data,thresh,n_out_mem) wrC, NumTypeParam#(n_en) entries, addr offset)
                    (Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
              provisos(Bits#(marg,a_),
                   Bits#(addr,b_),
                   Bits#(data,c_),
                   Bits#(sdarg,d_),
                   Arith#(sdarg),
                   Eq#(sdarg),
                   ////Add#(a__, d_, b_),
                   Add#(a__, d_, b_),
                   Add#(b__, a_, d_),
                   Log#(n_en, cl_idx),
                   Add#(c__, cl_idx, d_),
                   Add#(d__, 1, d_),
                   Log#(threshold, a_),
                   PrimIndex#(marg,g_));
                   ////Literal#(data));

  BRAM_Configure cfg = defaultValue; 
  cfg.memorySize = valueOf(n_en);
  cfg.allowWriteResponseBypass = False;
  BRAM2Port#(Bit#(cl_idx),CACHE_LINE#(sdarg,data)) cacheLines <- mkBRAM2Server(cfg);

  FIFOF#(AM_FULL#(sdarg,data)) inF <- mkPipelineFIFOF();
  FIFOF#(AM_FULL#(sdarg,data)) outF <- mkSizedBypassFIFOF(fromInteger(valueOf(threshold))); // bypass
  FIFOF#(AM_FULL#(sdarg,data)) readRspQ <- mkUGFIFOF(); // pipeline
  FIFOF#(AM_FULL#(sdarg,data)) writeRspQ <- mkUGFIFOF(); // pipeline

  FIFOF#(AM_FULL#(sdarg,data)) pendingReq <- mkPipelineFIFOF();
  FIFOF#(Bit#(0)) mainMemReq <- mkBypassFIFOF();
  Vector#(threshold, Array#(Reg#(sdarg))) rdAddrs <- replicateM(mkCReg(2,?));

  rule doCacheRequest(inF.notEmpty&&pendingReq.notFull);
    Bool write = unpack(truncate(pack(inF.first.head.arg0)));
    sdarg addr = inF.first.head.arg1;
    sdarg tag = inF.first.head.arg2;
    Bit#(cl_idx) address = truncate(pack(addr));
    let bramReq = BRAMRequest{write: write,
                              responseOnWrite: True,
                              address: address,
                              datain: ?};
    if (write) begin
      bramReq.datain = CACHE_LINE{addr: addr, data: tagged Valid inF.first.data.payload};
    end
    cacheLines.portA.request.put(bramReq);
    pendingReq.enq(inF.first);
    inF.deq;
      //$display("[CACHE] check cache");
  endrule

  rule bramResponse(pendingReq.notEmpty);
    let cacheLine <- cacheLines.portA.response.get;
    let req = pendingReq.first;
    Bool write = unpack(truncate(pack(pendingReq.first.head.arg0)));
    sdarg req_addr = pendingReq.first.head.arg1;
    sdarg tag = pendingReq.first.head.arg2;
    if (!write) begin
        if(cacheLine.addr == req_addr &&& cacheLine.data matches tagged Valid .data)
          begin
            let dd = AM_DATA { payload: data };
            let rsp = AM_FULL { head: req.head, data: dd };
            outF.enq(rsp);
            pendingReq.deq;
            //$display("[CACHE] enq read hit to outF");
          end
        else
          begin
            mainMemReq.enq(?);
            //$display("[CACHE] read miss send to memory A");
          end
    end else begin
      mainMemReq.enq(?);
      //$display("[CACHE] send write to memory A");
    end
  endrule

  rule memoryReq(pendingReq.notEmpty&&mainMemReq.notEmpty);
    let req = pendingReq.first;
    Bool write = unpack(truncate(pack(pendingReq.first.head.arg0)));
    sdarg req_addr = pendingReq.first.head.arg1;
    sdarg tag = pendingReq.first.head.arg2;
    marg tg = unpack(truncate(pack(tag)));
    addr a = unpack(extend(pack(req_addr))+pack(offset));
    if (write&&!wrC.txFull&&writeRspQ.notFull) begin
      wrC.tx(a,tg,req.data.payload);
      pendingReq.deq;
      mainMemReq.deq;
      marg md = wrC.rxMarg();
    // TODO full response setup
    sdarg writeI = unpack(extend(pack(True)));
    let hd = AM_HEAD { srcid:? , dstid:? , arg0:writeI , arg1:? 
                               , arg2:tag , arg3:? }; 
    let rsp = AM_FULL { head: hd, data: ? };
    // enq into full sized FIFO
    writeRspQ.enq(rsp);
      //$display("[CACHE] send write to memory B");
    end else if (!rdC.txFull) begin
      rdC.tx(a,tg);
      rdAddrs[pack(tg)][0] <= req_addr;
      pendingReq.deq;  
      mainMemReq.deq;
      //$display("[CACHE] send read to memory B");    
    end
  endrule

  (* fire_when_enabled *)
  rule drainWr(!wrC.rxEmpty);//&&writeRspQ.notFull);
    wrC.rxPop();
      //$display("[CACHE] recv write from memory");
  endrule
  (* fire_when_enabled *)
  rule drainRd(!rdC.rxEmpty&&readRspQ.notFull);
    marg md = rdC.rxMarg();
    data dr = rdC.rxData();
    sdarg addr = rdAddrs[pack(md)][1];
    Bit#(cl_idx) ad = truncate(pack(addr));
    let bramReq = BRAMRequest{write: True, 
                              responseOnWrite: False,
                              address: ad, 
                              datain: ?};
    bramReq.datain = CACHE_LINE{addr: addr, data: tagged Valid dr};
    sdarg write = unpack(extend(pack(False)));
    sdarg tag = unpack(extend(pack(md)));
    let hd = AM_HEAD { srcid:? , dstid:? , arg0:write , arg1:? 
                               , arg2:tag , arg3:? }; 
    let dd = AM_DATA { payload: dr };
    let rsp = AM_FULL { head: hd, data:dd };
    cacheLines.portB.request.put(bramReq);   
    readRspQ.enq(rsp);
    rdC.rxPop();
    //$display("[CACHE] recv read from memory");
  endrule

  rule fillOutF(outF.notFull&&(readRspQ.notEmpty||writeRspQ.notEmpty));
    if (writeRspQ.notEmpty) begin
      outF.enq(writeRspQ.first);
      writeRspQ.deq;
      //$display("[CACHE] enq write to outF");
    end else begin
      outF.enq(readRspQ.first);
      readRspQ.deq;
      //$display("[CACHE] enq read miss to outF");
    end
  endrule

    let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      return !inF.notFull();
    endmethod
    method Action tx(AM_FULL#(sdarg,data) r);
      inF.enq(r);
    endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return !outF.notEmpty();
    endmethod
    method Action rxPop();
      outF.deq();
    endmethod
    method AM_FULL#(sdarg,data) rx();
      return outF.first;
    endmethod
    endinterface;

  interface txPort = tx_ifc;
  interface rxPort = rx_ifc;

endmodule


module mkCacheServerRO#(RdChannel#(addr,marg,data,thresh,n_out_mem) rdC, addr offset, NumTypeParam#(n_en) entries)
                    (Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
              provisos(Bits#(marg,a_),
                   Bits#(addr,b_),
                   Bits#(data,c_),
                   Bits#(sdarg,d_),
                   Arith#(sdarg),
                   Eq#(sdarg),
                   ////Add#(a__, d_, b_),
                   Add#(a__, d_, b_),
                   Add#(b__, a_, d_),
                   Log#(n_en, cl_idx),
                   Add#(c__, cl_idx, d_),
                   Add#(d__, 1, d_),
                   Log#(threshold, a_),
                   PrimIndex#(marg,g_));
                   ////Literal#(data));

  BRAM_Configure cfg = defaultValue; 
  cfg.memorySize = valueOf(n_en);
  cfg.allowWriteResponseBypass = False;
  BRAM2Port#(Bit#(cl_idx),CACHE_LINE#(sdarg,data)) cacheLines <- mkBRAM2Server(cfg);

  FIFOF#(AM_FULL#(sdarg,data)) inF <- mkPipelineFIFOF();
  FIFOF#(AM_FULL#(sdarg,data)) outF <- mkSizedBypassFIFOF(fromInteger(valueOf(threshold))); // bypass
  FIFOF#(AM_FULL#(sdarg,data)) readRspQ <- mkUGFIFOF(); // pipeline
  
  FIFOF#(AM_FULL#(sdarg,data)) pendingReq <- mkPipelineFIFOF();
  FIFOF#(Bit#(0)) mainMemReq <- mkBypassFIFOF();
  Vector#(threshold, Array#(Reg#(sdarg))) rdAddrs <- replicateM(mkCReg(2,?));

  rule doCacheRequest(inF.notEmpty&&pendingReq.notFull);
    Bool write = False;
    sdarg addr = inF.first.head.arg1;
    sdarg tag = inF.first.head.arg2;
    Bit#(cl_idx) address = truncate(pack(addr));
    let bramReq = BRAMRequest{write: write,
                              responseOnWrite: True,
                              address: address,
                              datain: ?};
    cacheLines.portA.request.put(bramReq);
    pendingReq.enq(inF.first);
    inF.deq;
      //$display("[CACHE] check cache");
  endrule

  rule bramResponse(pendingReq.notEmpty);
    let cacheLine <- cacheLines.portA.response.get;
    let req = pendingReq.first;
    sdarg req_addr = pendingReq.first.head.arg1;
    sdarg tag = pendingReq.first.head.arg2;
    if(cacheLine.addr == req_addr &&& cacheLine.data matches tagged Valid .data)
      begin
        let dd = AM_DATA { payload: data };
        let rsp = AM_FULL { head: req.head, data: dd };
        outF.enq(rsp);
        pendingReq.deq;
        //$display("[CACHE] enq read hit to outF");
      end
    else
      begin
        mainMemReq.enq(?);
        //$display("[CACHE] read miss send to memory A");
      end
  endrule

  rule memoryReq(pendingReq.notEmpty&&mainMemReq.notEmpty);
    let req = pendingReq.first;
    sdarg req_addr = pendingReq.first.head.arg1;
    sdarg tag = pendingReq.first.head.arg2;
    marg tg = unpack(truncate(pack(tag)));
    addr a = unpack(extend(pack(req_addr))+pack(offset));
    if (!rdC.txFull) begin
      rdC.tx(a,tg);
      rdAddrs[pack(tg)][0] <= req_addr;
      pendingReq.deq;  
      mainMemReq.deq;
      //$display("[CACHE] send read to memory B");    
    end
  endrule

  (* fire_when_enabled *)
  rule drainRd(!rdC.rxEmpty&&readRspQ.notFull);
    marg md = rdC.rxMarg();
    data dr = rdC.rxData();
    sdarg addr = rdAddrs[pack(md)][1];
    Bit#(cl_idx) ad = truncate(pack(addr));
    let bramReq = BRAMRequest{write: True, 
                              responseOnWrite: False,
                              address: ad, 
                              datain: ?};
    bramReq.datain = CACHE_LINE{addr: addr, data: tagged Valid dr};
    sdarg write = unpack(extend(pack(False)));
    sdarg tag = unpack(extend(pack(md)));
    let hd = AM_HEAD { srcid:? , dstid:? , arg0:write , arg1:? 
                               , arg2:tag , arg3:? }; 
    let dd = AM_DATA { payload: dr };
    let rsp = AM_FULL { head: hd, data:dd };
    cacheLines.portB.request.put(bramReq);   
    readRspQ.enq(rsp);
    rdC.rxPop();
    //$display("[CACHE] recv read from memory");
  endrule

  rule fillOutF(outF.notFull&&readRspQ.notEmpty);
      outF.enq(readRspQ.first);
      readRspQ.deq;
      //$display("[CACHE] enq read miss to outF");
  endrule

    let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      return !inF.notFull();
    endmethod
    method Action tx(AM_FULL#(sdarg,data) r);
      inF.enq(r);
    endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return !outF.notEmpty();
    endmethod
    method Action rxPop();
      outF.deq();
    endmethod
    method AM_FULL#(sdarg,data) rx();
      return outF.first;
    endmethod
    endinterface;

  interface txPort = tx_ifc;
  interface rxPort = rx_ifc;

endmodule

// Scratchpad service with a dual RW ports. Write requests do return a response. 
/*module mkReadWriteServer2Cache#(RdChannel#(addr,marg,data,thresh,n_out_mem) rdC, WrChannel#(addr,marg,data,thresh,n_out_mem) wrC, addr offset)
                    (Server2#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
              provisos(Bits#(marg,a_),
                   Bits#(addr,b_),
                   Bits#(data,c_),
                   Bits#(sdarg,d_),
                   Arith#(sdarg),
                   Eq#(sdarg),
                   //Add#(a__, d_, b_),
                   Add#(a__, d_, b_),
                   Add#(b__, 12, d_),
                   Log#(threshold, a_),
                   PrimIndex#(marg,g_));

  Integer vth = valueOf(threshold);
  Bit#(TAdd#(s_,1)) sz = fromInteger(vth); 

  Bool order = True;
  CBuffer#(AM_HEAD#(sdarg),AM_DATA#(data),marg,2,threshold) cBufWr; 
  if (order) begin
    cBufWr <- mkCompletionBufferBypass;
  end else begin
    cBufWr <- mkCompletionBufferU;
  end
  CBuffer#(AM_HEAD#(sdarg),AM_DATA#(data),marg,2,threshold) cBufRd; 
  if (order) begin
    cBufRd <- mkCompletionBufferBypass;
  end else begin
    cBufRd <- mkCompletionBufferU;
  end

  function BRAMRequest#(Bit#(12), data) makeRequest(Bool w, Bit#(12) a, data d); 
      return BRAMRequest{
                  write: w,
                  responseOnWrite:False,
                  address: a,
                  datain: d
                };
  endfunction

  BRAM_Configure cfg = defaultValue; 
  cfg.memorySize = 4096;
  cfg.allowWriteResponseBypass = False;
  BRAM2Port#(Bit#(12),data) scratch <- mkBRAM2Server(cfg);

  FIFOF#(marg) waitFa <- mkUGSizedFIFOF(vth);  
  Vector#(threshold, Array#(Reg#(Bit#(12)))) rdIdxs <- replicateM(mkCReg(2,?));
  Vector#(4096, Reg#(Bool)) val <- replicateM(mkReg(False));
  //Vector#(4096, Reg#(Bool)) bsy <- replicateM(mkReg(False));
  Vector#(4096, Reg#(sdarg)) tag <- replicateM(mkReg(?));

  // arg0 
  // arg1 index
  // arg2 
  // arg3

  // A is rd channel
  rule hit_responseA(waitFa.notEmpty&&rdC.rxEmpty);
    let d <- scratch.portA.response.get;
    let dd = AM_DATA { payload: d };
    let md = waitFa.first;   
    cBufRd.complete(md,dd);
    waitFa.deq;
    $display("RD Server Cache Hit Recv.");
  endrule

  // A is rd channel
  rule miss_responseA(!rdC.rxEmpty);
    marg md = rdC.rxMarg();
    data dd = rdC.rxData();
    let ad = AM_DATA { payload: dd };
    cBufRd.complete(md,ad);
    // lookup idx at cbuf tag
    Bit#(12) idx = rdIdxs[md][1]; 
    // clear busy
    //bsy[idx] <= False;
    // set valid  
    val[idx] <= True;
    scratch.portA.request.put(makeRequest(True,idx,dd)); 
    rdC.rxPop();
    $display("RD Server Cache Miss Recv.");
  endrule

  // B is wr channel
  rule get_responseB(!wrC.rxEmpty);
    marg md = wrC.rxMarg();
    cBufWr.complete(md,?);
    wrC.rxPop();
    $display("WR Server Cache Recv.");
  endrule

    // Rd Ifc
    let tx_ifc_a = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      return !cBufRd.canReserve() || rdC.txFull();
    endmethod
    method Action tx(AM_FULL#(sdarg,data) r);
      addr a = unpack(extend(pack(r.head.arg1))+pack(offset));
      let tg <- cBufRd.reserve(r.head);
      // get idx from addr
      Bit#(12) idx = truncate(pack(r.head.arg1));
      rdIdxs[tg][0] <= idx;
      // check tag for hit @ idx
      Bool hit = val[idx] && (tag[idx] == r.head.arg1);
      if (hit) begin
        scratch.portA.request.put(makeRequest(False,idx,r.data.payload)); // do cache read
        waitFa.enq(tg); // enq tag 
      end else begin
        // check busy
        //if (bsy[idx]) // stall FIXME !!!
        //else begin
          rdC.tx(a,tg); // and set busy
          //bsy[idx] <= True;
          tag[idx] <= r.head.arg1;
        //end
      end
    endmethod
    endinterface;

    // Rd Ifc
    let rx_ifc_a = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return !cBufRd.notEmpty();
    endmethod
    method Action rxPop();      
      cBufRd.deq();
    endmethod
    method AM_FULL#(sdarg,data) rx();
       let rsp = AM_FULL { head: cBufRd.firstMeta, data: cBufRd.firstData };
      return rsp;
    endmethod
    endinterface;

    // Wr Ifc
    let tx_ifc_b = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      return !cBufWr.canReserve() || wrC.txFull();
    endmethod
    method Action tx(AM_FULL#(sdarg,data) w);
      addr a = unpack(extend(pack(w.head.arg1))+pack(offset));
      let tg <- cBufWr.reserve(w.head);
      // get idx from addr
      Bit#(12) idx = truncate(pack(w.head.arg1));
      // check tag for hit @ idx
      Bool hit = val[idx] && (tag[idx] == w.head.arg1);
      if (hit) begin
        scratch.portB.request.put(makeRequest(True,idx,w.data.payload)); // cache write on hit
        // TODO opt - send complete to a return FIFO // same size as thresh  
      end
      wrC.tx(a,tg,w.data.payload); 
    endmethod
    endinterface;

    // Wr Ifc
    let rx_ifc_b = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return !cBufWr.notEmpty();
    endmethod
    method Action rxPop();
      cBufWr.deq();
    endmethod
    method AM_FULL#(sdarg,data) rx();
      let rsp = AM_FULL { head: cBufWr.firstMeta, data: cBufWr.firstData };
      return rsp;
    endmethod
    endinterface;

  interface txPortA = tx_ifc_a;
  interface rxPortA = rx_ifc_a;
  interface txPortB = tx_ifc_b;
  interface rxPortB = rx_ifc_b;

endmodule*/

endpackage
