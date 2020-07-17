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
// Service modules for the BFS Graph services
//

package BFS;

import MessagePack::*;
import FIFO::*;
import FIFOF::*;
import FIFOFA::*;
import SpecialFIFOs::*;
import Vector::*;
import CBuffer::*;
import Scoreboard::*;

interface Control;
	method Action start;
	method Bool   idle;
	method Action halt;
endinterface

module mkTxEdgeReq2#(RxMsgChannel#(AM_FULL#(sdarg,data)) pernode, TxMsgChannel#(AM_FULL#(sdarg,data)) peredge) 
										(Control)
							provisos(Bits#(sdarg,a_),
									 Bits#(data,c_),
									 Literal#(sdarg),
									 Literal#(data),
									 Add#(a__,a_,32),
    								 Add#(b__, 4, a_),
									 Div#(c_,32,16));
	
	Reg#(Bit#(32)) edgeIdx <- mkReg(0);
	Reg#(Bit#(32)) fanout <- mkReg(0);
	Reg#(sdarg) srcIdx <- mkReg(0);
	Reg#(Bool) done[3] <- mkCReg(3,True);
	Reg#(Bit#(32)) edgeCnt <- mkReg(0);

	rule consume_node_line if ((done[1])&&(!pernode.rxEmpty));
			Vector#(16,Bit#(32)) temp = toChunks(pernode.rx.data.payload);
			Bit#(4) src = truncate(pack(pernode.rx.head.arg0)<<1); 
			//edgeIdx[1] <= temp[src];
			//fanout[1] <= temp[src+1];
			//srcIdx[1] <= pernode.rx.head.arg0;
			edgeIdx <= temp[src];
			fanout <= temp[src+1];
			srcIdx <= pernode.rx.head.arg0;
			pernode.rxPop;
			done[1]<=(temp[src+1]==0);
			//done<=False;
			//edgeCnt[1]<=0;
			$display("Stage 2: idx %d src %d recv edgeIdx %d fanout %d",pernode.rx.head.arg0,src,temp[src],temp[src+1]);
	endrule

	FIFOF#(AM_FULL#(sdarg,data)) reqQ <-mkPipelineFIFOF;

	rule fetch_edges if ((!done[0])&&(reqQ.notFull));
			//edgeLineIdx
			Bit#(32) argAddr   = (edgeIdx+edgeCnt)/16; 
			Bit#(32) lineIdx   = (edgeIdx+edgeCnt)%16;

			Bit#(32) lineTotal = ((16-lineIdx)>(fanout-edgeCnt)) 
									   ? (fanout-edgeCnt) : (16-lineIdx);
			//PIPELINE THIS     
			$display("Stage 2: req edge %d line total %d",lineIdx,lineTotal);                                                               
			let hd = AM_HEAD { srcid:2 , dstid:3 , arg0:srcIdx  , arg1:unpack(truncate(argAddr)) 
												 , arg2:unpack(truncate(lineIdx)) , arg3:unpack(truncate(lineTotal)) }; //arg0=? arg1=addr
			let req = AM_FULL { head: hd, data: ? };
			reqQ.enq(req);
			

			edgeCnt <= (fanout==(edgeCnt+lineTotal)) ? 0 : (edgeCnt + lineTotal);
			done[0] <= (fanout==(edgeCnt+lineTotal)); 
	endrule

	rule send((!peredge.txFull)&&reqQ.notEmpty);
		peredge.tx(reqQ.first);
		reqQ.deq;
	endrule

	method Action start;
		noAction;
	endmethod

	method Bool idle;
		return pernode.rxEmpty;
	endmethod

	method Action halt;
		noAction;
	endmethod
endmodule

module mkTxDstNodeReq#(RxMsgChannel#(AM_FULL#(sdarg,data)) peredge, TxMsgChannel#(AM_FULL#(sdarg,data)) nodepropR,//) (Control)//, 
					   Scoreboard#(ss,sdarg) sb) (Control)
							provisos(Bits#(sdarg,a_),
									 Bits#(data,c_),
									 Literal#(sdarg),
									 Literal#(data),
									 Arith#(sdarg),
									 Eq#(sdarg),
									 Ord#(sdarg),
									 Add#(a__,a_,32),
									 Div#(c_,32,16));
	
	Reg#(sdarg) dstIdx  <- mkReg(0); 
	Reg#(sdarg) argAddr <- mkReg(0);

	Reg#(sdarg) howmanyR <- mkReg(0);
	Reg#(sdarg) offsetR  <- mkReg(0);  
	Reg#(sdarg) srcIdx  <- mkReg(0); 

	Reg#(sdarg) dstCnt  <- mkReg(0); //MAYBE duplicate this path
	Wire#(Bool)  sent <- mkDWire(False); //FIXME make valid 
	Reg#(Bool)	 valid[2] <- mkCReg(2,False);
	//Wire#(Bool) 	popped <- mkDWire(False);
	
	//Reg#(Bool) found[2] <- mkCReg(2,True);

	rule consume_edge_line if ((!peredge.rxEmpty)&&(!valid[1]));
		//if  begin
			Vector#(16,Bit#(32)) temp = toChunks(peredge.rx.data.payload);
			sdarg offset = peredge.rx.head.arg2;
			sdarg howmany = peredge.rx.head.arg3;
			howmanyR <= howmany;
			offsetR <= offset;
						
			srcIdx <= peredge.rx.head.arg0;
			dstIdx <= unpack(truncate(temp[pack(offset+dstCnt)]));
			argAddr <= unpack(truncate( (temp[pack(offset+dstCnt)])/16) );

			sb.search( unpack(truncate((temp[pack(offset+dstCnt)])/16 )));
			valid[1] <= (howmany>0);

			// valid[1] <= (howmany>0) && !(sb.search( unpack(truncate((temp[pack(offset+dstCnt)])/16 ))));

			if ((howmany==0)||(howmany==(dstCnt+1))||((offset+dstCnt)>=15)) begin
				peredge.rxPop;
				dstCnt<=0; 
				$display("Stage 3: POP");
			end else begin
				dstCnt<=dstCnt+1;
			end

			$display("Stage 3: RECV idx %d offset %d howmany %d dstCnt %d",peredge.rx.head.arg0,peredge.rx.head.arg2,peredge.rx.head.arg3,dstCnt);
		//end
	endrule

	rule valid_rule if (sent);
				valid[0] <= False;
	endrule

	rule request_dest if ( (!nodepropR.txFull)&&(!sb.stall)&&valid[0] );
			sb.set(argAddr); 
			
			let hd = AM_HEAD { srcid:3 , dstid:4 , arg0:srcIdx , arg1:argAddr 
												 , arg2:dstIdx , arg3:? }; //arg0=? arg1=addr
			let req = AM_FULL { head: hd, data: ? };
			nodepropR.tx(req);
			
			sent <= True;

			$display("Stage 3: REQ src idx %d dst idx %d addr %d",srcIdx,dstIdx,argAddr);
	endrule

	method Action start;
		noAction;
	endmethod

	method Bool idle;
		return peredge.rxEmpty;
	endmethod

	method Action halt;
		noAction;
	endmethod
endmodule

module mkUdServer#(RxMsgChannel#(AM_FULL#(sdarg,Bit#(512))) nodepropR, TxMsgChannel#(AM_FULL#(sdarg,Bit#(512))) nodepropW, Scoreboard#(ss,sdarg) sb) 
					(Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
							provisos(Bits#(sdarg,a_),
									 //Bits#(data,512),
									 Literal#(sdarg),
									 Arith#(sdarg),
									 Bits#(data,32),
									 Add#(a__,a_,32),
									 Add#(b__, 1, a_)
									 /*Literal#(data)*/);
	
	Integer vthresh = valueOf(threshold)+2;

  FIFOF#(AM_FULL#(sdarg,data)) passIn <- mkUGSizedFIFOF(vthresh); // pipeline
  FIFOF#(AM_FULL#(sdarg,data)) passOut <- mkUGSizedFIFOF(vthresh); // pipeline
  FIFOF#(AM_FULL#(sdarg,Bit#(512))) passBy <- mkUGSizedFIFOF(vthresh); // pipeline

	rule consume_dst_line if (passIn.notFull&&passBy.notFull);// if (done[1]);
		if (!nodepropR.rxEmpty) begin
			Vector#(16,Bit#(32)) temp = toChunks(nodepropR.rx.data.payload);
			sdarg offset = (nodepropR.rx.head.arg2)%16;
			let hd = AM_HEAD { srcid:? , dstid:? , arg0:nodepropR.rx.head.arg0 , arg1:nodepropR.rx.head.arg2 
                               , arg2:? , arg3:? }; 
			let dd = AM_DATA { payload: unpack(temp[pack(offset)]) };
			let rsp = AM_FULL { head: hd, data:dd };
			passIn.enq(rsp);
			passBy.enq(nodepropR.rx);
			nodepropR.rxPop;
			$display("Stage 4: RSP src idx %d dst idx %d parent %d",nodepropR.rx.head.arg0,nodepropR.rx.head.arg2,temp[pack(offset)]);
		end //else $display("Stage 4: no new neighbor response!");
	endrule

	rule update_dest if (passOut.notEmpty&&passBy.notEmpty);//if (!done[0]);
		Bool hasParent = unpack(truncate(pack(passOut.first.head.arg2)));
		sdarg srcIdx = passOut.first.head.arg0;
		sdarg sbIdx = passBy.first.head.arg1;
		sdarg dstIdx = passOut.first.head.arg1;
		sdarg dstOffset = passOut.first.head.arg1%16;
		Vector#(16,Bit#(32)) cacheline = toChunks(passBy.first.data.payload);
		if (hasParent) begin
			// has parent and doesnt need update
			sb.clear1(sbIdx);
			$display("Stage 4: dst idx  %d has parent %d",dstIdx,pack(passOut.first.data.payload));
			passBy.deq;
			passOut.deq;
		end else if ( (!nodepropW.txFull) ) begin
			// doesnt have a parent		
			sdarg argAddr = dstIdx/16;
			Vector#(16,Bit#(32)) temp = cacheline;
			temp[pack(dstOffset)] = extend(pack(srcIdx));

			let hd = AM_HEAD { srcid:4 , dstid:5 , arg0:sbIdx , arg1:argAddr 
												 , arg2:dstIdx , arg3:? }; 
			let dd = AM_DATA { payload: pack(temp) };
			let req = AM_FULL { head: hd, data: dd };
			nodepropW.tx(req);
			passBy.deq;
			passOut.deq;
			$display("Stage 4: UPD dst idx %d parent %d",dstIdx,srcIdx);
		end else begin 
			$display("Stage 4: dst idx %d stalled - dst wr full!",dstIdx);
		end
	endrule

 	let tx_ifc = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      return !passOut.notFull();
    endmethod
    method Action tx(AM_FULL#(sdarg,data) r);
      passOut.enq(r);
    endmethod
    endinterface;

    let rx_ifc = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return !passIn.notEmpty();
    endmethod
    method Action rxPop();
      passIn.deq();
    endmethod
    method AM_FULL#(sdarg,data) rx();
      return passIn.first;
    endmethod
    endinterface;

  interface txPort = tx_ifc;
  interface rxPort = rx_ifc;
endmodule

module mkGraphServer#(Server#(AM_FULL#(sdarg,Bit#(512)),AM_FULL#(sdarg,Bit#(512)),threshold) nodes, 
					  Server#(AM_FULL#(sdarg,Bit#(512)),AM_FULL#(sdarg,Bit#(512)),threshold) edges,
					  Server#(AM_FULL#(sdarg,Bit#(512)),AM_FULL#(sdarg,Bit#(512)),threshold) distR,
					  Server#(AM_FULL#(sdarg,Bit#(512)),AM_FULL#(sdarg,Bit#(512)),threshold) distW) 
					(Server2#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold))
							provisos(Bits#(sdarg,a_),
									 Literal#(sdarg),
									 Arith#(sdarg),
									 Eq#(sdarg),
									 Ord#(sdarg),
									 Bits#(data,32),
									 Add#(a__,a_,32),
									 Add#(b__, 4, a_),
									 Add#(c__, 1, a_),
									 Add#(d__, 8, a_)
									 /*Literal#(data)*/);
	

	Scoreboard#(256,sdarg) sb <- mkScoreboard();

 	Control stg2 <- mkTxEdgeReq2(nodes.rxPort,edges.txPort); 
	Control stg3 <- mkTxDstNodeReq(edges.rxPort,distR.txPort,sb);
	Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold) servNeighbor <- mkUdServer(distR.rxPort,distW.txPort,sb);

 	let tx_ifc_a = interface TxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool txFull();
      return nodes.txPort.txFull;
    endmethod
    method Action tx(AM_FULL#(sdarg,data) r);
		let hd = r.head;
                hd.arg1 = unpack(pack(hd.arg0)>>3); 
		let req = AM_FULL { head: hd, data: ? };
		nodes.txPort.tx(req);
    endmethod
    endinterface;

    let rx_ifc_b = interface RxMsgChannel#(AM_FULL#(sdarg,data));
    method Bool rxEmpty();
      return distW.rxPort.rxEmpty;
    endmethod
    method Action rxPop();
      distW.rxPort.rxPop;
	  sb.clear2(distW.rxPort.rx.head.arg0);
    endmethod
    method AM_FULL#(sdarg,data) rx();
		let hd = distW.rxPort.rx.head; 
		let rsp = AM_FULL { head: hd, data: ? };
      return rsp;
    endmethod
    endinterface;

  let loc_neighborService = interface Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold);
    interface txPort = tx_ifc_a;
    interface rxPort = servNeighbor.rxPort;
  endinterface;
  let loc_updateService = interface Server#(AM_FULL#(sdarg,data),AM_FULL#(sdarg,data),threshold);
    interface txPort = servNeighbor.txPort;
    interface rxPort = rx_ifc_b;
  endinterface;

  interface serverA = loc_neighborService;
  interface serverB = loc_updateService;
endmodule

endpackage
