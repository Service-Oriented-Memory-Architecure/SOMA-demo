# Breadth-First Search Example

All Makefiles for this example exist in the configuration subdirectories:

- [CCIP](bfs_src/ccip/)
- [Avalon](bfs_src/avalon/)
- [Avalon Cache](bfs_src/avalon-cache/)

## BFS Kernel

The BFS kernel pipeline RTL is located in: [BFS Kernel](bfs_src/bfs-afu/)

The kernel is written in Bluespec however its simplicity is 
not a product of the language, it is due to absorbing much of
the complexity into services. The resulting user-level RTL is
clean resembling the algorithm pseudocode. Similar user-level
RTL in SystemVerilog is a trivial transition from Bluespec, 
however we chose to use Bluespec as it is familiar to our team.

Each example configuration supports this pipeline with different
memory landscapes: accessing data over CCIP or Avalon, and/or
with a configurable cache for the node distance data. 
