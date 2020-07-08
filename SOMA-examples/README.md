# Service-Oriented Memory Architecture Examples

SOMA examples depend on proper configuration of the OPAE and build environments.

These examples are provided as a demonstration for a service-oriented memory architecture here, instead of operating in terms of loads, stores and addresses, a compute accelerator design interacts with abstracted memory services that present high-level, semantic-rich operations---both compute and data transfers---on encapsulated data objects. The support for a memory service, realized as a soft-logic module or a composition of modules, is developed by domain experts and available to an accelerator design in a reusable catalog collection. This development framework provides a means to specify and generate a customized service-oriented memory system by configuring JSON files and our RTL generator script.

**Disclaimer: This is a pre-alpha proof of concept release. _Only the provided examples are guaranteed to work._ Any changes to the registry JSON files can produce invalid generated RTL.**

## Required Software Development Kits and Tools

- SOMA Generator [SOMA generator on GitHub](https://github.com/Service-Oriented-Memory-Architecure/SOMA-generator).

- SOMA Bluespec [SOMA bluespec on GitHub](https://github.com/Service-Oriented-Memory-Architecure/SOMA-bluespec).

- Open Programmable Acceleration Engine (OPAE) [OPAE sources on GitHub](https://github.com/OPAE/opae-sdk).

- Intel FPGA Basic Building Blocks (BBB) [BBB sources on GitHub](https://github.com/OPAE/intel-fpga-bbb).

- Bluespec Compiler (BSC) [BSC tools on GitHub](https://github.com/B-Lang-org/bsc).

## Environment Setup

Clone this repository into the intel-fpga-bbb/samples directory. 

**Be sure to EDIT and source init.sh!**

## Examples 

1. [Counters](01_counters). A sample application where two kernel modules invoke separate counter services to atomically increment specified indices in a table of counters in memory by a specified value a number of times. Each counters service is supported by individual write services and share a single read service. Read and write services provide their operations on host memory over CCIP.

2. [Memcpy](02_memcpy). This example demonstrates a memcpy service that operates as the similarly named software function does to transfer blocks of data from one memory location to another. The memcpy service is invoked by host software through a service that enables software to issue message requests to services through MMIO CSR writes. The memcpy service is supported by two sets of read and write services, one set for the CCIP interface and another for Avalon.

3. [Breadth-first search (BFS)](03_bfs). The BFS example demonstrates high-level services providing semantic-rich operations. The BFS kernel makes use of a queue service for the algorithm worklist, a graph traversal service that takes in a source node and returns a stream of its neighboring nodes with their distances as metadata, and an atomic update operation for the neighbor distance. 
This example also demonstrates the flexibility and convenience of the Service-Oriented Memory Architecture to specify and generate RTL with various memory interfaces and performance enhancements such as a cache. The following configurations are provided:  
   - Graph data accessed over CCIP (PCIe) in host memory
   - Graph data accessed over Avalon in local memory
   - Graph data accessed over Avalon in local memory and caching node distance data

### Directory Structure

- \{example\} : 
  - \{example\}\_gen : 
    Project directories for simulation and synthesis. Contains hw and sw code.
  - \{example\}\_src : 
    CATALOG and REGISTRY files the generator uses to output RTL. 
    Contains user-level kernel RTL as well as pre-generated RTL and pre-compiled Bluespec files.  

## Design Flow

**Makefiles exist in the example directories to run part or all of this flow.** Pre-generated and compiled RTL files are included for convenience, the entire generation flow does not need to be run to simulate the examples. 

1. Configure the example application REGISTRY and CATALOG JSON files. 

2. Run the application JSON files through the SOMA-generator producing the Bluespec System Verilog
   and System Verilog RTL for your specified design and memory system. 

3. Use the Makefile in .../SOMA-bluespec/soma-bsv-base to compile generated Bluespec to System Verilog.

4. Copy all generated and compiled SystemVerilog into the .../\{example\}\_gen/hw/rtl directory.

5. Run the ASE simulator or Quartus synthesis as usual. 

