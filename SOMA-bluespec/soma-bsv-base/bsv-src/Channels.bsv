	package Channels;

	import FIFO::*;
	import FIFOF::*;
	import FIFOFA::*;
	import BRAMFIFO::*;
	import FIFOLevel::*;
	import SpecialFIFOs::*;
	import Arbiters::*;
	import Vector::*;
	import CBuffer::*;
	import Clocks::*;

	/*typedef Bit#(14) MData;
	typedef Bit#(4) ChanID;
	typedef Bit#(10) OutTag;
	typedef SizeOf#(ChanID) ChanShift;
	typedef SizeOf#(MData) MSize;*/

	//
	// Simple AXI4 Bus Protocol Definitions
	//

	typedef enum {FIXED, INCR, WRAP}  AXI4BurstMode deriving(Bounded, Bits, Eq);
	typedef enum {OKAY, EXOKAY, SLVERR, DECERR} AXI4Resp deriving(Bounded, Bits, Eq);

	typedef struct 
	{
	    marg   id;
	    Bit#(8)         len;
	    Bit#(3)         size;
	    AXI4BurstMode   burst;
	    addr add;
	} 
	AXI4_ADDR_CMD#(type marg, type addr) 
	    deriving(Bits,Eq);

	typedef struct 
	{
	    marg  id;
	    data dat;
	    Bit#(TDiv#(SizeOf#(data),8)) strb;
	    Bool                     last;
	} 
	AXI4_WRITE_DATA#(type marg, type data) 
	    deriving(Bits,Eq);

	typedef struct 
	{
	    marg  id;
	    data dat;
	    AXI4Resp        resp;
	    Bool            last;
	} 
	AXI4_READ_RESP#(type marg, type data) 
	    deriving(Bits,Eq);

	typedef struct 
	{
	    marg   id;
	    AXI4Resp        resp;
	} 
	AXI4_WRITE_RESP#(type marg)
	    deriving(Bits,Eq);


	interface AXI4_READ_MASTER#(type addr, type marg, type data);
	    // Address Outputs
	    (* always_ready *)
	    method marg arId();
	    (* always_ready *)
	    method addr arAddr();
	    (* always_ready *)
	    method Bit#(8) arLen();
	    (* always_ready *)
	    method Bit#(3) arSize();
	    (* always_ready *)
	    method AXI4BurstMode arBurst();
	    (* always_ready *)
	    method Bit#(3) arProt();
	    (* always_ready *)
	    method Bit#(2) arLock();
	    (* always_ready *)
	    method Bit#(4) arCache();
	    (* always_ready *)
	    method Bit#(4) arQOS();
	    (* always_ready *)
	    method Bool arValid();
	    // Address Inputs
	    (* always_ready *)
	    method Action arReady();
	    // Response Outputs
	    (* always_ready *)
	    method Bool rReady();
	    // Response Inputs
	    (* always_ready *)
	    method Action readData(marg id, data dat, AXI4Resp resp, Bool last);
	    //method Action rId(Bit#(t_ID_SZ) id);
	    //method Action rData(Bit#(t_DATA_SZ) data);
	    //method Action rResp(AXI4Resp resp);
	    //method Action rLast();
	    //method Action rValid();
	endinterface

	interface AXI4_WRITE_MASTER#(type addr, type marg, type data);
	    // Address Outputs
	    (* always_ready *)
	    method marg awId();
	    (* always_ready *)
	    method addr awAddr();
	    (* always_ready *)
	    method Bit#(8) awLen();
	    (* always_ready *)
	    method Bit#(3) awSize();
	    (* always_ready *)
	    method AXI4BurstMode awBurst();
	    (* always_ready *)
	    method Bit#(3) awProt();
	    (* always_ready *)
	    method Bit#(2) awLock();
	    (* always_ready *)
	    method Bit#(4) awCache();
	    (* always_ready *)
	    method Bit#(4) awQOS();
	    (* always_ready *)
	    method Bool awValid();
	    // Address Inputs
	    (* always_ready *)
	    method Action awReady();
	    // Write Data Outputs
	    (* always_ready *)
	    method marg wId();
	    (* always_ready *)
	    method data wData();
	    (* always_ready *)
	    method Bit#(TDiv#(SizeOf#(data), 8)) wStrb();
	    (* always_ready *)
	    method Bool wLast();
	    (* always_ready *)
	    method Bool wValid();
	    // Write Data Inputs
	    (* always_ready *)
	    method Action wReady();
	    // Response Outputs
	    (* always_ready *)
	    method Bool bReady();
	    // Response Inputs
	    (* always_ready *)
	    method Action writeResp(marg id, AXI4Resp resp);
	    //method Action bId(Bit#(t_ID_SZ) id);
	    //method Action bResp(AXI4Resp resp);
	    //method Action bValid();
	endinterface

	interface HLS_AXI_BUS_IFC#(type addr, type marg, type data);
	    interface AXI4_READ_MASTER#(addr, marg, data) readPort;
	    interface AXI4_WRITE_MASTER#(addr, marg, data) writePort;
	endinterface

	//
	// End AXI definitions
	//

	//
	// Begin Avalon definitions
	//

	interface AVALON_MASTER#(type addr, type marg, type data);
		(* always_ready, always_enabled, prefix="", result="read" *) 
  		method Bool read();
  
  		(* always_ready, always_enabled, prefix="", result="write" *) 
  		method Bool write();

  		(* always_ready, always_enabled, prefix="", result="address" *) 
  		method addr address();

  		(* always_ready, always_enabled, prefix="", result="writedata" *) 
  		method data writedata();  

  		(* always_ready, always_enabled, prefix="", result="readdata" *) 
  		method Action readdata(data readdata);

  		(* always_ready, always_enabled, prefix="", result="waitrequest" *) 
  		method Action waitrequest(Bool waitrequest);

  		(* always_ready, always_enabled, prefix="", result="readdatavalid" *) 
  		method Action readdatavalid(Bool readdatavalid);

  		(* always_ready, always_enabled, prefix="", result="burstcount" *) 
  		method Bit#(7) burstcount();

  		(* always_ready, always_enabled, prefix="", result="byteenable" *) 
  		method Bit#(TDiv#(SizeOf#(data),8)) byteenable();
	endinterface

	//
	// End Avalon definitions
	//

	interface RdChannel#(type addr, type marg, type data, numeric type thresh, numeric type n_out);
		(* always_ready *) method Bool txFull();
		(* always_ready *) method Bool txAlmostFull();
		(* always_ready *) method Action tx(addr a, marg m);

		(* always_ready *) method Bool rxEmpty();
		(* always_ready *) method Bool rxAlmostEmpty();
		(* always_ready *) method Action rxPop();
		(* always_ready *) method marg rxMarg();
		(* always_ready *) method data rxData();
	endinterface

	interface RdY#(numeric type n_rd, type addr, type marg, type data, numeric type thresh, numeric type n_out);
		interface Vector#(n_rd,RdChannel#(addr,marg,data,thresh,n_out)) rdch;
	endinterface

	interface WrChannel#(type addr, type marg, type data, numeric type thresh, numeric type n_out);
		(* always_ready *) method Bool txFull();
		(* always_ready *) method Bool txAlmostFull();
		(* always_ready *) method Action tx(addr a, marg m, data d);

		(* always_ready *) method Bool rxEmpty();
		(* always_ready *) method Bool rxAlmostEmpty();
		(* always_ready *) method Action rxPop();
		(* always_ready *) method marg rxMarg();
	endinterface

	interface WrY#(numeric type n_wr, type addr, type marg, type data, numeric type thresh, numeric type n_out);
		interface Vector#(n_wr,WrChannel#(addr,marg,data,thresh,n_out)) wrch;
	endinterface

	interface ChannelsTopHARP#(type addr, type mdata, type data);
		(* always_ready, always_enabled *) method addr rdReqAddr();
		(* always_ready, always_enabled *) method mdata rdReqMdata();
		(* always_ready, always_enabled *) method Bool rdReqEN();
		(* always_ready, always_enabled *) method Action rdReqSent(Bool b);
	
		(* always_ready, always_enabled *) method Action rdRspMdata(mdata m);
		(* always_ready, always_enabled *) method Action rdRspData(data d);
		(* always_ready, always_enabled *) method Action rdRspValid(Bool b);
	
		(* always_ready, always_enabled *) method addr wrReqAddr();
		(* always_ready, always_enabled *) method mdata wrReqMdata();
		(* always_ready, always_enabled *) method data wrReqData();
		(* always_ready, always_enabled *) method Bool wrReqEN();
		(* always_ready, always_enabled *) method Action wrReqSent(Bool b);
	
		(* always_ready, always_enabled *) method Action wrRspMdata(mdata m);
		(* always_ready, always_enabled *) method Action wrRspValid(Bool b);
	endinterface
	
	interface TopConvertHARP#(type margR, type margW, type addr, type mdata, type data, numeric type thresh, numeric type n_out);
		interface ChannelsTopHARP#(addr,mdata,data) top;
		interface RdChannel#(addr,margR,data,thresh,n_out) rdch;
		interface WrChannel#(addr,margW,data,thresh,n_out) wrch;
	endinterface
	
	interface TopConvertAxi#(type margR, type margW, type addr, type mdata, type data, numeric type thresh, numeric type n_out);
		interface HLS_AXI_BUS_IFC#(addr,mdata,data) top;
		interface RdChannel#(addr,margR,data,thresh,n_out) rdch;
		interface WrChannel#(addr,margW,data,thresh,n_out) wrch;
	endinterface
	
	interface TopConvertAvalon#(type margR, type margW, type addr, type mdata, type data, numeric type thresh, numeric type n_out);
		interface AVALON_MASTER#(addr,mdata,data) top;
		interface RdChannel#(addr,margR,data,thresh,n_out) rdch;
		interface WrChannel#(addr,margW,data,thresh,n_out) wrch;
	endinterface

//
// Read
// Module for storing large meta data, sorting responses, and requests outstanding limiting
//
module mkChannelRd#(Bool order, RdChannel#(addr,mdata,data,thresh,n_out_mem) rdM) 
										(RdChannel#(addr,marg,data,thresh,n_out_in))
							provisos(Bits#(marg,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 Bits#(mdata,md_),
									 Log#(n_out_in,md_),
									 Ord#(mdata),
									 Arith#(mdata),
									 PrimIndex#(mdata,i_),
									 Literal#(marg),
									 Literal#(data));

	CBuffer#(marg,data,mdata,thresh,n_out_in) cBuf; 
	if (order) begin
		cBuf <- mkCompletionBuffer;
	end else begin
		cBuf <- mkCompletionBufferU;
	end

	rule get_response(!rdM.rxEmpty);
		mdata md = rdM.rxMarg();
		data dd = rdM.rxData();
		cBuf.complete(md,dd);
		rdM.rxPop();
	endrule

		method Bool txFull();
			return !cBuf.canReserve() || rdM.txFull();
		endmethod
		method Bool txAlmostFull();
			return !cBuf.canReserve() || rdM.txAlmostFull();
		endmethod
		method Action tx(addr a, marg m);
			let tg <- cBuf.reserve(m);
			rdM.tx(a,tg);
		endmethod

		method Bool rxEmpty();
			return !cBuf.notEmpty();
		endmethod
		method Bool rxAlmostEmpty();
			return !cBuf.notAlmostEmpty();
		endmethod 
		method Action rxPop();
			cBuf.deq();
		endmethod
		method marg rxMarg();
			return cBuf.firstMeta();
		endmethod
		method data rxData();
			return cBuf.firstData();
		endmethod

endmodule

//
// Read
// Module for storing large meta data, and effect ordering
//
module mkChannelRdE#(RdChannel#(addr,mdata,data,thresh,n_out_mem) rdM) 
										(RdChannel#(addr,marg,data,thresh,n_out_in))
							provisos(Bits#(marg,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 Bits#(mdata,md_),
									 Log#(n_out_in,md_),
									 Ord#(mdata),
									 Arith#(mdata),
									 PrimIndex#(mdata,i_),
									 Literal#(marg));

	Integer vthresh = 2+valueOf(thresh);
	
	FIFOFA#(marg,thresh,n_out_in) mfTx <- mkFIFOFA;
	FIFOF#(addr) afTx <- mkSizedFIFOF(vthresh);

	FIFOFA#(marg,thresh,n_out_in) mfRx <- mkFIFOFA;
	FIFOF#(data) dfRx <- mkSizedFIFOF(vthresh);

	Reg#(Bool)    flag[2] <- mkCReg(2,False);
	Reg#(marg)	  outM[2] <- mkCReg(2,0);

	rule get_response(!rdM.rxEmpty&&flag[0]);
		data dd = rdM.rxData();
		mfRx.enq(outM[0]);
		dfRx.enq(dd);
		rdM.rxPop();
		flag[0] <= False;
	endrule

	rule put_request(!rdM.txFull&&!flag[1]);	
		addr aa = afTx.first();
		outM[1] <= mfTx.first();
		rdM.tx(aa,57);
		afTx.deq();
		mfTx.deq();
		flag[1] <= True;
	endrule

		method Bool txFull();
			return !mfTx.notFull();
		endmethod
		method Bool txAlmostFull();
			return !mfTx.notAlmostFull();
		endmethod
		method Action tx(addr a, marg m);
			mfTx.enq(m);
			afTx.enq(a);
		endmethod

		method Bool rxEmpty();
			return !mfRx.notEmpty();
		endmethod
		method Bool rxAlmostEmpty();
			return !mfRx.notAlmostEmpty();
		endmethod 
		method Action rxPop();
			mfRx.deq();
		    dfRx.deq();
		endmethod
		method marg rxMarg();
			return mfRx.first();
		endmethod
		method data rxData();
			return dfRx.first();
		endmethod

endmodule

//
// Read
// Module for storing large meta data, sorting responses, and requests outstanding limiting
//
module mkChannelWr#(Bool order, WrChannel#(addr,mdata,data,thresh,n_out_mem) rdM) 
										(WrChannel#(addr,marg,data,thresh,n_out_in))
							provisos(Bits#(marg,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 Bits#(mdata,md_),
									 Log#(n_out_in,md_),
									 Ord#(mdata),
									 Arith#(mdata),
									 PrimIndex#(mdata,i_),
									 Literal#(marg),
									 Literal#(data));

	CBuffer#(marg,Bit#(1),mdata,thresh,n_out_in) cBuf; 
	if (order) begin
		cBuf <- mkCompletionBuffer;
	end else begin
		cBuf <- mkCompletionBufferU;
	end

	rule get_response(!rdM.rxEmpty);
		mdata md = rdM.rxMarg();
		cBuf.complete(md,fromInteger(1));
		rdM.rxPop();
	endrule

		method Bool txFull();
			return !cBuf.canReserve() || rdM.txFull();
		endmethod
		method Bool txAlmostFull();
			return !cBuf.canReserve() || rdM.txAlmostFull();
		endmethod
		method Action tx(addr a, marg m, data d);
			let tg <- cBuf.reserve(m);
			rdM.tx(a,tg,d);
		endmethod

		method Bool rxEmpty();
			return !cBuf.notEmpty();
		endmethod
		method Bool rxAlmostEmpty();
			return !cBuf.notAlmostEmpty();
		endmethod 
		method Action rxPop();
			cBuf.deq();
		endmethod
		method marg rxMarg();
			return cBuf.firstMeta();
		endmethod

endmodule

//
// Write
// Module for storing large meta data, and effect ordering
//
module mkChannelWrE#(WrChannel#(addr,mdata,data,thresh,n_out_mem) rdM) 
										(WrChannel#(addr,marg,data,thresh,n_out_in))
							provisos(Bits#(marg,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 Literal#(mdata),
									 Literal#(marg));

	Integer vthresh = 2+valueOf(thresh);
	
	FIFOFA#(marg,thresh,n_out_in) mfTx <- mkFIFOFA;
	FIFOF#(addr) afTx <- mkSizedFIFOF(vthresh);
	FIFOF#(data) dfTx <- mkSizedFIFOF(vthresh);

	FIFOFA#(marg,thresh,n_out_in) mfRx <- mkFIFOFA;

	Reg#(Bool)    flag[2] <- mkCReg(2,False);
	Reg#(marg)	  outM[2] <- mkCReg(2,0);

	rule get_response(!rdM.rxEmpty&&flag[0]);
		mfRx.enq(outM[0]);
		rdM.rxPop();
		flag[0] <= False;
	endrule

	rule put_request(!rdM.txFull&&!flag[1]);	
		addr aa = afTx.first();
		outM[1] <= mfTx.first();
		data dd = dfTx.first();
		rdM.tx(aa,64,dd);
		afTx.deq();
		mfTx.deq();
		dfTx.deq();
		flag[1] <= True;
	endrule

		method Bool txFull();
			return !mfTx.notFull();
		endmethod
		method Bool txAlmostFull();
			return !mfTx.notAlmostFull();
		endmethod
		method Action tx(addr a, marg m, data d);
			mfTx.enq(m);
			afTx.enq(a);
			dfTx.enq(d);
		endmethod

		method Bool rxEmpty();
			return !mfRx.notEmpty();
		endmethod
		method Bool rxAlmostEmpty();
			return !mfRx.notAlmostEmpty();
		endmethod 
		method Action rxPop();
			mfRx.deq();
		endmethod
		method marg rxMarg();
			return mfRx.first();
		endmethod

endmodule

//
// Read
// Module for splitting one interface to multiple with round robin or priority arbitration
//
module mkRdY#(Bool fair_arb, RdChannel#(addr,Bit#(md_),data,thresh,n_out_mem) rdM) 
										(RdY#(n_rd,addr,marg,data,thresh,n_out_in))
							provisos(Bits#(addr,b_),
								 Bits#(marg,m_),
								 Log#(n_rd,nr_),
								 Add#(m_,nr_,md_),
									 Bits#(data,c_));

	//Integer vthresh = 2;
	Integer vthresh = 2+valueOf(thresh);

	Vector#(n_rd,FIFOF#(addr))  inFA <- replicateM(mkUGSizedFIFOF(vthresh));
	Vector#(n_rd,FIFOF#(marg)) inFM <- replicateM(mkUGSizedFIFOF(vthresh));

	Vector#(n_rd,FIFOF#(marg)) outFM <- replicateM(mkUGSizedFIFOF(vthresh));
	Vector#(n_rd,FIFOF#(data))  outFD <- replicateM(mkUGSizedFIFOF(vthresh));

	Vector#(n_rd,RdChannel#(addr,marg,data,thresh,n_out_in)) rdch_loc;

  	for(Integer i=0; i < valueOf(n_rd); i=i+1) begin
  		let r_ifc = interface RdChannel#(addr,marg,data);
	  		method Action tx(addr a, marg m);
	  			inFA[i].enq(a);
	  			inFM[i].enq(m);
	  		endmethod
	  		method Bool txFull();
	  			return !(inFM[i].notFull());
	  		endmethod
	  		method Bool txAlmostFull();
	  			return True; // Always true so do NOT use.
	  		endmethod

	  		method Bool rxEmpty();
	  			return !outFM[i].notEmpty();
	  		endmethod
			method Bool rxAlmostEmpty();
	  			return True; // Always true so do NOT use.
	  		endmethod
			method Action rxPop();
				outFM[i].deq();
				outFD[i].deq();
	  		endmethod
			method marg rxMarg();
				return outFM[i].first();
	  		endmethod
			method data rxData();
				return outFD[i].first();
			endmethod
  		endinterface;

  		rdch_loc[i] = r_ifc;
  	end

  	Arbiter#(n_rd) rd_arb;
	if (fair_arb) begin
		rd_arb <- mkRoundRobinArbiter();
	end else begin
		rd_arb <- mkStaticPriorityArbiterStartAt(0);
	end

	(* fire_when_enabled *)
  	rule drain_in_fifo(!rdM.txFull);
  		Vector#(n_rd, Bool) txRdFifoReq = unpack(0);
  		for(Integer i=0; i < valueOf(n_rd); i=i+1) begin
  			txRdFifoReq[i] = inFM[i].notEmpty();
  		end
  		Vector#(n_rd, Bool) txRdFifoGrant = unpack(0);
  		txRdFifoGrant <- rd_arb.select(txRdFifoReq);
		//$display("...[ARB] Grant: [%0h]", txRdFifoGrant);

  		for(Integer i=0; i < valueOf(n_rd); i=i+1) begin
  			if (txRdFifoGrant[i]) begin
				//$display("..........[ARB] Grant:[%0d] Meta: %0d", i, inFM[i].first);
  				Bit#(nr_) chan = fromInteger(i);
  				marg ma = inFM[i].first();
				Bit#(md_) txM = {pack(ma),chan};
				addr txA = inFA[i].first();
  				rdM.tx(txA,txM);
  				inFA[i].deq();
  				inFM[i].deq();
  			end
  		end	
  	endrule

  	rule fill_out_fifo(!rdM.rxEmpty);
		//$display("*************************Steer: [%0d] Meta: %0d", rdM.rxMarg[3:0], rdM.rxMarg>>4);
  		Bit#(nr_) chan = truncate(rdM.rxMarg);
  		marg rxM = unpack(truncate(rdM.rxMarg>>valueOf(TLog#(n_rd))));
  		outFM[chan].enq(rxM);
  		outFD[chan].enq(rdM.rxData);
  		rdM.rxPop();
  	endrule

	interface rdch = rdch_loc;

endmodule

//
// Write
// Module for splitting one interface to multiple with round robin or priority arbitration
//
module mkWrY#(Bool fair_arb, WrChannel#(addr,Bit#(md_),data,thresh,n_out_mem) wrM) 
										(WrY#(n_wr,addr,marg,data,thresh,n_out_in))
							provisos(Bits#(addr,b_),
								 Bits#(marg,m_),
								 Log#(n_wr,nw_),
								 Add#(m_,nw_,md_),
								 Bits#(data,c_),
								 Add#(thresh,2,vt));

	//Integer vthresh = 2;
	Integer vthresh = 2+valueOf(thresh);

	Vector#(n_wr,FIFOF#(addr))  inFA <- replicateM(mkUGSizedFIFOF(vthresh));
	//Vector#(n_wr,FIFOF#(marg)) inFM <- replicateM(mkUGSizedFIFOF(vthresh));
	Vector#(n_wr,FIFOLevelIfc#(marg,vt))  inFM <- replicateM(mkGFIFOLevel(True,True,True));
	Vector#(n_wr,FIFOF#(data))  inFD <- replicateM(mkUGSizedFIFOF(vthresh));

	Vector#(n_wr,FIFOF#(marg)) outFM <- replicateM(mkUGSizedFIFOF(vthresh));

	Vector#(n_wr,WrChannel#(addr,marg,data,thresh,n_out_in)) wrch_loc;

  	for(Integer i=0; i < valueOf(n_wr); i=i+1) begin
  		let r_ifc = interface WrChannel#(addr,marg,data);
	  		method Action tx(addr a, marg m, data d);
	  			inFA[i].enq(a);
	  			inFM[i].enq(m);
	  			inFD[i].enq(d);
	  		endmethod
	  		method Bool txFull();
	  			return (inFM[i].isGreaterThan(valueOf(thresh)))||(wrM.txFull);
	  			//return !(inFM[i].notFull());
	  		endmethod
	  		method Bool txAlmostFull();
	  			return True; // Always true so do NOT use.
	  		endmethod

	  		method Bool rxEmpty();
	  			return !outFM[i].notEmpty();
	  		endmethod
			method Bool rxAlmostEmpty();
	  			return True; // Always true so do NOT use.
	  		endmethod
			method Action rxPop();
				outFM[i].deq();
	  		endmethod
			method marg rxMarg();
				return outFM[i].first();
	  		endmethod
  		endinterface;

  		wrch_loc[i] = r_ifc;
  	end

  	Arbiter#(n_wr) wr_arb;
	if (fair_arb) begin
		wr_arb <- mkRoundRobinArbiter();
	end else begin
		wr_arb <- mkStaticPriorityArbiterStartAt(0);
	end

	(* fire_when_enabled *)
  	rule drain_in_fifo(!wrM.txFull);
  		Vector#(n_wr, Bool) txWrFifoReq = unpack(0);
  		for(Integer i=0; i < valueOf(n_wr); i=i+1) begin
  			txWrFifoReq[i] = inFM[i].notEmpty();
  		end
  		Vector#(n_wr, Bool) txWrFifoGrant = unpack(0);
  		txWrFifoGrant <- wr_arb.select(txWrFifoReq);
		//$display("[ARB] Req: %0d...", txWrFifoReq);
		//$display("...[ARB] Grant: [%0h]", txWrFifoGrant);

  		for(Integer i=0; i < valueOf(n_wr); i=i+1) begin
  			if (txWrFifoGrant[i]) begin
				//$display("..........[ARB] Grant:[%0d] Meta: %0d", i, inFM[i].first);
  				Bit#(nw_) chan = fromInteger(i);
  				marg ma = inFM[i].first();
				Bit#(md_) txM = {pack(ma),chan};
				addr txA = inFA[i].first();
				data txD = inFD[i].first();
  				wrM.tx(txA,txM,txD);
  				inFA[i].deq();
  				inFM[i].deq();
  				inFD[i].deq();
  			end
  		end	
  	endrule

  	rule fill_out_fifo(!wrM.rxEmpty);
		//$display("*************************Steer: [%0d] Meta: %0d", wrM.rxMarg[3:0], wrM.rxMarg>>4);
  		Bit#(nw_) chan = truncate(wrM.rxMarg);
  		marg rxM = unpack(truncate(wrM.rxMarg>>valueOf(TLog#(n_wr))));
  		outFM[chan].enq(rxM);
  		wrM.rxPop();
  	endrule

	interface wrch = wrch_loc;

endmodule

module mkRdInvY#(Bool fair_arb, Integer shift, Vector#(n_rd,RdChannel#(Bit#(b_),mdata,data,thresh,n_out_mem)) rdM) 
										(RdChannel#(Bit#(b_),mdata,data,thresh,n_out_in))
							provisos(Bits#(data,c_),
									 Bits#(mdata,m_),
									 Log#(n_rd,h_),
									 Log#(n_out_mem,l_),
									 Add#(l_, 1, inL),
									 Add#(a__, h_, b_));

		//Integer vthresh = 4;
		Integer vthresh = 2 + valueOf(thresh);
		//Integer retthresh = valueOf(n_rd)*valueOf(n_out_in);
		Integer retthresh = valueOf(n_out_in);
		
	FIFOF#(Bit#(b_))  inFA <- mkUGSizedFIFOF(vthresh);
	FIFOF#(mdata) inFM <- mkUGSizedFIFOF(vthresh);

	FIFOF#(mdata) outFM <- mkUGSizedFIFOF(vthresh);
	FIFOF#(data)  outFD <- mkUGSizedFIFOF(vthresh);

	Vector#(n_rd,FIFOF#(mdata)) retFM <- replicateM(mkUGSizedFIFOF(retthresh));
	Vector#(n_rd,FIFOF#(data))  retFD <- replicateM(mkUGSizedFIFOF(retthresh));

	Vector#(n_rd, Array#(Reg#(UInt#(inL)))) noPmem <- replicateM(mkCReg(2,0));

	Arbiter#(n_rd) ret_arb;
	if (fair_arb) begin
		ret_arb <- mkRoundRobinArbiter();
	end else begin
		ret_arb <- mkStaticPriorityArbiterStartAt(0);
	end

	function UInt#(h_) hash (Bit#(b_) a);
		return truncate(unpack((a>>fromInteger(shift)) % fromInteger(valueOf(n_rd))));
	endfunction

	function Bool returnFullPressure();
		Bool valFull = False;
		for(Integer i=0; i < valueOf(n_rd); i=i+1) begin
			valFull = valFull || (noPmem[i][0]>=fromInteger(retthresh));
		end
		return valFull;
	endfunction

	(* fire_when_enabled *)
	rule drain_in_fifo(inFM.notEmpty&&inFA.notEmpty);
		mdata txM = inFM.first;
		Bit#(b_) txA = inFA.first;
		UInt#(h_) h_fun = hash(txA);
		for(Integer i=0; i < valueOf(n_rd); i=i+1) begin
			UInt#(h_) outP = fromInteger(i);
			if (outP == h_fun) begin
				if ((!rdM[i].txFull) && (noPmem[i][0]<fromInteger(retthresh))) begin
					rdM[i].tx(txA,txM);
				//end else begin
				//	inFM.enq(txM);
				//	inFA.enq(txA);
				//end
					inFA.deq();
					inFM.deq();
					noPmem[i][0] <= noPmem[i][0] + 1;
				end else begin
					$display("Channel %d Ret Queue is full: %d",i,noPmem[i][0]);	
				end
			end
		end
	endrule

  	for(Integer i=0; i < valueOf(n_rd); i=i+1) begin	
		rule fill_ret_fifo(!rdM[i].rxEmpty);
			retFM[i].enq(rdM[i].rxMarg);
			retFD[i].enq(rdM[i].rxData);
			rdM[i].rxPop();
		endrule
	end

	(* fire_when_enabled, no_implicit_conditions *)
  	rule drain_ret_fifo_fill_out_fifo(outFM.notFull&&outFD.notFull);
  		Vector#(n_rd, Bool) hasResp = unpack(0);
  		for(Integer i=0; i < valueOf(n_rd); i=i+1) begin
  			hasResp[i] = retFM[i].notEmpty();
  		end
  		Vector#(n_rd, Bool) retGrant = unpack(0);
  		retGrant <- ret_arb.select(hasResp);

  		for(Integer i=0; i < valueOf(n_rd); i=i+1) begin
  			if (retGrant[i]) begin
  				noPmem[i][1] <= noPmem[i][1] - 1;
  				outFM.enq(retFM[i].first);
  				outFD.enq(retFD[i].first);
  				retFM[i].deq();
  				retFD[i].deq();
  			end
  		end	
  	endrule

	method Action tx(Bit#(b_) a, mdata m);
		inFA.enq(a);
		inFM.enq(m);
	endmethod
	method Bool txFull();
		return (!inFM.notFull());
	endmethod
	method Bool txAlmostFull();
		return True; // Always true so do NOT use.
	endmethod

	method Bool rxEmpty();
		return !outFM.notEmpty();
	endmethod
	method Bool rxAlmostEmpty();
			return True; // Always true so do NOT use.
	endmethod
	method Action rxPop();
		outFM.deq();
		outFD.deq();
	endmethod
	method mdata rxMarg();
		return outFM.first();
	endmethod
	method data rxData();
		return outFD.first();
	endmethod

endmodule

module mkWrInvY#(Bool fair_arb, Integer shift, Vector#(n_wr,WrChannel#(Bit#(b_),mdata,data,thresh,n_out_mem)) wrM) 
										(WrChannel#(Bit#(b_),mdata,data,thresh,n_out_in))
							provisos(Bits#(data,c_),
									 Bits#(mdata,m_),
									 Log#(n_wr,h_),
									 Log#(n_out_mem,l_),
									 Add#(l_, 1, inL),
									 Add#(a__, h_, b_));

		//Integer vthresh = 4;
		Integer vthresh = 2 + valueOf(thresh);
		//Integer retthresh = valueOf(n_wr)*valueOf(n_out_in);
		Integer retthresh = valueOf(n_out_in);
		
	FIFOF#(Bit#(b_))  inFA <- mkUGSizedFIFOF(vthresh);
	FIFOF#(mdata) inFM <- mkUGSizedFIFOF(vthresh);
	FIFOF#(data)  inFD <- mkUGSizedFIFOF(vthresh);

	FIFOF#(mdata) outFM <- mkUGSizedFIFOF(vthresh);

	Vector#(n_wr,FIFOF#(mdata)) retFM <- replicateM(mkUGSizedFIFOF(retthresh));

	Vector#(n_wr, Array#(Reg#(UInt#(inL)))) noPmem <- replicateM(mkCReg(2,0));

	Arbiter#(n_wr) ret_arb;
	if (fair_arb) begin
		ret_arb <- mkRoundRobinArbiter();
	end else begin
		ret_arb <- mkStaticPriorityArbiterStartAt(0);
	end

	function UInt#(h_) hash (Bit#(b_) a);
		return truncate(unpack((a>>fromInteger(shift)) % fromInteger(valueOf(n_wr))));
	endfunction

	function Bool returnFullPressure();
		Bool valFull = False;
		for(Integer i=0; i < valueOf(n_wr); i=i+1) begin
			valFull = valFull || (noPmem[i][0]>=fromInteger(retthresh));
		end
		return valFull;
	endfunction

	(* fire_when_enabled *)
	rule drain_in_fifo(inFM.notEmpty&&inFA.notEmpty&&inFD.notEmpty);
		mdata txM = inFM.first;
		Bit#(b_) txA = inFA.first;
		UInt#(h_) h_fun = hash(txA);
		data txD = inFD.first;
		for(Integer i=0; i < valueOf(n_wr); i=i+1) begin
			UInt#(h_) outP = fromInteger(i);
			if (outP == h_fun) begin
				if ((!wrM[i].txFull) && (noPmem[i][0]<fromInteger(retthresh))) begin
					wrM[i].tx(txA,txM,txD);
				//end else begin
				//	inFM.enq(txM);
				//	inFA.enq(txA);
				//end
					inFA.deq();
					inFM.deq();
					inFD.deq();
					noPmem[i][0] <= noPmem[i][0] + 1;
				end
			end
		end
	endrule

  	for(Integer i=0; i < valueOf(n_wr); i=i+1) begin	
		rule fill_ret_fifo(!wrM[i].rxEmpty);
			retFM[i].enq(wrM[i].rxMarg);
			wrM[i].rxPop();
		endrule
	end

	(* fire_when_enabled, no_implicit_conditions *)
  	rule drain_ret_fifo_fill_out_fifo(outFM.notFull);
  		Vector#(n_wr, Bool) hasResp = unpack(0);
  		for(Integer i=0; i < valueOf(n_wr); i=i+1) begin
  			hasResp[i] = retFM[i].notEmpty();
  		end
  		Vector#(n_wr, Bool) retGrant = unpack(0);
  		retGrant <- ret_arb.select(hasResp);

  		for(Integer i=0; i < valueOf(n_wr); i=i+1) begin
  			if (retGrant[i]) begin
  				noPmem[i][1] <= noPmem[i][1] - 1;
  				outFM.enq(retFM[i].first);
  				retFM[i].deq();
  			end
  		end	
  	endrule

	method Action tx(Bit#(b_) a, mdata m, data d);
		inFA.enq(a);
		inFM.enq(m);
		inFD.enq(d);
	endmethod
	method Bool txFull();
		return (!inFM.notFull());
	endmethod
	method Bool txAlmostFull();
		return True; // Always true so do NOT use.
	endmethod

	method Bool rxEmpty();
		return !outFM.notEmpty();
	endmethod
	method Bool rxAlmostEmpty();
			return True; // Always true so do NOT use.
	endmethod
	method Action rxPop();
		outFM.deq();
	endmethod
	method mdata rxMarg();
		return outFM.first();
	endmethod

endmodule

module mkTopConvertHARP (TopConvertHARP#(margR,margW,addr,mdata,data,thresh,n_out))
							provisos(Bits#(margR,mr_),
									 Bits#(margW,mw_),
									 Bits#(mdata,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 //Max#(mr_,a_,a_),
									 Add#(a__,mr_,a_),
									 //Max#(mw_,a_,a_),
									 Add#(b__,mw_,a_),
									 Literal#(mdata),
									 Literal#(addr),
									 Literal#(data));

	RdChannel#(addr,margR,data,thresh,n_out) readCh;
	WrChannel#(addr,margW,data,thresh,n_out) writeCh;
	ChannelsTopHARP#(addr,mdata,data) chTopCh;

	FIFOF#(addr)  rd_inFA <- mkUGFIFOF();
	FIFOF#(mdata) rd_inFM <- mkUGFIFOF();

	FIFOF#(addr)  wr_inFA <- mkUGFIFOF();
	FIFOF#(mdata) wr_inFM <- mkUGFIFOF();
	FIFOF#(data)  wr_inFD <- mkUGFIFOF();

	//Wire#(Bool) w_rdRspValid <- mkDWire(False);
	//Wire#(data) w_rdRspData <- mkDWire(0);
	//Wire#(mdata) w_rdRspMdata <- mkDWire(16383);
    
    Reg#(Bool) w_rdRspValid <- mkReg(False);
	Reg#(data) w_rdRspData <- mkReg(0);
	Reg#(mdata) w_rdRspMdata <- mkReg(16383);
	Wire#(Bool) r_rdSent <- mkDWire(False);

	//FIFOF#(mdata) wr_retFM <- mkUGFIFOF();
	//Wire#(Bool) w_wrRspValid <- mkDWire(False);
	//Wire#(mdata) w_wrRspMdata <- mkDWire(16383);
	Reg#(Bool) w_wrRspValid <- mkReg(False);
	Reg#(mdata) w_wrRspMdata <- mkReg(16383);
	Wire#(Bool) w_wrSent <- mkDWire(False);
	
			  	let r_ifc = interface RdChannel#(addr,margR,data);
					method Bool txFull();
						return !rd_inFM.notFull();
					endmethod
					method Bool txAlmostFull();
						return False;
					endmethod
					method Action tx(addr a, margR m);
						rd_inFM.enq(unpack(extend(pack(m))));
						rd_inFA.enq(a);
					endmethod

					method Bool rxEmpty();
						return !w_rdRspValid; //I don't like thifs
					endmethod
					method Bool rxAlmostEmpty();
						return False;
					endmethod 
					method Action rxPop();
						noAction;
					endmethod
					method margR rxMarg();
						return unpack(truncate(pack(w_rdRspMdata)));
					endmethod
					method data rxData();
						return w_rdRspData;
					endmethod
				endinterface;
				readCh = r_ifc;	
				
			  	let w_ifc = interface WrChannel#(addr,margW,data);
					method Bool txFull();
						return !wr_inFM.notFull();
					endmethod
					method Bool txAlmostFull();
						return False;
					endmethod
					method Action tx(addr a, margW m, data d);
						wr_inFA.enq(a);
						wr_inFM.enq(unpack(extend(pack(m))));
						wr_inFD.enq(d);
					endmethod

					method Bool rxEmpty();
						return !w_wrRspValid; //I don't like this
						//return !wr_retFM.notEmpty();
					endmethod
					method Bool rxAlmostEmpty();
						return False;
					endmethod 
					method Action rxPop();
						noAction;
						//wr_retFM.deq();
					endmethod
					method margW rxMarg();
						return unpack(truncate(pack(w_wrRspMdata)));
						//return wr_retFM.first();
					endmethod
				endinterface;
				writeCh = w_ifc;	
				
				let tp_ifc = interface ChannelsTopHARP#(addr,mdata,data);
					method addr rdReqAddr();
						return rd_inFA.first();
					endmethod
					method mdata rdReqMdata();
						return rd_inFM.first();
					endmethod
					method Bool rdReqEN();
						return rd_inFM.notEmpty() && r_rdSent;
					endmethod
					/*method Action rdReqSent(Bool b);
						if (b) begin
							rd_inFM.deq();
							rd_inFA.deq();
						end
					endmethod*/
					method Action rdReqSent(Bool b);
						if (b && rd_inFM.notEmpty()) begin
							rd_inFM.deq();
							rd_inFA.deq();
						end
						r_rdSent <= b;
					endmethod

					method Action rdRspMdata(mdata m);
						w_rdRspMdata <= m;
					endmethod
					method Action rdRspData(data d);
						w_rdRspData <= d;
					endmethod
					method Action rdRspValid(Bool b);
						//FIXME
						w_rdRspValid <= b; //I don't like this
					endmethod

					method addr wrReqAddr();
						return wr_inFA.first();
					endmethod
					method mdata wrReqMdata();
						return wr_inFM.first();
					endmethod
					method data wrReqData();
						return wr_inFD.first();
					endmethod
					method Bool wrReqEN();
						return wr_inFM.notEmpty() && w_wrSent;
					endmethod
					method Action wrReqSent(Bool b);
						if (b && wr_inFM.notEmpty()) begin
							wr_inFM.deq();
							wr_inFA.deq();
							wr_inFD.deq();
						end
						w_wrSent <= b;
					endmethod

					method Action wrRspMdata(mdata m);
						w_wrRspMdata <= m;
						//wr_retFM.enq(m);
					endmethod
					method Action wrRspValid(Bool b);
						//FIXME
						w_wrRspValid <= b; //I don't like this
					endmethod
				endinterface;
				chTopCh = tp_ifc;
						 
		interface top = chTopCh;
		interface rdch = readCh;
		interface wrch = writeCh;
endmodule

module mkTopConvertAxi (TopConvertAxi#(margR,margW,addr,mdata,data,thresh,n_out))
							provisos(Bits#(margR,mr_),
									 Bits#(margW,mw_),
									 Bits#(mdata,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 //Max#(mr_,a_,a_),
									 Add#(a__,mr_,a_),
									 //Max#(mw_,a_,a_),
									 Add#(b__,mw_,a_),
									 Bitwise#(addr),
									 Literal#(mdata),
									 Literal#(addr),
									 Literal#(data),
              Alias#(AXI4_ADDR_CMD#(mdata,addr), t_ADDR_CMD), 
              Alias#(AXI4_WRITE_DATA#(mdata,data), t_WRITE_DATA), 
              Alias#(AXI4_READ_RESP#(mdata,data), t_READ_RESP), 
              Alias#(AXI4_WRITE_RESP#(mdata), t_WRITE_RESP));

	RdChannel#(addr,margR,data,thresh,n_out) readCh;
	WrChannel#(addr,margW,data,thresh,n_out) writeCh;
	HLS_AXI_BUS_IFC#(addr,mdata,data) chTopCh;

	FIFOF#(t_ADDR_CMD)     readReqQ <- mkUGSizedFIFOF(4);
    	FIFOF#(t_ADDR_CMD)    writeReqQ <- mkUGSizedFIFOF(4);
    	FIFOF#(t_WRITE_DATA) writeDataQ <- mkUGSizedFIFOF(4);
    	FIFOF#(t_READ_RESP)   readRespQ <- mkUGFIFOF();
    	FIFOF#(t_WRITE_RESP) writeRespQ <- mkUGFIFOF();
	Integer shift = valueOf(TLog#(TDiv#(c_,8)));
 
	
			  	let r_ifc = interface RdChannel#(addr,margR,data);
					method Bool txFull();
						return !readReqQ.notFull;
					endmethod
					method Bool txAlmostFull();
						return True; //Don't use
					endmethod
					method Action tx(addr a, margR m);
						let req = AXI4_ADDR_CMD { id: unpack(extend(pack(m))), len: fromInteger(0), size: fromInteger(3), burst: INCR, add: a<<shift };
        				readReqQ.enq(req);
					endmethod

					method Bool rxEmpty();
						return !readRespQ.notEmpty; //I don't like this
					endmethod
					method Bool rxAlmostEmpty();
						return True;
					endmethod 
					method Action rxPop();
						readRespQ.deq();
					endmethod
					method margR rxMarg();
						return unpack(truncate(pack(readRespQ.first.id)));
					endmethod
					method data rxData();
						return readRespQ.first.dat;
					endmethod
				endinterface;
				readCh = r_ifc;	
				
			  	let w_ifc = interface WrChannel#(addr,margW,data);
					method Bool txFull();
						return (!writeReqQ.notFull || !writeDataQ.notFull); 
					endmethod
					method Bool txAlmostFull();
						return True; //Don't use
					endmethod
					method Action tx(addr a, margW m, data d);
						let req = AXI4_ADDR_CMD { id: unpack(extend(pack(m))), len: fromInteger(0), size: fromInteger(3), burst: INCR, add: a<<shift };
        				writeReqQ.enq(req);
        				let dat = AXI4_WRITE_DATA { id: unpack(extend(pack(m))), dat: d, strb: 'hFF, last: True };
        				writeDataQ.enq(dat);
					endmethod

					method Bool rxEmpty();
						return !writeRespQ.notEmpty; //I don't like this
					endmethod
					method Bool rxAlmostEmpty();
						return True;
					endmethod 
					method Action rxPop();
						writeRespQ.deq;
					endmethod
					method margW rxMarg();
						return unpack(truncate(pack(writeRespQ.first.id)));
					endmethod
				endinterface;
				writeCh = w_ifc;	
				
				// SIZE = Log2( ( (USER_DATA_WIDTH/8) == USER_DATA_BYTES ) )
				// LEN => LEN+1 == XFER LENGTH
				// BURST = 1 (incrementing)

				let a_t = interface HLS_AXI_BUS_IFC;
				    interface AXI4_READ_MASTER readPort;
					    // Address Outputs
					    method arId = readReqQ.first.id;
					    method arAddr = readReqQ.first.add;
					    method arLen = readReqQ.first.len;
					    method arSize = readReqQ.first.size;
					    method arBurst = readReqQ.first.burst;
					    method arLock = 2'b00;
					    method arCache = 4'b0011;
					    method arQOS = 4'b0000;
					    method arProt = 3'b000;
					    method arValid = readReqQ.notEmpty;
					    // Address Inputs
					    method Action arReady();
					    	if (readReqQ.notEmpty) readReqQ.deq();
					    endmethod
					    // Response Outputs
					    method Bool rReady = readRespQ.notFull;
					    // Response Inputs
    					method Action readData(mdata id, data datt, AXI4Resp resp, Bool last);
    						let rsp = AXI4_READ_RESP { id: id, dat: datt, resp: resp, last: last };
    						readRespQ.enq(rsp);
    					endmethod
					    //method Action rId(Bit#(t_ID_SZ) id);
					    //method Action rData(Bit#(t_DATA_SZ) data);
					    //method Action rResp(AXI4Resp resp);
					    //method Action rLast();
					    //method Action rValid();
					endinterface
				    interface AXI4_WRITE_MASTER writePort;
					    // Address Outputs
					    method awId = writeReqQ.first.id;
					    method awAddr = writeReqQ.first.add;
					    method awLen = writeReqQ.first.len;
					    method awSize = writeReqQ.first.size;
					    method awBurst = writeReqQ.first.burst;
					    method awLock = 2'b00;
					    method awCache = 4'b0011;
					    method awQOS = 4'b0000;
					    method awProt = 3'b000;
					    method awValid = writeReqQ.notEmpty;
					    // Address Inputs
					    method Action awReady();
					    	if (writeReqQ.notEmpty) writeReqQ.deq();
					    endmethod
					    // Write Data Outputs
					    method wId = writeDataQ.first.id; 
					    method wData = writeDataQ.first.dat;
					    method wStrb = writeDataQ.first.strb;
					    method wLast = writeDataQ.first.last;
					    method wValid = writeDataQ.notEmpty;
					    // Write Data Inputs
					    method Action wReady();
						if (writeDataQ.notEmpty) writeDataQ.deq();
					    endmethod
					    // Response Outputs
					    method Bool bReady = writeRespQ.notFull;
					    // Response Inputs
    					method Action writeResp(mdata id, AXI4Resp resp);
    						let rsp = AXI4_WRITE_RESP { id: id, resp: resp };
    						writeRespQ.enq(rsp);
    					endmethod
					    //method Action bId(Bit#(t_ID_SZ) id);
					    //method Action bResp(AXI4Resp resp);
					    //method Action bValid();
					endinterface
				endinterface;
				chTopCh = a_t;
						 
		interface rdch = readCh;
		interface wrch = writeCh;
		interface top = chTopCh;
endmodule

typedef enum {
  Idle,
  ReadReq,
  WriteReq	
} MasterStates deriving (Bits,Eq);

module mkTopConvertAvalon (TopConvertAvalon#(margR,margW,addr,mdata,data,thresh,n_out))
							provisos(Bits#(margR,mr_),
								 	 Bits#(margW,mw_),
									 Bits#(mdata,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 //Max#(mr_,a_,a_),
									 Add#(a__,mr_,a_),
									 //Max#(mw_,a_,a_),
									 Add#(b__,mw_,a_),
									 Literal#(mdata),
									 Literal#(addr),
									 Literal#(data));

	RdChannel#(addr,margR,data,thresh,n_out) readCh;
	WrChannel#(addr,margW,data,thresh,n_out) writeCh;
	AVALON_MASTER#(addr,mdata,data) chTopCh;

	    FIFOF#(addr)     readReqQ_a <- mkUGSizedFIFOF(4);
	    FIFOF#(mdata)     readReqQ_m <- mkUGSizedFIFOF(4);
    	FIFOF#(addr)    writeReqQ_a <- mkUGSizedFIFOF(4);
    	FIFOF#(mdata)    writeReqQ_m <- mkUGSizedFIFOF(4);
    	FIFOF#(data) writeDataQ <- mkUGSizedFIFOF(4);
    	FIFOF#(mdata)   readRespQ <- mkUGFIFOF();
    	FIFOF#(data)   readRespQ_d <- mkUGFIFOF();
    	FIFOF#(mdata) writeRespQ <- mkUGFIFOF();
    	FIFOF#(mdata) readTagQ <- mkUGSizedFIFOF(4*valueOf(n_out));
	
			  	let r_ifc = interface RdChannel#(addr,margR,data);
					method Bool txFull();
				        //Handle TagQ Full
						return !readReqQ_m.notFull;
					endmethod
					method Bool txAlmostFull();
						return True; //Don't use
					endmethod
					method Action tx(addr a, margR m);
        				readReqQ_a.enq(a);
        				readReqQ_m.enq(unpack(extend(pack(m))));
					endmethod

					method Bool rxEmpty();
						return !readRespQ.notEmpty; //I don't like this
					endmethod
					method Bool rxAlmostEmpty();
						return True;
					endmethod 
					method Action rxPop();
						readRespQ_d.deq();
						readRespQ.deq();
					endmethod
					method margR rxMarg();
						return unpack(truncate(pack(readRespQ.first)));
					endmethod
					method data rxData();
						return readRespQ_d.first;
					endmethod
				endinterface;
				readCh = r_ifc;	
				
			  	let w_ifc = interface WrChannel#(addr,margW,data);
					method Bool txFull();
						return (!writeReqQ_m.notFull || !writeDataQ.notFull); 
					endmethod
					method Bool txAlmostFull();
						return True; //Don't use
					endmethod
					method Action tx(addr a, margW m, data d);
        				writeReqQ_a.enq(a);
        				writeReqQ_m.enq(unpack(extend(pack(m))));
        				writeDataQ.enq(d);
					endmethod

					method Bool rxEmpty();
						return !writeRespQ.notEmpty; //I don't like this
					endmethod
					method Bool rxAlmostEmpty();
						return True;
					endmethod 
					method Action rxPop();
						writeRespQ.deq;
					endmethod
					method margW rxMarg();
						return unpack(truncate(pack(writeRespQ.first)));
					endmethod
				endinterface;
				writeCh = w_ifc;	
				
				  Reg#(addr) addrReg <- mkReg(0); 
				  Reg#(data) dataOut <- mkReg(0);
				  Reg#(Bool) readReg <- mkReg(False);
				  Reg#(Bool) writeReg <- mkReg(False);
				  Reg#(data) dataIn <- mkRegU;
				  Reg#(Bool) readdatavalidIn <- mkReg(False);
				  PulseWire waitrequestIn <- mkPulseWire;
				  Reg#(MasterStates) state <- mkReg(Idle);

				  //Handle TagQ Full
				  rule start(state == Idle);
				    if(writeReqQ_m.notEmpty)
				      begin
				        writeReg <= True;
				        readReg <= False;
				        dataOut <= writeDataQ.first;
				        addrReg <= writeReqQ_a.first;
				        state <= WriteReq;
				        writeRespQ.enq(writeReqQ_m.first);
				        writeReqQ_m.deq;
				        writeReqQ_a.deq;
				        writeDataQ.deq;
				      end
				    else if (readReqQ_m.notEmpty && readTagQ.notFull) //handle Read
				      begin
				        writeReg <= False;
				        readReg <= True;
				        dataOut <= 0;
				        addrReg <= readReqQ_a.first;
				        state <= ReadReq;
				        readTagQ.enq(readReqQ_m.first);
				        readReqQ_a.deq;
				        readReqQ_m.deq;
				      end
				  endrule

				  rule handleReq((state == ReadReq || state == WriteReq) && !waitrequestIn);
				    state <= Idle;
				    readReg <= False;
				    writeReg <= False;
				  endrule

				  rule handleResp(readdatavalidIn);
				  	readRespQ.enq(readTagQ.first);
				    readRespQ_d.enq(dataIn);
				    readTagQ.deq;
				  endrule

				let a_t = interface AVALON_MASTER; 
  					method Bool read();		
      					return readReg;
    				endmethod
   
  					method Bool write();		
      					return writeReg;
    				endmethod
 
  					method addr address();
  						return addrReg;
  					endmethod
 
  					method data writedata();  
  						return dataOut;
  					endmethod

  					method Action readdata(data rd);
  						dataIn <= rd;
  					endmethod
 
  					method Action waitrequest(Bool waitrequestN);
  						if (waitrequestN) begin
  							waitrequestIn.send;
  						end
  					endmethod

  					method Action readdatavalid(Bool readdatavalidN);
  						readdatavalidIn <= readdatavalidN;
  					endmethod

  					method Bit#(7) burstcount();
  						return 1;
  					endmethod

  					method Bit#(TDiv#(SizeOf#(data),8)) byteenable();
						Vector#(TDiv#(SizeOf#(data),8),Bit#(1)) vec = replicate(1'b1);
  						return pack(vec);
  					endmethod
				endinterface;
				chTopCh = a_t;
						 
		interface rdch = readCh;
		interface wrch = writeCh;
		interface top = chTopCh;
endmodule

module mkSyncChannelRd#(Clock clkM, Reset rstM, RdChannel#(addr,marg,data,thresh,n_out) rdM) 
										(RdChannel#(addr,marg,data,thresh,n_out))
							provisos(Bits#(marg,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 Log#(n_out,n_),
									 Add#(n_,d_,a_),
									 Add#(1, a__, a_),
									 Add#(1, b__, b_),
									 Add#(1, c__, c_),
									 Mul#(n_out,16,n_mem));

	
	SyncFIFOIfc#(addr) sync_AddrReqQ <- mkSyncBRAMFIFOFromCC(valueOf(n_out),clkM,rstM);
	SyncFIFOIfc#(marg) sync_MargReqQ <- mkSyncBRAMFIFOFromCC(valueOf(n_out),clkM,rstM);

	SyncFIFOIfc#(data) sync_DataRspQ <- mkSyncBRAMFIFOToCC(valueOf(n_out),clkM,rstM);
	SyncFIFOIfc#(marg) sync_MargRspQ <- mkSyncBRAMFIFOToCC(valueOf(n_out),clkM,rstM);

	//(* no_implicit_conditions *)
	rule get_response(!rdM.rxEmpty&&sync_MargRspQ.notFull);
		sync_MargRspQ.enq(rdM.rxMarg());
		sync_DataRspQ.enq(rdM.rxData()); 
		rdM.rxPop();
	endrule

	rule send_request(sync_MargReqQ.notEmpty&&!rdM.txFull);
		marg mm = sync_MargReqQ.first;
		addr aa = sync_AddrReqQ.first;
		sync_MargReqQ.deq;
		sync_AddrReqQ.deq;
		rdM.tx(aa,mm);
	endrule

		method Bool txFull();
			return !sync_MargReqQ.notFull;
		endmethod
		method Bool txAlmostFull();
			return True;
		endmethod
		method Action tx(addr a, marg m);
			sync_AddrReqQ.enq(a);
			sync_MargReqQ.enq(m);
		endmethod

		method Bool rxEmpty();
			return !sync_MargRspQ.notEmpty();
		endmethod
		method Bool rxAlmostEmpty();
			return True;
		endmethod 
		method Action rxPop();
			sync_MargRspQ.deq();
			sync_DataRspQ.deq();
		endmethod
		method marg rxMarg();
			return sync_MargRspQ.first();
		endmethod
		method data rxData();
			return sync_DataRspQ.first();
		endmethod

endmodule

module mkSyncChannelWr#(Clock clkM, Reset rstM, WrChannel#(addr,marg,data,thresh,n_out) rdM) 
										(WrChannel#(addr,marg,data,thresh,n_out))
							provisos(Bits#(marg,a_),
									 Bits#(addr,b_),
									 Bits#(data,c_),
									 Log#(n_out,n_),
									 Add#(n_,d_,a_),
									 Add#(1, a__, a_),
									 Add#(1, b__, b_),
									 Add#(1, c__, c_),
									 Mul#(n_out,16,n_mem));
	
	SyncFIFOIfc#(addr) sync_AddrReqQ <- mkSyncBRAMFIFOFromCC(valueOf(n_out),clkM,rstM);
	SyncFIFOIfc#(marg) sync_MargReqQ <- mkSyncBRAMFIFOFromCC(valueOf(n_out),clkM,rstM);
	SyncFIFOIfc#(data) sync_DataReqQ <- mkSyncBRAMFIFOFromCC(valueOf(n_out),clkM,rstM);

	SyncFIFOIfc#(marg) sync_MargRspQ <- mkSyncBRAMFIFOToCC(valueOf(n_out),clkM,rstM);

	//(* no_implicit_conditions *)
	rule get_response(!rdM.rxEmpty&&sync_MargRspQ.notFull);
		sync_MargRspQ.enq(rdM.rxMarg());
		rdM.rxPop();
	endrule

	rule send_request(sync_MargReqQ.notEmpty&&!rdM.txFull);
		marg mm = sync_MargReqQ.first;
		addr aa = sync_AddrReqQ.first;
		data dd = sync_DataReqQ.first;
		sync_MargReqQ.deq;
		sync_AddrReqQ.deq;
		sync_DataReqQ.deq;
		rdM.tx(aa,mm,dd);
	endrule

		method Bool txFull();
			return !sync_MargReqQ.notFull;
		endmethod
		method Bool txAlmostFull();
			return True;
		endmethod
		method Action tx(addr a, marg m, data d);
			sync_AddrReqQ.enq(a);
			sync_MargReqQ.enq(m);
			sync_DataReqQ.enq(d);
		endmethod

		method Bool rxEmpty();
			return !sync_MargRspQ.notEmpty();
		endmethod
		method Bool rxAlmostEmpty();
			return True;
		endmethod 
		method Action rxPop();
			sync_MargRspQ.deq();
		endmethod
		method marg rxMarg();
			return sync_MargRspQ.first();
		endmethod

endmodule

endpackage 
