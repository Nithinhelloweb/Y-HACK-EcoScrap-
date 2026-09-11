import os
import re

frontend_dir = r"d:\HACKTHON\KPR Y-Hack\Version1\frontend\lib"
pattern = re.compile(r"String\s+([a-zA-Z0-9_]+)\s*=\s*([^;]+);")

results = []
for root, dirs, files in os.walk(frontend_dir):
    for f in files:
        if f.endswith(".dart"):
            filepath = os.path.join(root, f)
            with open(filepath, "r", encoding="utf-8", errors="ignore") as fp:
                for i, line in enumerate(fp, 1):
                    m = pattern.search(line)
                    if m:
                        rhs = m.group(2).strip()
                        if any(k in rhs for k in ["[", "data", "user", "profile", "lot", "bid", "item", "p[", "ev["]) and "??" not in rhs and not rhs.startswith("'") and not rhs.startswith('"') and not rhs.startswith("const"):
                            rel = os.path.relpath(filepath, frontend_dir)
                            results.append(f"{rel}:{i}: {line.strip()}")

for r in results:
    print(r)
print(f"Total String declarations without ??: {len(results)}")
