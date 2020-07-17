// MIT License
// 
// Copyright (c) 2020 by Yu Wang, Carnegie Mellon University
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
// BFS specialized
#ifndef CSR_H
#define CSR_H

// CSR representation of a sparse directed graph of positive weights
#define NOCOUT 1
#include <iostream>
#include <cstdlib>
#include <cassert>
#include <string>
#include <fstream>

typedef unsigned long ULONG;
typedef unsigned long long ULONGLONG;
typedef long long LONGLONG;
typedef signed long LONG;
typedef unsigned int UINT;
typedef signed int INT;

typedef UINT TcsrNODEIDX;
static const TcsrNODEIDX NOBODY=-1;
typedef UINT TcsrEDGEIDX;
typedef UINT TcsrFANOUT;

typedef UINT TcsrDIST;
static const TcsrDIST MAXDIST=((TcsrDIST)-1)>>1;

static const ULONG CACHE_LINE_SIZE_LG=(6);
static const ULONG CWLONG_SIZE=(sizeof(ULONG));
static const ULONG CACHE_LINE_SIZE=(1<<CACHE_LINE_SIZE_LG);
static const ULONGLONG CACHE_LINE_MASK=(CACHE_LINE_SIZE-1);

#define WORK_BUNDLE_SIZE ((CACHE_LINE_SIZE/sizeof(TcsrNODEIDX))-1)
typedef struct {
  TcsrNODEIDX howmany;
  TcsrNODEIDX node[WORK_BUNDLE_SIZE];
} Work;

// elements of the node array
// size of this struct must be a two-power and <= cacheline size
typedef struct { 
  TcsrEDGEIDX edges;   // index to this node's edges in the per edge array
  TcsrFANOUT fanout; // how many edges from this node, redundantly stored to reduce CCI loads
} PerNodeForward ;

typedef struct { 
  TcsrNODEIDX back;   // index to this node's parent in BFS
} PerNodeBackward;


// elements of the edge array
typedef struct {
  TcsrNODEIDX dest;
} PerEdge;


class WorkList {
 public:
  TcsrNODEIDX *mList; // circular buffer -> DRAM
  ULONG mEnq;   // enqueue index -> HW reg
  ULONG mDeq;   // dequeue index -> HW reg
  ULONG mHowmany; // howmany in use -> HW reg 
  ULONG mCapacity2;  // how much buffer allocated -> HW constant
  ULONG mMask;  // how much buffer allocated -> HW constant
  
  WorkList(ULONG capacity) {

    {
      ULONG temp=capacity;
      
      mCapacity2=1;
      while (temp) {
	mCapacity2*=2;
	temp/=2;
      }
      mCapacity2*=2;
      mMask=mCapacity2-1;
    }

    mList=new TcsrNODEIDX[mCapacity2];
    mEnq=0;
    mDeq=0;
    mHowmany=0;
  }

  ~WorkList() {
    delete mList;
  }
};

class CsrGraph {
 public:
  TcsrDIST *mDist; // SW-only auxiliary state for checking bfs solution
  ULONG mSparsity;
  ULONG mReserve;

  ULONG mNumNodes; // node array -> HW config reg
  ULONG mNumEdges; // edge array -> HW config reg
  PerNodeForward *mPerNodeForward; // array of nodes -> DRAM
  PerNodeBackward *mPerNodeBackward; // array of nodes -> DRAM
  PerNodeBackward *mPerNodeBackward_r;
  PerEdge *mPerEdge; // array of edges -> DRAM
  
  void initRandom() {
    TcsrNODEIDX src, dst;
    TcsrEDGEIDX scan=0;
    
    srand(0);
    
    for(src=0; src<mNumNodes; src++) {
      mPerNodeForward[src].edges=scan;
      for(dst=0; dst<mNumNodes; dst++) {
	assert(scan<mReserve);
	if (!(rand()%mSparsity)) {
	  mPerEdge[scan].dest=dst;
 	  scan++;
	}
      }
    }
    
    mPerNodeForward[src].edges=scan;
    mNumEdges=scan;
    
    for(src=0; src<mNumNodes; src++) {
      mPerNodeForward[src].fanout=mPerNodeForward[src+1].edges-mPerNodeForward[src].edges;
    }

    {
      TcsrNODEIDX node;
      for(node=0;node<mNumNodes;node++) {
	mPerNodeBackward[node].back=NOBODY;
	mDist[node]=MAXDIST;
      }
    }
  }
  
  void initFile(char *inputFile, int numEdges)
  {
    mNumEdges=numEdges;
    std::ifstream myfile(inputFile);
    if(!myfile.is_open())assert(0);
    std::string line;
    int numEdgesScan;
    int numNodesScan;
    std::getline(myfile, line);
    sscanf(line.c_str(), "%d",&numNodesScan);
    assert(numNodesScan==mNumNodes);

    std::getline(myfile, line);
    sscanf(line.c_str(), "%d",&numEdgesScan);
    assert(numEdgesScan=mNumEdges);

    TcsrEDGEIDX scan=0;
    int prev=-1;    
    TcsrNODEIDX from, to;
    int weight;  

    while(std::getline(myfile, line))
    {
      sscanf(line.c_str(), "%d %d %d",&from, &to, &weight);

      if(prev!=from)
      {
        
        if(prev>=(int)from)printf("prev=%d, from=%d\n", prev, from);
        assert(prev<(int)from);
        for(int i=prev+1;i<from;i++)
        {
          mPerNodeForward[i].edges=scan;
        }

        prev=from;
        mPerNodeForward[from].edges=scan;
      }
      assert(from<mNumNodes);
      assert(to<mNumNodes);
      mPerEdge[scan].dest=to;
      //mPerEdge[scan].weight=weight;
      scan++;
    }
    for(int i=prev+1;i<(mNumNodes+1);i++)
    {
      mPerNodeForward[i].edges=scan;
    }
    assert(mNumEdges==scan);


    //////////////////////////////////////////////////////////////////////////////////////
    int src;
    for(src=0; src<mNumNodes; src++) {
      mPerNodeForward[src].fanout=mPerNodeForward[src+1].edges-mPerNodeForward[src].edges;
    }

    {
      TcsrNODEIDX node;
      for(node=0;node<mNumNodes;node++) {
	mPerNodeBackward[node].back=NOBODY;
	mDist[node]=MAXDIST;
      }
    }

  }

  TcsrDIST calcDist(TcsrNODEIDX node, TcsrNODEIDX source) {
    if (mDist[node]!=MAXDIST) {
      return mDist[node];
    }
	//printf("(source=%d, node=%d) ", source, node);
    if (node==source) {
      mDist[node]=0;
    } else if (mPerNodeBackward[node].back==NOBODY) {
      assert(mDist[node]==MAXDIST);
    } else {
      mDist[node]=1+calcDist(mPerNodeBackward[node].back,source);
    }

    return mDist[node];
  }

  int verify(TcsrNODEIDX source) {
    TcsrNODEIDX node;
    
    assert(mPerNodeBackward[source].back==source);
    
	printf("in verify\n");
/*
bfs(source);
for(node=0; node<mNumNodes; node++) 
{
/	if(mPerNodeBackward[node].back!=mPerNodeBackward_r[node].back)
	{
		printf("ERR: at node %d, fpga has parents %d, ref has parents %d\n", node, mPerNodeBackward[node], mPerNodeBackward_r[node]);
		assert(0);
	}
}
*/

    for(node=0; node<mNumNodes; node++) {
      TcsrEDGEIDX scan=mPerNodeForward[node].edges;
	//printf("here1\n");
      TcsrNODEIDX myParent=mPerNodeBackward[node].back;
	//printf("here2\n");
      TcsrDIST myDist=calcDist(node, source);
      //printf("myDist of node %d=%d\n", node, myDist) ;
      if ((myParent!=NOBODY)&&(node!=source)) {
	assert(calcDist(node, source)==(calcDist(myParent, source)+1));
	if (!(calcDist(node, source)==(calcDist(myParent, source)+1))) {
	  cerr << "**CSR** Verification failed\n";
	  return(1);
	}
	//printf("here3\n");
      }

      while(scan<(mPerNodeForward[node+1].edges)) {
	// inductively proof no shorter path exist to dest nodes possible
	//assert((myDist+1)>=calcDist(mPerEdge[scan].dest, source));
	if (!((myDist+1)>=calcDist(mPerEdge[scan].dest, source))) {
          //printf("myParent dist=%d\n",calcDist(myParent, source) );
          //printf("myParentY=%d\n", myParent);
          //printf("myDist=%d\n", myDist);
          //printf("failed at dest node %d check: (myDist+1)=%d >= calcDist=%d\n", mPerEdge[scan].dest, myDist+1, calcDist(mPerEdge[scan].dest, source) );
	  cerr << "**CSR** Verification failed\n";
	  return(1);
	}
	scan++;
      }
    }
    
    for(node=0; node<mNumNodes; node++) {
      TcsrDIST myDist=calcDist(node, source);
      // check all reacheable nodes are indeed reached by the min dist
      if ((node!=source) && (mPerNodeBackward[node].back!=NOBODY)) {
	assert(myDist<MAXDIST);
	if (!(myDist<MAXDIST)) {
	  cerr << "**CSR** Verification failed\n";
	  return(1);
	}
      }
    }
    
    cerr << "**CSR** Verification succeded\n";
    return(0);
  }
  
  void printSolution(TcsrNODEIDX source) {
    TcsrNODEIDX node;

    for(node=0; node<mNumNodes; node++) {

	printf("at node %d: ", node);
      unsigned int prev=mPerNodeBackward[node].back;
      cout << "node " << node << " back: ";
      cout << mPerNodeBackward[node].back << " >>> ";

	printf(" prev=%d ", prev);
	if((prev<0 || prev>=mNumNodes) && -1!=prev )assert(0);

      cout << "  BFS: Node " << node 
	   //<< "=" << calcDist(node, source)
	   << "; parent=" << mPerNodeBackward[node].back
	   << "\n";
    }
  }
  
  void printGraph() {
    TcsrNODEIDX node;
    TcsrEDGEIDX scan=0;
    
    for(node=0; node<mNumNodes; node++) {
      cout << "  BFS: Src " << node <<  "("<<mPerNodeForward[node].fanout<<") " 
	   << "->";
      while(scan<(mPerNodeForward[node+1].edges)) {
	cout << "Dest " << mPerEdge[scan].dest 
	     << "); "; 
	scan++;
      }
      cout << "\n";
    }
  }

  double bfs(TcsrNODEIDX source) {
    WorkList wl(mNumNodes); // might need to be bigger
    int numWorkRead=0; 
    int numNodeForwardRead=0;
    int numEdgesRead=0;
    int numNodeBackwardRead=0;  

    //first clear the result
    for(int i=0;i<mNumNodes;i++)mPerNodeBackward_r[i].back=NOBODY;
 
    mPerNodeBackward_r[source].back=source; // source' parent is itself
    { // add source to worklist
      wl.mList[wl.mEnq]=source;
      wl.mEnq=(wl.mEnq+1)&wl.mMask;
      wl.mHowmany++;
      assert (wl.mHowmany<=wl.mCapacity2);
    }
    
    
    while(wl.mHowmany) { // worklist not empty

      TcsrNODEIDX curr=wl.mList[wl.mDeq]; // next on worklist

      TcsrFANOUT numEdges=mPerNodeForward[curr].fanout;
      TcsrEDGEIDX scan=mPerNodeForward[curr].edges;
      
      numWorkRead++;
      numNodeForwardRead++;
      { // dequue from worklist
	wl.mDeq=(wl.mDeq+1)&wl.mMask;
	wl.mHowmany--;
      }
      
      while (numEdges--) {
        //printf("numEdges=%d,node=%d\n ", numEdges, curr); 
        numEdgesRead++;
        numNodeBackwardRead++;
               
	TcsrNODEIDX dest=mPerEdge[scan].dest;
	TcsrDIST destParent=mPerNodeBackward_r[dest].back;
	
	if (destParent==NOBODY) {
#ifndef NOCOUT
	  cout << "  BFS: Adding node " << dest 
	       << " >> parent >>" << curr
	       << "\n";
#endif
	  mPerNodeBackward_r[dest].back=curr;
	  { // add dest to worklist 
	    wl.mList[wl.mEnq]=dest;
	    wl.mEnq=(wl.mEnq+1)&wl.mMask;
	    wl.mHowmany++;
	    assert (wl.mHowmany<=wl.mCapacity2);
	  }
	}
        //printf("wl.mHowmany=%d\n", wl.mHowmany);	
        
	scan++;
      }
      numWorkRead=(numWorkRead/15+1)*1.3;
      
      //return(numWorkRead+numNodeForwardRead+numEdgesRead+numNodeBackwardRead);


    }
  }
};

#endif


