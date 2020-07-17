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
// Utility module that keeps score of oustanding requests as a locking mechanism
//

package Scoreboard;

import FIFOLevel::*;
import RegFile::*;
import FIFOF::*;
import BRAMCore::*;
import Vector::*;

interface Scoreboard#(numeric type n, type st);
	method Action set(st x);
 	method Action clear1(st x);
 	method Action clear2(st x);
 	//method Bool   search(st x);
 	method Action search(st x);
 	method Bool   stall();
endinterface

interface ScoreboardSimple#(numeric type n, type st);
	method Action set(st x);
 	method Action clear1(st x);
 	method Action clear2(st x);
 	(* always_ready *) method Bool search(st x);
endinterface

module mkScoreboard(Scoreboard#(n, t)) provisos(Bits#(t, a_),Log#(n,filt_idx),Add#(a__, filt_idx, a_));

	//Vector#(n,Array#(Reg#(Bool))) filter <- replicateM(mkCReg(4,False)); 
	//Vector#(n,Array#(Reg#(Bool))) filter <- replicateM(mkCReg(2,False)); 
	Vector#(n,Reg#(Bool)) filter <- replicateM(mkReg(False)); 
	
	Reg#(Bool) searchOut <- mkReg(False);
	Reg#(Bool) setBypass <- mkReg(False);
	Reg#(Bool) clrBypass <- mkReg(False);
	Wire#(Bool) searchW <- mkDWire(False);
	//PulseWire searchW <- mkPulseWire();
	Wire#(Bit#(filt_idx)) searchIdx <- mkDWire(?);
	Reg#(Bit#(filt_idx)) searchIdx_reg[2] <- mkCReg(2,0);
	Wire#(Bool) setV    <- mkDWire(False); //Wires with valid
	Wire#(Bool) clear1V <- mkDWire(False); // ||
	Wire#(Bool) clear2V <- mkDWire(False); // ||
	Wire#(Bit#(filt_idx)) setIdx    <- mkDWire(?); //Wires with valid
	Wire#(Bit#(filt_idx)) clear1Idx <- mkDWire(?); // ||
	Wire#(Bit#(filt_idx)) clear2Idx <- mkDWire(?); // ||
	//RWire#(Bit#(filt_idx)) setIdx    <- mkRWireSBR(); //Wires with valid
	//RWire#(Bit#(filt_idx)) clear1Idx <- mkRWireSBR(); // ||
	//RWire#(Bit#(filt_idx)) clear2Idx <- mkRWireSBR(); // ||
	Reg#(Bool) clearSinceRead_reg <- mkReg(False);

	function Bit#(filt_idx) hash(t x);
		return truncate(pack(x));
	endfunction
	
	(* conflict_free = "setr, clear1r, clear2r" *)

	(* fire_when_enabled, no_implicit_conditions *)
	rule update_stall(searchW);
		//Maybe#(Bit#(filt_idx)) s_idx = setIdx.wget();
		//Maybe#(Bit#(filt_idx)) c_idx1 = clear1Idx.wget();
		//Maybe#(Bit#(filt_idx)) c_idx2 = clear2Idx.wget();
		//Bool clr1_pass = (isValid(c_idx1)) ? (fromMaybe(?,c_idx1)==searchIdx) : False; 
		//Bool clr2_pass = (isValid(c_idx2)) ? (fromMaybe(?,c_idx2)==searchIdx) : False; 
		Bool clr1_pass = (clear1V) ? (clear1Idx==searchIdx) : False; 
		Bool clr2_pass = (clear2V) ? (clear2Idx==searchIdx) : False; 
		searchOut <= filter[searchIdx];
		//setBypass <= (isValid(s_idx)) ? (fromMaybe(?,s_idx)==searchIdx) : False; //set and s_idx match
		setBypass <= (setV) ? (setIdx==searchIdx) : False; //set and s_idx match
		clrBypass <= clr1_pass || clr2_pass; //clr1 and c_idx1 match OR clr2 and c_idx2 match
		searchIdx_reg[1] <= searchIdx;
		
		//clearSinceRead_reg <= False;
		//$display("UPDATE STALL: set: %d clr: %d sea: %d",(setV) ? (setIdx==searchIdx) : False,clr1_pass || clr2_pass, filter[searchIdx]);
	endrule
	
	(* fire_when_enabled, no_implicit_conditions *)
	rule setr(setV);
		//filter[setIdx][1] <= True;
		filter[setIdx] <= True;
		//$display("SET %d",setIdx);
	endrule
	(* fire_when_enabled, no_implicit_conditions *)
	rule clear1r(clear1V);
		//filter[clear1Idx][1] <= False;
		filter[clear1Idx] <= False;
		//$display("CLEAR1 %d",clear1Idx);
	endrule
	(* fire_when_enabled, no_implicit_conditions *)
	rule clear2r(clear2V);
		//filter[clear2Idx][1] <= False;
		filter[clear2Idx] <= False;
		//$display("CLEAR2 %d",clear2Idx);
	endrule
	
	(* fire_when_enabled, no_implicit_conditions *)
	rule clearSinceRead(searchW || clear1V||clear2V);
		if (searchW) begin
			clearSinceRead_reg <= False;
			//$display(".           CLEAR SINCE READ SEARCH %d",0);
		end else begin
			//Maybe#(Bit#(filt_idx)) c_idx1 = clear1Idx.wget();
			//Maybe#(Bit#(filt_idx)) c_idx2 = clear2Idx.wget();
			//Bool clr1_pass = (isValid(c_idx1)) ? (fromMaybe(?,c_idx1)==searchIdx_reg) : False; 
			//Bool clr2_pass = (isValid(c_idx2)) ? (fromMaybe(?,c_idx2)==searchIdx_reg) : False; 
			Bool clr1_pass = (clear1V) ? (clear1Idx==searchIdx_reg[0]) : False; 
			Bool clr2_pass = (clear2V) ? (clear2Idx==searchIdx_reg[0]) : False; 
			clearSinceRead_reg <= (clearSinceRead_reg || clr1_pass || clr2_pass);
			//$display(".     CLEAR SINCE READ SearchIdxReg %d : %d or %d or %d",searchIdx_reg[0],clearSinceRead_reg,clr1_pass,clr2_pass);
		end
	endrule

	method Action set(t x);
		let idx = hash(x);
		//setIdx.wset(idx);
		setIdx<=idx;
		setV<=True;
		//filter[idx][1] <= True;
	endmethod

	method Action clear1(t x);
		let idx = hash(x);
		//clear1Idx.wset(idx);
		clear1Idx<=idx;
		clear1V<=True;
		//filter[idx][2] <= False; //wire to trigger rule?
	endmethod

	method Action clear2(t x);
		let idx = hash(x);
		//clear2Idx.wset(idx);
		clear2Idx<=idx;
		clear2V<=True;
		//filter[idx][3] <= False; //wires to trigger rule?
	endmethod

	// method Bool search(t x);
	// 	let idx = hash(x);
	// 	//searchIdx<=idx;
	//  	return filter[idx][1];
	// endmethod

	method Action search(t x);
		let idx = hash(x);
		searchIdx<=idx;
		searchW<=True;
		/*Bool clr1_pass = (clear1V) ? (clear1Idx==idx) : False; 
		Bool clr2_pass = (clear2V) ? (clear2Idx==idx) : False; 
		searchOut <= filter[idx][0];
		setBypass <= (setV) ? (setIdx==idx) : False; //set and s_idx match
		clrBypass <= clr1_pass || clr2_pass; //clr1 and c_idx1 match OR clr2 and c_idx2 match
		searchIdx_reg[0] <= idx;*/
	 	//return filter[idx][1];
	endmethod

	method Bool stall();
		return ((searchOut && !clrBypass) || setBypass) && !clearSinceRead_reg; //TODO all these signals 
	endmethod
endmodule

module mkScoreboardSimple(ScoreboardSimple#(n, t)) provisos(Bits#(t, a_),Log#(n,filt_idx),Add#(a__, filt_idx, a_));

	Vector#(n,Reg#(Bool)) filter <- replicateM(mkReg(False)); 
		
	RWire#(Bit#(filt_idx)) setIdx    <- mkRWire(); //Wires with valid
	RWire#(Bit#(filt_idx)) clear1Idx <- mkRWire(); // ||
	RWire#(Bit#(filt_idx)) clear2Idx <- mkRWire(); // ||

	function Bit#(filt_idx) hash(t x);
		return truncate(pack(x));
	endfunction
	
	(* fire_when_enabled, no_implicit_conditions *)
	rule setr(setIdx.wget() matches tagged Valid .idx);
		filter[idx] <= True;
		//$display("SET %d",idx);
	endrule
	(* fire_when_enabled, no_implicit_conditions *)
	rule clear1r(clear1Idx.wget() matches tagged Valid .idx);
		filter[idx] <= False;
		//$display("CLEAR1 %d",idx);
	endrule
	(* fire_when_enabled, no_implicit_conditions *)
	rule clear2r(clear2Idx.wget() matches tagged Valid .idx);
		filter[idx] <= False;
		//$display("CLEAR2 %d",idx);
	endrule
	
	method Action set(t x);
		let idx = hash(x);
		setIdx.wset(idx);
	endmethod

	method Action clear1(t x);
		let idx = hash(x);
		clear1Idx.wset(idx);
	endmethod

	method Action clear2(t x);
		let idx = hash(x);
		clear2Idx.wset(idx);
	endmethod

	method Bool search(t x);
		let idx = hash(x);
	 	return filter[idx];
	endmethod
endmodule

endpackage
