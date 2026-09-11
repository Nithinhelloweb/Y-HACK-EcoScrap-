import os
import re

frontend_dir = r"d:\HACKTHON\KPR Y-Hack\Version1\frontend\lib"
text_pattern = re.compile(r"Text\s*\(\s*([^,\)\n]+)")

results = []
for root, dirs, files in os.walk(frontend_dir):
    for f in files:
        if f.endswith(".dart"):
            filepath = os.path.join(root, f)
            with open(filepath, "r", encoding="utf-8", errors="ignore") as fp:
                for i, line in enumerate(fp, 1):
                    m = text_pattern.search(line)
                    if m:
                        arg = m.group(1).strip()
                        if any(k in arg for k in ["[", "data", "user", "profile", "lot", "bid", "item", "p[", "ev["]) and "??" not in arg and not arg.startswith("'") and not arg.startswith('"') and not arg.startswith("const"):
                            rel = os.path.relpath(filepath, frontend_dir)
                            results.append(f"{rel}:{i}: {line.strip()}")

for r in results:
    print(r)
print(f"Total found: {len(results)}")
