import sys
import json

# generator-specific utility classes and functions
from catalog import parse_catalog, SourceType, Direction
from utilities import VerilogWriter, BSVWriter, BSVType, bit, Log
from registry import parse_registry, Connection, MemoryType


running_log = Log("Running")

is_counters = False
is_memcopy = False
is_bfs = False

def log2(x):
    b = int.bit_length(x) - 1
    val = 2**b
    if val < x:
        b += 1
    return b

#################### Catalog Driver #########################

with open(sys.argv[1]) as handle:
    catalog_json = json.load(handle)

catalog = parse_catalog(catalog_json)
running_log.log("Catalog", "parsing complete")

service_type_to_obj = {}
for service in catalog:
    service_type_to_obj[service.service_type] = service

#figure out if it's counters, memcopy, or bfs
#TODO add a general way to import modules to catalog
for service in catalog:
    if service.service_type == "memcopy":
        is_memcopy = True
        break
    elif service.service_type == "counters":
        is_counters = True
        break
    elif service.service_type == "BFSafuPipeline":
        is_bfs = True


################### Registry Driver ########################

with open(sys.argv[2]) as handle:
    registry_json = json.load(handle)

registry = parse_registry(registry_json)
running_log.log("Registry", "parsing complete")

top_threshold_map = {}
for memory in registry.platform.memories:
    for component in registry.connected_components:
        if component.memory_top == memory.name:
            if component.threshold != None:
                top_threshold_map[memory.name] = component.threshold
                break

default_threshold = 32

for name, threshold in top_threshold_map.items():
    default_threshold = threshold
    break

#TODO incredible shifty, fix
server_type_map = {}
for component in registry.connected_components:
    service = service_type_to_obj[component.component_type]
    if service.is_compound_service:
        server_type_map[component.name] = BSVType(component.component_type)
    else:
        addr = 32
        data = 512
        threshold = default_threshold
        if service.channels != []:
            channel = service.channels[0]
            addr = channel.argument_size
            data = channel.data_size
        if component.threshold != None:
            threshold = component.threshold
        if service.service_type == "memcopy":
            threshold = 1
        if component.addr_width != None:
            addr = component.addr_width
        # if component.memory_top != None:
        #     if "A" in component.memory_top:
        #         addr = 64

        am_full_type = BSVType("AM_FULL", [bit(addr), bit(data)])
        server_type_map[component.name] = BSVType(
            "Server", [am_full_type, am_full_type, threshold])


connection_map = {}
for component in registry.connected_components:
    for port in component.ports:
        if port.connection in connection_map:
            connection_map[port.connection].add_component(
                component, port)
        else:
            connection_map[port.connection] = Connection(port.connection)
            connection_map[port.connection].add_component(
                component, port)

for connection_name in connection_map:
    connection_map[connection_name].identify_provider(service_type_to_obj)

# isolate verilog modules
verilog_components = []
verilog_component_names = []
for component in registry.connected_components:
    service = service_type_to_obj[component.component_type]
    if service.source_type == SourceType.SYSTEM_VERILOG:
        verilog_components.append(component)
        verilog_component_names.append(component.name)

verilog_connection_names = []
for component in verilog_components:
    for port in component.ports:
        if port.connection not in verilog_connection_names:
            verilog_connection_names.append(port.connection)


used_memory_interfaces = []
for memory in registry.platform.memories:
    for component in registry.connected_components:
        if component.memory_top == memory.name:
            used_memory_interfaces.append(memory)
            break


################## Generate App Top ########################

running_log.log("Codegen", "generating app top")

app_top = VerilogWriter()

#include headers
app_top.include("csr_mgr.vh")
app_top.include("platform_if.vh")
app_top.include("active_msg.vh")

app_top.line()

#import something useful
app_top.import_all("local_mem_cfg_pkg")

app_top.line()

#start the module
app_top.begin_module("soma_app_top", parameters=[("NUM_LOCAL_MEM_BANKS", 2)])
app_top.inc_indent()

#generate clock and reset
app_top.port(Direction.INPUT, registry.platform.clock)
app_top.port(Direction.INPUT, registry.platform.reset)

app_top.line()

#generate memory connections
app_top.custom_indented("avalon_mem_if.to_fiu local_mem[NUM_LOCAL_MEM_BANKS],")
app_top.port(Direction.INPUT, "cp2af_sRx", "t_if_ccip_Rx")
app_top.port(Direction.OUTPUT, "af2cp_sTx", "t_if_ccip_Tx")

app_top.line()

#generate CSR connections
app_top.port(None, "csrs", "app_csrs.app")

#close module definition
app_top.dec_indent()
app_top.remove_last_comma()
app_top.close_and_semicolon()

app_top.line()

app_top.inc_indent()

#switch off unused Avalon interfaces
avalon_count = 0
for memory in used_memory_interfaces:
    if memory.memory_type == MemoryType.AVALON:
        avalon_count += 1

print(avalon_count)

if avalon_count <= 2:
    for i in range(1, avalon_count - 1, -1):
        app_top.continuous("local_mem[" + str(i) + "].read", "1'b0")
        app_top.continuous("local_mem[" + str(i) + "].write", "1'b0")

app_top.line()

#generate verilog servers
verilog_connection_map = {}
for connection_name in verilog_connection_names:
    connection = connection_map[connection_name]
    fanout = len(connection.components) - 1
    
    for i, (component, port) in enumerate(connection.components, 0):
        if component != connection.provider:
            if fanout == 1:
                generated_name = connection.provider.name
            else:
                generated_name = connection.provider.name+"_"+str(i)
            if component.name in verilog_connection_map:
                verilog_connection_map[component.name].append(
                    (port.channel_interface_name, generated_name))
            else:
                verilog_connection_map[component.name] = [
                    (port.channel_interface_name, generated_name)]
            providing_server_type = server_type_map[connection.provider.name]
            addr_width = providing_server_type.type_args[0].type_args[0].type_args
            if addr_width != 32:
                app_top.decl(generated_name + "()", "server" + "#(.SDARG_BITS(" + str(addr_width) + "))")
            else:
                app_top.decl(generated_name + "()", "server")

app_top.line()

#generate start, finish
app_top.decl("start")
app_top.decl("finish")

app_top.line()

#generate local start and finishes
nodes_with_finish = []
app_top.decl("startLocal")
for component in registry.connected_components:
    try:
        service = service_type_to_obj[component.component_type]
        if service.control.finish != None:
            app_top.decl("finish_" + component.name)
            nodes_with_finish.append(component)
    except:
        pass

app_top.line()

#generate start and finish logic
app_top.custom("""    always_ff @(posedge clk) begin
        if (SoftReset) begin
            startLocal <= 0;
            finish <= 0;
        end else begin
            startLocal <= start;""")

app_top.inc_indent()
app_top.inc_indent()
if nodes_with_finish == []:
    app_top.non_blocking("finish", "0")
else:
    app_top.non_blocking("finish", " && ".join(
        map(lambda x: "finish_"+x.name, nodes_with_finish)))
app_top.dec_indent()
app_top.dec_indent()

app_top.custom("""        end
    end""")

app_top.line()

#generate configuration signals
config_signal_names = []
bsv_config_signal_names = []
bsv_config_signal_map = {}
for component in registry.connected_components:
    service = service_type_to_obj[component.component_type]
    if service.control != None:
        for config in service.control.configs:
            config_signal_name = config.name + "_" + component.name
            app_top.decln(config.size, config_signal_name)
            config_signal_names.append(config_signal_name)
            if component.name not in verilog_component_names:
                bsv_config_signal_names.append(config_signal_name)
                bsv_config_signal_map[config_signal_name] = config
        
app_top.line()

#generate control ports
control_port_names = []
for component in registry.connected_components:
    service = service_type_to_obj[component.component_type]
    if service.control != None:
        for control_port in service.control.control_ports:
            control_port_name = control_port.name + "_" + component.name
            control_port_names.append(control_port_name)
            app_top.decln(control_port.size, control_port_name)

app_top.line()

#generate CSR module
app_top.instantiate("soma_csr", "csr")
app_top.inc_indent()

app_top.connect("clk", registry.platform.clock)
app_top.connect("SoftReset", registry.platform.reset)
app_top.connect("csrs", "csrs")
app_top.connect("start", "start")
app_top.connect("finish", "finish")

for config_name in config_signal_names:
    app_top.connect(config_name, config_name)

for control_port_name in control_port_names:
    app_top.connect(control_port_name, control_port_name)

app_top.dec_indent()
app_top.remove_last_comma()
app_top.close_and_semicolon()
app_top.line()

#generate verilog server modules
for component in verilog_components:
    service = service_type_to_obj[component.component_type]
    app_top.instantiate(service.source_path, "my_" + component.name)

    app_top.inc_indent()

    app_top.connect("clk", registry.platform.clock)
    app_top.connect("rst", registry.platform.reset)
    for channel_interface_name, generated_name in verilog_connection_map[component.name]:
        app_top.connect(channel_interface_name, generated_name)
    if component in nodes_with_finish:
        app_top.connect("start", "startLocal")
        app_top.connect("done", "finish_" + component.name)
    try:
        for config in service.control.configs:
            app_top.connect(config.name, config.name + "_" + component.name)
        for control_port in service.control.control_ports:
            app_top.connect(control_port.name,
                            control_port.name + "_" + component.name)
    except:
        pass

    app_top.dec_indent()
    app_top.remove_last_comma()
    app_top.close_and_semicolon()
    app_top.line()

#generate server system
app_top.instantiate("servers_system", "system_top")

app_top.inc_indent()

app_top.connect("clk", registry.platform.clock)
app_top.connect("SoftReset", registry.platform.reset)
for name, connection_list in verilog_connection_map.items():
    for channel_interface_name, generated_name in connection_list:
        app_top.connect(generated_name, generated_name)
for name in bsv_config_signal_names:
    app_top.connect(name, name)

avalon_index = 0
for memory in used_memory_interfaces:
    app_top.line()
    if memory.memory_type == MemoryType.AVALON:
        memory.generate_passthrough(app_top, avalon_index=avalon_index)
        avalon_index += 1
    else:
        memory.generate_passthrough(app_top)


app_top.dec_indent()
app_top.remove_last_comma()
app_top.close_and_semicolon()

app_top.line()

app_top.end_module("soma_app_top")
running_log.log("Codegen", "finished generating app top")


################ Generate Verilog System ###################

running_log.log("Codegen", "generating SystemVerilog system")

verilog_system = VerilogWriter()

#generate includes
verilog_system.include("platform_if.vh")
verilog_system.include("active_msg.vh")

verilog_system.line()

#generate module beginning
verilog_system.begin_module("servers_system")
verilog_system.inc_indent()

#generate clock and reset
verilog_system.port(Direction.INPUT, registry.platform.clock)
verilog_system.port(Direction.INPUT, registry.platform.reset)

verilog_system.line()

#generate verilog server connections
for name, connection_list in verilog_connection_map.items():
    for channel_interface_name, generated_name in connection_list:
        verilog_system.port(None, generated_name, "server.svr")

verilog_system.line()

#generate configuration signals
for name, config in bsv_config_signal_map.items():
    verilog_system.portn(config.direction, config.size, name)

#generate memory interface connections
for memory in used_memory_interfaces:
    verilog_system.line()
    memory.generate_ports(verilog_system)

#end module definition
verilog_system.dec_indent()
verilog_system.remove_last_comma()
verilog_system.close_and_semicolon()
verilog_system.inc_indent()

#generate logic for memory interfaces
for memory in used_memory_interfaces:
    memory.generate_logic(
        verilog_system, registry.platform.clock, registry.platform.reset)
    verilog_system.line()

verilog_system.line()

#generate BSV module
verilog_system.instantiate("mkServerSys", "my_sys")
verilog_system.inc_indent()

#connect clock and reset
verilog_system.connect("CLK", registry.platform.clock)
verilog_system.connect("RST_N", "~" + registry.platform.reset)

verilog_system.line()

#generate memory top connections
for memory in used_memory_interfaces:
    memory.generate_connections(verilog_system)
    verilog_system.line()

verilog_system.line()

#generate BSV to verilog connections
for name, connection_list in verilog_connection_map.items():
    for channel_interface_name, generated_name in connection_list:
        verilog_system.connect(generated_name + "_txFull",
                               generated_name + ".txFull")
        verilog_system.connect(generated_name + "_tx_msg",
                               generated_name + ".txP.tx_msg")
        verilog_system.connect("EN_" + generated_name +
                               "_tx", generated_name + ".txP.tx")
        verilog_system.connect(generated_name + "_rxEmpty",
                               generated_name + ".rxP.rxEmpty")
        verilog_system.connect("EN_" + generated_name +
                               "_rxPop", generated_name + ".rxPop")
        verilog_system.connect(generated_name + "_rx_msg",
                               generated_name + ".rxP.rx_msg")
        verilog_system.line()

for name in bsv_config_signal_names:
    verilog_system.connect(name, name)

#end module
verilog_system.dec_indent()
verilog_system.remove_last_comma()
verilog_system.close_and_semicolon()
verilog_system.line()

verilog_system.end_module("servers_system")

running_log.log("Codegen", "finished generating SystemVerilog system")


################## Generate BSV System #####################

running_log.log("Codegen", "generating BSV system")

bsv_system = BSVWriter()

#import modules
bsv_system.import_all("MessagePack")
bsv_system.import_all("Vector")
bsv_system.import_all("Channels")

if is_counters:
    bsv_system.import_all("CountersServer")
elif is_bfs:
    bsv_system.import_all("MemCopy")
    bsv_system.import_all("Cache")
    bsv_system.import_all("Worklist")
    bsv_system.import_all("BFS")
    bsv_system.import_all("BFSafuPipeline")

elif is_memcopy:
    bsv_system.import_all("MemCopy")

bsv_system.line()

#start main interface
bsv_system.begin_interface("ServerSys")
bsv_system.inc_indent()

#declare memory interfaces
for memory in used_memory_interfaces:
    memory.generate_interface(bsv_system)

#declare BSV servers that provide to verilog servers
provider_type_map = {}
for connection_name in verilog_connection_names:
    connection = connection_map[connection_name]
    connection_fanout = len(connection.components) - 1
    if (connection_fanout > 1):
        provider_type = BSVType("Vector", [
            connection_fanout,
            server_type_map[connection.provider.name]
        ])
    else:
        provider_type = server_type_map[connection.provider.name]
    provider_type_map[connection.provider.name] = provider_type
    bsv_system.interface_decl(provider_type, connection.provider.name)

#declare configuration signals
for name, config in bsv_config_signal_map.items():
    if config.size == 1:
        t = BSVType("Bool")
    else:
        t = bit(config.size)

    if config.direction == Direction.INPUT:
        bsv_system.method_single_arg_action_decl(name, "x", t, name, '(* always_ready, always_enabled, prefix = "" *)')
    else:
        bsv_system.custom_indented('(* always_ready, always_enabled, prefix = "" *) method ' + str(t) + " " + name + "();")

#end interface declaration
bsv_system.end_interface()

bsv_system.line()

#start module declaration
bsv_system.custom("(* synthesize *)")
bsv_system.begin_module("mkServerSys", "ServerSys")


#count channel usage
read_channels_count = {}
write_channels_count = {}
for memory in used_memory_interfaces:
    read_channels_count[memory.name] = 0
    write_channels_count[memory.name] = 0

for connection_name, connection in connection_map.items():
    if connection.provider.component_type == "read":
        read_channels_count[connection.provider.memory_top] += 1
    elif connection.provider.component_type == "write":
        write_channels_count[connection.provider.memory_top] += 1
    elif connection.provider.component_type == "cache":
        read_channels_count[connection.provider.memory_top] += 1
        write_channels_count[connection.provider.memory_top] += 1

#channel_type_lt = [bit(64), bit(4), bit(512), 2, 8]
#read_channel_type = BSVType("RdChannel", channel_type_lt)
#write_channel_type = BSVType("WrChannel", channel_type_lt)

#generate memory tops and Ys
for memory in used_memory_interfaces:
    convert_name = memory.name + "_convert"
    read_channel_name = "memR" + "_" + memory.name
    write_channel_name = "memW" + "_" + memory.name
    read_y_name = "memRY" + "_" + memory.name
    write_y_name = "memWY" + "_" + memory.name

    top_threshold = top_threshold_map[memory.name]

    read_count = read_channels_count[memory.name]
    write_count = write_channels_count[memory.name]

    
    read_channel_marg = log2(top_threshold) + log2(read_count)
    write_channel_marg = log2(top_threshold) + log2(write_count)

    address_width = 64
    if memory.memory_type == MemoryType.AVALON:
        address_width = 32

    read_y_type_lt = [bit(address_width), bit(log2(top_threshold)), bit(512), 2, top_threshold]
    write_y_type_lt = [bit(address_width), bit(log2(top_threshold)), bit(512), 2, top_threshold]

    convert_args_lt = [
        bit(read_channel_marg),
        bit(write_channel_marg),
        bit(address_width),
        bit(14),
        bit(512),
        2,
        top_threshold
    ]

    if memory.memory_type == MemoryType.CCIP:
        bsv_system.instantiate(BSVType("TopConvertHARP", convert_args_lt),
                               convert_name, "mkTopConvertHARP")
    elif memory.memory_type == MemoryType.AVALON:
        bsv_system.instantiate(BSVType("TopConvertAvalon", convert_args_lt),
                               convert_name, "mkTopConvertAvalon")
    elif memory.memory_type == MemoryType.AVALON:
        bsv_system.instantiate(BSVType("TopConvertAxi", convert_args_lt),
                               convert_name, "mkTopConvertAxi")

    # Generate RW channels
    bsv_system.assign(BSVType("RdChannel", [bit(address_width), bit(read_channel_marg), bit(512), 2, top_threshold]), read_channel_name,
                      convert_name + ".rdch")
    bsv_system.assign(BSVType("WrChannel", [bit(address_width), bit(write_channel_marg), bit(512), 2, top_threshold]), write_channel_name,
                      convert_name + ".wrch")

    if read_count > 1:
        read_y_type = BSVType("RdY", [read_count] + read_y_type_lt)
        bsv_system.instantiate(read_y_type, read_y_name, "mkRdY", [
                               "True", read_channel_name])

    if write_count > 1:
        write_y_type = BSVType("WrY", [write_count] + write_y_type_lt)
        bsv_system.instantiate(write_y_type, write_y_name, "mkWrY", [
                               "True", write_channel_name])

    bsv_system.line()

bsv_system.line()

for name, config in bsv_config_signal_map.items():
    if config.direction == Direction.INPUT and not config.is_compound_service:
        if config.size == 1:
            t = BSVType("Bool")
        else:
            t = bit(config.size)
        signal_type = BSVType("Reg", t)
        if config.size == 1:
            bsv_system.instantiate(signal_type, "reg" + name, "mkReg", "False")
        else:
            bsv_system.instantiate(signal_type, "reg" + name, "mkReg", 0)

bsv_system.line()

bsv_system.line()

#wire everything up
connection_map_counts = {}
for connection_name, connection in connection_map.items():
    connection_map_counts[connection.provider.name] = len(
        connection.components) - 1

#iterate till map is empty i.e. all connection ports have been used up
remaining_map = {}
for key, val in connection_map_counts.items():
    remaining_map[key] = val

done_map = {}
completed_map = {}
completed_list = []

read_server_index = {}
write_server_index = {}
for memory in used_memory_interfaces:
    read_server_index[memory.name] = 0
    write_server_index[memory.name] = 0

were_changes_made = True
while(were_changes_made):
    were_changes_made = False
    for component in registry.connected_components:
        if component.name in verilog_component_names:
            continue

        if component.name in completed_list:
            continue

        server_type = server_type_map[component.name]
        args_lt = []
        service = service_type_to_obj[component.component_type]
        config_str = ""

        if component.component_type == "read" or component.component_type == "write" or component.component_type == "cache":
            configs_lt = []
            if service.control != None:
                for config in service.control.configs:
                    signal_name = "reg" + config.name + "_" + component.name
                    if config.size > server_type.type_args[0].type_args[0].type_args:
                        signal_name = "truncate(" + signal_name + ")"
                    elif config.size < server_type.type_args[0].type_args[0].type_args:
                        signal_name = "extend(" + signal_name + ")"
                    configs_lt.append(signal_name) 
            config_str = ", ".join(configs_lt)
        else:
            try:
                config_str = ", ".join(
                    ["reg" + config.name + "_" + component.name for config in service.control.configs])
            except:
                pass
        
        if component.component_type == "read":
            if read_channels_count[component.memory_top] == 1:
                args_lt = ["memR" + "_" + component.memory_top, config_str]
            else:
                args_lt = [
                    "memRY" + "_" + component.memory_top + ".rdch[" + str(read_server_index[component.memory_top]) + "]", config_str]
            read_server_index[component.memory_top] += 1
        elif component.component_type == "write":
            if write_channels_count[component.memory_top] == 1:
                args_lt = ["memW" + "_" + component.memory_top, config_str]
            else:
                args_lt = [
                    "memWY" + "_" + component.memory_top + ".wrch[" + str(write_server_index[component.memory_top]) + "]", config_str]
            write_server_index[component.memory_top] += 1
        elif component.component_type == "cache":
            if read_channels_count[component.memory_top] == 1:
                args_lt = ["memR" + "_" + component.memory_top]
            else:
                args_lt = [
                    "memRY" + "_" + component.memory_top + ".rdch[" + str(read_server_index[component.memory_top]) + "]"]

            if write_channels_count[component.memory_top] == 1:
                args_lt.append("memW" + "_" + component.memory_top)
            else:
                args_lt.append("memWY" + "_" + component.memory_top + ".wrch[" + str(write_server_index[component.memory_top]) + "]")

            args_lt.append("cache_entries")
            args_lt.append(config_str)

            read_server_index[component.memory_top] += 1
            write_server_index[component.memory_top] += 1

            bsv_system.custom_indented("NumTypeParam#(" + str(component.cache_entries) + ") cache_entries = ?;")

        else:
            # check if prerequisites done
            provided_interface_names = [
                provision.channel_interface_name for provision in service.provisions]
            prerequisites_met = True
            for port in component.ports:
                if port.channel_interface_name in provided_interface_names:
                    continue
                elif connection_map[port.connection].provider_name not in done_map:
                    prerequisites_met = False

            if not prerequisites_met:
                continue
            else:
                for port in component.ports:
                    if port.channel_interface_name in provided_interface_names:
                        continue
                    else:
                        provider_name = connection_map[port.connection].provider_name
                        provider_generated_name, provider_count, provider_index = done_map[
                            provider_name]
                        if provider_count == 1:
                            args_lt.append(provider_generated_name)
                            del done_map[provider_name]
                        else:
                            args_lt.append(
                                provider_generated_name + "[" + str(provider_index) + "]")
                            provider_index += 1
                            if provider_index == provider_count:
                                del done_map[provider_name]
                            else:
                                done_map[provider_name] = (
                                    provider_generated_name, provider_count, provider_index)
                if service.control != None and not service.is_compound_service:
                    for config in service.control.configs:
                        args_lt.append("reg" + config.name + "_" + component.name)

        count = 1
        generated_name = "srv" + component.name

        if component.name in connection_map_counts:
            count = connection_map_counts[component.name]

        if not service.is_compound_service:
            am_type = server_type.type_args[0]
            if len(service.provisions) > 1:
                server_type.primary += str(len(service.provisions))

        bsv_system.instantiate(server_type, generated_name,
                               service.source_path, args_lt)

        if count > 1:
            tx_msg_channel_mux_type = BSVType(
                "TxMsgChannelMux", [count, am_type])
            rx_msg_channel_demux_type = BSVType(
                "RxMsgChannelDemux", [count, am_type])
            
            bsv_system.instantiate(tx_msg_channel_mux_type, generated_name +
                                "TxY", "mkTxMuxAuto", [True, generated_name + ".txPort"])
        
            bsv_system.instantiate(rx_msg_channel_demux_type, generated_name +
                                   "RxY", "mkRxDemux", [True, generated_name + ".rxPort"])
            generated_name += "Y"
            vector_type = BSVType("Vector", [count, server_type])
            bsv_system.decl(vector_type, generated_name)
            bsv_system.custom_indented(
                "for(Integer i=0; i < " + str(count) + "; i=i+1) begin")

            bsv_system.inc_indent()
            bsv_system.custom_indented(
                "let sv = interface " + str(server_type) + ";")
            bsv_system.inc_indent()
            bsv_system.assign(
                "", "txPort", generated_name[:-1] + "TxY.txPort[i]", True)
            bsv_system.assign(
                "", "rxPort", generated_name[:-1] + "RxY.rxPort[i]", True)
            bsv_system.dec_indent()
            bsv_system.custom_indented("endinterface;")
            bsv_system.assign("", generated_name + "[i]", "sv")
            bsv_system.dec_indent()
            bsv_system.custom_indented("end")

        if service.is_compound_service:
            name = component.name
            try:
                name += "." + service.provisions[0].channel_interface_name
            except:
                pass
            gen_name = "srv" + name
            done_map[name] = (gen_name, 1, 0)
            completed_map[name] = gen_name
            completed_list.append(name)
        elif len(service.provisions) > 1:
            for i in range(len(service.provisions)):
                name = component.name + ".server" + ["A", "B", "C", "D", "E"][i]
                gen_name = "srv" + name
                done_map[name] = (gen_name, 1, 0)
                completed_map[name] = gen_name
                completed_list.append(name)
        else:
            done_map[component.name] = (generated_name, count, 0)
            completed_map[component.name] = generated_name
            completed_list.append(component.name)
        were_changes_made = True
        bsv_system.line()

# Wire up interfaces and methods
for memory in used_memory_interfaces:
    bsv_system.assign("", memory.name, memory.name + "_convert.top", True)

for name in provider_type_map:
    bsv_system.assign("", name, completed_map[name], True)

bsv_system.line()

for name, config in bsv_config_signal_map.items():
    if config.size == 1:
        t = BSVType("Bool")
    else:
        t = bit(config.size)

    if config.direction == Direction.INPUT:
        bsv_system.custom_indented(
            "method Action " + name + "(" + str(t) + " x);")
        bsv_system.inc_indent()
        if config.is_compound_service:
            component_name = name.split("_")[-1]
            bsv_system.custom_indented("srv" + component_name + "." + config.name + "(x);")
        else:
            bsv_system.non_blocking("reg" + name, "x")
        bsv_system.dec_indent()
        bsv_system.custom_indented("endmethod")
    else:
        component_name = name.split("_")[-1]
        bsv_system.custom_indented("method " + str(t) + " " + name + "();")
        bsv_system.inc_indent()
        bsv_system.custom_indented("return srv" + component_name + "." + config.name + "();")
        bsv_system.dec_indent()
        bsv_system.custom_indented("endmethod")

bsv_system.line()
bsv_system.end_module()

running_log.log("Codegen", "finished generating BSV system")

running_log.log("Output", "opening app top file for writing")
with open("soma_app_top.sv", "w") as handle:
    handle.write(app_top.buffer)
running_log.log("Output", "finished writing app top")

running_log.log("Output", "opening SystemVerilog system file for writing")
with open("servers_system.sv", "w") as handle:
    handle.write(verilog_system.buffer)
running_log.log("Output", "finished writing SystemVerilog system")

running_log.log("Output", "opening BSV system file for writing")
with open("ServerSys.bsv", "w") as handle:
    handle.write(bsv_system.buffer)
running_log.log("Output", "finished writing BSV system")

print(running_log)
