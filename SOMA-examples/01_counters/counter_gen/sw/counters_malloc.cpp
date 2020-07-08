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

#ifndef CL
# define CL(x)                       ((x) * 64)
#endif
#ifndef MB
# define MB(x)                       ((x) * 1024 * 1024)
#endif // MB
#define CEILING(x, y) (((x) + (y) - 1) / (y))

#define TIMEOUT 100

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
         << (fpga.hwIsSimulated() ? " [simulated]" : "") << endl
         << "#" << endl
         << endl;

    csrs.writeCSR(3,0); // Make sure Mux is low

    int i,j;
    uint64_t data = 0;
    uint32_t *src           = NULL;     // = &(cl_ptr[0]);

    cout << "Allocating counter table." << endl;

    // Like the MPF linked list example we use only virtual addresses
    // here, passing them to the FPGA directly. This example, however, does
    // not call either OPAE or MPF to allocate the storage. It is allocated
    // using standard buffer management. The VTP run-time logic in MPF will
    // automatically call OPAE to pin pages on first use by the FPGA.
    //
    // There is one key difference. Addresses used by the FPGA must be at
    // least cache-line aligned.
    src = reinterpret_cast<uint32_t*>(malloc_cache_aligned(CL(16)));    

    cout << "Displaying cleared counters..." << endl; 
    int timeout = 0;
    for (j=0; j<48; j++) {
        src[j] = 0;
        printf("Clr [%2d]: %2d\t",j,src[j]);
        if(((j)%4 == 3)&&((j)!=0)) printf("\n");   
    } printf("\n");  

    cout << "Starting counter test CCIP." << endl;
    cout << "Incrementing counters 0, 5, 18, and 33." << endl;
    cout << "Running test:";
    csrs.writeCSR(4,84); // num increments
    csrs.writeCSR(5,intptr_t(src)); // src
    csrs.writeCSR(3,5); // flip reset and mux
    csrs.writeCSR(3,7); // start test
    do {
       data = csrs.readCSR(9);
       nanosleep(&pause, NULL);
    } while ((timeout<TIMEOUT)&&(0x4 != (data & 0x4)));
    cout << endl << "Stopping counter hardware." << endl << endl;
    csrs.writeCSR(3,0); // stop test and flip mux
    nanosleep(&pause, NULL);
    
    cout << "Displaying counter result CCIP..." << endl;
    for (j=0; j<48; j++) {
        printf("Idx [%2d]: %2d\t",j,src[j]);
        if(((j)%4 == 3)&&((j)!=0)) printf("\n");   
    } printf("\n");  

    cout << "Done with counter test." << endl << endl;

    free(src);

    return 0;
}
