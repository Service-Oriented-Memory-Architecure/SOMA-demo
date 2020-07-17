# MIT License
# 
# Copyright (c) 2020 by Joseph Melber, Siddharth Sahay, Carnegie Mellon University
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

from enum import Enum


class PropertyType(Enum):
    INTEGER = 1
    STRING = 2
    BOOLEAN = 3
    UNKNOWN = 4

    @staticmethod
    def from_string(string):
        if string == "integer":
            return PropertyType.INTEGER
        elif string == "string":
            return PropertyType.STRING
        elif string == "boolean":
            return PropertyType.BOOLEAN
        else:
            return PropertyType.UNKNOWN


def check_default():
    return True


def check_numeric(value, bounds):
    minimum_value, maximum_value = bounds
    return (value >= minimum_value) & (value <= maximum_value)


def check_list(value, values_list):
    return value in values_list


class Property:
    def __init__(self, name, description, property_type, constraint_data):
        self.name = name
        self.description = description
        self.constraint_data = constraint_data
        self.property_type = property_type
        if property_type is PropertyType.INTEGER:
            self.check_constraint_fn = check_numeric
        elif property_type is PropertyType.STRING:
            self.check_constraint_fn = check_list
        else:
            self.check_constraint_fn = check_default

    def check_constraint(self, value):
        return self.check_constraint_fn(value, self.constraint_data)

    def __str__(self):
        return "\t[Property]\n\t\t" + "\n\t\t".join([self.name, self.description, str(self.property_type), str(self.constraint_data)])


class SourceType(Enum):
    VERILOG = 1
    SYSTEM_VERILOG = 2
    BLUESPEC_SYSTEM_VERILOG = 3
    BLUESPEC_CLASSIC = 4
    SOFTWARE = 5
    UNKNOWN = 6

    @staticmethod
    def from_string(string):
        if string == "SV":
            return SourceType.SYSTEM_VERILOG
        elif string == "BSV":
            return SourceType.BLUESPEC_SYSTEM_VERILOG
        else:
            return SourceType.UNKNOWN

    @staticmethod
    def to_path_key(source_type):
        if source_type == SourceType.SYSTEM_VERILOG:
            return "sv-mod"
        elif source_type == SourceType.BLUESPEC_SYSTEM_VERILOG:
            return "bsv-mod"
        else:
            return "unknown"


class Channel:
    def __init__(self, interface_name, argument_size, data_size):
        self.interface_name = interface_name
        self.argument_size = argument_size
        self.data_size = data_size

    def __str__(self):
        return "\t[Channel]\n\t\t" + "\n\t\t".join([self.interface_name, str(self.argument_size), str(self.data_size)])


class Requirement:
    def __init__(self, service_type, channel_interface_name):
        self.service_type = service_type
        self.channel_interface_name = channel_interface_name

    def __str__(self):
        return "\t[Requirement]\n\t\t" + "\n\t\t".join([self.service_type, self.channel_interface_name])


class Direction(Enum):
    INPUT = 1
    OUTPUT = 2
    INOUT = 3
    UNKNOWN = 4

    @staticmethod
    def from_string(string):
        if string == "input":
            return Direction.INPUT
        elif string == "output":
            return Direction.OUTPUT
        elif string == "inout":
            return Direction.INOUT
        else:
            return Direction.UNKNOWN

    @staticmethod
    def to_string(direction):
        if direction == Direction.INPUT:
            return "input"
        elif direction == Direction.OUTPUT:
            return "output"
        elif direction == Direction.INOUT:
            return "inout"
        else:
            return "unknown"


class Config:
    def __init__(self, name, size, direction):
        self.name = name
        self.size = size
        self.direction = direction

    def __str__(self):
        return "[Config]\n\t\t\t" + "\n\t\t\t".join([self.name, str(self.size), str(self.direction)])


class ControlPort:
    def __init__(self, name, size, direction):
        self.name = name
        self.size = size
        self.direction = direction


class Control:
    def __init__(self, start, finish, configs, control_ports):
        self.start = start
        self.finish = finish
        self.configs = configs
        self.control_ports = control_ports

    def __str__(self):
        return "\t[Control]\n\t\t" + "\n\t\t".join([str(self.start), str(self.finish), "\n".join(map(str, self.configs))])


class Provision:
    def __init__(self, service_type, channel_interface_name):
        self.service_type = service_type
        self.channel_interface_name = channel_interface_name

    def __str__(self):
        return "\t[Provision]\n\t\t" + "\n\t\t".join([self.service_type, self.channel_interface_name])


class Service:
    def __init__(self, service_type, description, source_type, source_path, channels, requirements, properties, provisions, control, is_compound_service):
        self.service_type = service_type
        self.description = description
        self.source_type = source_type
        self.source_path = source_path
        self.channels = channels
        self.requirements = requirements
        self.properties = properties
        self.provisions = provisions
        self.control = control
        self.is_compound_service = is_compound_service

    def __str__(self):
        return "[Service]\n" + "\n".join([str(self.service_type), self.description, str(self.source_type), self.source_path,
                                          "\n".join(map(str, self.channels)), "\n".join(
                                              map(str, self.requirements)), "\n".join(map(str, self.properties)),
                                          "\n".join(map(str, self.provisions)), str(self.control)])


def parse_catalog(catalog_json):
    catalog = []
    for service_json in catalog_json:
        service_type = service_json["type"]
        description = None
        try:
            description = service_json["description"]
        except:
            pass
        source_type = SourceType.from_string(service_json["source"])
        source_path = service_json[SourceType.to_path_key(source_type)]

        channels = []
        for channel_json in service_json["channels"]:
            interface_name = channel_json["ifc-name"]
            argument_size = 32
            try:
                argument_size = int(channel_json["arg-size"])
            except:
                pass
            data_size = int(channel_json["data-size"])
            channels.append(Channel(interface_name, argument_size, data_size))

        requirements = []
        try:
            for requirement_json in service_json["requires"]:
                required_service_type = requirement_json["service-type"]
                channel_interface_name = requirement_json["channel-ifc-name"]
                requirements.append(Requirement(
                    required_service_type, channel_interface_name))
        except(KeyError):
            pass

        control = None
        try:
            control_json = service_json["control"]
            start = None
            finish = None
            try:
                start = control_json["start"]
                finish = control_json["finish"]
            except(KeyError):
                start = None
                finish = None

            configs = []
            try:
                for config_json in control_json["config"]:
                    name = config_json["name"]
                    size = config_json["size"]
                    direction = Direction.from_string(
                        config_json["direction"])
                    configs.append(Config(name, size, direction))
            except(KeyError):
                pass

            control_ports = []
            try:
                for control_port_json in control_json["ports"]:
                    control_name = control_port_json["name"]
                    control_size = int(control_port_json["size"])
                    control_direction = Direction.from_string(
                        control_port_json["direction"])
                    control_ports.append(ControlPort(
                        control_name, control_size, control_direction))
            except(KeyError):
                pass

            control = Control(start, finish, configs, control_ports)
        except(KeyError):
            pass

        provisions = []
        try:
            for provision_json in service_json["provides"]:
                provided_service_type = provision_json["service-type"]
                channel_interface_name = provision_json["channel-ifc-name"]
                provisions.append(
                    Provision(provided_service_type, channel_interface_name))
        except(KeyError):
            pass

        properties = []
        try:
            for name, property_json in service_json["properties"].items():
                property_description = property_json["description"]
                property_type = PropertyType.from_string(property_json["type"])
                constraint_data = None
                if property_type is PropertyType.INTEGER:
                    minimum_value = int(property_json["min"])
                    maximum_value = int(property_json["max"])
                    constraint_data = (minimum_value, maximum_value)
                elif property_type is PropertyType.STRING:
                    constraint_data = []
                    for option in property_json["options"]:
                        constraint_data.append(str(option))
                else:
                    constraint_data = None
                properties.append(Property(name, property_description,
                                           property_type, constraint_data))
        except(KeyError):
            pass

        is_compound_service = False
        try:
            is_compound_service = bool(service_json["compound-interface"])
        except:
            pass
    
        if control != None:
            for config in control.configs:
                config.is_compound_service = is_compound_service
        
        service = Service(service_type, description, source_type,
                               source_path, channels, requirements, properties, provisions, control, is_compound_service)
        catalog.append(service)

    return catalog
