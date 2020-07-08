package FIFOFA;

import FIFOLevel::*;
import FIFOF::*;

interface FIFOFA#(type a, numeric type n, numeric type depth);
	method Action enq (a x);
	method Action deq;
	method a first;
	method Action clear;
	method Bool notFull;
	method Bool notEmpty;
	method Bool notAlmostFull;
	method Bool notAlmostEmpty;
endinterface: FIFOFA

module mkFIFOFA (FIFOFA#(a,n,depth))
            provisos(Bits#(a,as),
            	     Max#(depth,n,d));
		//Bounded#(n),
		//Bounded#(depth));

	FIFOLevelIfc#(a,d) store <- mkFIFOLevel();

	method Action enq(a x);
		store.enq(x);
	endmethod

	method Action deq();
		store.deq();
	endmethod

	method a first();
		return store.first();
	endmethod

	method Action clear();
		store.clear();
	endmethod

	method Bool notFull();
		return store.notFull();
	endmethod

	method Bool notEmpty();
		return store.notEmpty();
	endmethod

	method Bool notAlmostFull();
		return !(store.isGreaterThan(valueOf(d)-valueOf(n)));
	endmethod

	method Bool notAlmostEmpty();
		return !(store.isLessThan(valueOf(n)));
	endmethod
endmodule: mkFIFOFA

module mkFIFOFAU (FIFOFA#(a,n,depth))
            provisos(Bits#(a,as),
            	     Max#(depth,n,d));
		//Bounded#(n),
		//Bounded#(depth));

        FIFOF#(a) store <- mkUGSizedFIFOF(valueOf(depth));
        Reg#(UInt#(TLog#(depth))) count[2] <- mkCReg(2,0);
	UInt#(TLog#(depth)) fullThresh = fromInteger(valueOf(depth)) - fromInteger(valueOf(n));
	UInt#(TLog#(depth)) emptyThresh = fromInteger(valueOf(n));

	method Action enq(a x);
		count[1] <= count[1] + 1;
		store.enq(x);
	endmethod

	method Action deq();
                count[0] <= count[0] - 1;
		store.deq();
	endmethod

	method a first();
		return store.first();
	endmethod

	method Action clear();
		store.clear();
	endmethod

	method Bool notFull();
		return store.notFull();
	endmethod

	method Bool notEmpty();
		return store.notEmpty();
	endmethod

	method Bool notAlmostFull();
		return (count[1] < fullThresh);
	endmethod

	method Bool notAlmostEmpty();
		return (count[1] > emptyThresh);
	endmethod
endmodule

endpackage
