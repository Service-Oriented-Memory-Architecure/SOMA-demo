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
// Interface and struct definitions
//

`ifndef ACT_MSG_VH
`define ACT_MSG_VH

interface server#(SDARG_BITS=32, DATA_BITS=512) ();

    //localparam SDARG_BITS = 32;
    typedef logic [SDARG_BITS-1:0] t_sdarg;

    //localparam DATA_BITS = 512;
    typedef logic [DATA_BITS-1:0] t_data;

    // AM_HEAD
    typedef struct packed
    {
        t_sdarg srcid; // Server ID sending message to server to complete request
        t_sdarg dstid; // Server ID receiving message after request completed
        t_sdarg arg0;  // User defined arguments for server processing
        t_sdarg arg1;  // ie.) Typically I use arg 1 for address on a read/write server
        t_sdarg arg2;  // These need to be returned with a response
        t_sdarg arg3;  //
    }
    t_am_head;

    // AM_DATA
    typedef struct packed
    {
        t_data data;
    }
    t_am_data;

    // AM_FULL
    typedef struct packed
    {
        t_am_data data;
        t_am_head head;
    }
    t_am_full;

    typedef struct packed
    {
        t_am_full tx_msg;
        logic     tx;
    }
    t_tx_msg_channel;

    typedef struct packed
    {
        logic     rxEmpty;
        t_am_full rx_msg;
    }
    t_rx_msg_channel;

    t_tx_msg_channel txP;
    logic            txFull;

    t_rx_msg_channel rxP;
    logic            rxPop;

    // Server port
    modport svr
       (
        input  txP,
        output txFull,
        output rxP,
        input  rxPop
        );

    // Client port
    modport clt
       (
        output txP,
        input  txFull,
        input  rxP,
        output rxPop
        );

endinterface // server

`endif
