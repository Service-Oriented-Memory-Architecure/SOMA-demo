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
// FIFO with almostFull and almostEmpty signals
//

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
