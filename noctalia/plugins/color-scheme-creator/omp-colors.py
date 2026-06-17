#!/usr/bin/env python3
import sys, json, re

USAGE = "Usage: omp-colors.py read <file> | write <file> <json>"

TEMPLATE_RE = re.compile(r"\{\{colors\.([\w_]+)\.default\.hex\}\}")

def extract_colors(obj, path="", segment_type=""):
    entries = []
    if isinstance(obj, dict):
        seg_type = obj.get("type", segment_type)
        for k, v in obj.items():
            if k in ("foreground", "background") and isinstance(v, str):
                m = TEMPLATE_RE.search(v)
                if m:
                    entries.append({"path": path + "." + k, "color": v, "kind": k, "segment": seg_type or "unknown", "isTemplate": True, "colorKey": m.group(1)})
                elif v.startswith("#"):
                    entries.append({"path": path + "." + k, "color": v, "kind": k, "segment": seg_type or "unknown", "isTemplate": False, "colorKey": ""})
            elif k in ("foreground_templates", "background_templates") and isinstance(v, list):
                for i, t in enumerate(v):
                    if isinstance(t, str):
                        m = TEMPLATE_RE.search(t)
                        if m:
                            kind = k.replace("_templates", "")
                            entries.append({"path": path + "." + k + "[" + str(i) + "]", "color": t, "kind": kind + "_template", "segment": seg_type or "unknown", "isTemplate": True, "colorKey": m.group(1)})
                        else:
                            colors = re.findall(r"#[0-9a-fA-F]{6}", t)
                            if colors:
                                kind = k.replace("_templates", "")
                                entries.append({"path": path + "." + k + "[" + str(i) + "]", "color": colors[0], "kind": kind + "_template", "segment": seg_type or "unknown", "isTemplate": False, "colorKey": ""})
            else:
                entries.extend(extract_colors(v, path + "." + k if path else k, seg_type))
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            entries.extend(extract_colors(item, path + "[" + str(i) + "]", segment_type))
    return entries

def set_nested(obj, dotpath, value):
    parts = re.findall(r"\w+|\[\d+\]", dotpath)
    cur = obj
    for p in parts[:-1]:
        if p.startswith("["):
            idx = int(p[1:-1])
            cur = cur[idx]
        else:
            cur = cur[p]
    last = parts[-1]
    if last.startswith("["):
        cur[int(last[1:-1])] = value
    else:
        cur[last] = value

def main():
    if len(sys.argv) < 3:
        print(USAGE); sys.exit(1)

    cmd = sys.argv[1]
    filepath = sys.argv[2]

    if cmd == "read":
        with open(filepath) as f:
            data = json.load(f)
        entries = extract_colors(data)
        seen = set()
        unique = []
        for e in entries:
            if e["path"] not in seen:
                seen.add(e["path"])
                unique.append(e)
        print(json.dumps(unique))

    elif cmd == "write":
        if len(sys.argv) < 4:
            print(USAGE); sys.exit(1)
        changes = json.loads(sys.argv[3])
        with open(filepath) as f:
            data = json.load(f)
        for change in changes:
            set_nested(data, change["path"], change["color"])
        with open(filepath, "w") as f:
            json.dump(data, f, indent=2)
        print("ok")

    else:
        print(USAGE); sys.exit(1)

if __name__ == "__main__":
    main()
