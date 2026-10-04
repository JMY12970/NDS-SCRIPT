#!/usr/bin/env python3
"""
OzionUI test runner.

Runs the headless mock harness (test/harness.lua) twice:
  1. Normal mode    - CanvasGroup available (modern Roblox / executors)
  2. Fallback mode  - CanvasGroup missing (simulates very old executors)

Usage:  python3 test/run_tests.py
Exits non-zero if any test fails.
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

RUNNER_SNIPPET = r"""
import sys
import lupa

rt = lupa.LuaRuntime()
rt.execute('_G.__LIB_PATH = "OzionUI.lua"')
if sys.argv[1] == "fallback":
    rt.execute("_G.NO_CANVAS_GROUP = true")
rt.execute(open("test/harness.lua").read())
"""


def run(mode: str) -> bool:
    proc = subprocess.run(
        [sys.executable, "-c", RUNNER_SNIPPET, mode],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=300,
    )
    output = proc.stdout + proc.stderr
    print(f"\n########## RUN: {mode} ##########")
    print(output)
    if "RESULT: ALL TESTS PASSED" not in output:
        print(f">>> {mode} run FAILED")
        return False
    print(f">>> {mode} run PASSED")
    return True


if __name__ == "__main__":
    ok = run("normal") and run("fallback")
    if not ok:
        print("TESTS FAILED")
        sys.exit(1)
    print("ALL RUNS PASSED")
