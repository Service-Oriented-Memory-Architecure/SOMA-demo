package BFSafuPipeline;

import MessagePack::*;

interface BFSafuPipeline;
    (* always_ready, always_enabled *) method Action start(Bool strt);
    (* always_ready, always_enabled *) method Bool finish();
    (* always_ready, always_enabled *) method Bit#(64) getNodesTchd();
endinterface

interface Control;
	method Action start;
	method Bool   idle;
	method Action halt;
endinterface

//
// BFS application kernel pipeline.
// 
// This elastic pipeline implementation has three simple stages as services
// absorb complexity and simplify the user-level kernel logic. 
//
// The design relys on three services:
//  - worklist service (operates like a queue with 'unlimited' capacity)
//  - node index to neighbors (traverses CSR graph returning a node's neighbors and edge weights)
//  - atomic node update (updates a node's distance with proper locking at the node granularity)
//
module mkBFSafuPipeline#(Server#(AM_FULL#(Bit#(32),Bit#(32)),AM_FULL#(Bit#(32),Bit#(32)),32) worklist_chan,
	          Server#(AM_FULL#(Bit#(32),Bit#(32)),AM_FULL#(Bit#(32),Bit#(32)),32) neighbor_chan,
	          Server#(AM_FULL#(Bit#(32),Bit#(32)),AM_FULL#(Bit#(32),Bit#(32)),32) update_chan)
                (BFSafuPipeline);

 Reg#(Bit#(64)) nds_t <- mkReg(0);
  
  Control stg1 <- mkFetchSourceNodeStage(worklist_chan.rxPort,neighbor_chan.txPort); 
  Control stg2 <- mkUpdateNeighborStage(neighbor_chan.rxPort,update_chan.txPort);
  Control stg3 <- mkUpdateWorklistStage(update_chan.rxPort,worklist_chan.txPort,32'd0,nds_t);

  Reg#(Bool) start_in <- mkReg(False);
  Reg#(Bool) fin <- mkReg(False);
  Reg#(Bit#(64)) idleCnt <- mkReg(0);

  rule starter;
    if (start_in) begin
      stg1.start();
      stg2.start();
      stg3.start();
    end 
  endrule

  rule ender;
      if(stg2.idle&&stg3.idle) begin
        idleCnt <= idleCnt + 1;
      end else begin
        idleCnt <= 0;
      end
      if (idleCnt>500) fin<=True;
      else fin<=False;
  endrule

  method Action start(Bool strt);
      start_in <= strt;
  endmethod
  method Bool finish();
      return fin;
  endmethod
  method Bit#(64) getNodesTchd();
      return nds_t;
  endmethod
endmodule

//
// First pipeline stage.
// 
// Simple combinational logic that issues requests to the "node index to neighbors"
// service whenever a new node is available for processing in the worklist queue.
//
module mkFetchSourceNodeStage#(RxMsgChannel#(AM_FULL#(sdarg,work)) wklist, TxMsgChannel#(AM_FULL#(sdarg,data)) pernode) 
										(Control)
							provisos(Bits#(sdarg,a_),
									 Bits#(data,c_),
									 Bits#(work,d_),
									 Literal#(sdarg),
									 Add#(a__, a_, d_));

	rule fetch_src if ((!wklist.rxEmpty)&&(!pernode.txFull));
			$display("Stage 1: req node %d",wklist.rx.data.payload);
			sdarg argIdx = unpack(truncate(pack(wklist.rx.data.payload)));
			let hd = AM_HEAD { srcid:? , dstid:? , arg0:argIdx , arg1:?    //arg0=? arg1=srcIdx
							     , arg2:?      , arg3:? }; //arg2=? arg3=?
			let req = AM_FULL { head: hd, data: ? };
			pernode.tx(req);

			wklist.rxPop;
	endrule

	method Action start;
		noAction;
	endmethod

	method Bool idle;
		return wklist.rxEmpty;
	endmethod

	method Action halt;
		noAction;
	endmethod
endmodule

//
// Second pipeline stage.
// 
// Combinational logic to update a neighbor node's distance with its parent node
// index if it has not been visited before. The atomic update service completes
// the update if arg2==True and handles locking of the neighbor's cacheline.
//
module mkUpdateNeighborStage#(RxMsgChannel#(AM_FULL#(sdarg,Bit#(32))) neighborRd, TxMsgChannel#(AM_FULL#(sdarg,Bit#(32))) neighborUd) 
							(Control)
							provisos(Bits#(sdarg,a_),
									 Literal#(sdarg),
									 Arith#(sdarg),
									 Add#(a__,a_,32),
									 Add#(b__, 1, a_));

	rule inner_loop if ((!neighborRd.rxEmpty) && (!neighborUd.txFull));
		$display("Stage 2: update neighbor node %d parent %d",neighborRd.rx.head.arg0,neighborRd.rx.data.payload);
		let parent = neighborRd.rx.data.payload;
		let srcIdx = neighborRd.rx.head.arg0;
		Bool hasParent = parent!=32'hFFFFFFFF;
		Bit#(32) weight;
		if (hasParent) begin
			weight = parent;
		end else begin
			weight = extend(pack(srcIdx));
		end
		let hd = neighborRd.rx.head;
		hd.arg2 = unpack(extend(pack(hasParent)));
		let dd = AM_DATA { payload: weight };
		let rsp = AM_FULL { head: hd, data:dd };
		neighborUd.tx(rsp);
		neighborRd.rxPop;
	endrule

	method Action start;
		noAction;
	endmethod

	method Bool idle;
		return neighborRd.rxEmpty;
	endmethod

	method Action halt;
		noAction;
	endmethod
endmodule

//
// Third pipeline stage.
// 
// Sends a node index to the worklist for processing once it has been updated.
// As in the first stage the worklist consumes and provides work items like a 
// queue at the work item granularity. 
//
module mkUpdateWorklistStage#(RxMsgChannel#(AM_FULL#(sdarg,data)) nodepropW, TxMsgChannel#(AM_FULL#(sdarg,work)) wklist, 
					    Bit#(32) num_nodes, Reg#(Bit#(64)) numDone) (Control)
							provisos(Bits#(sdarg,a_),
									 Bits#(data,b_),
									 Bits#(work,c_),
									 Add#(a__,a_,c_));
	
	Reg#(Bit#(32)) nodeCnt     <- mkReg(0); 
	Reg#(Bool) started <- mkReg(False);

	rule consume_update_rsp if ((!nodepropW.rxEmpty));
		if ((!wklist.txFull)) begin	
			let dd = AM_DATA { payload: unpack(extend(pack(nodepropW.rx.head.arg2))) };
			let req = AM_FULL { head: ?, data: dd };
			wklist.tx(req);
			nodepropW.rxPop;

			nodeCnt <= nodeCnt + 1;
			numDone <= extend(nodeCnt + 1);	
			$display("Stage 3: consume update: %0d", nodepropW.rx.head.arg2);
		end else begin
			$display("Stage 3: update ready - worklist full!");
		end
		if (started) begin
			$display("NUM_NODES: %d nodeCnt: %d",num_nodes,nodeCnt);
		end
	endrule

	method Action start;
		started <= True;
	endmethod

	method Bool idle;
		return nodepropW.rxEmpty;
	endmethod

	method Action halt;
		noAction;
	endmethod
endmodule

endpackage
