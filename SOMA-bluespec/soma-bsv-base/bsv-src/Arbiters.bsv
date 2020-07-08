/* =========================================================================
 *
 * Filename:            Arbiters.bsv
 * Date created:        05-09-2011
 * Last modified:       05-09-2011
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Implements static priority and round-robin arbiters. 
 *
 * =========================================================================
 */

import Vector::*;
import Arbiter::*;

/////////////////////////////////////////////////////////////////////////
// Static Priority Arbiter that starts at specific bit
// Given a bitmask that has a few bits toggled, it produces a same size
// bitmask that only has the least-significant bit toggled. If no bits
// were originally toggled, then result is same as input.
function Vector#(n, Bool) static_priority_arbiter_onehot_start_at( Vector#(n, Bool) vec, Integer startAt);
  Vector#(n, Bool) selected = unpack(0);
  //Maybe#(Bit#(m)) choice = Invalid;
  //for(Integer i=0; i < valueOf(n); i=i+1)   // I want the highest to have highest priority
  Integer cur = startAt;
  for(Integer i=valueOf(n)-1; i >= 0; i=i-1)  // I want the lowest to have highest priority
  begin
    if(vec[cur%valueOf(n)]) begin
      selected = unpack(0);
      selected[cur%valueOf(n)] = True; //Valid(fromInteger(i));
    end
    cur = cur+1;
  end
  return selected;
endfunction


interface Arbiter#(type n);
  (* always_ready *) method ActionValue#(Vector#(n, Bool)) select( Vector#(n, Bool) requests );
  (* always_ready *) method Action           next();
endinterface
 

module mkStaticPriorityArbiterStartAt#(Integer startAt) (Arbiter#(n));
  method ActionValue#(Vector#(n, Bool)) select( Vector#(n, Bool) requests );
    return static_priority_arbiter_onehot_start_at(requests, startAt);
  endmethod

  method Action next();
    action noAction; endaction
  endmethod
endmodule



// From Bill Dally, page 354 in Dally's book
(* noinline *)
function Tuple2#(Bool,Bool) gen_grant_carry(Bool c, Bool r, Bool p);
    return tuple2(r && (c || p), !r && (c || p)); // grant and carry signals
endfunction

//////////////////////////////////////////////////////
// Round-robin arbiter from Dally's book. Page 354
module mkRoundRobinArbiter( Arbiter#(n) );

  Reg#(Vector#(n, Bool)) token <- mkReg(unpack(1));

//added by zhipeng
   function Bool vec2bool( Vector#(n, Bool) grants );
	  Bit#(n) grants_bit = pack(grants);
	  Bool grants_or = unpack(|grants_bit);
	  return grants_or;

   endfunction
//end add

  method ActionValue#(Vector#(n, Bool)) select( Vector#(n, Bool) requests );
  	Vector#(n, Bool) granted_A = unpack(0);
  	Vector#(n, Bool) granted_B = unpack(0);

    /////////////////////////////////////////////////////////////////////
    // Replicated arbiters are used to avoid cyclical carry chain
    // (see page 354, footnote 2 in Dally's book)
    /////////////////////////////////////////////////////////////////////

    // Arbiter 1
    Bool carry = False;
    for(Integer i=0; i < valueOf(n); i=i+1) begin
        let gc = gen_grant_carry(carry, requests[i], token[i]);
        granted_A[i] = tpl_1(gc);
        carry = tpl_2(gc);
    end

    // Arbiter 2 (uses the carry from Arbiter 1)
    for(Integer i=0; i < valueOf(n); i=i+1) begin
        let gc = gen_grant_carry(carry, requests[i], token[i]);
        granted_B[i] = tpl_1(gc);
        carry = tpl_2(gc);
    end

    Vector#(n, Bool) winner = unpack(0);
    //Maybe#(Bit#(m)) winner = Invalid;
    for(Integer k=0; k < valueOf(n); k=k+1) begin
      if(granted_A[k] || granted_B[k]) begin
        winner = unpack(0);
	    winner[k] = True;
      end
    end
	token <= vec2bool(winner) ? rotateR(winner) : token; //Added by zhipeng
   return winner;
  endmethod

//added by zhipeng
  method Action next();	
    action
      //token <= vec2bool(grants) ? rotateR( grants ) : token; // WRONG -> this should get
    endaction

  endmethod
//end add

endmodule

