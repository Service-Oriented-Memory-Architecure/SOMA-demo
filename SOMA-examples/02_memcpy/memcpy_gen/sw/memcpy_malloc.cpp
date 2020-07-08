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
#define INPUT_FILE "./rome99.dat"
#define NUMNODES 3354
#define NUMEDGES 8859
#define SOURCE 1
#define NUM_CHECK 3352
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
    
    cout << "SRC CCI 2 AVL COPY" << endl;
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
    cout << "SRC CCI 2 AVL COPY DONE." << endl;
 
    cout << "SRC AVL 2 CCI COPY..." << endl;
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
    cout << "SRC AVL 2 CCI COPY DONE." << endl;

    cout << "Verifying result..." << endl;
    for (i=0; i<NUMNODES_CL; i++)
       for (j=0; j<8; j++) 
          if (copycat[i].uint[j]!=src[i*8+j]) cout << "FAIL MATCH " << copycat[i].uint[j] << endl;
 
    cout << "Done verifying test." << endl << endl;

    free(src);
    free(edge);
    free(dst);
    free(worklist);
    free(graph.mPerNodeBackward_r);

    return 0;
}
