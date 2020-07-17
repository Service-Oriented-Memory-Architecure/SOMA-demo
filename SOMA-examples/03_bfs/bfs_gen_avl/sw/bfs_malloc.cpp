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
// Copyright (c) 2017, Intel Corporation
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
//
// Neither the name of the Intel Corporation nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#include <stdint.h>
#include <stdlib.h>
#include <malloc.h>
#include <unistd.h>
#include <assert.h>

#include <iostream>
#include <string>
#include <atomic>
#include <chrono>

using Clock = std::chrono::steady_clock;
using std::chrono::time_point;
using std::chrono::duration_cast;
using std::chrono::milliseconds;
using std::chrono::microseconds;

using namespace std;

#include "opae_svc_wrapper.h"
#include "csr_mgr.h"

using namespace opae::fpga::types;
using namespace opae::fpga::bbb::mpf::types;

// State from the AFU's JSON file, extracted using OPAE's afu_json_mgr script
#include "afu_json_info.h"

///////////////////////////////////////////////////////////////////////////////
#include "csr.h"

#ifndef CL
# define CL(x)                       ((x) * 64)
#endif
#ifndef MB
# define MB(x)                       ((x) * 1024 * 1024)
#endif // MB
#define CEILING(x, y) (((x) + (y) - 1) / (y))

#define USE_FILE 1
//#define INPUT_FILE "../../graphs/test.dat"
//#define NUMNODES 15
//#define NUMEDGES 20
//#define SOURCE 0
//#define NUM_CHECK 11
#define INPUT_FILE "../../graphs/rome99.dat"
#define NUMNODES 3354
#define NUMEDGES 8859
#define SOURCE 1
#define NUM_CHECK 3352
//#define INPUT_FILE "../../graphs/cond-mat.dat"
//#define NUMNODES 40421
//#define NUMEDGES 351386
//#define SOURCE 0
//#define NUM_CHECK 36457
//#define INPUT_FILE "../../graphs/USA_FLA.dat"
//#define NUMNODES 1070377
//#define NUMEDGES 2687902
//#define SOURCE 1
//#define NUM_CHECK 1070375
//#define INPUT_FILE "../../graphs/USA_east.dat"
//#define NUMNODES 3598624
//#define NUMEDGES 8708058
//#define SOURCE 1
//#define NUM_CHECK 3598622
//#define INPUT_FILE "../../graphs/rmat_256k_16x.dat"
//#define NUMNODES 262135
//#define NUMEDGES 4194304
//#define SOURCE 0
//#define NUM_CHECK 233430
//#define INPUT_FILE "../../graphs/rmat_1m_16x.dat"
//#define NUMNODES 1048561
//#define NUMEDGES 16777216
//#define SOURCE 0
//#define NUM_CHECK 909302
#define NUMNODES_CL CEILING(NUMNODES,8) //number of cl holding nodes (8 per line / 8B node)
#define NUMEDGES_CL CEILING(NUMEDGES,16)  //number of cl holding edges (16 per line / 4B edge)

#define TIMEOUT 10000

/* Type definitions */
typedef struct {
    uint32_t uint[16];
} cache_line;

typedef struct {
    uint32_t uint[16];
} cache_line32;

typedef struct {
    uint64_t uint[8];
} cache_line64;

//
// The key difference between CPU and FPGA access to memory is the required alignment.
// malloc_cache_aligned() allocates buffers that are aligned to multiples of cache
// lines. The FPGA requires natural alignment up to the load/store request size.
// Namely, 4 line read requests require buffers aligned to 4 cache lines.
//
// For this example the allocator is kept simple. It could be turned into a class
// that wraps the buffer in a smart pointer so it is deallocated on last use.
//
static const uint32_t BYTES_PER_LINE = 64;
static void* malloc_cache_aligned(size_t size, size_t align_to_num_lines = 1)
{
    void* buf;

    // Aligned to the requested number of cache lines
    if (0 == posix_memalign(&buf, BYTES_PER_LINE * align_to_num_lines, size)) {
      return buf;
    }

    return NULL;
}


int main(int argc, char *argv[])
{
    // Find and connect to the accelerator
    OPAE_SVC_WRAPPER fpga(AFU_ACCEL_UUID);
    assert(fpga.isOk());

    // Connect the CSR manager
    CSR_MGR csrs(fpga);

    csrs.writeCSR(3,0); // Set MUX Init

    // Spin, waiting for the value in memory to change to something non-zero.
    struct timespec pause;
    // Longer when simulating
    pause.tv_sec = (fpga.hwIsSimulated() ? 1 : 0);
    pause.tv_nsec = 3500000;

    cout << "#" << endl
         << "# AFU frequency: " << csrs.getAFUMHz() << " MHz"
         << (fpga.hwIsSimulated() ? " [simulated]" : "")
         << endl;

    csrs.writeCSR(3,0); // Make sure Mux is low

    int i,j;
    uint64_t data = 0;

    cache_line *cl_ptr      = NULL;     // = (cache_line *)input_ptr;
    uint32_t *source        = NULL;     // = &(cl_ptr[20]);
    uint64_t *src           = NULL;     // = &(cl_ptr[0]);
    uint64_t *edge          = NULL;     // = &(cl_ptr[10]);
    uint64_t *dst           = NULL;     // = &(cl_ptr[20]);
    cache_line *worklist    = NULL; // = &(cl_ptr[50]);
    uint64_t *dist          = NULL;
    UINT dd[NUMNODES];
    dist = (uint64_t *) (&dd[0]);
    cache_line64 *copycat      = NULL;

    cout << "Allocating BFS Buffers" << endl;

    // Like the MPF linked list example we use only virtual addresses
    // here, passing them to the FPGA directly. This example, however, does
    // not call either OPAE or MPF to allocate the storage. It is allocated
    // using standard buffer management. The VTP run-time logic in MPF will
    // automatically call OPAE to pin pages on first use by the FPGA.
    //
    // There is one key difference. Addresses used by the FPGA must be at
    // least cache-line aligned.
    src = reinterpret_cast<uint64_t*>(malloc_cache_aligned(CL(NUMNODES_CL)));    
    edge = reinterpret_cast<uint64_t*>(malloc_cache_aligned(CL(NUMEDGES_CL)));
    dst = reinterpret_cast<uint64_t*>(malloc_cache_aligned(CL(NUMNODES_CL)));
    source = reinterpret_cast<uint32_t*>(dst);
    worklist = reinterpret_cast<cache_line*>(malloc_cache_aligned(6*CL(NUMNODES))); // 16MB
    cout << "src " << src << " edge " << edge << " dst " << dst << " work " 
         << worklist << endl;
    cout << "src sz " << CL(NUMNODES_CL) << "B edge sz " << CL(NUMEDGES_CL) << "B dst sz " << CL(NUMNODES_CL) << "B work sz " 
         << 6*CL(NUMNODES) << "B" << endl;
    cout << "total size " << CL(NUMNODES_CL+NUMEDGES_CL+NUMNODES_CL)+6*CL(NUMNODES) << "B" << endl;
    
    cout << "Creating graph input from file" << endl;

    CsrGraph graph;
   
    graph.mNumNodes=NUMNODES;
    graph.mPerNodeBackward_r=reinterpret_cast<PerNodeBackward*>(malloc(NUMNODES*8)); 
    
    graph.mPerNodeForward=reinterpret_cast<PerNodeForward*>(src);
    graph.mPerNodeBackward=reinterpret_cast<PerNodeBackward*>(dst);
    graph.mPerEdge=reinterpret_cast<PerEdge*>(edge);
     
    graph.mDist=new TcsrDIST[NUMNODES]; 

     #if(USE_FILE==1) 
       graph.initFile((char*)INPUT_FILE, NUMEDGES);
     #else 
       graph.initRandom();
     #endif
    
  //graph.bfs(SOURCE);
     {
       graph.mPerNodeBackward[SOURCE].back=SOURCE;
     }

    {
        worklist[0].uint[0] = SOURCE;
        worklist[0].uint[15] = 1;
    }
    source[SOURCE] = (int)SOURCE;

   //
   // Maybe flush cache here?
   //
   char dummy[MB(32)]; 
   for (i=0; i<MB(32); i++) dummy[i] = 0;

    csrs.writeCSR(3,0); // Make sure Mux is low

    int ddr_src, ddr_edg, ddr_dst, ddr_wrk;
    uint64_t mcp_num, mcp_cmd;
    uint64_t mcp;
    // Copy SRC
    int ddr; ddr=0;
    ddr_src = ddr;
    copycat = reinterpret_cast<cache_line64*>(src);
    mcp_num = NUMNODES_CL;
    
    cout << "SRC COPY TO AVL" << endl;
    csrs.writeCSR(3,5);  // flip reset and mux
    csrs.writeCSR(0xC,0x11+ddr_src); // MCP DST
    csrs.writeCSR(0xD,intptr_t(copycat)); // MCP SRC
    csrs.writeCSR(0xE,0x000000000|NUMNODES_CL); // MCP NUM && CMD
    cout << "SRC 0x" << hex << intptr_t(copycat) << " DST 0x" << hex << 0x11+ddr_src << endl;//<< " CMD 0x" << hex << (mcp_cmd|mcp_num) << endl;
    csrs.writeCSR(3,21); // clear
    csrs.writeCSR(3,5);  // !clear
    csrs.writeCSR(3,13); // start test
    do {
       data = csrs.readCSR(9);
       nanosleep(&pause, NULL);
    } while ((0x40 != (data & 0x40)));
    csrs.writeCSR(3,5); // !start
    csrs.writeCSR(3,21); // clear
    csrs.writeCSR(3,0); // flip mux
    cout << "SRC COPY DONE AVL" << endl;
    // // Copy EDG
    cout << "EDG COPY TO AVL" << endl;
    copycat = reinterpret_cast<cache_line64*>(edge);
    ddr = ddr + NUMNODES_CL;// + 2;
    ddr_edg = ddr;
    csrs.writeCSR(3,5);  // flip reset and mux
    csrs.writeCSR(0xC,0x11+ddr_edg); // MCP DST
    csrs.writeCSR(0xD,intptr_t(copycat)); // MCP SRC
    csrs.writeCSR(0xE,0x000000000|NUMEDGES_CL); // MCP NUM && CMD
    cout << "SRC 0x" << hex << intptr_t(copycat) << " DST 0x" << hex << 0x11+ddr_edg << endl;
    csrs.writeCSR(3,21); // clear
    csrs.writeCSR(3,5);  // !clear
    csrs.writeCSR(3,13); // start test
    do {
       data = csrs.readCSR(9);
       nanosleep(&pause, NULL);
    } while ((0x40 != (data & 0x40)));
    csrs.writeCSR(3,5); // !start
    csrs.writeCSR(3,21); // clear
    csrs.writeCSR(3,0); // flip mux
    cout << "EDG COPY DONE AVL" << endl;
    cout << "DST COPY TO AVL" << endl;
    copycat = reinterpret_cast<cache_line64*>(dst);
    ddr = ddr + NUMEDGES_CL;// + 2;
    ddr_dst = ddr;
    csrs.writeCSR(3,5);  // flip reset and mux
    csrs.writeCSR(0xC,0x11+ddr_dst); // MCP DST
    csrs.writeCSR(0xD,intptr_t(copycat)); // MCP SRC
    csrs.writeCSR(0xE,0x000000000|NUMNODES_CL); // MCP NUM && CMD
    cout << "SRC 0x" << hex << intptr_t(copycat) << " DST 0x" << hex << 0x11+ddr_dst << endl;
    csrs.writeCSR(3,21); // clear
    csrs.writeCSR(3,5);  // !clear
    csrs.writeCSR(3,13); // start test
    do {
       data = csrs.readCSR(9);
       nanosleep(&pause, NULL);
    } while ((0x40 != (data & 0x40)));
    csrs.writeCSR(3,5); // !start
    csrs.writeCSR(3,21); // clear
    csrs.writeCSR(3,0); // flip mux
    cout << "DST COPY DONE AVL" << endl;
    cout << "WRK COPY TO AVL" << endl;
    copycat = reinterpret_cast<cache_line64*>(worklist);
    ddr = ddr + NUMNODES_CL;// + 2;
    ddr_wrk = ddr;
    csrs.writeCSR(3,5);  // flip reset and mux
    csrs.writeCSR(0xC,0x11+ddr_wrk); // MCP DST
    csrs.writeCSR(0xD,intptr_t(copycat)); // MCP SRC
    csrs.writeCSR(0xE,0x000000000|16); // MCP NUM && CMD
    cout << "SRC 0x" << hex << intptr_t(copycat) << " DST 0x" << hex << 0x0 << endl;
    //csrs.writeCSR(16,0x45); // clear      
    csrs.writeCSR(3,21); // clear      
    csrs.writeCSR(3,5);  // !clear
    //csrs.writeCSR(16,0x25); // start test 
    csrs.writeCSR(3,13); // start test 
    do {
       data = csrs.readCSR(9);
       nanosleep(&pause, NULL);
    //} while ((0x400 != (data & 0x400))); 
    } while ((0x40 != (data & 0x40))); 
    csrs.writeCSR(3,5); // !start 
    //csrs.writeCSR(16,0x45); // clear 
    csrs.writeCSR(3,21); // clear 
    csrs.writeCSR(3,0); // flip mux
    cout << "WRK COPY DONE AVL" << endl;
 
    int timeout = 0;
    /*cout << "Start BFS test CCIP" << endl;
    csrs.writeCSR(4,NUMNODES-1-SOURCE); // numlines
    csrs.writeCSR(5,intptr_t(worklist)); // work
    csrs.writeCSR(6,intptr_t(src)); // src
    csrs.writeCSR(7,intptr_t(edge)); // edge
    csrs.writeCSR(8,intptr_t(dst)); // dst
    csrs.writeCSR(11,4*16384); // worklist capacity
    csrs.writeCSR(3,5); // flip reset and mux
    csrs.writeCSR(3,13); // start test
    do {
       data = csrs.readCSR(9);
       nanosleep(&pause, NULL);
       cout << "time count: " << timeout++ << endl;
    //} while ((0x40 != (data & 0x40)));
    } while ((timeout<TIMEOUT)&&(0x4 != (data & 0x4)));

    cout << "Stopping BFS hardware CCIP" << endl;
    csrs.writeCSR(3,0); // stop test and flip mux

    cout << "Verifying BFS result CCIP" << endl;
    //int v = verify(SOURCE,NUMNODES,src,edge,dst,dist);
    int v = graph.verify(SOURCE);*/
    struct timespec mmio_delay;
    // Longer when simulating
    mmio_delay.tv_sec = (fpga.hwIsSimulated() ? 1 : 0);
    mmio_delay.tv_nsec = 25000;

    cout << "Start BFS test AVL" << endl;
    csrs.writeCSR(4,NUMNODES-1-SOURCE); // numlines
    csrs.writeCSR(5,0x11+ddr_wrk); // work
    csrs.writeCSR(6,0x11+ddr_src); // src
    csrs.writeCSR(7,0x11+ddr_edg); // edge
    csrs.writeCSR(8,0x11+ddr_dst); // dst
    csrs.writeCSR(11,4*16384); // worklist capacity
    csrs.writeCSR(3,5); // flip reset and mux
    csrs.writeCSR(3,7); // start test
    time_point<Clock> startcr = Clock::now();
    do {
       data = csrs.readCSR(10);
       nanosleep(&mmio_delay, NULL);
       cout << "time count: " << dec << timeout++ << " node count: " << dec << data << endl;
    } while ((timeout<TIMEOUT)&&(data < NUM_CHECK));
    time_point<Clock> endcr = Clock::now();
    cout << "Stopping BFS hardware AVL" << endl;
    csrs.writeCSR(3,0); // stop test and flip mux
    nanosleep(&pause, NULL);

    cout << "Copying BFS result AVL" << endl;

    cout << "AVL COPY DST TO CCI" << endl;
    copycat = reinterpret_cast<cache_line64*>(dst);
    csrs.writeCSR(3,5);  // flip reset and mux
    csrs.writeCSR(0xC,intptr_t(copycat)); // MCP DST
    csrs.writeCSR(0xD,0x11+ddr_dst); // MCP SRC
    csrs.writeCSR(0xE,0x100000000|NUMNODES_CL); // MCP NUM && CMD
    cout << "SRC 0x" << hex << 0x11+ddr_dst << " DST 0x" << hex << intptr_t(copycat) << endl;//" CMD 0x" << hex << (mcp_cmd|mcp_num) << endl;
    csrs.writeCSR(3,21); // clear
    csrs.writeCSR(3,5);  // !clear
    csrs.writeCSR(3,13); // start test
    do {
       data = csrs.readCSR(9);
       nanosleep(&pause, NULL);
    } while ((0x40 != (data & 0x40)));
    csrs.writeCSR(3,5); // !start
    csrs.writeCSR(3,21); // clear
    csrs.writeCSR(3,0); // flip mux
    cout << "AVL COPY DONE CCI" << endl;

    cout << "Verifying BFS result AVL" << endl;
    int v = graph.verify(SOURCE);
    
    cout << "Done verifying test." << endl << endl;

    if (!fpga.hwIsSimulated()) {   
       microseconds diff = duration_cast<microseconds>(endcr - startcr);
       cout << "BFS test time is " << dec << diff.count() << " us." << endl;
       cout << "BFS throughput for '" << INPUT_FILE << "' is " << (double)NUMEDGES / (double)diff.count() << " MTEPS." << endl << endl;
    }

    free(src);
    free(edge);
    free(dst);
    free(worklist);
    free(graph.mPerNodeBackward_r);

    return 0;
}
