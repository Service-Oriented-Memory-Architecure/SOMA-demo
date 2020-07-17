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
// Service module providing an elastic queue for the worklist service.
// Work items are packed into memory interface granularity lines and 
// spilled to memory. This service prefetches memory buffered lines.
// The service consumer pushes and pops work items as if this is an 
// entirely on-chip latency insensitive FIFO.
//

package Worklist;

import MessagePack::*;
import FIFO::*;
import FIFOF::*;
import FIFOFA::*;
import SpecialFIFOs::*;
import Vector::*;
import CBuffer::*;
import Scoreboard::*;

interface Worklist;//#(type work, numeric type n_in);
        interface Server#(AM_FULL#(Bit#(32),Bit#(32)),AM_FULL#(Bit#(32),Bit#(32)),32) workQ; 
	(* always_ready, always_enabled, prefix="" *) 
	method Action start((* port= "start" *) Bool s);
	(* always_ready, always_enabled, prefix="" *) 
	method Action setCapacity((* port= "setCapacity" *) Bit#(32) c);
endinterface

module mkWorklist#(Server#(AM_FULL#(Bit#(32),data),AM_FULL#(Bit#(32),data),n_out_r) listRd, Server#(AM_FULL#(Bit#(32),data),AM_FULL#(Bit#(32),data),n_out_w) listWr) 
						(Worklist)
						//(Worklist#(work,n_in))
						//(Server#(AM_FULL#(Bit#(32),work),AM_FULL#(Bit#(32),work),n_in))
							provisos(Bits#(Bit#(32),a_),
									 Bits#(data,512),
									 //Bits#(work,32),
									 //Literal#(Bit#(32)),
									 Literal#(data),
									 //Literal#(work),
									 //Arith#(Bit#(32)),
									 //Eq#(Bit#(32)),
									 //Ord#(Bit#(32)),
									 Add#(a__,a_,32));


    FIFOF#(AM_FULL#(Bit#(32),Bit#(32)))  inF  <- mkSizedFIFOF(4); 
    FIFOF#(AM_FULL#(Bit#(32),Bit#(32)))  outF <- mkSizedFIFOF(256); 

    Reg#(Bit#(32)) capacity <- mkReg(16384);
    Reg#(Bool) start_in <- mkReg(False);
    Reg#(Bool) started <- mkReg(False);
    rule starter;
      if (start_in) begin
        started <= True;
      end 
    endrule 

	Reg#(Bit#(32)) nextTxIdx <- mkReg(1); //This needs to connect better to first stage.
	Reg#(Bit#(32)) nextIdx[2] <- mkCReg(2,0);
	Reg#(Bit#(32)) howmany <- mkReg(1);
	PulseWire increment_called <- mkPulseWire();
    PulseWire decrement_called <- mkPulseWire();
	Reg#(Bit#(32)) howmany_w <- mkReg(1);
	PulseWire increment_calledW <- mkPulseWire();
    PulseWire decrement_calledW <- mkPulseWire();

    Reg#(Bit#(32)) numworks[2] <- mkCReg(2,0);
	Reg#(Vector#(15,Bit#(32))) works[2] <- mkCReg(2,Vector::replicate(0));
	Reg#(Bool) done[3] <- mkCReg(3,True);

	rule do_increment(increment_called && !decrement_called);
    	howmany <= howmany + 1;
	endrule
	rule do_decrement(!increment_called && decrement_called);
    	howmany <= howmany - 1;
	endrule
	rule do_incrementW(increment_calledW && !decrement_calledW);
    	howmany_w <= howmany_w + 1;
	endrule
	rule do_decrementW(!increment_calledW && decrement_calledW);
    	howmany_w <= howmany_w - 1;
	endrule

	(* fire_when_enabled *)
	rule req_work if ((!listRd.txPort.txFull)&&started&&(howmany>0));
			$display("Stage 0: request work: %0d howmany %d",nextIdx[0],howmany);
		//nextIdx <= nextIdx + 1;
		if (nextIdx[0]==nextTxIdx) $display("ERROR nextIdx == nextTxIdx");
		if (0==howmany) $display("ERROR howmany < 1");
		nextIdx[0] <= ((nextIdx[0]+1)>=capacity) ? 0 : nextIdx[0] + 1;
		let hd = AM_HEAD { srcid:0 , dstid:1 , arg0:? , arg1:nextIdx[0]
											 , arg2:? , arg3:? }; //arg0=? arg1=addr
		let req = AM_FULL { head: hd, data: ? };
		listRd.txPort.tx(req);
			decrement_called.send();
			decrement_calledW.send();
		//decrement_called.send(); // FIXME?? maybe this is when it comes back
	endrule

	/////////////////////////////////////////////////////////////////////////

	rule consume_bundle if (done[1]&&(!listRd.rxPort.rxEmpty));
			Vector#(16,Bit#(32)) temp = toChunks(pack(listRd.rxPort.rx.data.payload));
			$display("Worklist: recv numworks %d",temp[15]);
			works[1] <= takeAt(0,temp);
			numworks[1] <= temp[15];
			listRd.rxPort.rxPop;
			if (temp[15] != 0) begin
				done[1]<=False;
			end
	endrule

	rule work_sendoff if ((!done[0])&&(outF.notFull));
			$display("Worklist: parsed node %d",works[0][0]);
			let dd = AM_DATA { payload: unpack(works[0][0]) };
			let req = AM_FULL { head: ?, data: dd };
			outF.enq(req);

			Bit#(32) temp = ?;
			works[0] <= shiftInAtN(works[0],temp);
			done[0] <= (numworks[0] == 1); 
			numworks[0] <= numworks[0] - 1;
	endrule

	/////////////////////////////////////////////////////////////////////////

		Reg#(Bit#(32)) lineworks <- mkReg(0);
	Reg#(Vector#(15,Bit#(32))) bundle <- mkReg(Vector::replicate(0));
	Reg#(Bool) linefull <- mkReg(False);
	
	//TODO shortcut FIFO??
	(* fire_when_enabled *)
	rule consume_update_rsp if (!linefull);
		if (inF.notEmpty) begin
			$display("Worklist Stage 5: consume update: %0d numworks: %d howmany: %d", inF.first.data.payload,lineworks,howmany);
			//destIdx <= extend(pack(nodepropW.rx.head.arg2));
			if (lineworks==0) begin
			   Vector#(15,Bit#(32)) zero = replicate(0);
			   zero[0] = extend(pack(inF.first.data.payload));
			   bundle <= zero;
			end else begin
			   bundle[pack(lineworks)] <= extend(pack(inF.first.data.payload));
			end
			
			//sb.clear2(inF.first.head.arg0);

			inF.deq;
			linefull<=(lineworks==14)||(howmany==0);
			lineworks<=lineworks+1;
		end
	endrule

	(* fire_when_enabled *)
	rule send_bundle if (linefull);
		if ((!listWr.txPort.txFull)&&(howmany_w<capacity)) begin
			if (howmany_w>=capacity) $display("ERROR howmany >= capacity");
			if (howmany>=capacity) $display("ERROR howmany >= capacity");
			$display("Worklist Stage 5: send bundle: %h numworks: %d howmany: %d idx: %d",pack(bundle),lineworks,howmany,nextTxIdx);
			Bit#(32) nw = extend(pack(lineworks));
			let hd = AM_HEAD { srcid:5 , dstid:0 , arg0:lineworks , arg1:nextTxIdx 
												 , arg2:? , arg3:? }; 
			let dd = AM_DATA { payload: unpack({nw,pack(bundle)}) };
			let req = AM_FULL { head: hd, data: dd };
			listWr.txPort.tx(req);

			//nextTxIdx<=nextTxIdx+1;
			nextTxIdx <= ((nextTxIdx+1)>=capacity) ? 0 : nextTxIdx + 1;
			lineworks<=0;
			linefull <= False; 
			increment_calledW.send();
		end else begin
			$display("Worklist Stage 5: STALL bundle: %h numworks: %d howmany: %d txidx: %d rxidx: %d",pack(bundle),lineworks,howmany,nextTxIdx,nextIdx[1]);
		end
	endrule

	/////////////////////////////////////////////////////////////////////////

	(* fire_when_enabled *)
	rule cleanup_work if (!listWr.rxPort.rxEmpty);
			$display("Stage 0: recv work: %0d",pack(howmany)+1);
		increment_called.send();
		listWr.rxPort.rxPop;
	endrule

	/////////////////////////////////////////////////////////////////////////

	let tx_ifc = interface TxMsgChannel#(AM_FULL#(Bit#(32),Bit#(32)));
    method Bool txFull();
      return !inF.notFull();
    endmethod
    method Action tx(AM_FULL#(Bit#(32),Bit#(32)) r);
      inF.enq(r);
    endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(Bit#(32),Bit#(32)));
    method Bool rxEmpty();
      return !outF.notEmpty();
    endmethod
    method Action rxPop();
      outF.deq();
    endmethod
    method AM_FULL#(Bit#(32),Bit#(32)) rx();
      return outF.first;
    endmethod
    endinterface;

    let sv = interface Server#(AM_FULL#(Bit#(32),Bit#(32)),AM_FULL#(Bit#(32),Bit#(32)),n_in);
      interface txPort = tx_ifc;
      interface rxPort = rx_ifc;
    endinterface;
  
  interface workQ = sv;
  method Action start(Bool s);
	start_in <= s;
  endmethod
  method Action setCapacity(Bit#(32) c);
	capacity <= c;
  endmethod

endmodule

module mkWorklistCircularStats#(Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),n_out_r) listRd, Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),n_out_w) listWr, Bool started, sdarg capacity) 
										(ServerStats#(AM_FULL#(sdarg,work),AM_FULL#(sdarg,work),n_in))
							provisos(Bits#(sdarg,a_),
									 Bits#(data,512),
									 Bits#(work,32),
									 Literal#(sdarg),
									 Literal#(data),
									 Literal#(work),
									 Arith#(sdarg),
									 Eq#(sdarg),
									 Ord#(sdarg),
									 Add#(a__,a_,32));

	//sdarg capacity = 16384;
	Reg#(Bool) started_loc <- mkReg(False);
	SAMPLER#(32,8,3) qdepth <- mkSampler();

    FIFOF#(AM_FULL#(sdarg,work))  inF  <- mkSizedFIFOF(4); 
    FIFOF#(AM_FULL#(sdarg,work))  outF <- mkSizedFIFOF(256);  

	Reg#(sdarg) nextTxIdx <- mkReg(1); //This needs to connect better to first stage.
	Reg#(sdarg) nextIdx[2] <- mkCReg(2,0);
	Reg#(sdarg) howmany <- mkReg(1);
	PulseWire increment_called <- mkPulseWire();
    PulseWire decrement_called <- mkPulseWire();
	Reg#(sdarg) howmany_w <- mkReg(1);
	PulseWire increment_calledW <- mkPulseWire();
    PulseWire decrement_calledW <- mkPulseWire();

    Reg#(Bit#(32)) numworks[2] <- mkCReg(2,0);
	Reg#(Vector#(15,Bit#(32))) works[2] <- mkCReg(2,Vector::replicate(0));
	Reg#(Bool) done[3] <- mkCReg(3,True);

	rule do_increment(increment_called && !decrement_called);
    	howmany <= howmany + 1;
	endrule
	rule do_decrement(!increment_called && decrement_called);
    	howmany <= howmany - 1;
	endrule
	rule do_incrementW(increment_calledW && !decrement_calledW);
    	howmany_w <= howmany_w + 1;
	endrule
	rule do_decrementW(!increment_calledW && decrement_calledW);
    	howmany_w <= howmany_w - 1;
	endrule

	rule sample(started_loc);
		qdepth.addSample(extend(pack(howmany)));
	endrule

	(* fire_when_enabled *)
	rule req_work if ((!listRd.txPort.txFull)&&started&&(howmany>0));
			$display("Stage 0: request work: %0d howmany %d",nextIdx[0],howmany);
		//nextIdx <= nextIdx + 1;
		if (nextIdx[0]==nextTxIdx) $display("ERROR nextIdx == nextTxIdx");
		if (0==howmany) $display("ERROR howmany < 1");
		nextIdx[0] <= ((nextIdx[0]+1)>=capacity) ? 0 : nextIdx[0] + 1;
		let hd = AM_HEAD { srcid:1 , dstid:1 , arg0:0 , arg1:nextIdx[0]
											 , arg2:? , arg3:? }; //arg0=? arg1=addr
		let req = AM_FULL { head: hd, data: ? };
		listRd.txPort.tx(req);
			decrement_called.send();
			decrement_calledW.send();
		//decrement_called.send(); // FIXME?? maybe this is when it comes back
	endrule

	/////////////////////////////////////////////////////////////////////////

	rule consume_bundle if (done[1]&&(!listRd.rxPort.rxEmpty));
			Vector#(16,Bit#(32)) temp = toChunks(pack(listRd.rxPort.rx.data.payload));
			$display("Worklist: recv numworks %d",temp[15]);
			works[1] <= takeAt(0,temp);
			numworks[1] <= temp[15];
			listRd.rxPort.rxPop;
			if (temp[15] != 0) begin
				done[1]<=False;
			end
	endrule

	rule work_sendoff if ((!done[0])&&(outF.notFull));
			$display("Worklist: parsed node %d",works[0][0]);
			let dd = AM_DATA { payload: unpack(works[0][0]) };
			let req = AM_FULL { head: ?, data: dd };
			outF.enq(req);

			Bit#(32) temp = ?;
			works[0] <= shiftInAtN(works[0],temp);
			done[0] <= (numworks[0] == 1); 
			numworks[0] <= numworks[0] - 1;
	endrule

	/////////////////////////////////////////////////////////////////////////

		Reg#(sdarg) lineworks <- mkReg(0);
	Reg#(Vector#(15,Bit#(32))) bundle <- mkReg(Vector::replicate(0));
	Reg#(Bool) linefull <- mkReg(False);
	
	//(* fire_when_enabled *)
	rule consume_update_rsp if (!linefull);
		if (inF.notEmpty) begin
			$display("Worklist Stage 5: consume update: %0d numworks: %d howmany: %d", inF.first.data.payload,lineworks,howmany);
			//destIdx <= extend(pack(nodepropW.rx.head.arg2));
			if (lineworks==0) begin
			   Vector#(15,Bit#(32)) zero = replicate(0);
			   zero[0] = extend(pack(inF.first.data.payload));
			   bundle <= zero;
			end else begin
			   bundle[pack(lineworks)] <= extend(pack(inF.first.data.payload));
			end
			
			//sb.clear2(inF.first.head.arg0);

			inF.deq;
			linefull<=(lineworks==14)||(howmany==0);
			lineworks<=lineworks+1;
		end
	endrule

	//(* fire_when_enabled *)
	rule send_bundle if (linefull);
		if ((!listWr.txPort.txFull)&&(howmany_w<capacity)) begin
			if (howmany_w>=capacity) $display("ERROR howmany >= capacity");
			if (howmany>=capacity) $display("ERROR howmany >= capacity");
			$display("Worklist Stage 5: send bundle: %h numworks: %d howmany: %d idx: %d",pack(bundle),lineworks,howmany,nextTxIdx);
			Bit#(32) nw = extend(pack(lineworks));
			let hd = AM_HEAD { srcid:1 , dstid:1 , arg0:1 , arg1:nextTxIdx 
												 , arg2:lineworks , arg3:? }; 
			let dd = AM_DATA { payload: unpack({nw,pack(bundle)}) };
			let req = AM_FULL { head: hd, data: dd };
			listWr.txPort.tx(req);

			//nextTxIdx<=nextTxIdx+1;
			nextTxIdx <= ((nextTxIdx+1)>=capacity) ? 0 : nextTxIdx + 1;
			lineworks<=0;
			linefull <= False; 
			increment_calledW.send();
		end else begin
			$display("Worklist Stage 5: STALL bundle: %h numworks: %d howmany: %d txidx: %d rxidx: %d",pack(bundle),lineworks,howmany,nextTxIdx,nextIdx[1]);
		end
	endrule

	/////////////////////////////////////////////////////////////////////////

	//(* fire_when_enabled *)
	rule cleanup_work if (!listWr.rxPort.rxEmpty);
			$display("Stage 0: recv work: %0d",pack(howmany)+1);
		increment_called.send();
		listWr.rxPort.rxPop;
	endrule

	/////////////////////////////////////////////////////////////////////////

	let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,work));
    method Bool txFull();
      return !inF.notFull();
    endmethod
    method Action tx(AM_FULL#(sdarg,work) r);
      inF.enq(r);
    endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,work));
    method Bool rxEmpty();
      return !outF.notEmpty();
    endmethod
    method Action rxPop();
      outF.deq();
    endmethod
    method AM_FULL#(sdarg,work) rx();
      return outF.first;
    endmethod
    endinterface;

    let db_ifc = interface Stats#(32);
		method Bit#(32) sum_intarr_time();
			return 0;//intarr.total;
		endmethod
		method Bit#(32) cnt_intarr_time();
			return 0;//intarr.samples;
		endmethod
		method Bit#(32) min_intarr_time();
			return 0;//intarr.min;
		endmethod
		method Bit#(32) max_intarr_time();
			return 0;//intarr.max;
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
			return 0;//delay.total;
		endmethod
		method Bit#(32) cnt_req_delay();
			return 0;//delay.samples;
		endmethod
		method Bit#(32) min_req_delay();
			return 0;//delay.min;
		endmethod
		method Bit#(32) max_req_delay();
			return 0;//delay.max;
		endmethod
		method Action clear();
			//intarr.clear;
			qdepth.clear;
			//delay.clear;
		endmethod
		method Action start();
			started_loc <= True;
		endmethod
		method Action stop();
			started_loc <= False;
		endmethod
    endinterface;

  interface txPort = tx_ifc;
  interface rxPort = rx_ifc;
	interface debug  = db_ifc;

endmodule

endpackage
