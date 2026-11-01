"""Applies one small edit at a time to lua/ and reruns the tests that cover it.

An edit the tests still pass with is a survivor: behaviour nothing checks.
Usage: python3 tests/mutate.py [path substring]
Each worker has its own copy of the config, and the tests use a throwaway $HOME.
"""

import concurrent.futures
import os
import pathlib
import queue
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass

ROOT = pathlib.Path(__file__).resolve().parent.parent
WORKERS = 12
TIMEOUT_SECONDS = 60

# Each module group, and the test files that cover it.
GROUPS = [
    ("lua/plugins/editor/git_changes/", "git_changes_"),
    ("lua/plugins/editor/git_changes/line_history", "history_and_keys"),
    ("lua/plugins/editor/git_changes/commits", "history_and_keys"),
    ("lua/plugins/editor/pins/", "pins_test"),
    ("lua/plugins/editor/pins/list", "units_test"),
    ("lua/plugins/coding/build/", "build_test"),
    ("lua/plugins/coding/build/detect", "units_test"),
    ("lua/plugins/coding/build/store", "units_test"),
    ("lua/plugins/coding/build/tests", "units_test"),
    ("lua/plugins/debug/dap", "dap_test"),
    ("lua/plugins/debug/elf", "debug_test"),
    ("lua/plugins/debug/types", "debug_test"),
    ("lua/plugins/lsp/peek", "config_test"),
    ("lua/plugins/lsp/readiness", "units_test"),
    ("lua/plugins/editor/telescope/glob", "units_test"),
    ("lua/plugins/editor/telescope/grep", "history_and_keys"),
    ("lua/plugins/editor/telescope/keymaps", "history_and_keys"),
    ("lua/config/keymaps", "config_test"),
    ("lua/config/input", "config_test"),
    ("lua/config/terminal", "config_test"),
    ("lua/config/autocmds", "config_test"),
    ("lua/config/statusline", "config_test"),
    ("lua/lib/json_file", "units_test"),
    ("lua/lib/on_first_require", "units_test"),
]

STRUCTURE = re.compile(
    r"^\s*(end\b|else\b|elseif\b|until\b|\}|\)|local function\b|function\b|if\b|for\b|while\b|repeat\b|return M\b)"
)
REPLACEMENTS = [
    (r" == ", " ~= "),
    (r" ~= ", " == "),
    (r" >= ", " < "),
    (r" <= ", " > "),
    (r" > ", " <= "),
    (r" < ", " >= "),
    (r" \+ 1\b", " - 1"),
    (r" - 1\b", " + 1"),
    (r"\bnot ", ""),
    (r" and ", " or "),
    (r" or ", " and "),
    (r"\btrue\b", "false"),
    (r"\bfalse\b", "true"),
    (r"\breturn nil\b", "return false"),
]


@dataclass(frozen=True)
class Mutant:
    file: str
    line: int
    description: str
    text: str
    tests: str


def tests_for(path):
    """The last matching group is the most specific."""
    matched = None
    for prefix, tests in GROUPS:
        if path.startswith(prefix):
            matched = tests
    return matched


def mutants_of(path, source, tests):
    lines = source.split("\n")
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith("--"):
            continue
        edits = []
        if not STRUCTURE.match(line) and "= function" not in line and not line.rstrip().endswith(("(", "{", ",")):
            edits.append(("delete the line", ""))
        for pattern, replacement in REPLACEMENTS:
            changed = re.sub(pattern, replacement, line, count=1)
            if changed != line:
                edits.append((f"change to: {changed.strip()}", changed))
        for description, new_line in edits:
            mutated = lines[:index] + [new_line] + lines[index + 1 :]
            yield Mutant(path, index + 1, description, "\n".join(mutated), tests)


def parses(copy, path):
    check = 'if not loadfile(arg[1]) then os.exit(1) end'
    script = copy / "check.lua"
    script.write_text(check)
    return subprocess.run(["nvim", "-l", str(script), str(copy / path)], capture_output=True).returncode == 0


def survives(mutant, copy):
    target = copy / mutant.file
    original = target.read_text()
    target.write_text(mutant.text)
    try:
        if not parses(copy, mutant.file):
            return None
        command = ["nvim", "-l", str(copy / "tests/run.lua"), mutant.tests]
        return subprocess.run(command, capture_output=True, timeout=TIMEOUT_SECONDS).returncode == 0
    except subprocess.TimeoutExpired:
        return False
    finally:
        target.write_text(original)


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    base = pathlib.Path(tempfile.mkdtemp(prefix="nvim-mutants-"))
    idle = queue.Queue()
    for number in range(WORKERS):
        copy = base / str(number)
        copy.mkdir()
        for folder in ("lua", "tests", "lsp"):
            shutil.copytree(ROOT / folder, copy / folder)
        shutil.copy(ROOT / "init.lua", copy / "init.lua")
        idle.put(copy)

    jobs = []
    for path in sorted((ROOT / "lua").rglob("*.lua")):
        relative = str(path.relative_to(ROOT))
        tests = tests_for(relative)
        if tests and only in relative:
            jobs += list(mutants_of(relative, path.read_text(), tests))

    def check(mutant):
        copy = idle.get()
        try:
            return mutant, survives(mutant, copy)
        finally:
            idle.put(copy)

    with concurrent.futures.ThreadPoolExecutor(WORKERS) as pool:
        results = list(pool.map(check, jobs))
    shutil.rmtree(base)

    valid = [(mutant, survived) for mutant, survived in results if survived is not None]
    survivors = [mutant for mutant, survived in valid if survived]
    print(f"Caught {len(valid) - len(survivors)} of {len(valid)} edits\n")
    for mutant in survivors:
        print(f"{mutant.file}:{mutant.line}: {mutant.description}")


if __name__ == "__main__":
    main()
