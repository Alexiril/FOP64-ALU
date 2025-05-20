from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from json import dumps, loads
from os import mkdir, remove
from pathlib import Path
from socketserver import BaseServer
from subprocess import PIPE, CalledProcessError, Popen, run as sp_run
from threading import Thread
from typing import Any
from webbrowser import open as web_open

from _socket import socket

vdmt_file: None | dict[str, Any] = None


def main():
    server = Server(("localhost", 8080))
    thread = Thread(target=server.serve_forever)
    thread.start()
    thread.join()


class Server(ThreadingHTTPServer):
    def __init__(
        self,
        server_address: tuple[str | bytes | bytearray, int],
    ) -> None:
        super().__init__(server_address, Handler, True)
        print("Server created")
        web_open("http://localhost:8080/")


class Handler(BaseHTTPRequestHandler):
    response_content: bytes
    response_code: int
    response_content_type: str
    response_headers: dict[str, str]
    request_method: str

    def __init__(
        self,
        request: socket | tuple[bytes, socket],
        client_address: Any,
        server: BaseServer,
    ) -> None:
        super().__init__(request, client_address, server)  # type: ignore

    def do_GET(self) -> None:
        self.request_method = "GET"
        self.do_HEAD()
        try:
            self.wfile.write(self.response_content)
        except Exception as e:  # pylint: disable=broad-exception-caught
            self.wfile.write(f"Couldn't send data. Error is {e}".encode())

    def do_POST(self) -> None:
        self.request_method = "POST"
        self.do_HEAD()
        try:
            self.wfile.write(self.response_content)
        except Exception as e:  # pylint: disable=broad-exception-caught
            self.wfile.write(f"Couldn't send data. Error is {e}".encode())

    def do_HEAD(self) -> None:
        self.response_content = b"ok"
        self.response_code = 200
        self.response_content_type = "text/html"
        self.response_headers = {}
        if not hasattr(self, "request_method") or self.request_method == "":
            self.request_method = "HEAD"
        try:
            self.do_content()
            self.send_response_only(self.response_code)
            self.send_header("server", self.version_string())
            self.send_header("date", self.date_time_string())
            self.send_header("content-type", self.response_content_type)
            if len(self.response_content) > 0:
                self.send_header("content-length", f"{len(self.response_content)}")
            for header, value in self.response_headers.items():
                self.send_header(header, value)
            self.end_headers()
        except Exception as e:  # pylint: disable=broad-exception-caught
            self.send_response_only(500, str(e))

    def do_content(self) -> None:
        global vdmt_file  # pylint: disable=global-statement
        if self.path in ("/", "/create-test") and self.request_method == "GET":
            if vdmt_file is None:
                html = "debugger/html/load_vdmt.html"
            else:
                if self.path == "/":
                    html = "debugger/html/debug.html"
                elif self.path == "/create-test":
                    html = "debugger/html/create_test.html"
                else:
                    html = ""
            with open(html, "rt", encoding="utf-8") as inp:
                self.response_content = self.handle_vdmt_html_template(
                    inp.read()
                ).encode()
        elif self.path.split("/")[1] == "shared" and self.request_method == "GET":
            if not (
                asset := Path("debugger/shared/" + "/".join(self.path.split("/")[2:]))
            ).is_file():
                self.response_code = 404
                return
            with open(asset, "rb") as inp:
                self.response_content = inp.read()
                self.response_content_type = "text/css"
        elif self.path == "/clear-module" and self.request_method == "GET":
            if vdmt_file is not None:
                vdmt_file = None
        elif self.path == "/reset-state" and self.request_method == "GET":
            if vdmt_file is not None:
                vdmt_file["step"] = 0
                vdmt_file["current_state"].update(
                    {
                        "log": [],
                        "tick": 0,
                        "selected_test": "",
                        "selected_instruction": 0,
                        "inputs_values": {},
                        "outputs_values": {},
                        "running": 0,
                    }
                )
        elif self.path == "/state" and self.request_method == "GET":
            if vdmt_file is None:
                self.response_content = "{}".encode()
            else:
                self.response_content = dumps(vdmt_file["current_state"]).encode()
        elif self.path.startswith("/run") and self.request_method == "GET":
            self.run()
            return
        elif self.path.startswith("/step") and self.request_method == "GET":
            self.step()
            return
        elif self.path == "/parse-vdmt" and self.request_method == "POST":
            content_length = int(self.headers["Content-Length"])
            inp_bytes = self.rfile.read(content_length)
            try:
                inp = inp_bytes.decode()
            except Exception:  # pylint: disable=broad-exception-caught
                self.response_code = 302
                self.headers["location"] = "/"
                return
            inp = "\n".join(inp.split("\r\n")[4:-2])
            vdmt_data = self.get_vdmt_data(inp)
            if vdmt_data is not None:
                vdmt_file = {
                    "code": inp,
                    "vvp_file": None,
                    "simulation": [],
                    "step": 0,
                    "simulated": False,
                    "current_state": {
                        "log": [],
                        "tick": 0,
                        "selected_test": "",
                        "selected_instruction": 0,
                        "inputs_values": {},
                        "outputs_values": {},
                        "running": 0,
                    },
                }
                vdmt_file.update(vdmt_data)
            self.response_code = 302
            self.response_headers["location"] = "/"
        elif self.path == "/create-test" and self.request_method == "POST":
            if vdmt_file is None:
                self.response_code = 500
                return
            content_length = int(self.headers["Content-Length"])
            inp_bytes = self.rfile.read(content_length)
            try:
                inp = loads(inp_bytes.decode())
            except Exception:  # pylint: disable=broad-exception-caught
                self.response_code = 500
                return
            vdmt_file["tests"] = [  # type: ignore  # pylint: disable=unsupported-assignment-operation
                test
                for test in vdmt_file["tests"]
                if test["name"] != inp["name"]  # type: ignore  # pylint: disable=unsubscriptable-object
            ]
            vdmt_file["tests"].append(inp)  # type: ignore  # pylint: disable=unsubscriptable-object
        else:
            self.response_code = 404

    def get_vdmt_data(self, verilog: str) -> dict[str, Any] | None:
        lines = [line.strip() for line in verilog.split("\n")]
        vdmt_header = 0
        while (
            vdmt_header < len(lines)
            and lines[vdmt_header].lower() != "/*verilogdebugmoduletemplate"
        ):
            vdmt_header += 1
        if vdmt_header == len(lines):
            return None
        decl: dict[str, Any] | None = {}
        tests: list[dict[str, Any]] = []
        while vdmt_header < len(lines) and not lines[vdmt_header].endswith("*/"):
            if lines[vdmt_header].startswith("decl "):
                decl, vdmt_header = self.get_decl_vdmt_header(lines, vdmt_header)
            elif lines[vdmt_header].startswith("test "):
                test, vdmt_header = self.get_test_vdmt_header(lines, vdmt_header)
                if test is None:
                    return None
                tests.append(test)
            else:
                vdmt_header += 1
        if decl is None:
            return None
        decl["tests"] = tests
        return decl

    def get_decl_vdmt_header(
        self, verilog: list[str], start: int
    ) -> tuple[dict[str, Any] | None, int]:
        decl_def = verilog[start]
        while "  " in decl_def:
            decl_def = decl_def.replace("  ", " ")
        if decl_def != "decl {":
            return None, start
        module = "Unnamed module"
        defs: list[str] = []
        inputs: list[dict[str, str | bool | int]] = []
        outputs: list[dict[str, str | bool | int]] = []
        start += 1
        try:
            while start < len(verilog) and not verilog[start].endswith("}"):
                decl_array = verilog[start].split(":")
                if len(decl_array) == 0:
                    start += 1
                    continue
                if decl_array[0] == "module":
                    module = decl_array[1]
                elif decl_array[0] == "def":
                    defs.append(decl_array[1])
                elif decl_array[0] == "i":
                    inputs.append(
                        {
                            "bits": int(decl_array[1]),
                            "signed": decl_array[2] == "s",
                            "name": decl_array[3],
                            "human_name": decl_array[4],
                        }
                    )
                elif decl_array[0] == "o":
                    outputs.append(
                        {
                            "bits": int(decl_array[1]),
                            "signed": decl_array[2] == "s",
                            "name": decl_array[3],
                            "human_name": decl_array[4],
                        }
                    )
                start += 1
        except Exception:  # pylint: disable=broad-exception-caught
            return None, start
        return {
            "module": module,
            "defs": defs,
            "inputs": inputs,
            "outputs": outputs,
        }, start + 1

    def get_test_vdmt_header(
        self, verilog: list[str], start: int
    ) -> tuple[dict[str, str | list[dict[str, str | list[int]]]] | None, int]:
        test_def = verilog[start].removeprefix("test ")
        while "  " in test_def:
            test_def = test_def.replace("  ", " ")
        test_def_separated = test_def.split(" ")
        if len(test_def_separated) != 2 or test_def_separated[-1] != "{":
            return None, start
        test_name = test_def_separated[0]
        instructions: list[dict[str, str | list[int]]] = []
        start += 1
        while start < len(verilog) and not verilog[start].endswith("}"):
            inst_array = verilog[start].split(":")
            if len(inst_array) == 0:
                start += 1
                continue
            instructions.append(
                {
                    "name": inst_array[0],
                    "params": list(map(lambda x: int(x, base=0), inst_array[1:])),
                }
            )
            start += 1
        if start == len(verilog):
            return None, start
        return {"name": test_name, "instructions": instructions}, start + 1

    def handle_vdmt_html_template(self, html: str) -> str:
        if vdmt_file is None:
            return html
        html = html.replace("{{module_name}}", vdmt_file["module"])
        html = html.replace("{{defs}}", ", ".join(vdmt_file["defs"]))
        inputs = ""
        inputs_names = ""
        new_command_fields = ""
        for index, i in enumerate(vdmt_file["inputs"]):
            inputs += (
                f"<tr><td>{i['human_name']}</td><td class='centered'>{i['bits']}</td>"
                f"<td class='centered'><input readonly type='text' value='0' data-actualvalue='0' class='diff-base' id='input-{i['name']}'></td></tr>"
            )
            inputs_names += f"<th>{i['human_name']}</th>"
            new_command_fields += (
                f'<div class="row input-field"><label for="{i["name"]}">{i["human_name"]}:</label>'
                f'<input type="text" name="{i["name"]}" id="{i["name"]}" class="new-command-input" '
                f'data-order="{index + 1}"></div>'
            )
        html = html.replace("{{inputs}}", inputs)
        html = html.replace("{{inputs_names}}", inputs_names)
        outputs = ""
        for i in vdmt_file["outputs"]:
            outputs += (
                f"<tr><td>{i['human_name']}</td><td class='centered'>{i['bits']}</td>"
                f"<td class='centered'><input readonly type='text' value='0' data-actualvalue='0' class='diff-base' id='output-{i['name']}'></td></tr>"
            )
        html = html.replace("{{outputs}}", outputs)
        tests_headers = ""
        tests = ""
        for test in vdmt_file["tests"]:
            tests_headers += f"""<button class="tablinks" data-tab="{test["name"]}">{test["name"]}</button>"""
            first = True
            for i in test["instructions"]:
                line = f"<td>{i['name']}</td>"
                for param in i["params"]:
                    line += (
                        f"<td class='diff-base' data-actualvalue='{param}'>{param}</td>"
                    )
                tests += f"""<tr class="{test["name"]} tabcontent {"selected" if first else ""}">{line}</tr>"""
                first = False
        html = html.replace("{{tests_headers}}", tests_headers)
        html = html.replace("{{tests}}", tests)
        html = html.replace("{{new_command_fields}}", new_command_fields)
        return html

    def run(self) -> None:
        if vdmt_file is None or vdmt_file["current_state"]["running"] == 1:
            return
        if not vdmt_file["simulated"]:
            self.start()
        elif (
            self.path.split("=")[1] != ""
            and vdmt_file["current_state"]["selected_test"] != self.path.split("=")[1]
        ):
            self.start(True)
        vdmt_file["step"] = len(vdmt_file["simulation"]) - 1
        self.actual_step()
        vdmt_file["current_state"]["log"] = []
        for s in vdmt_file["simulation"]:
            vdmt_file["current_state"]["log"].append(self.construct_log(s))

    def step(self) -> None:
        if vdmt_file is None or vdmt_file["current_state"]["running"] == 1:
            return
        if not vdmt_file["simulated"]:
            self.start()
        elif (
            self.path.split("=")[1] != ""
            and vdmt_file["current_state"]["selected_test"] != self.path.split("=")[1]
        ):
            self.start(True)
        self.actual_step()

    def actual_step(self) -> None:
        if vdmt_file is None:
            return
        if vdmt_file["step"] < len(vdmt_file["simulation"]):
            step = vdmt_file["simulation"][vdmt_file["step"]]
            vdmt_file["current_state"]["log"].append(self.construct_log(step))
            vdmt_file["current_state"]["tick"] = int(step.split("&")[0])
            vdmt_file["current_state"]["selected_instruction"] = vdmt_file["step"]
            io_state = loads(step.split("&")[1].replace("'", '"'))
            vdmt_file["current_state"]["inputs_values"] = {
                key.removeprefix("input_"): value
                for key, value in io_state.items()
                if key.startswith("input_")
            }
            vdmt_file["current_state"]["outputs_values"] = {
                key.removeprefix("output_"): value
                for key, value in io_state.items()
                if key.startswith("output_")
            }
            vdmt_file["step"] += 1

    def start(self, force_build: bool = False) -> None:
        if vdmt_file is None or vdmt_file["current_state"]["running"] == 1:
            return
        if vdmt_file["vvp_file"] is None or force_build:
            self.build()

        vdmt_file["current_state"]["running"] = 1
        with Popen(
            ["debugger/bin/vvp", vdmt_file["vvp_file"]],
            stdout=PIPE,
            stdin=PIPE,
            text=True,
        ) as handler:
            vdmt_file["simulation"] = [
                self.clear_output(line)
                for line in handler.communicate()[0].splitlines()
            ]
        vdmt_file["step"] = 0
        vdmt_file["simulated"] = True
        vdmt_file["current_state"]["running"] = 0

    def build(self) -> None:
        if vdmt_file is None or vdmt_file["current_state"]["running"] == 1:
            return
        build_folder = Path("./build-files")
        if not build_folder.is_dir():
            if build_folder.exists():
                remove(build_folder)
            mkdir(build_folder)
        t: Any = list(  # type: ignore
            filter(lambda x: x["name"] == self.path.split("=")[1], vdmt_file["tests"])  # type: ignore
        )[0]  # type: ignore
        vdmt_file["current_state"]["selected_test"] = t["name"]
        v_file = build_folder / f"{vdmt_file['module']}_{t['name']}.v"
        test = self.generate_testbench(t)  # type: ignore
        with open(v_file, "wt", encoding="utf-8") as out:
            out.write(test)
            out.write(vdmt_file["code"])
        try:
            sp_run(
                [
                    "debugger/bin/iverilog",
                    "-g2012",
                    "-o",
                    (build_folder / "machine.vvp"),
                    v_file,
                ],
                check=True,
                cwd=Path("."),
            )
        except CalledProcessError as e:
            print("iverilog error", e)
            return
        vdmt_file["vvp_file"] = build_folder / "machine.vvp"

    def generate_testbench(self, test: dict[str, Any]) -> str:
        if vdmt_file is None:
            return ""
        defines = ""

        for define in vdmt_file["defs"]:
            defines += f"`define {define}\n"

        ios = ""
        initialization_list: list[str] | str = []
        task_ios: list[str] | str = []
        setting_ios = ""
        output_line = "{"
        output_params: list[str] | str = []

        for inp in vdmt_file["inputs"]:
            ios += f"reg {'signed' if inp['signed'] else ''} [{inp['bits'] - 1}:0] {inp['name']} = -1;\n"
            initialization_list.append(f".{inp['name']}({inp['name']})")
            task_ios.append(f"input [{inp['bits'] - 1}:0] _{inp['name']}")
            setting_ios += f"{inp['name']} = _{inp['name']};\n"
            output_line += f"""'input_{inp["name"]}':'%d',"""
            output_params.append(inp["name"])

        for out in vdmt_file["outputs"]:
            ios += f"wire {'signed' if out['signed'] else ''} [{out['bits'] - 1}:0] {out['name']};\n"
            initialization_list.append(f".{out['name']}({out['name']})")
            output_line += f"""'output_{out["name"]}':'%d',"""
            output_params.append(out["name"])

        initialization_list = ",".join(initialization_list)
        task_ios = ",".join(task_ios)
        if output_line[-1] == ",":
            output_line = output_line[:-1]
        output_line += "}"
        output_params = ",".join(output_params)

        commands = ""
        for x in test["instructions"]:
            x["params"] = [
                param if isinstance(param, int) else 0
                for param in x["params"]
            ]
            commands += f"runcommand({','.join(map(str, x['params']))});\n"
        return f"""
// Testbench '{test["name"]}'
{defines}
module testbench;
{ios}
{vdmt_file["module"]} m0 ({initialization_list});
task automatic runcommand({task_ios});
begin
{setting_ios}
#1;
$display("%d&{output_line}", $time, {output_params});
end
endtask
initial begin
{commands}
end
endmodule
"""

    def clear_output(self, line: str) -> str:
        while "  " in line:
            line = line.replace("  ", " ")
        return line.strip()

    def construct_log(self, line: str) -> str:
        tick, params = line.split("&")
        return f"""Tick ({tick}), Params: {params}"""
