package CBuffer;

import Vector::*;
import RegFile::*;
import ConfigReg::*;
import FIFOF::*;
import FIFOFA::*;
import FIFOLevel::*;
import GetPut::*;
import CompletionBuffer::*;

interface CBuffer#(type m, type t, type g, numeric type thresh, numeric type size);
	method ActionValue#(g) reserve(m a);
	method Bool canReserve();
	method Action complete(g e, t d);

	//method m getMeta(Tag g);

	method Action deq();
	method t firstData();
	method m firstMeta();
	method Bool notEmpty();
	method Bool notAlmostEmpty();
	method Bit#(TAdd#(TLog#(size),1)) count();
endinterface: CBuffer

interface COUNTER#(numeric type nBits);
    // The value at the beginning of the FPGA cycle.
    method Bit#(nBits) value();

    method Action up();
    method Action upBy(Bit#(nBits) c);

    method Action down();
    method Action downBy(Bit#(nBits) c);

    method Action setC(Bit#(nBits) newVal);

    // Is value() zero?
    method Bool isZero();
endinterface: COUNTER

interface SAMPLER#(numeric type nBits, numeric type nBuckets, numeric type bucketShift);
    method Bit#(nBits) total();
    method Bit#(nBits) samples();
    method Bit#(nBits) min();
    method Bit#(nBits) max();
    method Bit#(nBits) getBucket(Bit#(TLog#(nBuckets)) b);

    method Action addSample(Bit#(nBits) c);

    method Action clear();
endinterface: SAMPLER

interface CompletionDelay#(numeric type nBits, type g, numeric type size);
	method Action start(g e);
	method ActionValue#(Bit#(nBits)) stop(g e);
endinterface: CompletionDelay

interface InterarrivalTime#(numeric type nBits);
	method ActionValue#(Bit#(nBits)) arrival();
endinterface: InterarrivalTime

module mkCompletionBuffer (CBuffer#(m,t,g,thresh,size))
						provisos(//Literal#(m),
								 Bits#(m,a_),
								 Bits#(g,d_),
								 Log#(size,d_),
								 //Ord#(g),
								 //Arith#(g),
								 //PrimIndex#(g,c_),
								 Bits#(Maybe#(t), b_));	

	Integer vsize = valueOf(size);
	Bit#(TAdd#(d_,1)) sz = fromInteger(vsize);
	Integer vthresh = valueOf(thresh);
	Bit#(TAdd#(d_,1)) th = fromInteger(vthresh);
	Integer mi = valueOf(TSub#(TExp#(TAdd#(d_,1)),1));
	Bit#(TAdd#(d_,1)) maxIndex = fromInteger(mi);
	
	//Vector#(size, Reg#(Bool)) req <- replicateM(mkReg(False)); //regfile here...
	//Vector#(size, Reg#(Bool)) rdy <- replicateM(mkReg(False)); //...here too
	RegFile#(Bit#(TAdd#(d_,1)),Bool) req <- mkRegFile(0,sz); //regfile here...
	RegFile#(Bit#(TAdd#(d_,1)),Bool) rdy <- mkRegFile(0,sz); //...here too
	//Vector#(size, Reg#(m)) 	  mb  <- replicateM(mkReg(?));
	//Vector#(size, Reg#(t)) 	  cb  <- replicateM(mkReg(?));
	RegFile#(Bit#(TAdd#(d_,1)),m) mb <- mkRegFile(0,sz); //regfile here...
	RegFile#(Bit#(TAdd#(d_,1)),t) cb <- mkRegFile(0,sz); //...here too
	Reg#(Bit#(TAdd#(d_,1)))   iidx <- mkReg(0);
	Reg#(Bit#(TAdd#(d_,1)))   ridx <- mkReg(0);
	//Reg#(Bit#(TAdd#(d_,1)))   cnt  <- mkReg(0); //single update rule    
	COUNTER#(TAdd#(d_,1)) cnt <- mkLCounter(0);

	//Wire#(Bool) resV <- mkDWire(False); 
	//Wire#(Bool) rdyV <- mkDWire(False);	
	//Wire#(Bit#(TAdd#(d_,1))) resIdx <- mkDWire(?); 
	//Wire#(Bit#(TAdd#(d_,1))) rdyIdx <- mkDWire(?); 
	RWire#(Bit#(TAdd#(d_,1))) resIdx <- mkRWire(); 
	RWire#(Bit#(TAdd#(d_,1))) rdyIdx <- mkRWire(); 

	Wire#(Bool) oldestReady <- mkDWire(False);

	function isNotFull() = (cnt.value != sz);
    function isNotEmpty() = (cnt.value != 0);
    function isNotAlmEmpty() = (cnt.value >= th);

    Reg#(Bool) didInit <- mkReg(False);
    Reg#(Bit#(TAdd#(d_,1))) initIdx <- mkReg(0);

    rule doInit (!didInit);
        req.upd(initIdx, False);
        rdy.upd(initIdx, False);

        if (initIdx == (sz-1))
        begin
            didInit <= True;
        end
        //$display("CB DID INIT %d sz %d size %d",initIdx,sz,valueOf(size));
        initIdx <= initIdx + 1;
    endrule

	(* fire_when_enabled, no_implicit_conditions *)
    rule checkOldest(didInit);
        Bool ready = (req.sub(ridx) == rdy.sub(ridx));
        oldestReady <= isNotEmpty() && ready;
    endrule
    (* fire_when_enabled, no_implicit_conditions *)
	//rule doReserve(didInit&&resV);
	rule doReserve(didInit &&& resIdx.wget() matches tagged Valid .idx);
		req.upd(idx, !req.sub(idx));
  		//$display("Reserve UD: idx %d",idx);
	endrule
	(* fire_when_enabled, no_implicit_conditions *)
	//rule doReady(didInit&&rdyV);
	rule doReady(didInit &&& rdyIdx.wget() matches tagged Valid .idx);
		rdy.upd(idx, req.sub(idx));
  		//$display("Ready UD: idx %d",idx);
	endrule

	method ActionValue#(g) reserve(m a) if (didInit && isNotFull());
		//resV <= True;
		//resIdx <= iidx;
		resIdx.wset(iidx);
		mb.upd(iidx, a);
		//cb[iidx] <= ?;
  		iidx <= iidx==sz-1 ? 0 : iidx + 1;
  		//cnt <= (cnt + 1);
  		cnt.up;
  		//$display("Reserve: idx %d md %d",iidx,a);
  		return unpack(truncate(iidx));   
	endmethod

	method Bool canReserve();
		return 	isNotFull();
	endmethod

	method Action complete(g e, t data);  
		Bit#(TAdd#(d_,1)) ie = extend(pack(e));
		//rdyV <= True;
		//rdyIdx <= ie;
		rdyIdx.wset(ie);
		cb.upd(ie, data);
  		$display("Complete: idx %d",ie);
	endmethod

	method Action deq() if (oldestReady);
  		ridx <= ridx==sz-1 ? 0 : ridx + 1;         
  		//cnt <= cnt - 1;
  		if (!oldestReady)
  			$display("ERROR Deq when oldest not ready. Not empty = %d",isNotEmpty);
  		cnt.down;   
	endmethod

	method m firstMeta() if (oldestReady);
		return mb.sub(ridx);
	endmethod

	method t firstData() if (oldestReady);
		return cb.sub(ridx);  
	endmethod

	method Bool notEmpty(); 
		return oldestReady();
	endmethod 

	method Bool notAlmostEmpty(); 
		return isNotAlmEmpty();
	endmethod

	method Bit#(TAdd#(TLog#(size),1)) count();
		return cnt.value;
	endmethod
endmodule: mkCompletionBuffer

module mkCompletionBufferBypass (CBuffer#(m,t,g,thresh,size))
						provisos(//Literal#(m),
								 Bits#(m,a_),
								 Bits#(g,d_),
								 Log#(size,d_),
								 //Ord#(g),
								 //Arith#(g),
								 //PrimIndex#(g,c_),
								 Bits#(Maybe#(t), b_));
	
	//typedef Bit#(TAdd#(d_,1)) ig;			

	Vector#(size, Array#(Reg#(Maybe#(t)))) cb <- replicateM(mkCReg(3, tagged Invalid));
	//Vector#(size, Array#(Reg#(Maybe#(m)))) mb <- replicateM(mkCReg(2,Invalid));
	Vector#(size, Array#(Reg#(m))) 		   mb <- replicateM(mkCReg(2,?));
	Reg#(Bit#(TAdd#(d_,1)))   iidx <- mkReg(0);
	Reg#(Bit#(TAdd#(d_,1)))   ridx <- mkReg(0);
	Reg#(Bit#(TAdd#(d_,1)))   cnt[2] <- mkCReg(2,0);
	Integer vsize = valueOf(size);
	Bit#(TAdd#(d_,1)) sz = fromInteger(vsize);
	Integer vthresh = valueOf(thresh);
	Bit#(TAdd#(d_,1)) th = fromInteger(vthresh);
	/*Reg#(g)   iidx <- mkReg(0);
	Reg#(g)   ridx <- mkReg(0);
	Reg#(g)   cnt[2] <- mkCReg(2,0);
	Integer vsize = valueOf(size);
	g sz = fromInteger(vsize);
	Integer vthresh = valueOf(thresh);
	g th = fromInteger(vthresh);*/

	method ActionValue#(g) reserve(m a); // if(cnt[0]!=sz);
		mb[iidx][0] <= a;
		cb[iidx][0] <= Invalid;
  		iidx <= iidx==sz-1 ? 0 : iidx + 1;
  		cnt[0] <= (cnt[0] + 1);
  		return unpack(truncate(iidx));   
	endmethod

	method Bool canReserve(); //Valid concurrency state??
		return 	cnt[0]<sz;
	endmethod

	method Action complete(g e, t data);  
		Bit#(TAdd#(d_,1)) ie = extend(pack(e));
		cb[ie][1] <= tagged Valid data;
	endmethod

	//method m getMeta(Tag g);
	//	return mb[g][1];
	//endmethod

	method Action deq();// if(cnt[1]!=0);
		cb[ridx][2] <= tagged Invalid;
  		ridx <= ridx==sz-1 ? 0 : ridx + 1;         
  		cnt[1] <= cnt[1] - 1;   
	endmethod

	method m firstMeta();// if(cnt[1] != 0 && isValid(cb[ridx][2]));
		return mb[ridx][1];
	endmethod

	method t firstData();// if(cnt[1] != 0 && isValid(cb[ridx][2]));
		return fromMaybe(?,cb[ridx][2]);  
		//return x;
	endmethod

	method Bool notEmpty(); //Valid concurrency state??
		return cnt[1] != 0 && isValid(cb[ridx][2]);
	endmethod 

	method Bool notAlmostEmpty(); //Valid concurrency state??
		return cnt[1] >= th && isValid(cb[ridx][2]);
	endmethod

	method Bit#(TAdd#(TLog#(size),1)) count();
		return cnt[1];
	endmethod
endmodule: mkCompletionBufferBypass

module mkCompletionBufferU (CBuffer#(m,t,g,thresh,size))
						provisos(Bits#(m,a_),
								 Bits#(Maybe#(t),b_),
								 //Literal#(m),
								 //Literal#(t),
								 Bits#(g,c_),
								 Log#(size,c_),
								 //Ord#(g),
								 //Arith#(g),
								 PrimIndex#(g,d_),
								 Bits#(t,e_));
								 //Add#(TLog#(size),1,TLog#(size)));

	Vector#(size, Array#(Reg#(Maybe#(t)))) cb <- replicateM(mkCReg(3, tagged Invalid));
	//Vector#(size, Array#(Reg#(Maybe#(m)))) mb <- replicateM(mkCReg(2,Invalid));
	Vector#(size, Array#(Reg#(m))) 		   mb <- replicateM(mkCReg(2,?));
	Reg#(Bit#(TAdd#(c_,1)))   iidx <- mkReg(0);
	Reg#(Bit#(TAdd#(c_,1)))   ridx <- mkReg(0);
	Reg#(Bit#(TAdd#(c_,1)))    cnt[2] <- mkCReg(2,0);
	Integer vsize = valueOf(size);
	Bit#(TAdd#(c_,1)) sz = fromInteger(vsize);
	Integer vthresh = valueOf(thresh);
	Bit#(TAdd#(c_,1)) th = fromInteger(vthresh);
	FIFOFA#(m,thresh,size) mf <- mkFIFOFAU;
	FIFOFA#(t,thresh,size) df <- mkFIFOFAU;

	rule dealocate(cnt[1] != 0 && isValid(cb[ridx][2]));
             		//(cb[ridx][2] matches tagged (Valid .x)));
		cb[ridx][2] <= tagged Invalid;
  		ridx <= ridx==sz-1 ? 0 : ridx + 1;         
  		cnt[1] <= cnt[1] - 1; 
	endrule

	method ActionValue#(g) reserve(m a); //if(cnt[0]!=sz);
		mb[iidx][0] <= a;
		cb[iidx][0] <= tagged Invalid;
  		iidx <= iidx==sz-1 ? 0 : iidx + 1;
  		cnt[0] <= (cnt[0] + 1);
		//$display("ENQ: %d",iidx); 
  		return unpack(truncate(iidx));   
	endmethod

	method Bool canReserve(); //Valid concurrency state??
		return 	cnt[0]!=sz;
	endmethod

	method Action complete(g e, t d);
	        Bit#(TAdd#(c_,1)) ie = extend(pack(e));	
		cb[ie][1] <= tagged Valid d;
		df.enq(d);
		mf.enq(mb[e][1]);
	endmethod

	method Action deq();
		df.deq();
		mf.deq();    
	endmethod

	method m firstMeta();
		return mf.first();
	endmethod

	method t firstData();
  		return df.first();
	endmethod

	method Bool notEmpty();
		return mf.notEmpty();
	endmethod 

	method Bool notAlmostEmpty();
		return mf.notAlmostEmpty();
	endmethod

	method Bit#(TAdd#(TLog#(size),1)) count();
		return cnt[1];
	endmethod

endmodule: mkCompletionBufferU

module mkLCounter#(Bit#(nBits) initialValue)
    // interface:
        (COUNTER#(nBits));

    // Counter value
    Reg#(Bit#(nBits)) ctr <- mkConfigReg(initialValue);
    // Is counter 0?
    Reg#(Bool) zero <- mkConfigReg(initialValue == 0);

    Wire#(Bit#(nBits)) upByW   <- mkUnsafeDWire(0);
    Wire#(Bit#(nBits)) downByW <- mkUnsafeDWire(0);
    RWire#(Bit#(nBits)) setcCalledW <- mkUnsafeRWire();

    (* fire_when_enabled, no_implicit_conditions *)
    rule updateCounter;
        Bit#(nBits) new_value;
        Bit#(nBits) base_value = ctr;

        if (setcCalledW.wget() matches tagged Valid .v)
            base_value = v;
       
        new_value = base_value + upByW - downByW;

        ctr <= new_value;
        zero <= (new_value == 0);
    endrule

    method Bit#(nBits) value();
        return ctr;
    endmethod

    method Action up();
        upByW <= 1;
    endmethod

    method Action upBy(Bit#(nBits) c);
        upByW <= c;
    endmethod

    method Action down();
        downByW <= 1;
    endmethod

    method Action downBy(Bit#(nBits) c);
        downByW <= c;
    endmethod

    method Action setC(Bit#(nBits) newVal);
        setcCalledW.wset(newVal);
    endmethod

    method Bool isZero();
        return zero;
    endmethod
endmodule: mkLCounter

module mkSampler
         (SAMPLER#(nBits,nBuckets,bucketShift))
         provisos(Add#(a__, TLog#(nBuckets), nBits));

    Bit#(TLog#(nBuckets)) logB = fromInteger(valueOf(bucketShift));
    Bit#(nBits) maxI = fromInteger(valueOf(nBuckets));
    Bit#(nBits) bound = fromInteger(-1);

    Vector#(nBuckets,COUNTER#(nBits)) histogram <- replicateM(mkLCounter(0));
    COUNTER#(nBits) sum     <- mkLCounter(0);
    COUNTER#(nBits) count <- mkLCounter(0);
    COUNTER#(nBits) minVal  <- mkLCounter(bound);
    COUNTER#(nBits) maxVal  <- mkLCounter(0);

    method Bit#(nBits) total();
    	return sum.value();
    endmethod
    method Bit#(nBits) samples();
    	return count.value();
    endmethod
    method Bit#(nBits) min();
    	return minVal.value();
    endmethod
    method Bit#(nBits) max();
    	return maxVal.value();
    endmethod    
    method Bit#(nBits) getBucket(Bit#(TLog#(nBuckets)) b);
    	return histogram[b].value;
    endmethod

    method Action addSample(Bit#(nBits) c);
    	sum.upBy(c);
    	count.up;
    	if (c<minVal.value) minVal.setC(c);
    	if (c>maxVal.value) maxVal.setC(c);
    	Bit#(nBits) shift = c>>logB;
    	Bit#(TLog#(nBuckets)) idx = (shift>=maxI) ? truncate(maxI-1) : truncate(shift);
    	histogram[idx].up;
    endmethod

    method Action clear();
    	sum.setC(0);
    	count.setC(0);
    	minVal.setC(0);
    	maxVal.setC(0);
  		for(Integer i=0; i < valueOf(nBuckets); i=i+1) begin
  			histogram[i].setC(0);
  		end
    endmethod
endmodule: mkSampler


module mkCompletionDelay
		 (CompletionDelay#(nBits,g,size))
		 provisos(Bits#(g,d_),
				  Log#(size,d_));

    Vector#(size,COUNTER#(nBits)) delay <- replicateM(mkLCounter(0));
    Vector#(size,Reg#(Bool)) tick <- replicateM(mkReg(False));

    for (Integer i=0; i<valueOf(size); i=i+1) begin
	    rule ticker(tick[i]);
	    	delay[i].up;
	    endrule
    end

	method Action start(g e);
		delay[pack(e)].setC(0);
		tick[pack(e)] <= True;
	endmethod
	method ActionValue#(Bit#(nBits)) stop(g e);
	    tick[pack(e)] <= False;
		return delay[pack(e)].value;
	endmethod
endmodule: mkCompletionDelay


module mkInterarrivalTime
	     (InterarrivalTime#(nBits));

    COUNTER#(nBits) ticker <- mkLCounter(0);

    rule spin;
    	ticker.up;
    endrule

	method ActionValue#(Bit#(nBits)) arrival();
		Bit#(nBits) last = ticker.value;
		ticker.setC(0);
		return last;
	endmethod
	// method Bit#(nBits) delay();
	// 	return ticker.value;
	// endmethod
endmodule: mkInterarrivalTime

endpackage
