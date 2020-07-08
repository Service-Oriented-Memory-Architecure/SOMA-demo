from enum import Enum
from catalog import Direction
from utilities import BSVType, bit


class MemoryType(Enum):
    CCIP = 0
    AVALON = 1
    AXI = 2
    UNKNOWN = 3

    @staticmethod
    def from_string(string):
        if string == "CCIP":
            return MemoryType.CCIP
        elif string == "AVL" or string == "Avalon" or string == "AVALON":
            return MemoryType.AVALON
        elif string == "AXI":
            return MemoryType.AXI
        else:
            return MemoryType.UNKNOWN


class Memory:
    def __init__(self, memory_type, name):
        self.memory_type = memory_type
        self.name = name

    def add_prefix(self, string):
        return self.name + "_" + string

    def generate_ports(self, writer):
        if self.memory_type == MemoryType.CCIP:
            writer.port(Direction.INPUT, "cp2af_sRx", "t_if_ccip_Rx")
            writer.port(Direction.OUTPUT, "af2cp_sTx", "t_if_ccip_Tx")
        elif self.memory_type == MemoryType.AVALON:
            writer.port(Direction.OUTPUT, self.add_prefix("read"))
            writer.port(Direction.OUTPUT, self.add_prefix("write"))
            writer.portn(Direction.OUTPUT, 64, self.add_prefix("address"))
            writer.portn(Direction.OUTPUT, 512, self.add_prefix("writedata"))
            writer.portn(Direction.INPUT, 512, self.add_prefix("readdata"))
            writer.port(Direction.INPUT, self.add_prefix("waitrequest"))
            writer.port(Direction.INPUT, self.add_prefix("readdatavalid"))
            writer.portn(Direction.OUTPUT, 11, self.add_prefix("burstcount"))
            writer.portn(Direction.OUTPUT, 64, self.add_prefix("byteenable"))

    def generate_logic(self, writer, clock, reset):
        if self.memory_type == MemoryType.CCIP:
            writer.custom("""    assign af2cp_sTx.c2.mmioRdValid = 1'b0;

    wire c0valid;
    wire [15:0] rd_mdata;
    wire [63:0] rd_addr;
    t_ccip_c0_ReqMemHdr rd_hdr;
    always_comb begin
        rd_hdr = t_ccip_c0_ReqMemHdr'(0);
        rd_hdr.req_type = eREQ_RDLINE_I;
        rd_hdr.address = rd_addr;
        rd_hdr.vc_sel = eVC_VA;
        rd_hdr.cl_len = eCL_LEN_1;
        rd_hdr.mdata = '0;
        rd_hdr.mdata = rd_mdata;
    end""")

            writer.line()

            writer.custom_indented(
                "always_ff @(posedge " + clock + ") begin")
            writer.inc_indent()
            writer.custom_indented("if(" + reset + ") begin")
            writer.dec_indent()
            writer.custom("""            af2cp_sTx.c0.valid <= 1'b0;
        end else begin
            af2cp_sTx.c0.valid <= c0valid;
            af2cp_sTx.c0.hdr   <= rd_hdr;
        end
    end
	
    wire c1valid;
    wire [15:0] wr_mdata;
    wire [63:0] wr_addr;
    wire [511:0] wr_data;
    t_ccip_c1_ReqMemHdr wr_hdr;
    always_comb begin
        wr_hdr = t_ccip_c1_ReqMemHdr'(0);
        wr_hdr.req_type = eREQ_WRLINE_I;
        wr_hdr.address = wr_addr;
        wr_hdr.vc_sel = eVC_VA;
        wr_hdr.cl_len = eCL_LEN_1;
        wr_hdr.mdata = '0;
        wr_hdr.mdata = wr_mdata;
        wr_hdr.sop = 1'b1;
    end""")

            writer.line()

            writer.custom_indented(
                "always_ff @(posedge " + clock + ") begin")
            writer.inc_indent()
            writer.custom_indented("if(" + reset + ") begin")
            writer.dec_indent()
            writer.custom("""            af2cp_sTx.c1.valid <= 1'b0;
        end else begin
            af2cp_sTx.c1.valid <= c1valid;
            af2cp_sTx.c1.hdr   <= wr_hdr;
            af2cp_sTx.c1.data <= t_ccip_clData'(wr_data);
            if (c1valid) $display("WR HDR %h",wr_hdr);
        end
    end""")
        else:
            pass

    def generate_connections(self, writer):
        if self.memory_type == MemoryType.CCIP:
            [writer.custom_indented("." + self.add_prefix(s) + ",") for s in
                ["rdReqAddr(rd_addr)",
                 "rdReqMdata(rd_mdata)",
                 "rdReqEN(c0valid)",
                 "rdReqSent_b(!cp2af_sRx.c0TxAlmFull)",
                 "rdRspMdata_m(cp2af_sRx.c0.hdr.mdata)",
                 "rdRspData_d(cp2af_sRx.c0.data)",
                 "rdRspValid_b(cp2af_sRx.c0.rspValid && !cp2af_sRx.c0.mmioRdValid && !cp2af_sRx.c0.mmioWrValid)",
                 "wrReqAddr(wr_addr)",
                 "wrReqMdata(wr_mdata)",
                 "wrReqData(wr_data)",
                 "wrReqEN(c1valid)",
                 "wrReqSent_b(!cp2af_sRx.c1TxAlmFull)",
                 "wrRspMdata_m(cp2af_sRx.c1.hdr.mdata)",
                 "wrRspValid_b(cp2af_sRx.c1.rspValid)"]
             ]
        elif self.memory_type == MemoryType.AVALON:
            [writer.custom_indented("." + self.name + "_" + s + "(" + self.name + "_" + s + "),") for s in
                [
                    "read",
                    "write",
                    "address",
                    "writedata",
                    "readdata",
                    "waitrequest",
                    "readdatavalid",
                    "burstcount",
                    "byteenable",
                ]
            ]

    def generate_passthrough(self, writer, avalon_index=0):
        if self.memory_type == MemoryType.CCIP:
            writer.connect("cp2af_sRx", "cp2af_sRx")
            writer.connect("af2cp_sTx", "af2cp_sTx")
        elif self.memory_type == MemoryType.AVALON:
            [writer.connect(self.add_prefix(s), "local_mem[" + str(avalon_index) + "]." + s) for s in
                [
                    "read",
                    "write",
                    "address",
                    "writedata",
                    "readdata",
                    "waitrequest",
                    "readdatavalid",
                    "burstcount",
                    "byteenable",
                ]
            ]

    def generate_interface(self, writer):
        if self.memory_type == MemoryType.CCIP:
            channels_top_HARP_type = BSVType("ChannelsTopHARP", [bit(64), bit(14), bit(512)])
            writer.interface_decl(channels_top_HARP_type, self.name)
        elif self.memory_type == MemoryType.AVALON:
            avalon_master_type = BSVType("AVALON_MASTER", [bit(32), bit(14), bit(512)])
            writer.interface_decl(avalon_master_type, self.name)
            

    def __str__(self):
        return "[Memory]\n\t" + self.memory_type + "\n\t" + self.name


class Platform:
    def __init__(self, clock, reset, memories):
        self.clock = clock
        self.reset = reset
        self.memories = memories

    def __str__(self):
        return "[Platform]\n\t" + "\n\t".join([self.clock, self.reset, "\n".join(map(str, self.memories))])


class Port:
    def __init__(self, channel_interface_name, connection):
        self.channel_interface_name = channel_interface_name
        self.connection = connection

    def __str__(self):
        return "[Port]\n\t" + self.channel_interface_name + "\n\t" + self.connection


class ConnectedComponent:
    def __init__(self, component_type, name, ports, memory_top, threshold, addr_width, cache_entries):
        self.component_type = component_type
        self.name = name
        self.ports = ports
        self.memory_top = memory_top
        self.threshold = threshold
        self.addr_width = addr_width
        self.cache_entries = cache_entries

    def __str__(self):
        return "[Connected Component]\n\t" + "\n\t".join([self.component_type, self.name, "\n".join(map(str, self.ports))])


class Registry:
    def __init__(self, platform, connected_components):
        self.platform = platform
        self.connected_components = connected_components

    def __str__(self):
        return "[Registry]\n" + "\n".join([str(self.platform), "\n".join(map(str, self.connected_components))])


class Connection:
    def __init__(self, name):
        self.name = name
        self.components = []

    def add_component(self, connected_component, port):
        self.components.append((connected_component, port))

    def identify_provider(self, service_type_to_obj):
        self.provider = None
        self.provider_name = None
        current_provision = None
        for connected_component, port in self.components:
            service = service_type_to_obj[connected_component.component_type]
            for provision in service.provisions:
                if provision.channel_interface_name == port.channel_interface_name:
                    current_provision = provision
                    self.provider = connected_component
                    break
        providing_service = service_type_to_obj[self.provider.component_type]
        if providing_service.is_compound_service:
            self.provider_name = self.provider.name + "." + current_provision.channel_interface_name
        elif len(providing_service.provisions) > 1:
            provider_index = providing_service.provisions.index(current_provision)
            self.provider_name = self.provider.name + ".server" + ["A", "B", "C", "D", "E"][provider_index]
        else:
            self.provider_name = self.provider.name


def parse_registry(registry_json):
    platform_json = registry_json["platform"]
    clock = platform_json["clock"]
    reset = platform_json["reset"]
    memories = []
    for memory_json in platform_json["memory"]:
        memory_type = MemoryType.from_string(memory_json["type"])
        name = memory_json["name"]
        memories.append(Memory(memory_type, name))
    platform = Platform(clock, reset, memories)

    connected_components = []
    for connected_component_json in registry_json["connected-components"]:
        component_type = connected_component_json["type"]
        name = connected_component_json["name"]
        ports = []
        for port_json in connected_component_json["connections"]:
            channel_interface_name = port_json["channel-ifc-name"]
            connection = port_json["connection"]
            ports.append(Port(channel_interface_name, connection))
        memory_top = None
        try:
            memory_top = connected_component_json["memory-ifc"]
        except(KeyError):
            pass
        threshold = None
        try:
            threshold = int(connected_component_json["req-limit"])
        except(KeyError):
            pass
        addr_width = None
        try:
            addr_width = int(connected_component_json["addr-width"])
        except(KeyError):
            pass
        
        cache_entries = 32
        try:
            cache_entries = int(connected_component_json["cache-entries"])
        except(KeyError):
            pass
        connected_components.append(
            ConnectedComponent(component_type, name, ports, memory_top, threshold, addr_width, cache_entries))

    registry = Registry(platform, connected_components)
    return registry
