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
// Service module providing an atomic increment operation to a counter at the
// specified index. 
//

package CountersServer;

import MessagePack::*;
import FIFO::*;
import FIFOF::*;
import FIFOFA::*;
import SpecialFIFOs::*;
import Vector::*;
import Scoreboard::*;
import Channels::*;
import CBuffer::*;

interface CounterServerCCIP#(type addr, type mdata, type data, type sdarg, numeric type threshold);
        interface ChannelsTopHARP#(addr,mdata,data) top;


        interface Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold) counter;
        (* always_ready, always_enabled *) method Action setRd((* port= "addr" *) addr ra);
        (* always_ready, always_enabled *) method Action setWr((* port= "addr" *) addr wa);
endinterface

module mkCountersServer#(Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold) read, Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold) write) 
										(Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
							provisos(Bits#(sdarg,a_),
									 Bits#(data,c_),
									 Add#(a__, a_, c_), // Data larger than sdarg
									 Add#(b__, 8, a_), // From scoreboard set at 256...
									 Add#(c__, a_, 32), // From toChunks // sdarg <= 32
									 Div#(c_, 32, e_), // data in 32b chunks
									 Mul#(e_, 32, c_), // data in 32b chunks
									 Log#(e_,f_),      // idx to data chunk size
									 Add#(d__, f_, a_), // idx size <= sdarg size
									 Literal#(sdarg),
    								 Bitwise#(sdarg),
									 Arith#(sdarg),
									 Log#(threshold,t_));
	
	Scoreboard#(256,sdarg) sb <- mkScoreboard();

    //sdarg my_id = 0;
 
	FIFOF#(AM_HEAD#(sdarg)) reqBuf <- mkUGSizedFIFOF(valueof(threshold));
	FIFOF#(AM_HEAD#(sdarg)) rspBuf <- mkUGSizedFIFOF(valueof(threshold));    
	COUNTER#(TAdd#(t_,1)) cnt <- mkLCounter(0);   
	COUNTER#(TAdd#(t_,1)) cnt2 <- mkLCounter(0);
	Reg#(Bool)	 valid[2] <- mkCReg(2,False);
	Reg#(Bool)	 inc[2] <- mkCReg(2,False);
	Reg#(Vector#(e_,Bit#(32)))	 write_data <- mkReg(?);
	Reg#(AM_HEAD#(sdarg)) write_head <- mkReg(?);

	//FIFOF#(AM_HEAD#(sdarg)) pendActn <- mkSizedFIFOF(threshold); 

	function isNotFull() = ((cnt.value+cnt2.value) != fromInteger(valueof(threshold)));
    function isNotEmpty() = ((cnt.value+cnt2.value) != 0);

    Reg#(AM_HEAD#(sdarg)) req_hold <- mkReg(?);

	rule receive_request(!valid[1]&&reqBuf.notEmpty);        
        sb.search(reqBuf.first.arg0>>4); // SPEC arg0 = ctr idx // Shift to CL addr
		reqBuf.deq;
		req_hold <= reqBuf.first; 
		valid[1] <= True;
		$display("Ctr Server [%d] Recv. Req. srcid %d dstid %d arg0 %d arg1 %d arg2 %d",0,reqBuf.first.srcid,reqBuf.first.dstid,reqBuf.first.arg0,reqBuf.first.arg1,reqBuf.first.arg2);
	endrule

	rule process_request((!read.txPort.txFull)&&(!sb.stall)&&valid[0]);
        // Send read req			
        let hd = AM_HEAD { srcid:req_hold.dstid , dstid:? , arg0:req_hold.arg0 , arg1:req_hold.arg0>>4 
											         , arg2:req_hold.arg1 , arg3:req_hold.arg2 }; 
		let rq = AM_FULL { head: hd, data: ? };
        read.txPort.tx(rq);
        sb.set(req_hold.arg0>>4);
        // Buffer update 
        // Push to FIFO or expect return?? // TODO figure out a more efficient way to do this.
        //pendActn.enq(req_hold);
        valid[0] <= False;
		$display("Ctr Server [%d] Proc. Req. Idx %d",0,req_hold.arg0);
	endrule

	rule do_increment((!read.rxPort.rxEmpty)&&!inc[1]);
        let hd = read.rxPort.rx.head;													
        // SPEC arg1 = action (inc by val)
		Vector#(e_,Bit#(32)) temp = toChunks(read.rxPort.rx.data.payload);
		Bit#(32) inc_by = extend(pack(hd.arg2));
		Bit#(f_) ctr_idx = truncate(pack(hd.arg0));

        temp[ctr_idx] = temp[ctr_idx] + inc_by;
        write_data <= temp;
        write_head <= hd;
		inc[1] <= True;

        read.rxPort.rxPop;
	endrule

	rule do_update((!write.txPort.txFull)&&inc[0]);
               
        AM_DATA#(data) dd;
        dd.payload = unpack(pack(write_data));
		let rq = AM_FULL { head: write_head, data: dd };

        write.txPort.tx(rq);
        inc[0] <= False;
		//pendActn.deq;
		$display("Ctr Server UD CL: [%d] %h",write_head.arg0,dd.payload);
	endrule

    rule clear_sb((!write.rxPort.rxEmpty));
        let hd = write.rxPort.rx.head;
        let rh = AM_HEAD { srcid:0 , dstid:hd.srcid , arg0:hd.arg0 , arg1:hd.arg2 
											         , arg2:hd.arg3 , arg3:? }; 
        if(unpack(pack(hd.arg3)[0])) begin // SPEC (arg2==1) = ack required
            rspBuf.enq(rh);
            cnt2.up;
            $display("ACK REQUESTED Server [%d]",0);
        end //else begin
            cnt.down;
        //end
        write.rxPort.rxPop;
        sb.clear1(hd.arg1);
        //$display("Ctr Server [%d] Clear Sb.",0,hd.arg0);
	endrule

    let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data)); //OK 
		method Bool txFull();
			return !isNotFull || !reqBuf.notFull;
		endmethod
		method Action tx(AM_FULL#(sdarg,data) w);
			reqBuf.enq(w.head);
			cnt.up;
		endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data)); //OK
		method Bool rxEmpty();
			return !rspBuf.notEmpty();
		endmethod
		method Action rxPop();
			rspBuf.deq();
			cnt2.down;
		endmethod
		method AM_FULL#(sdarg,data) rx();
			//let dd = AM_DATA { payload: cBuf.firstData };
		    let rsp = AM_FULL { head: rspBuf.first, data: ? };
			return rsp;
		endmethod
    endinterface;

	interface txPort = tx_ifc;
	interface rxPort = rx_ifc;

endmodule

module mkCountersServerSimple#(Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold_r) read, Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold_w) write) 
										(Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
							provisos(Bits#(sdarg,a_),
									 Bits#(data,c_),
									 Add#(a__, a_, c_), // Data larger than sdarg
									 Add#(c__, a_, 32), // From toChunks // sdarg <= 32
									 Div#(c_, 32, e_), // data in 32b chunks
									 Mul#(e_, 32, c_), // data in 32b chunks
									 Log#(e_,f_),      // idx to data chunk size
									 Add#(d__, f_, a_), // idx size <= sdarg size
									 Literal#(sdarg),
    								 Bitwise#(sdarg),
									 Arith#(sdarg),
									 Log#(threshold,t_));
	

	FIFOF#(AM_HEAD#(sdarg)) reqBuf <- mkUGSizedFIFOF(valueof(threshold));
	FIFOF#(AM_HEAD#(sdarg)) rspBuf <- mkUGSizedFIFOF(valueof(threshold));    
	Reg#(Bool)	 outstanding <- mkReg(False);
	Reg#(Bool)	 valid <- mkReg(False);
	Reg#(Vector#(e_,Bit#(32)))	 write_data <- mkReg(?);
	Reg#(AM_HEAD#(sdarg)) write_head <- mkReg(?);

	//FIFOF#(AM_HEAD#(sdarg)) pendActn <- mkSizedFIFOF(threshold); 
	//rule monitor(outstanding||valid||!reqBuf.notFull);
	//	$display("MONITOR Server [%d] reqFull %d outstanding %d valid %d",!reqBuf.notFull,outstanding,valid);
	//endrule
	
	rule receive_process_request((!outstanding)&&reqBuf.notEmpty&&(!read.txPort.txFull));        
        reqBuf.deq;
		outstanding <= True;		
        let hd = AM_HEAD { srcid:reqBuf.first.dstid , dstid:0 , arg0:reqBuf.first.arg0 , arg1:reqBuf.first.arg0>>4 
											         , arg2:reqBuf.first.arg1 , arg3:reqBuf.first.arg2 }; 
		let rq = AM_FULL { head: hd, data: ? };
        read.txPort.tx(rq);
		//$display("Ctr Server [%d] Recv.+Proc. Req. srcid %d dstid %d arg0 %d arg1 %d arg2 %d",0,reqBuf.first.srcid,reqBuf.first.dstid,reqBuf.first.arg0,reqBuf.first.arg1,reqBuf.first.arg2);
	endrule

	rule do_increment((!read.rxPort.rxEmpty));
        let hd = read.rxPort.rx.head;													
        // SPEC arg1 = action (inc by val)
		Vector#(e_,Bit#(32)) temp = toChunks(read.rxPort.rx.data.payload);
		Bit#(32) inc_by = extend(pack(hd.arg2));
		Bit#(f_) ctr_idx = truncate(pack(hd.arg0));

        temp[ctr_idx] = temp[ctr_idx] + inc_by;
        write_data <= temp;
        write_head <= hd;
		valid <= True;

        read.rxPort.rxPop;
		//$display("Ctr Server RD CL: [%d] %h Addr: %d",hd.arg0,read.rxPort.rx.data.payload,read.rxPort.rx.head.arg1);
		//$display("Ctr Server [%d] Do Update Idx %d Val %d Inc_by %d dst %d addr %d",0,ctr_idx,temp[ctr_idx],inc_by,hd.srcid,hd.arg1);
	endrule

	rule do_update((!write.txPort.txFull)&&valid);
               
        AM_DATA#(data) dd;
        dd.payload = unpack(pack(write_data));
		let rq = AM_FULL { head: write_head, data: dd };

        write.txPort.tx(rq);
        valid <= False;
		//$display("Ctr Server UD CL: [%d] %h",write_head.arg0,dd.payload);
	endrule

    rule clear_sb((!write.rxPort.rxEmpty));
        let hd = write.rxPort.rx.head;
        if(unpack(pack(hd.arg3)[0])) begin // SPEC (arg2==1) = ack required
       		let rh = AM_HEAD { srcid:0 , dstid:hd.srcid , arg0:hd.arg0 , arg1:hd.arg2 
											                , arg2:hd.arg3 , arg3:? }; 
            rspBuf.enq(rh);
            //$display("ACK REQUESTED Server [%d]",0);
        end 
        write.rxPort.rxPop;
        outstanding <= False;
        //$display("Ctr Server [%d] Clear Sb. Addr %d reqNotFull %d",0,hd.arg0,reqBuf.notFull);
	endrule

    let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data)); //OK 
		method Bool txFull();
			return !reqBuf.notFull;
		endmethod
		method Action tx(AM_FULL#(sdarg,data) w);
            //$display("ENQ Server [%d]",0);
			reqBuf.enq(w.head);
		endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data)); //OK
		method Bool rxEmpty();
			return !rspBuf.notEmpty();
		endmethod
		method Action rxPop();
			rspBuf.deq();
		endmethod
		method AM_FULL#(sdarg,data) rx();
			//let dd = AM_DATA { payload: cBuf.firstData };
		    let rsp = AM_FULL { head: rspBuf.first, data: ? };
			return rsp;
		endmethod
    endinterface;

	interface txPort = tx_ifc;
	interface rxPort = rx_ifc;

endmodule


//(* synthesize *)
//module mkCounterServerTestCCIP(CounterServerCCIP#(Bit#(64),Bit#(14),Bit#(512),Bit#(32),8));
//
//  TopConvertHARP#(Bit#(3),Bit#(3),Bit#(64),Bit#(14),Bit#(512),2,8) tc <- mkTopConvertHARP();
//  //WrChannel#(Bit#(64),Bit#(3),Bit#(512),2,2) wrMem = tc.wrch;
//  //RdChannel#(Bit#(64),Bit#(3),Bit#(512),2,2) rdMem = tc.rdch;
//  //WrY#(4,Bit#(64),Bit#(1),Bit#(512),2,2) spWrY <- mkWrY(False,wrMem);
//  //RdY#(4,Bit#(64),Bit#(1),Bit#(512),2,2) spRdY <- mkRdY(False,rdMem);
//  //Vector#(4,WrChannel#(Bit#(64),Bit#(1),Bit#(512),2,2)) splitWr = spWrY.wrch;
//  //Vector#(4,RdChannel#(Bit#(64),Bit#(1),Bit#(512),2,2)) splitRd = spRdY.rdch;
//  //Vector#(8,WrChannel#(Bit#(20),Bit#(32),Bit#(512),2,16)) userChWr;
//  //Vector#(8,RdChannel#(Bit#(20),Bit#(32),Bit#(512),2,16)) userChRd;
//
//   Reg#(Bit#(64)) idleCnt <- mkReg(0);
//
//  RdChannel#(Bit#(64),Bit#(3),Bit#(512),2,8) memR = tc.rdch;
//  WrChannel#(Bit#(64),Bit#(3),Bit#(512),2,8) memW = tc.wrch;
//
//  Reg#(Bit#(64)) ofstRd   <- mkReg(0);
//  Reg#(Bit#(64)) ofstWr  <- mkReg(0);
//
//  	Server#(AM_FULL#(Bit#(32),Bit#(512)),AM_FULL#(Bit#(32),Bit#(512)),8) servR <- mkReadServer(memR,ofstRd);
//  	Server#(AM_FULL#(Bit#(32),Bit#(512)),AM_FULL#(Bit#(32),Bit#(512)),8) servW <- mkWriteServer(memW,ofstWr);
//
//   	Server#(AM_FULL#(Bit#(32),Bit#(512)),AM_FULL#(Bit#(32),Bit#(512)),8) servCtr <- mkCountersServer(servR,servW,0);
//  
//  interface top = tc.top;
//
//  interface counter = servCtr;
//
//  method Action setRd(Bit#(64) ra);
//  		ofstRd <= extend(ra);
//  endmethod
//  method Action setWr(Bit#(64) wa);
//  		ofstWr <= extend(wa);
//  endmethod
//
//endmodule

endpackage
