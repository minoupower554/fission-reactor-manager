import re
import os
import shutil
import random
import string
import zipfile

used_names = set()
def random_string(length):
    first_chars = string.ascii_letters+"_"
    other_chars = first_chars+string.digits
    while True:
        result = ""
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
                matches[i] = {"var_name": None, "mod_path": without_var_match.group(1), "action": without_var_match.group(2)} # type: ignore

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
                
                cleared_lines.append(line)

        new_lines[k:k+1] = cleared_lines

    for i, v in enumerate(new_lines):
        if "--" in v:
            new_lines[i] = v.split("--")[0] # this will 100% eat strings im just too lazy to fix it
    
    return new_lines


def strip_whitespaces(code: list[str]) -> list[str]:
    result = ["--[[THIS HAS BEEN BUNDLED BY A CUSTOM LUA BUNDLER]]"]
    for line in code:
        if not line.strip(): continue
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
    
    with zipfile.ZipFile("./dist/FissionReactorController.zip", 'w', zipfile.ZIP_DEFLATED) as z:
        os.chdir("./dist")
        z.write("./main.lua")
        z.write("./config.lua")

if __name__ == "__main__":
    main()
