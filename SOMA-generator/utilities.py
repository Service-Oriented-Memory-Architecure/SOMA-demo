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

from catalog import Direction

class Log:
    def __init__(self, name):
        self.logs = []
        self.name = name

    def log(self, category, string):
        self.logs.append((category, string))

    def __str__(self):
        return "\n".join(["[" + self.name + " " + category + "]" + " " + string for category, string in self.logs])


class GeneratorError:
    pass


class VerilogWriter:
    def __init__(self):
        self.buffer = ""
        self.indent = ""
        self.indent_num = 0

    def include(self, name):
        self.buffer += '`include "' + name + '"\n'

    def port(self, direction, name, wire_type="logic"):
        if direction != None:
            self.buffer += self.indent + \
                " ".join([Direction.to_string(direction), wire_type, name+",\n"])
        else:
            self.buffer += self.indent + wire_type + " " + name+",\n"

    def portn(self, direction, num_wires, name, wire_type="logic"):
        if num_wires == 1:
            self.port(direction, name, wire_type)
        else:
            self.buffer += self.indent + \
                " ".join([Direction.to_string(direction), wire_type,
                          "[" + str(num_wires-1) + ":0]", name+",\n"])

    def line(self):
        self.buffer += "\n"

    def begin_module(self, name, parameters=None):
        self.buffer += self.indent + "module " + name
        if parameters != None:
            self.buffer += "\n" + self.indent + "    " + "#(" + ",".join(
                ["parameter " + str(param_name) + " = " + str(param_val) for (param_name, param_val) in parameters]
            ) + ")\n" + self.indent + "(\n"
        else:
            self.buffer += " (\n"

    def close_and_semicolon(self):
        self.buffer += self.indent + ");\n"

    def end_module(self, name):
        self.buffer += "endmodule: " + name + "\n"

    def set_indent(self, indent_num):
        self.indent = "".join(["    " for _ in range(indent_num)])
        self.indent_num = indent_num

    def inc_indent(self):
        self.set_indent(self.indent_num + 1)

    def dec_indent(self):
        self.set_indent(self.indent_num - 1)

    def custom_indented(self, line):
        self.buffer += self.indent + line + "\n"

    def custom(self, line):
        self.buffer += line + "\n"

    def decl(self, name, wire_type="logic"):
        self.buffer += self.indent + wire_type + " " + name + ";\n"

    def decln(self, num_wires, name, wire_type="logic"):
        self.buffer += self.indent + wire_type + " " + \
            "[" + str(num_wires-1) + ":0] " + name + ";\n"

    def non_blocking(self, lhs, rhs):
        self.buffer += self.indent + lhs + " <= " + rhs + ";\n"

    def instantiate(self, module_name, name):
        self.buffer += self.indent + module_name + " " + name + " (\n"

    def connect(self, socket, wire):
        self.buffer += self.indent + "." + socket + "(" + wire + "),\n"

    def import_all(self, name):
        self.buffer += self.indent + "import " + name + "::*;\n"

    def continuous(self, lhs, rhs):
        self.buffer += self.indent + "assign " + lhs + " = " + rhs + ";\n"

    def remove_last_comma(self):
        self.buffer = self.buffer[:-2] + "\n"



class BSVWriter:
    def __init__(self):
        self.buffer = ""
        self.indent = ""
        self.indent_num = 0

    def set_indent(self, indent_num):
        self.indent = "".join(["    " for _ in range(indent_num)])
        self.indent_num = indent_num

    def inc_indent(self):
        self.set_indent(self.indent_num + 1)

    def dec_indent(self):
        self.set_indent(self.indent_num - 1)

    def custom_indented(self, line):
        self.buffer += self.indent + line + "\n"

    def custom(self, line):
        self.buffer += line + "\n"

    def line(self):
        self.buffer += "\n"

    def import_all(self, name):
        self.buffer += "import " + name + "::*;\n"

    def begin_interface(self, name):
        self.buffer += "interface " + name + ";\n"

    def end_interface(self):
        self.buffer += "endinterface\n"

    def interface_decl(self, type_, name):
        self.buffer += self.indent + "interface " + \
            str(type_) + " " + name + ";\n"

    def method_single_arg_action_decl(self, name, arg_name, arg_type, arg_port=None, prefix=None):
        port_str = '(* port = "' + arg_port + \
            '" *) ' if arg_port != None else ""
        prefix_str = prefix + " " if prefix != None else ""
        self.buffer += self.indent + prefix_str + "method Action " + \
            name + "(" + port_str + str(arg_type) + " " + arg_name + ");\n"

    def begin_module(self, name, interface=""):
        self.buffer += "module " + name + "(" + interface + ");\n"

    def end_module(self):
        self.buffer += "endmodule\n"

    def instantiate(self, type_, name, module, args=None):
        args_str = ""
        if args != None:
            if not isinstance(args, list):
                args_str = str(args)
            else:
                args_str = ", ".join(map(str, args))
        self.buffer += self.indent + \
            str(type_) + " " + name + " <- " + module + "(" + args_str + ");\n"

    def assign(self, type_, lhs, rhs, is_interface=False):
        if type_ != "":
            self.buffer += self.indent + \
                ("", "interface ")[is_interface] + \
                " ".join([str(type_), lhs, "=", rhs+";\n"])
        else:
            self.buffer += self.indent + \
                ("", "interface ")[is_interface] + \
                " ".join([lhs, "=", rhs+";\n"])

    def decl(self, type_, name):
        self.buffer += self.indent + str(type_) + " " + name + ";\n"

    def non_blocking(self, lhs, rhs):
        self.buffer += self.indent + lhs + " <= " + rhs + ";\n"


# Class for representing BSV's type system for simpler output
class BSVType:
    def __init__(self, primary, type_args=None):
        self.primary = primary
        self.type_args = type_args

    def __str__(self):
        if self.type_args == None:
            return str(self.primary)
        elif not isinstance(self.type_args, list):
            return str(self.primary) + "#(" + str(self.type_args) + ")"
        else:
            return str(self.primary) + "#(" + ", ".join(map(str, self.type_args)) + ")"


def bit(width):
    return BSVType("Bit", width)
