"""Fail CI unless every file in Pepline/Core is 100% line-covered.

The calculator math is the heart of the app (competitors ship wrong results),
so untested Core code is a build failure, not a warning.

Usage: python3 check_core_coverage.py build/coverage.json
(the output of `xcrun xccov view --report --json <xcresult>`).
"""
import json
import sys

report = json.load(open(sys.argv[1]))
core = [
    f
    for target in report["targets"]
    if target["name"].startswith("Pepline.app")
    for f in target["files"]
    if "/Pepline/Core/" in f["path"]
]

if not core:
    sys.exit("No Pepline/Core files in the coverage report")

failed = False
for f in sorted(core, key=lambda f: f["name"]):
    covered, total = f["coveredLines"], f["executableLines"]
    print(f"{f['name']:<28} {covered:>4}/{total:<4} {f['lineCoverage']:.1%}")
    if covered < total:
        failed = True
        for fn in f.get("functions", []):
            if fn["coveredLines"] < fn["executableLines"]:
                print(f"    uncovered: {fn['name']} (line {fn['lineNumber']})")

sys.exit("Core coverage below 100%" if failed else 0)
