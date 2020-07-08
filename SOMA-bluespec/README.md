# Service-Oriented Memory Architecture Bluespec Build Facility and Service Catalog

Requires: Bluespec Compiler (BSC) [BSC tools on GitHub](https://github.com/B-Lang-org/bsc).

CURRENT_CATALOG.json : json file containing all currently made available services that can be used by designers in the SOMA-generator.

## Directory Structure

[Bluespec Build Facility](soma-bsv-base) : 
Place the generated ServerSys.bsv file here and run the make command. The BSC will compile the ServerSys.bsv file to verilog (mkServerSys.v) that can be used for simulation and synthesis. This file should be copied to your project rtl directory along with the other generated SystemVerilog files.
- [Bluespec SystemVerilog Catalog Source](soma-bsv-base/bsv-src) : 
  This directory contains Bluespec SystemVerilog source files for services and AFU kernels written in Bluespec. There is a Makefile that will run the BSC to generate Bluespec object files if there are any changes to these source files. The make command asks for the file name to compile as an input.
- [Bluespec Object Files](soma-bsv-base/bsv-obj) : 
  This directory contains pre-compiled Bluespec object files from the Bluespec source. 
  
[SystemVerilog Catalog](soma-sv-base/sv-src) : 
This directory contains SystemVerilog source files for services and AFU kernels written in Bluespec.
