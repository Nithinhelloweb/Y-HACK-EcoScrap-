import os
import re

frontend_dir = r"d:\HACKTHON\KPR Y-Hack\Version1\frontend\lib"
patterns = [
    ("as Map<String, String>", re.compile(r"as\s+Map<String,\s*String>")),
    ("List<String>.from", re.compile(r"List<String>\.from")),
    ("cast<String>()", re.compile(r"cast<String>\(\)")),
    ("cast<String, String>()", re.compile(r"cast<String,\s*String>\(\)")),
    ("Map<String, String>.from", re.compile(r"Map<String,\s*String>\.from")),
]

for label, pat in patterns:
    matches = []
    for root, dirs, files in os.walk(frontend_dir):
        for f in files:
            if f.endswith(".dart"):
                filepath = os.path.join(root, f)
                with open(filepath, "r", encoding="utf-8", errors="ignore") as fp:
                    for i, line in enumerate(fp, 1):
                        if pat.search(line):
                            rel = os.path.relpath(filepath, frontend_dir)
                            matches.append(f"{rel}:{i}: {line.strip()}")
    print(f"=== {label} ({len(matches)}) ===")
    for m in matches:
        print(m)
