import re
import os
import shutil
import random
import string
import luaparser.ast as ast
from luaparser.astnodes import *

used_names = set()
def random_string(length):
    first_chars = string.ascii_letters+"_"
    other_chars = first_chars+string.digits
    result = ""
    while True:
        for i in range(length):
            if i==0:
                result += random.choice(first_chars)
            else:
                result += random.choice(other_chars)

        if result not in used_names:
            used_names.add(result)
            return result

def inline(lines: list[str]) -> list[str]:
    matches: dict[int, dict[str, str]] = {}
    for i, v in enumerate(lines):
        with_var = r"""^local\s+(\w+)\s*=\s*require\(['"]([^'"]+)['"]\)\s*---#(include|remove)$"""
        var_match = re.search(with_var, v)
        if var_match:
            matches[i] = {"var_name": var_match.group(1), "mod_path": var_match.group(2), "action": var_match.group(3)}
        else:
            without_var = r"""require\(['\"]([^'\"]+)['\"]\)\s*---#(include|remove)"""
            without_var_match = re.search(without_var, v)
            if without_var_match:
                matches[i] = {"var_name": None, "mod_path": without_var_match.group(1), "action": without_var_match.group(2)}

    matches = dict(reversed(list(matches.items()))) # make it bottom to top to avoid line shifting

    new_lines = lines.copy()
    for k, v in matches.items():
        file_path = "./"+v["mod_path"].replace(".", "/")+".lua"
        if v["action"] == "remove":
            del new_lines[k]
            continue
        with open(file_path, "r") as f:
            with_var = r"""^local\s+\w+\s*=\s*require\(['"][^'"]+['"]\)\s*(?!---#keep)"""
            without_var = r"""require\(['"][^'"]+['"]\)\s*(?!---#keep)"""
            cleared_lines = []
            for line in f.readlines():
                if re.search(with_var, line):
                    continue
                elif re.search(without_var, line):
                    continue
                if line.startswith("return function"):
                    line = "local function "+v["var_name"]+line[len("return function"):]
                elif line.startswith("return "): # named returns
                    continue
                if "--" in line:
                    line = line.split("--")[0] # this will 100% eat strings im just too lazy to fix it
                cleared_lines.append(line)

        new_lines[k:k+1] = cleared_lines

    return new_lines


def minify(code: list[str]) -> list[str]: # i gave up on this. lua ast is like lua tables, one thing to "simplify" stuff, so generalized it's a pain to work with
    blacklist = {"debug", "os", "fs", "term", "peripheral", "textutils", "colors", "colours"}
    parsed = ast.parse(''.join(code))
    variables: dict[str, dict[str, str|int]] = {}
    functions: dict[str, dict[str, str|int]] = {}
    for node in ast.walk(parsed): # read pass
        if isinstance(node, LocalAssign): # ignore globals
            for v in node.targets:
                if not v.id in variables and len(v.id)>3: # if the name is already in here for a new identifier they were already shadowed/unrelated
                    variables[v.id] = {"shortened": random_string(3)}
        elif isinstance(node, LocalFunction): # ignore globals again
            if not node.name.id in functions: functions[node.name.id] = {"shortened": random_string(2)}
            for v in node.args:
                if not v.id in variables and len(v.id)>3:
                    variables[v.id] = {"shortened": random_string(3)}
        elif isinstance(node, Function):
            if not isinstance(node.name, Index) and not node.name.id in functions:
                functions[node.name.id] = {"shortened": random_string(2)}
            for v in node.args:
                if not v.id in variables and len(v.id)>3:
                    variables[v.id] = {"shortened": random_string(3)}
        # elif isinstance(node, Call):
        #     for v in node.args:
        #         if isinstance(v, Name) and not v.id in variables and len(v.id)>3:
        #             variables[v.id] = {"shortened": random_string(3)}

    for node in ast.walk(parsed): # mutate pass
        if isinstance(node, Call):
            if not isinstance(node.func, Index):
                if node.func.id in functions:
                    node.func.id = functions[node.func.id]["shortened"]
            for v in node.args:
                if isinstance(v, Name):
                    if v.id in variables:
                        v.id = variables[v.id]["shortened"]
                    elif v.id in functions:
                        v.id = functions[v.id]["shortened"]
        elif isinstance(node, LocalAssign):
            for v in node.targets:
                if isinstance(v, Name):
                    if v.id in variables:
                        v.id = variables[v.id]["shortened"]
                    elif v.id in functions:
                        v.id = functions[v.id]["shortened"]

            for v in node.values:
                if isinstance(v, Name):
                    if v.id in variables:
                        v.id = variables[v.id]["shortened"]
                    elif v.id in functions:
                        v.id = functions[v.id]["shortened"]
                elif isinstance(v, Index):
                    if v.value.id in variables:
                        v.value.id = variables[v.value.id]["shortened"]
                    elif v.value.id in functions:
                        v.value.id = functions[v.value.id]["shortened"]
        elif isinstance(node, LocalFunction):
            if node.name.id in functions:
                node.name.id = functions[node.name.id]["shortened"]
            for v in node.args:
                if isinstance(v, Name):
                    if v.id in variables:
                        v.id = variables[v.id]["shortened"]
                    elif v.id in functions:
                        v.id = functions[v.id]["shortened"]
        elif isinstance(node, Function):
            if not isinstance(node.name, Index) and node.name.id in functions:
                node.name.id = functions[node.name.id]["shortened"]
            for v in node.args:
                if isinstance(v, Name):
                    if v.id in variables:
                        v.id = variables[v.id]["shortened"]
                    elif v.id in functions:
                        v.id = functions[v.id]["shortened"]
        elif isinstance(node, Invoke):
            if isinstance(node.source, Name) and node.source.id in variables:
                node.source.id = variables[node.source.id]["shortened"]
            for v in node.args:
                if isinstance(v, Name):
                    if v.id in variables:
                        v.id = variables[v.id]["shortened"]
                    elif v.id in functions:
                        v.id = functions[v.id]["shortened"]
        elif isinstance(node, If):...


    return ast.to_lua_source(parsed).split("\n")


def strip_whitespaces(code: list[str]) -> list[str]:
    result = ["--[[THIS HAS BEEN BUNDLED BY A CUSTOM LUA BUNDLER]]"]
    for line in code:
        result.append(line.strip()+" ")
    return result


def main():
    with open("./main.lua", "r") as f:
        code = f.readlines()

    inlined = inline(code)
    stripped = strip_whitespaces(inlined)

    if os.path.exists("./dist"): shutil.rmtree("./dist")
    os.mkdir("./dist")
    shutil.copy2('./config.lua', './dist/config.lua')

    with open("./dist/main.lua", "w") as f:
        f.writelines(stripped)

if __name__ == "__main__":
    main()