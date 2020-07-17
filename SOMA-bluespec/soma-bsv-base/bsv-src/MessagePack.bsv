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
// Service-oriented Memory Architecture Message specification and implementation
// Read and Write service module implementations
//

package MessagePack;

import Channels::*;
import CBuffer::*;
import FIFO::*;
import FIFOF::*;
import FIFOFA::*;
import FIFOLevel::*;
import SpecialFIFOs::*;
import Vector::*;
import Arbiters::*;
import Clocks::*;
import Connectable::*;

typedef struct 
	{
	    sdarg   srcid; // maybe not separate I might need to pass all data
	    sdarg   dstid;
	    addr    add;
	} 
	RD_REQ#(type sdarg, type addr) 
	    deriving(Bits,Eq);

typedef struct 
	{
	    sdarg   srcid; // maybe not separate I might need to pass all data
	    sdarg   dstid;
	    addr    add;
	    data	dat;
	} 
	WR_REQ#(type sdarg, type addr, type data) 
	    deriving(Bits,Eq);

typedef struct 
	{
	    sdarg   srcid;
	    sdarg   dstid;
	    data	dat;
	} 
	RD_RSP#(type sdarg, type data) 
	    deriving(Bits,Eq);


typedef struct 
	{
	    sdarg   srcid;
	    sdarg   dstid;
	} 
	WR_RSP#(type sdarg) 
	    deriving(Bits,Eq);

typedef struct
	{
		data 	payload;
	}
	AM_DATA#(type data)
		deriving(Bits,Eq);

typedef struct
	{
		sdarg	srcid;
		sdarg	dstid;
		//sdarg	handler;
		sdarg	arg0;
		sdarg	arg1;
		sdarg	arg2;
		sdarg	arg3;
		//sdarg	arg4;
	}
	AM_HEAD#(type sdarg)
		deriving(Bits,Eq);

typedef struct
	{
		AM_DATA#(data)	data;
		AM_HEAD#(sdarg) head;
	}
	AM_FULL#(type sdarg, type data)
		deriving(Bits,Eq);

typedef struct
	{
		AM_HEAD#(sdarg) head;
		AM_DATA#(data)	data;
		sdarg			tag;
	}
	AM_FULL_TAG#(type sdarg, type data)
		deriving(Bits,Eq);

///////////////////////////////////////////////////////////////////////////////
/////////////////////////// INTERFACES ////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

	interface TxMsgChannel#(type req_typ);
		(* always_ready *) method Bool txFull();
		(* always_ready, result="tx" *) method Action tx((* port= "msg" *) req_typ m); // removed always ready
	endinterface

	interface RxMsgChannel#(type rsp_typ);
		(* always_ready *) method Bool rxEmpty();
		(* always_ready *) method Action rxPop(); // removed always_ready
		(* always_ready, result="rx_msg" *) method rsp_typ rx(); // removed always_ready
	endinterface

	interface ClientTxMsgChannel#(type req_typ);
		(* always_ready, always_enabled, prefix="" *) 
		method Action txFull((* port= "txFull" *) Bool b);
		(* always_ready, result="tx_msg" *) 
		method req_typ tx_msg(); 
		(* always_ready, always_enabled, result="tx" *) 
		method Bool tx(); 
	endinterface

	interface ClientRxMsgChannel#(type rsp_typ);
		(* always_ready, always_enabled, prefix="" *) 
		method Action rxEmpty((* port= "rxEmpty" *) Bool b);
		(* always_ready, always_enabled *) 
		method Bool rxPop(); 
		(* always_ready, always_enabled, result="rx" *) 
		method Action rx((* port= "msg" *) rsp_typ m);
	endinterface

	interface TxRxMsgChannel#(type req_typ, type rsp_typ);
		(* prefix="" *) 
		interface TxMsgChannel#(req_typ) txPort;
		(* prefix="" *) 
		interface RxMsgChannel#(rsp_typ) rxPort;
	endinterface

    interface TxMsgChannelMux#(numeric type n_tx, type req_typ);
		(* prefix="" *) 
		interface Vector#(n_tx,TxMsgChannel#(req_typ)) txPort;
	endinterface

    interface RxMsgChannelDemux#(numeric type n_rx, type rsp_typ);
		(* prefix="" *) 
		interface Vector#(n_rx,RxMsgChannel#(rsp_typ)) rxPort;
	endinterface

	interface Client#(type req_typ, type rsp_typ, numeric type threshold);
		(* prefix="" *) 
		interface RxMsgChannel#(req_typ) txPort;
		(* prefix="" *) 
		interface TxMsgChannel#(rsp_typ) rxPort;
	endinterface 

	interface ClientExternal#(type req_typ, type rsp_typ, numeric type threshold);
		(* prefix="" *) 
		interface ClientTxMsgChannel#(req_typ) txPort;
		(* prefix="" *) 
		interface ClientRxMsgChannel#(rsp_typ) rxPort;
	endinterface 

	interface Server#(type req_typ, type rsp_typ, numeric type threshold);
		(* prefix="" *) 
		interface TxMsgChannel#(req_typ) txPort;
		(* prefix="" *) 
		interface RxMsgChannel#(rsp_typ) rxPort;
	endinterface

	interface Server2#(type req_typ, type rsp_typ, numeric type threshold);
		(* prefix="" *) 
		interface Server#(req_typ,rsp_typ,threshold) serverA;
		(* prefix="" *) 
		interface Server#(req_typ,rsp_typ,threshold) serverB;
	endinterface

	//interface Server2#(type req_typ, type rsp_typ, numeric type threshold);
	//	(* prefix="" *) 
	//	interface TxMsgChannel#(req_typ) txPortA;
	//	(* prefix="" *) 
	//	interface RxMsgChannel#(rsp_typ) rxPortA;
	//	(* prefix="" *) 
	//	interface TxMsgChannel#(req_typ) txPortB;
	//	(* prefix="" *) 
	//	interface RxMsgChannel#(rsp_typ) rxPortB;
	//endinterface

	interface MsgChannel#(type req_typ, type rsp_typ, numeric type threshold);
		//(* prefix="" *) 
		interface Server#(req_typ,rsp_typ,threshold) server;
		//(* prefix="" *) 
		interface Client#(req_typ,rsp_typ,threshold) client;
	endinterface

	interface MsgChannelExternal#(type req_typ, type rsp_typ, numeric type threshold);
		//(* prefix="" *) 
		interface Server#(req_typ,rsp_typ,threshold) server;
		//(* prefix="" *) 
		interface ClientExternal#(req_typ,rsp_typ,threshold) client;
	endinterface

	interface Stats#(numeric type nBits);
		(* always_ready *) method Bit#(nBits) sum_intarr_time();
		(* always_ready *) method Bit#(nBits) cnt_intarr_time();
		(* always_ready *) method Bit#(nBits) min_intarr_time();
		(* always_ready *) method Bit#(nBits) max_intarr_time();
		(* always_ready *) method Bit#(nBits) sum_queue_depth();
		(* always_ready *) method Bit#(nBits) cnt_queue_depth();
		(* always_ready *) method Bit#(nBits) min_queue_depth();
		(* always_ready *) method Bit#(nBits) max_queue_depth();
		(* always_ready *) method Bit#(nBits) sum_req_delay();
		(* always_ready *) method Bit#(nBits) cnt_req_delay();
		(* always_ready *) method Bit#(nBits) min_req_delay();
		(* always_ready *) method Bit#(nBits) max_req_delay();
		(* always_ready *) method Action clear();
		(* always_ready *) method Action start();
		(* always_ready *) method Action stop();
	endinterface	

	interface ServerStats#(type req_typ, type rsp_typ, numeric type threshold);
		(* prefix="" *) 
		interface TxMsgChannel#(req_typ) txPort;
		(* prefix="" *) 
		interface RxMsgChannel#(rsp_typ) rxPort;
		(* prefix="" *) 
		interface Stats#(32) debug;
	endinterface

///////////////////////////////////////////////////////////////////////////////
////////////////////////////// ROUTING ////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

instance Connectable#(RxMsgChannel#(r),TxMsgChannel#(r));
    module mkConnection#(RxMsgChannel#(r) in, TxMsgChannel#(r) out)(Empty);
    	rule connect(!in.rxEmpty&&!out.txFull);
			let v = in.rx;
			in.rxPop;
			out.tx(v);
    	endrule
    endmodule
endinstance

instance Connectable#(Client#(rq,rs,th),Server#(rq,rs,th));
    module mkConnection#(Client#(rq,rs,th) in, Server#(rq,rs,th) out)(Empty);
    	rule connect_req(!in.txPort.rxEmpty&&!out.txPort.txFull);
			let v = in.txPort.rx;
			in.txPort.rxPop;
			out.txPort.tx(v);
    	endrule
    	rule connect_rsp(!out.rxPort.rxEmpty&&!in.rxPort.txFull);
			let v = out.rxPort.rx;
			out.rxPort.rxPop;
			in.rxPort.tx(v);
    	endrule
    endmodule
endinstance
instance Connectable#(Server#(rq,rs,th),Client#(rq,rs,th));
    module mkConnection#(Server#(rq,rs,th) in, Client#(rq,rs,th) out)(Empty);
    	rule connect_rsp(!in.rxPort.rxEmpty&&!out.rxPort.txFull);
			let v = in.rxPort.rx;
			in.rxPort.rxPop;
			out.rxPort.tx(v);
    	endrule
    	rule connect_req(!out.txPort.rxEmpty&&!in.txPort.txFull);
			let v = out.txPort.rx;
			out.txPort.rxPop;
			in.txPort.tx(v);
    	endrule
    endmodule
endinstance

module mkMsgChannelExternal(MsgChannelExternal#(req_typ,rsp_typ,threshold))
		    provisos(Bits#(req_typ, a_),
                             Bits#(rsp_typ, b_));

		FIFOF#(req_typ) reqF <- mkUGFIFOF();
		FIFOF#(rsp_typ) rspF <- mkUGFIFOF();

	Wire#(Bool) reqSent <- mkDWire(False);
	Wire#(Bool) rspRecv <- mkDWire(False);

    interface Server server;
	    interface TxMsgChannel txPort;
	    method Bool txFull();
	      return !reqF.notFull;
	    endmethod
	    method Action tx(req_typ r);
	      reqF.enq(r);    
	    endmethod
	    endinterface

	    interface RxMsgChannel rxPort;
	    method Bool rxEmpty();
	      return !rspF.notEmpty;
	    endmethod
	    method Action rxPop();
	      rspF.deq;
	    endmethod
	    method rsp_typ rx();
	      return rspF.first;
	    endmethod
	    endinterface
    endinterface

    interface ClientExternal client;
	    interface ClientTxMsgChannel txPort;
		method Action txFull( Bool b);
	      	if (!b && reqF.notEmpty()) begin
				reqF.deq();
			end
			reqSent <= !b;
	    endmethod
	    method req_typ tx_msg();
	      	return reqF.first();    
	    endmethod
	    method Bool tx();
	      	return reqF.notEmpty() && reqSent;    
	    endmethod
	    endinterface

	    interface ClientRxMsgChannel rxPort;
		method Action rxEmpty(Bool b);
			rspRecv <= !b && rspF.notFull;
	    endmethod
	    method Bool rxPop();
	      	return rspRecv;
	    endmethod
	    method Action rx(rsp_typ m);
	      	if (rspRecv) begin
	      		rspF.enq(m);
	      	end
	    endmethod
	    endinterface
    endinterface
endmodule
module mkMsgChannel(MsgChannel#(req_typ,rsp_typ,threshold))
		    provisos(Bits#(req_typ, a_),
                             Bits#(rsp_typ, b_));

	Integer vt = valueOf(threshold);
		FIFOF#(req_typ) reqF <- mkUGFIFOF();
		FIFOF#(rsp_typ) rspF <- mkUGFIFOF();

    interface Server server;
	    interface TxMsgChannel txPort;
	    method Bool txFull();
	      return !reqF.notFull;
	    endmethod
	    method Action tx(req_typ r);
	      reqF.enq(r);    
	    endmethod
	    endinterface

	    interface RxMsgChannel rxPort;
	    method Bool rxEmpty();
	      return !rspF.notEmpty;
	    endmethod
	    method Action rxPop();
	      rspF.deq;
	    endmethod
	    method rsp_typ rx();
	      return rspF.first;
	    endmethod
	    endinterface
    endinterface

    interface Client client;
	    interface RxMsgChannel txPort;
	    method Bool rxEmpty();
	      return !reqF.notEmpty;
	    endmethod
	    method Action rxPop();
	      reqF.deq;
	    endmethod
	    method req_typ rx();
	      return reqF.first;
	    endmethod
	    endinterface

	    interface TxMsgChannel rxPort;
	    method Bool txFull();
	      return !rspF.notFull;
	    endmethod
	    method Action tx(rsp_typ r);
	      rspF.enq(r);    
	    endmethod
	    endinterface
    endinterface

	//interface server = srv;
	//interface client = cli;
endmodule

module mkTxMux#(Bool fair_arb, TxMsgChannel#(req_typ) txOut) 
										(TxMsgChannelMux#(n_tx,req_typ))
						provisos(Bits#(req_typ, a_));

	Integer vthresh = 4;

        Vector#(n_tx,FIFOF#(req_typ))  inF <- replicateM(mkUGSizedFIFOF(vthresh));

	Vector#(n_tx,TxMsgChannel#(req_typ)) tx_loc;

  	for(Integer i=0; i < valueOf(n_tx); i=i+1) begin
  		let r_ifc = interface TxMsgChannel#(req_typ);
	  		method Action tx(req_typ a);
	  			inF[i].enq(a);
	  		endmethod
	  		method Bool txFull();
	  			return (!inF[i].notFull)||(txOut.txFull);
	  		endmethod
  		endinterface;
  		tx_loc[i] = r_ifc;
  	end

  	Arbiter#(n_tx) tx_arb;
	if (fair_arb) begin
		tx_arb <- mkRoundRobinArbiter();
	end else begin
		tx_arb <- mkStaticPriorityArbiterStartAt(0);
	end

	(* fire_when_enabled *)
  	rule drain_in_fifo(!txOut.txFull);
  		Vector#(n_tx, Bool) txFifoReq = unpack(0);
  		for(Integer i=0; i < valueOf(n_tx); i=i+1) begin
  			txFifoReq[i] = inF[i].notEmpty();
  		end
  		Vector#(n_tx, Bool) txFifoGrant = unpack(0);
  		txFifoGrant <- tx_arb.select(txFifoReq);
  		for(Integer i=0; i < valueOf(n_tx); i=i+1) begin
  			if (txFifoGrant[i]) begin
  				txOut.tx(inF[i].first());
  				inF[i].deq();
  			end
  		end	
  	endrule

    interface txPort = tx_loc;

endmodule
module mkTxMuxAuto#(Bool fair_arb, TxMsgChannel#(AM_FULL#(sdarg,data)) txOut) 
										(TxMsgChannelMux#(n_tx,AM_FULL#(sdarg,data)))
							provisos(Bits#(sdarg,a_),
									 Bits#(data,c_),
								         Log#(n_tx,nt_),
								         Add#(n__,nt_,a_),
									 Literal#(sdarg),
									 Literal#(data));

	Integer vthresh = 4;

        Vector#(n_tx,FIFOF#(AM_FULL#(sdarg,data)))  inF <- replicateM(mkUGSizedFIFOF(vthresh));

	Vector#(n_tx,TxMsgChannel#(AM_FULL#(sdarg,data))) tx_loc;

  	for(Integer i=0; i < valueOf(n_tx); i=i+1) begin
  		let r_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data));
	  		method Action tx(AM_FULL#(sdarg,data) a);
	  			inF[i].enq(a);
	  		endmethod
	  		method Bool txFull();
	  			//return (inF[i].isGreaterThan(2))||(txOut.txFull);
	  			return (!inF[i].notFull)||(txOut.txFull);
	  		endmethod
  		endinterface;
  		tx_loc[i] = r_ifc;
  	end

  	Arbiter#(n_tx) tx_arb;
	if (fair_arb) begin
		tx_arb <- mkRoundRobinArbiter();
	end else begin
		tx_arb <- mkStaticPriorityArbiterStartAt(0);
	end

	(* fire_when_enabled *)
  	rule drain_in_fifo(!txOut.txFull);
  		Vector#(n_tx, Bool) txFifoReq = unpack(0);
  		for(Integer i=0; i < valueOf(n_tx); i=i+1) begin
  			txFifoReq[i] = inF[i].notEmpty();
  		end
  		Vector#(n_tx, Bool) txFifoGrant = unpack(0);
  		txFifoGrant <- tx_arb.select(txFifoReq);
  		for(Integer i=0; i < valueOf(n_tx); i=i+1) begin
  			if (txFifoGrant[i]) begin
				Bit#(nt_) chan = fromInteger(i);
				AM_FULL#(sdarg,data) tx_msg = inF[i].first();
				tx_msg.head.srcid = unpack(extend(chan));
  				txOut.tx(tx_msg);
  				inF[i].deq();
  			end
  		end	
  	endrule

    interface txPort = tx_loc;

endmodule

module mkRxDemux#(Bool fair_arb, RxMsgChannel#(AM_FULL#(sdarg,data)) rxIn) 
										(RxMsgChannelDemux#(n_rx,AM_FULL#(sdarg,data)))
							provisos(Bits#(sdarg,a_),
									 Bits#(data,c_),
									 Eq#(sdarg),
									 Literal#(sdarg),
									 Literal#(data));

	Integer vthresh = 4;

	Vector#(n_rx,FIFOF#(AM_FULL#(sdarg,data)))  outF <- replicateM(mkUGSizedFIFOF(vthresh));
    //Vector#(n_rx,FIFOF#(AM_FULL#(sdarg,data)))  outF <- replicateM(mkSizedBypassFIFOF(vthresh));

	Vector#(n_rx,RxMsgChannel#(AM_FULL#(sdarg,data))) rx_loc;

  	for(Integer i=0; i < valueOf(n_rx); i=i+1) begin
  		let r_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data));
	  		method AM_FULL#(sdarg,data) rx();
	  			return outF[i].first();
	  		endmethod
	  		method Bool rxEmpty();
	  			return !(outF[i].notEmpty());
	  		endmethod
	  		method Action rxPop();
	  			outF[i].deq();
	  		endmethod
  		endinterface;
  		rx_loc[i] = r_ifc;
  	end

  	/*Arbiter#(n_tx) tx_arb;
	if (fair_arb) begin
		tx_arb <- mkRoundRobinArbiter();
	end else begin
		tx_arb <- mkStaticPriorityArbiterStartAt(0);
	end*/

	(* fire_when_enabled *)
  	rule drain_in_fifo(!rxIn.rxEmpty);
  		for(Integer i=0; i < valueOf(n_rx); i=i+1) begin
 			let recv = rxIn.rx();
  			if (recv.head.dstid == fromInteger(i)) begin
  				outF[i].enq(recv);
  				rxIn.rxPop();
  			end
  		end	
  	endrule

	interface rxPort = rx_loc;

endmodule

///////////////////////////////////////////////////////////////////////////////
/////////////////////////// WRAPPER / SHELL ///////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

module mkReadServer#(RdChannel#(addr,marg,data,thresh,n_out_mem) rdC, addr offset)
										(Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
							provisos(Bits#(marg,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 Bits#(sdarg,d_),
									 Arith#(sdarg),
									 //Add#(a__, d_, b_),
									 Add#(a__, d_, b_),
									 Log#(threshold, a_),
									 PrimIndex#(marg,g_));
									 //Literal#(data));
	Bool order = True;

	CBuffer#(AM_HEAD#(sdarg),AM_DATA#(data),marg,2,threshold) cBuf; 
	if (order) begin
		cBuf <- mkCompletionBufferBypass;
	end else begin
		cBuf <- mkCompletionBufferU;
	end

	rule get_response(!rdC.rxEmpty);
		marg md = rdC.rxMarg();
		data dd = rdC.rxData();
		let ad = AM_DATA { payload: dd };
		cBuf.complete(md,ad);
		rdC.rxPop();
		//$display("RD Server Recv.");
	endrule

    let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data));
		method Bool txFull();
			return !cBuf.canReserve() || rdC.txFull();
		endmethod
		method Action tx(AM_FULL#(sdarg,data) r);
			addr a = unpack(extend(pack(r.head.arg1))+pack(offset));
			//addr a = unpack(truncate(pack(r.head.arg1+offset)));
			let tg <- cBuf.reserve(r.head);
			rdC.tx(a,tg);
		endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data));
		method Bool rxEmpty();
			return !cBuf.notEmpty();
		endmethod
		method Action rxPop();
			cBuf.deq();
		endmethod
		method AM_FULL#(sdarg,data) rx();
                    let hd = cBuf.firstMeta;
                    sdarg srcid = hd.srcid;
                    hd.srcid = hd.dstid;
                    hd.dstid = srcid;
		    let rsp = AM_FULL { head: hd, data: cBuf.firstData };
			return rsp;
		endmethod
    endinterface;

	interface txPort = tx_ifc;
	interface rxPort = rx_ifc;

endmodule

module mkReadServerStats#(RdChannel#(addr,marg,data,thresh,n_out_mem) rdC, addr offset)
										(ServerStats#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
							provisos(Bits#(marg,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 Bits#(sdarg,d_),
									 Arith#(sdarg),
									 //Add#(a__, d_, b_),
									 Add#(a__, d_, b_),
									 Log#(threshold, a_),
									 Add#(TLog#(threshold), b__, 31),
									 PrimIndex#(marg,g_));
									 //Literal#(data));
	Bool order = True;

	Reg#(Bool) started <- mkReg(False);
	PulseWire increment_called <- mkPulseWire();
    PulseWire decrement_called <- mkPulseWire();
	SAMPLER#(32,8,3) intarr <- mkSampler();
	SAMPLER#(32,8,3) qdepth <- mkSampler();
	SAMPLER#(32,8,3) delay <- mkSampler();
	CompletionDelay#(32,marg,threshold) cd <- mkCompletionDelay;
	InterarrivalTime#(32) it <- mkInterarrivalTime;

	CBuffer#(AM_HEAD#(sdarg),AM_DATA#(data),marg,2,threshold) cBuf; 
	if (order) begin
		cBuf <- mkCompletionBufferBypass;
	end else begin
		cBuf <- mkCompletionBufferU;
	end

	rule sample(started);
		qdepth.addSample(extend(pack(cBuf.count)));
	endrule

	rule get_response(!rdC.rxEmpty);
		marg md = rdC.rxMarg();
		data dd = rdC.rxData();
		let ad = AM_DATA { payload: dd };
		cBuf.complete(md,ad);
		let dy <- cd.stop(md);
		delay.addSample(dy);
		rdC.rxPop();
		//$display("RD Server Recv.");
	endrule

    let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data));
		method Bool txFull();
			return !cBuf.canReserve() || rdC.txFull();
		endmethod
		method Action tx(AM_FULL#(sdarg,data) r);
			addr a = unpack(extend(pack(r.head.arg1))+pack(offset));
			//addr a = unpack(truncate(pack(r.head.arg1+offset)));
			let tg <- cBuf.reserve(r.head);
			cd.start(tg);
			let ar <- it.arrival;
			intarr.addSample(ar);
			rdC.tx(a,tg);
		endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data));
		method Bool rxEmpty();
			return !cBuf.notEmpty();
		endmethod
		method Action rxPop();
			cBuf.deq();
		endmethod
		method AM_FULL#(sdarg,data) rx();
                    let hd = cBuf.firstMeta;
                    sdarg srcid = hd.srcid;
                    hd.srcid = hd.dstid;
                    hd.dstid = srcid;
		    let rsp = AM_FULL { head: hd, data: cBuf.firstData };
			return rsp;
		endmethod
    endinterface;

    rule do_increment(increment_called && !decrement_called);
    	started <= True;
	endrule
	rule do_decrement(!increment_called && decrement_called);
    	started <= False;
	endrule

    let db_ifc = interface Stats#(32);
		method Bit#(32) sum_intarr_time();
			return intarr.total;
		endmethod
		method Bit#(32) cnt_intarr_time();
			return intarr.samples;
		endmethod
		method Bit#(32) min_intarr_time();
			return intarr.min;
		endmethod
		method Bit#(32) max_intarr_time();
			return intarr.max;
		endmethod
		method Bit#(32) sum_queue_depth();
			return qdepth.total;
		endmethod
		method Bit#(32) cnt_queue_depth();
			return qdepth.samples;
		endmethod
		method Bit#(32) min_queue_depth();
			return qdepth.min;
		endmethod
		method Bit#(32) max_queue_depth();
			return qdepth.max;
		endmethod
		method Bit#(32) sum_req_delay();
			return delay.total;
		endmethod
		method Bit#(32) cnt_req_delay();
			return delay.samples;
		endmethod
		method Bit#(32) min_req_delay();
			return delay.min;
		endmethod
		method Bit#(32) max_req_delay();
			return delay.max;
		endmethod
		method Action clear();
			//intarr.clear;
			//qdepth.clear;
			//delay.clear;
		endmethod
		method Action start();
			increment_called.send();
		endmethod
		method Action stop();
			decrement_called.send();
		endmethod
    endinterface;

	interface txPort = tx_ifc;
	interface rxPort = rx_ifc;
	interface debug  = db_ifc;

endmodule

module mkReadServerEffect#(RdChannel#(addr,marg,data,thresh,n_out_mem) rdC, addr offset)
										(Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
							provisos(Bits#(marg,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 Bits#(sdarg,d_),
									 Arith#(sdarg),
									 //Add#(a__, d_, b_),
									 Add#(a__, d_, b_),
									 Log#(threshold, e_),
									 Add#(b__, e_, a_),
									 Add#(threshold, 2, nth),
									 PrimIndex#(marg,g_));
									 //Literal#(data));

	Integer vthresh = valueOf(threshold);
	
	//FIFOLevelIfc#(AM_FULL#(sdarg,data),threshold) inF <- mkGFIFOLevel(True,True,True);
	FIFOF#(AM_FULL#(sdarg,data))  inF <- mkUGSizedFIFOF(vthresh);	

	FIFOF#(AM_FULL#(sdarg,data))  outF <- mkUGSizedFIFOF(vthresh+2);	

	Reg#(Bool)    flag[2] <- mkCReg(2,False);
	Reg#(Bool)    lock[2] <- mkCReg(2,False);
	Reg#(AM_HEAD#(sdarg))	  outHead[2] <- mkCReg(2,?);

	rule get_response(!rdC.rxEmpty&&flag[0]);
		data dd = rdC.rxData();
		let ad = AM_DATA { payload: dd };
		let rsp = AM_FULL { head: outHead[0], data: ad };
		outF.enq(rsp);
		rdC.rxPop();
		flag[0] <= False;
		//$display("RD Server Effect Resp.");
	endrule

	rule put_request(!rdC.txFull&&!flag[1]&&inF.notEmpty);	
		let req = inF.first();
		inF.deq();
		outHead[1] <= req.head;
		addr a = unpack(extend(pack(req.head.arg1))+pack(offset));
		rdC.tx(a,5);
		flag[1] <= True;
		//$display("RD Server Effect Req.");
	endrule

    let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data));
		method Bool txFull();
			//return inF.isGreaterThan(valueOf(threshold)) || rdC.txFull();
			return !inF.notFull() || rdC.txFull() || lock[0];
		endmethod
		method Action tx(AM_FULL#(sdarg,data) r);
			//$display("RD Server Effect Tx.");
			inF.enq(r);
			lock[0] <= True;
		endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data));
		method Bool rxEmpty();
			return !outF.notEmpty();
		endmethod
		method Action rxPop();
			//$display("RD Server Effect Rx.");
			lock[1] <= False;
			outF.deq();
		endmethod
		method AM_FULL#(sdarg,data) rx();
                    let hd = outF.first.head;
                    sdarg srcid = hd.srcid;
                    hd.srcid = hd.dstid;
                    hd.dstid = srcid;
		    let rsp = AM_FULL { head: hd, data: outF.first.data };
			return rsp;
		endmethod
    endinterface;

	interface txPort = tx_ifc;
	interface rxPort = rx_ifc;

endmodule

module mkWriteServer#(WrChannel#(addr,marg,data,thresh,n_out_mem) wrC, addr offset)
										(Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
							provisos(Bits#(marg,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 Bits#(sdarg,d_),
									 Arith#(sdarg),
									 //Add#(a__, d_, b_),
									 Add#(a__, d_, b_),
									 Log#(threshold, a_),
									 PrimIndex#(marg,g_));
									 //Literal#(data));
	Bool order = True;

	CBuffer#(AM_HEAD#(sdarg),AM_DATA#(data),marg,2,threshold) cBuf; 
	if (order) begin
		cBuf <- mkCompletionBufferBypass;
	end else begin
		cBuf <- mkCompletionBufferU;
	end

	rule get_response(!wrC.rxEmpty);
		marg md = wrC.rxMarg();
		//let dd = AM_DATA { payload: ? };
		cBuf.complete(md,?);
		wrC.rxPop();
		//$display("WR Server Recv.");
	endrule

    let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data));
		method Bool txFull();
			return !cBuf.canReserve() || wrC.txFull();
		endmethod
		method Action tx(AM_FULL#(sdarg,data) w);
			//addr a = unpack(truncate(pack(w.head.arg1+offset)));
			addr a = unpack(extend(pack(w.head.arg1))+pack(offset));
			let tg <- cBuf.reserve(w.head);
			//$display("WR Server Wr Sent %d",w.head.arg1);
			wrC.tx(a,tg,w.data.payload);
		endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data));
		method Bool rxEmpty();
			return !cBuf.notEmpty();
		endmethod
		method Action rxPop();
			cBuf.deq();
		endmethod
		method AM_FULL#(sdarg,data) rx();
                    let hd = cBuf.firstMeta;
                    sdarg srcid = hd.srcid;
                    hd.srcid = hd.dstid;
                    hd.dstid = srcid;
		    let rsp = AM_FULL { head: hd, data: cBuf.firstData };
			return rsp;
		endmethod
    endinterface;

	interface txPort = tx_ifc;
	interface rxPort = rx_ifc;

endmodule

module mkWriteServerStats#(WrChannel#(addr,marg,data,thresh,n_out_mem) wrC, addr offset)
										(ServerStats#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
							provisos(Bits#(marg,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 Bits#(sdarg,d_),
									 Arith#(sdarg),
									 //Add#(a__, d_, b_),
									 Add#(a__, d_, b_),
									 Log#(threshold, a_),
									 Add#(TLog#(threshold), b__, 31),
									 PrimIndex#(marg,g_));
									 //Literal#(data));
	Bool order = True;

	Reg#(Bool) started <- mkReg(False);
	PulseWire increment_called <- mkPulseWire();
    PulseWire decrement_called <- mkPulseWire();
	SAMPLER#(32,8,3) intarr <- mkSampler();
	SAMPLER#(32,8,3) qdepth <- mkSampler();
	SAMPLER#(32,8,3) delay <- mkSampler();
	CompletionDelay#(32,marg,threshold) cd <- mkCompletionDelay;
	InterarrivalTime#(32) it <- mkInterarrivalTime;

	CBuffer#(AM_HEAD#(sdarg),AM_DATA#(data),marg,2,threshold) cBuf; 
	if (order) begin
		cBuf <- mkCompletionBufferBypass;
	end else begin
		cBuf <- mkCompletionBufferU;
	end

	rule sample(started);
		qdepth.addSample(extend(pack(cBuf.count)));
	endrule

	rule get_response(!wrC.rxEmpty);
		marg md = wrC.rxMarg();
		//let dd = AM_DATA { payload: ? };
		cBuf.complete(md,?);
		let dy <- cd.stop(md);
		delay.addSample(dy);
		wrC.rxPop();
		//$display("WR Server Recv.");
	endrule

    let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data));
		method Bool txFull();
			return !cBuf.canReserve() || wrC.txFull();
		endmethod
		method Action tx(AM_FULL#(sdarg,data) w);
			//addr a = unpack(truncate(pack(w.head.arg1+offset)));
			addr a = unpack(extend(pack(w.head.arg1))+pack(offset));
			let tg <- cBuf.reserve(w.head);
			cd.start(tg);
			let ar <- it.arrival;
			intarr.addSample(ar);
			//$display("WR Server Wr Sent %d",w.head.arg1);
			wrC.tx(a,tg,w.data.payload);
		endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data));
		method Bool rxEmpty();
			return !cBuf.notEmpty();
		endmethod
		method Action rxPop();
			cBuf.deq();
		endmethod
		method AM_FULL#(sdarg,data) rx();
                    let hd = cBuf.firstMeta;
                    sdarg srcid = hd.srcid;
                    hd.srcid = hd.dstid;
                    hd.dstid = srcid;
		    let rsp = AM_FULL { head: hd, data: cBuf.firstData };
			return rsp;
		endmethod
    endinterface;

    rule do_increment(increment_called && !decrement_called);
    	started <= True;
	endrule
	rule do_decrement(!increment_called && decrement_called);
    	started <= False;
	endrule

    let db_ifc = interface Stats#(32);
		method Bit#(32) sum_intarr_time();
			return intarr.total;
		endmethod
		method Bit#(32) cnt_intarr_time();
			return intarr.samples;
		endmethod
		method Bit#(32) min_intarr_time();
			return intarr.min;
		endmethod
		method Bit#(32) max_intarr_time();
			return intarr.max;
		endmethod
		method Bit#(32) sum_queue_depth();
			return qdepth.total;
		endmethod
		method Bit#(32) cnt_queue_depth();
			return qdepth.samples;
		endmethod
		method Bit#(32) min_queue_depth();
			return qdepth.min;
		endmethod
		method Bit#(32) max_queue_depth();
			return qdepth.max;
		endmethod
		method Bit#(32) sum_req_delay();
			return delay.total;
		endmethod
		method Bit#(32) cnt_req_delay();
			return delay.samples;
		endmethod
		method Bit#(32) min_req_delay();
			return delay.min;
		endmethod
		method Bit#(32) max_req_delay();
			return delay.max;
		endmethod
		method Action clear();
			//intarr.clear;
			//qdepth.clear;
			//delay.clear;
		endmethod
		method Action start();
			increment_called.send();
		endmethod
		method Action stop();
			decrement_called.send();
		endmethod
    endinterface;

	interface txPort = tx_ifc;
	interface rxPort = rx_ifc;
	interface debug  = db_ifc;

endmodule

module mkWriteServerEffect#(WrChannel#(addr,marg,data,thresh,n_out_mem) wrC, addr offset)
										(Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
							provisos(Bits#(marg,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 Bits#(sdarg,d_),
									 Arith#(sdarg),
									 //Add#(a__, d_, b_),
									 Add#(a__, d_, b_),
									 Log#(threshold, e_),
									 Add#(b__, e_, a_),
									 Add#(threshold, 2, nth),
									 PrimIndex#(marg,g_));
									 //Literal#(data));

	Integer vthresh = valueOf(threshold);
	
	//FIFOLevelIfc#(AM_FULL#(sdarg,data),threshold) inF <- mkGFIFOLevel(True,True,True);
	FIFOF#(AM_FULL#(sdarg,data))  inF <- mkUGSizedFIFOF(vthresh);

	FIFOF#(AM_FULL#(sdarg,data))  outF <- mkUGSizedFIFOF(vthresh+2);	

	Reg#(Bool)    flag[2] <- mkCReg(2,False);
	Reg#(Bool)    lock[2] <- mkCReg(2,False);
	Reg#(AM_HEAD#(sdarg))	  outHead[2] <- mkCReg(2,?);

	rule get_response(!wrC.rxEmpty&&flag[0]);
		let rsp = AM_FULL { head: outHead[0], data: ? };
		outF.enq(rsp);
		wrC.rxPop();
		flag[0] <= False;
		//$display("WR Server Effect Resp.");
	endrule

	rule put_request(!wrC.txFull&&!flag[1]&&inF.notEmpty);	
		let req = inF.first();
		inF.deq();
		outHead[1] <= req.head;
		addr a = unpack(extend(pack(req.head.arg1))+pack(offset));
		wrC.tx(a,5,req.data.payload);
		//$display("WR Server Effect Req.");
		flag[1] <= True;
	endrule

    let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data));
		method Bool txFull();
			//return inF.isGreaterThan(valueOf(threshold)) || wrC.txFull();
			return !inF.notFull() || wrC.txFull() || lock[0];
		endmethod
		method Action tx(AM_FULL#(sdarg,data) r);
			//$display("WR Server Effect Tx.");
			inF.enq(r);
			lock[0] <= True;
		endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data));
		method Bool rxEmpty();
			return !outF.notEmpty();
		endmethod
		method Action rxPop();
			//$display("WR Server Effect Rx.");
			outF.deq();
			lock[1] <= False;
		endmethod
		method AM_FULL#(sdarg,data) rx();
                    let hd = outF.first.head;
                    sdarg srcid = hd.srcid;
                    hd.srcid = hd.dstid;
                    hd.dstid = srcid;
		    let rsp = AM_FULL { head: hd, data: outF.first.data };
			return rsp;
		endmethod
    endinterface;

	interface txPort = tx_ifc;
	interface rxPort = rx_ifc;

endmodule

endpackage
