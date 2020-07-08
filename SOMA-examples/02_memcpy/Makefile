PY=python3
BSC=bsc
SIM=QUESTA
#SIM=VCS

default: sim

help:
	@echo The default command is: make sim;
	@echo This command sets up the ASE simulation directory for the example.;
	@echo Previously generated verilog and bluespec, and compiled bluespec are included for convenience.;
	@echo ;
	@echo make full: Runs the entire flow to generate the example from CATALOG and REGISTRY files to RTL.;
	@echo This requires the SOMA-generator and SOMA-bluespec repositories, and the bluespec compiler.;
	@echo ;
	@echo make generate: Runs the generation script producing the RTL for the example from the CATALOG and REGISTRY files.;
	@echo ;
	@echo make bsv-compile: Runs the bluespec compiler to compile the generated ServerSys.bsv file.;
	@echo ;

generate: 
	cp ${SOMAEX}/02_memcpy/memcpy_src/MEMCPY_CATALOG.json ${SOMAGEN}
	cp ${SOMAEX}/02_memcpy/memcpy_src/MEMCPY_REGISTRY.json ${SOMAGEN}
	cd ${SOMAGEN}; \
	$(PY) generate.py MEMCPY_CATALOG.json MEMCPY_REGISTRY.json; \
	cp ${SOMAGEN}/*v ${SOMAEX}/02_memcpy/memcpy_src/; \
	rm *.json
	@echo ; \
	echo Finished generating soma_app_top.sv servers_system.sv and ServerSys.bsv.; \
	echo Please run: make bsv-compile.

bsv-compile:
	cp ${SOMAEX}/02_memcpy/memcpy_src/ServerSys.bsv ${SOMABSV}/soma-bsv-base/; \
	cd ${SOMABSV}/soma-bsv-base; \
	bsc -verilog -u -bdir ${SOMABSV}/soma-bsv-base/bsv-obj -vdir ${SOMABSV}/soma-bsv-base/ -g mkServerSys ServerSys.bsv; \
	cp mkServerSys.v ${SOMAEX}/02_memcpy/memcpy_src/
	@echo ; \
	echo Finished Bluespec compilation. Built: mkServerSys.v.; \
	echo Please run: make sim.

sim:	
	cd ${SOMAEX}/02_memcpy/memcpy_gen; \
	afu_sim_setup -s hw/rtl/sources.txt -p discrete_pcie3 -t $(SIM) build_sim; \
	cd ./build_sim
	@echo ; \
	echo ASE hardware simulation directory now set up.; \
        echo Please change directories to ${SOMAEX}/02_memcpy/memcpy_gen/build_sim to proceed.

synth:	
	cd ${SOMAEX}/02_memcpy/memcpy_gen; \
	afu_synth_setup -s hw/rtl/sources.txt -p discrete_pcie3 build_synth
	@echo ; \
	echo ASE hardware synthesis directory now set up.; \
        echo Please change directories to ${SOMAEX}/02_memcpy/memcpy_gen/build_synth to proceed.

full: generate bsv-compile sim
	@cp ${SOMAEX}/02_memcpy/memcpy_src/*.sv ${SOMAEX}/02_memcpy/memcpy_gen/hw/rtl/; \
	cp ${SOMAEX}/02_memcpy/memcpy_src/*.v ${SOMAEX}/02_memcpy/memcpy_gen/hw/rtl/;

clean: 
	rm -r ${SOMAEX}/02_memcpy/memcpy_gen/build_sim

