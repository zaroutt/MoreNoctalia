#!/usr/bin/env python3
import fcntl
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from datetime import datetime

SNAPSHOTS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "snapshots.json")
CONFIG = "/home/za/.config/niri/config.kdl"
RULES = "/home/za/.config/niri/cfg/rules.kdl"
KITTY_CONFIG = "/home/za/.config/kitty/kitty.conf"
COLORS_FILE = "/home/za/.config/noctalia/colors.json"
WALLPAPER_CACHE = "/home/za/.cache/noctalia/wallpapers.json"
LOCK_FILE = "/tmp/niri-toggle.lock"
NOCTALIA_SETTINGS = "/home/za/.config/noctalia/settings.json"
SYNC_COLORS_FILE = "/home/za/.config/noctalia/sync-colors.json"


def atomic_write(path: str, content: str):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=os.path.basename(path) + ".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise

def load_snapshots():
    if not os.path.exists(SNAPSHOTS_FILE):
        return []
    with open(SNAPSHOTS_FILE) as f:
        return json.load(f)

def save_snapshots(snapshots):
    atomic_write(SNAPSHOTS_FILE, json.dumps(snapshots, indent=2))

def get_niri_global_blur_state():
    """Read global blur block from config.kdl: returns True/False"""
    try:
        with open(CONFIG) as f:
            c = f.read()
        m = re.search(r'blur\s*\{([^}]*)\}', c, re.DOTALL)
        if m:
            return re.search(r'^\s*on\s*$', m.group(1), re.MULTILINE) is not None
    except:
        pass
    return False

def get_niri_window_blur_state():
    """Read background-effect blur from config.kdl: returns True/False"""
    try:
        with open(CONFIG) as f:
            c = f.read()
        m = re.search(r'background-effect\s*\{([^}]*)\}', c, re.DOTALL)
        if m:
            return re.search(r'blur\s+true', m.group(1)) is not None
    except:
        pass
    return False

def get_niri_border():
    try:
        with open(CONFIG) as f:
            content = f.read()
        m = re.search(r'border\s*\{([^}]*)\}', content, re.DOTALL)
        if m:
            inner = m.group(1)
            on = bool(re.search(r'^\s*on\s*$', inner, re.MULTILINE))
            w = re.search(r'width\s+(\d+)', inner)
            ac = re.search(r'active-color\s+"([^"]+)"', inner)
            ic = re.search(r'inactive-color\s+"([^"]+)"', inner)
            return {"on": on, "width": int(w.group(1)) if w else 4,
                    "activeColor": ac.group(1) if ac else "#d65ccd",
                    "inactiveColor": ic.group(1) if ic else "#401b3d"}
    except:
        pass
    return None

def get_current_wallpaper():
    try:
        with open(WALLPAPER_CACHE) as f:
            cache = json.load(f)
        monitors = cache.get("wallpapers", {})
        if monitors:
            first = list(monitors.keys())[0]
            # Check current dark mode from noctalia settings
            try:
                with open(NOCTALIA_SETTINGS) as f:
                    settings = json.load(f)
                is_dark = settings.get("colorSchemes", {}).get("darkMode", True)
            except:
                is_dark = True
            if is_dark:
                return monitors[first].get("dark", "")
            else:
                return monitors[first].get("light", monitors[first].get("dark", ""))
    except:
        pass
    return ""

def get_current_wallpaper_light():
    try:
        with open(WALLPAPER_CACHE) as f:
            cache = json.load(f)
        monitors = cache.get("wallpapers", {})
        if monitors:
            first = list(monitors.keys())[0]
            return monitors[first].get("light", monitors[first].get("dark", ""))
    except:
        pass
    return ""

def get_kitty_opacity():
    try:
        with open(KITTY_CONFIG) as f:
            for line in f:
                m = re.match(r'^\s*background_opacity\s+([0-9.]+)', line)
                if m:
                    return float(m.group(1))
    except:
        pass
    return 0.5

def get_focus_ring_state():
    try:
        with open(CONFIG) as f:
            c = f.read()
        m = re.search(r'focus-ring\s*\{([^}]*)\}', c, re.DOTALL)
        if m:
            return "on" if re.search(r'^\s*on\s*$', m.group(1), re.MULTILINE) else "off"
    except:
        pass
    return "on"

def get_current_colors():
    try:
        with open(COLORS_FILE) as f:
            return json.load(f)
    except:
        return {}

def get_noise_value():
    try:
        with open(CONFIG) as f:
            c = f.read()
        m = re.search(r'noise\s+([0-9.]+)', c)
        return float(m.group(1)) if m else 0.0
    except:
        return 0.0

def get_corner_radius():
    try:
        with open(CONFIG) as f:
            c = f.read()
        m = re.search(r'(?<!/-)window-rule\s*\{[^}]*geometry-corner-radius (\d+)', c, re.DOTALL)
        return int(m.group(1)) if m else 14
    except:
        return 14

def get_niri_shadow():
    try:
        with open(CONFIG) as f:
            c = f.read()
        m = re.search(r'shadow\s*(\{[^}]*\})', c, re.DOTALL)
        if m:
            return m.group(1)
    except:
        pass
    return None

def parse_niri_shadow_props():
    try:
        with open(CONFIG) as f:
            c = f.read()
    except:
        return {"on": False, "color": "#000000", "softness": 6, "spread": 0, "offsetX": 0, "offsetY": 4}
    m = re.search(r'shadow\s*\{([^}]*)\}', c, re.DOTALL)
    if not m:
        return {"on": False, "color": "#000000", "softness": 6, "spread": 0, "offsetX": 0, "offsetY": 4}
    inner = m.group(1)
    on = re.search(r'^\s*on\s*$', inner, re.MULTILINE) is not None
    color = "#000000"
    cm = re.search(r'color\s+"([^"]+)"', inner)
    if cm:
        color = cm.group(1)
    softness = 6
    sm = re.search(r'softness\s+(\d+)', inner)
    if sm:
        softness = int(sm.group(1))
    spread = 0
    spm = re.search(r'spread\s+(\d+)', inner)
    if spm:
        spread = int(spm.group(1))
    offset_x = 0
    oxm = re.search(r'offset-x\s+(-?\d+)', inner)
    if not oxm:
        oxm = re.search(r'(?<!y=)x=(-?\d+)', inner)
    if oxm:
        offset_x = int(oxm.group(1))
    offset_y = 4
    oym = re.search(r'offset-y\s+(-?\d+)', inner)
    if not oym:
        oym = re.search(r'y=(-?\d+)', inner)
    if oym:
        offset_y = int(oym.group(1))
    return {"on": on, "color": color, "softness": softness,
            "spread": spread, "offsetX": offset_x, "offsetY": offset_y}

def write_shadow_to_settings(props):
    try:
        with open(NOCTALIA_SETTINGS) as f:
            settings = json.load(f)
    except:
        settings = {}
    if "bar" not in settings:
        settings["bar"] = {}
    settings["bar"]["shadowEnabled"] = props["on"]
    settings["bar"]["shadowColor"] = props["color"]
    settings["bar"]["shadowSoftness"] = props["softness"]
    settings["bar"]["shadowSpread"] = props["spread"]
    settings["bar"]["shadowOffsetX"] = props["offsetX"]
    settings["bar"]["shadowOffsetY"] = props["offsetY"]
    atomic_write(NOCTALIA_SETTINGS, json.dumps(settings, indent=4))

def cmd_save(widget_json):
    widget_state = json.loads(widget_json)
    # Override QML-tracked states with actual niri config values
    widget_state["focusRingEnabled"] = (get_focus_ring_state() == "on")
    widget_state["noiseEnabled"] = (get_noise_value() > 0)
    widget_state["squareCorners"] = (get_corner_radius() == 0)
    shadow_block = get_niri_shadow()
    widget_state["shadowEnabled"] = (shadow_block is not None and re.search(r'^\s*on\s*$', shadow_block, re.MULTILINE) is not None)
    widget_state["niriBlurGlobal"] = get_niri_global_blur_state()
    widget_state["niriBlurWindow"] = get_niri_window_blur_state()

    snapshot = {
        "name": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "timestamp": datetime.now().isoformat(),
        "widgetState": widget_state,
        "hoverRevealOpacity": widget_state.get("hoverRevealOpacity", 1.0),
        "colors": get_current_colors(),
        "wallpaper": get_current_wallpaper(),
        "wallpaperLight": get_current_wallpaper_light(),
        "niriBorder": get_niri_border(),
        "niriShadow": get_niri_shadow(),
        "kittyOpacity": get_kitty_opacity()
    }
    snapshots = load_snapshots()
    snapshots.append(snapshot)
    save_snapshots(snapshots)
    print(json.dumps(snapshot))

def cmd_list():
    snapshots = load_snapshots()
    print(json.dumps(snapshots))

def cmd_load(index):
    # Shared lock with niri-toggle.py and noctalia-niri-sync.py
    with open(LOCK_FILE, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            _do_load(index)
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def _do_load(index):
    snapshots = load_snapshots()
    if not (0 <= index < len(snapshots)):
        print("{}")
        return

    snap = snapshots[index]
    ws = snap.get("widgetState", {})
    kitty_opa = snap.get("kittyOpacity")

    # ── Phase 1: write colors.json ──────────────────────────────────
    colors = snap.get("colors", {})
    if colors:
        atomic_write(COLORS_FILE, json.dumps(colors, indent=2))

    # ── Phase 1b: restore widget color preferences ──────────────────
    sync_data = {}
    if ws.get("syncWidgetColors") is not None:
        sync_data["syncWidgetColors"] = ws["syncWidgetColors"]
    if ws.get("syncedCountColor") is not None:
        sync_data["syncedCountColor"] = ws["syncedCountColor"]
    if ws.get("syncedIconColor") is not None:
        sync_data["syncedIconColor"] = ws["syncedIconColor"]
    if ws.get("syncedHoverColor") is not None:
        sync_data["syncedHoverColor"] = ws["syncedHoverColor"]
    if sync_data:
        atomic_write(SYNC_COLORS_FILE, json.dumps(sync_data, indent=2))

    # ── Phase 2: apply ALL niri config in one pass ──────────────────
    try:
        with open(CONFIG) as f:
            c = f.read()
    except:
        c = ""

    niri_reload = False

    # 2a. Border
    border = snap.get("niriBorder")
    if border:
        onoff = "on" if border.get("on", False) else "off"
        # Use colors from the just-written colors.json for consistency
        primary = colors.get("mPrimary", "#67abe4")
        secondary = colors.get("mSecondary", "#5c60d6")
        def darken(hex_color, factor=0.3):
            h = hex_color.lstrip("#")
            r = int(int(h[0:2], 16) * factor)
            g = int(int(h[2:4], 16) * factor)
            b = int(int(h[4:6], 16) * factor)
            return f"#{r:02x}{g:02x}{b:02x}"
        new_border = (
            f'border {{\n        {onoff}\n\n'
            f'        width {border.get("width", 4)}\n'
            f'        active-color "{secondary}"\n'
            f'        inactive-color "{darken(secondary)}"\n    }}'
        )
        c = re.sub(r'border\s*\{[^}]*\}', new_border, c, flags=re.DOTALL)
        niri_reload = True

    # 2b. Blur — use individual states from widgetState
    blur_global = ws.get("niriBlurGlobal", False)
    blur_window = ws.get("niriBlurWindow", False)
    blur_global_state = "on" if blur_global else "off"
    blur_window_value = "true" if blur_window else "false"
    c = re.sub(r'blur\s*\{([^}]*)\}', f'blur {{\n    {blur_global_state}\n}}', c)

    def replace_blur(m):
        inner = m.group(1)
        if 'blur' in inner:
            return f'background-effect {{{inner.replace("blur true", f"blur {blur_window_value}").replace("blur false", f"blur {blur_window_value}")}}}'
        else:
            return f'background-effect {{\n        blur {blur_window_value}\n{inner}}}'
    c = re.sub(r'background-effect\s*\{([^}]*)\}', replace_blur, c)
    niri_reload = True

    # 2c. Corner radius (active rule only, skip /-commented)
    square = ws.get("squareCorners", False)
    corner_val = "0" if square else "14"
    rules_val = "0" if square else "20"

    def replace_corner(m):
        inner = m.group(1)
        inner = re.sub(r'geometry-corner-radius \d+', f'geometry-corner-radius {corner_val}', inner)
        return f'window-rule {{{inner}}}'
    c = re.sub(r'(?<!/-)window-rule\s*\{([^}]*)\}', replace_corner, c, flags=re.DOTALL)
    try:
        with open(RULES) as f:
            rc = f.read()
        rc = re.sub(r'(geometry-corner-radius )\d+', f'\\g<1>{rules_val}', rc)
        atomic_write(RULES, rc)
    except:
        pass
    niri_reload = True

    # 2d. Focus ring
    focus_on = ws.get("focusRingEnabled", True)
    focus_state = "on" if focus_on else "off"
    focus_gradient = ws.get("focusRingGradient", False)
    focus_width = ws.get("focusRingWidth", 3)
    gradient_line = '        active-gradient from="#ff0080" to="#00d4ff" angle=45 relative-to="workspace-view"\n'
    primary = colors.get("mPrimary", "#67abe4")
    def darken(hex_color, factor=0.3):
        h = hex_color.lstrip("#")
        r = int(int(h[0:2], 16) * factor)
        g = int(int(h[2:4], 16) * factor)
        b = int(int(h[4:6], 16) * factor)
        return f"#{r:02x}{g:02x}{b:02x}"
    def set_focus(m):
        block = m.group(0)
        block = re.sub(r'^\s*(on|off)\s*$', f'    {focus_state}', block, count=1, flags=re.MULTILINE)
        block = re.sub(r'width\s+\d+', f'width {focus_width}', block)
        block = re.sub(r'(active-color\s+")#[^"\n]+(")', rf'\g<1>{primary}\g<2>', block)
        block = re.sub(r'(inactive-color\s+")#[^"\n]+(")', rf'\g<1>{darken(primary)}\g<2>', block)
        if focus_gradient:
            if 'active-gradient' not in block:
                block = re.sub(r'(active-color\s+"[^"]*"\n)', r'\1' + gradient_line, block)
        else:
            block = re.sub(r'\n?\s*active-gradient[^\n]*', '', block)
        return block
    def replace_focus_block(content):
        idx = content.find('focus-ring')
        if idx == -1:
            return content
        brace_start = content.find('{', idx)
        if brace_start == -1:
            return content
        depth = 1
        i = brace_start + 1
        while i < len(content) and depth > 0:
            if content[i] == '{':
                depth += 1
            elif content[i] == '}':
                depth -= 1
            i += 1
        if depth != 0:
            return content
        full_block = content[idx:i]
        modified = set_focus(type('M', (), {'group': lambda self, n: full_block})())
        return content[:idx] + modified + content[i:]
    c = replace_focus_block(c)
    niri_reload = True

    # 2e. Noise + saturation
    noise_val = "0.15" if ws.get("noiseEnabled", False) else "0"
    if re.search(r'noise\s+', c):
        c = re.sub(r'noise\s+[0-9.]+', f'noise {noise_val}', c)
    else:
        c = re.sub(r'(blur\s*\{\s*\n\s*on\s*\n)', f'\\1    noise {noise_val}\n\n', c)
    if re.search(r'saturation\s+', c):
        c = re.sub(r'saturation\s+[0-9.]+', 'saturation 1', c)
    else:
        c = re.sub(r'(noise\s+[0-9.]+\s*\n)', f'\\1    saturation 1\n\n', c)
    niri_reload = True

    # 2f. Shadow
    niri_shadow = snap.get("niriShadow")
    if niri_shadow:
        c = re.sub(r'shadow\s*\{[^}]*\}', f'shadow {niri_shadow}', c, flags=re.DOTALL)
    else:
        shadow_on = ws.get("shadowEnabled", True)
        shadow_state = "on" if shadow_on else "off"
        def set_shadow(m):
            block = m.group(0)
            return re.sub(r'^\s*(on|off)\s*$', f'    {shadow_state}', block, count=1, flags=re.MULTILINE)
        c = re.sub(r'shadow\s*\{[^}]*\}', set_shadow, c, flags=re.DOTALL)
    niri_reload = True

    # Write config.kdl once
    if c:
        atomic_write(CONFIG, c)
    if niri_reload:
        subprocess.run(["niri", "msg", "action", "load-config-file"])

    # ── Phase 3: verify blur states took effect ────────────────────
    actual_global = get_niri_global_blur_state()
    actual_window = get_niri_window_blur_state()
    if actual_global != blur_global or actual_window != blur_window:
        print(json.dumps({
            "_blur_warning": "mismatch after write",
            "expected": {"niriBlurGlobal": blur_global, "niriBlurWindow": blur_window},
            "actual": {"niriBlurGlobal": actual_global, "niriBlurWindow": actual_window}
        }), file=sys.stderr)

    # ── Phase 4: kitty opacity ─────────────────────────────────────
    kitty_applied = False
    print(json.dumps({"_kitty_phase4": "started", "kitty_opa": kitty_opa}), file=sys.stderr)
    if kitty_opa is not None:
        try:
            with open(KITTY_CONFIG) as f:
                kc = f.read()
            import re as _re
            # Find current opacity for debugging
            _match = _re.search(r'^(\s*background_opacity\s+)([0-9.]+)', kc, _re.MULTILINE)
            _current = _match.group(2) if _match else "NOT_FOUND"
            print(json.dumps({"_kitty_before": _current, "target": kitty_opa}), file=sys.stderr)
            
            new_kc = _re.sub(r'^(\s*background_opacity\s+)[0-9.]+', f'\\g<1>{kitty_opa}', kc, flags=_re.MULTILINE)
            if new_kc != kc:
                atomic_write(KITTY_CONFIG, new_kc)
                # Verify write
                with open(KITTY_CONFIG) as f2:
                    verify = f2.read()
                _match2 = _re.search(r'^(\s*background_opacity\s+)([0-9.]+)', verify, _re.MULTILINE)
                _after = _match2.group(2) if _match2 else "NOT_FOUND"
                print(json.dumps({"_kitty_after_write": _after}), file=sys.stderr)
            else:
                print(json.dumps({"_kitty_no_change": "regex didn't match"}), file=sys.stderr)
            subprocess.run(["pkill", "-SIGUSR1", "-x", "kitty"], capture_output=True)
            kitty_applied = True
        except Exception as e:
            print(json.dumps({"_kitty_error": str(e)}), file=sys.stderr)

    # ── Phase 5: verify kitty opacity took effect ──────────────────
    if kitty_applied and kitty_opa is not None:
        time.sleep(0.3)
        actual_kitty = get_kitty_opacity()
        if abs(actual_kitty - kitty_opa) > 0.01:
            print(json.dumps({
                "_kitty_warning": "kitty opacity mismatch after write",
                "expected": kitty_opa,
                "actual": actual_kitty
            }), file=sys.stderr)

    # ── Phase 6: hover reveal opacity ──────────────────────────────
    hover_opa = snap.get("hoverRevealOpacity")
    if hover_opa is not None:
        print(json.dumps({"hoverRevealOpacity": hover_opa}))

    # ── Phase 7: wallpaper ─────────────────────────────────────────
    # Check if we're in dark or light mode to pick correct wallpaper
    is_dark = colors.get("darkMode", True) if colors else True
    wallpaper = snap.get("wallpaper") if is_dark else snap.get("wallpaperLight", snap.get("wallpaper"))
    if wallpaper and wallpaper != "":
        print(json.dumps({"wallpaper": wallpaper}))

    # ── Phase 8: sync niri shadow → noctalia bar shadow ───────────
    write_shadow_to_settings(parse_niri_shadow_props())

    print(json.dumps(snap))

def cmd_delete(index):
    snapshots = load_snapshots()
    if 0 <= index < len(snapshots):
        snapshots.pop(index)
        save_snapshots(snapshots)
    cmd_list()

def cmd_delete_all():
    save_snapshots([])
    cmd_list()

def cmd_rename(index, new_name):
    snapshots = load_snapshots()
    if 0 <= index < len(snapshots):
        new_name = new_name.strip()
        if new_name:
            snapshots[index]["name"] = new_name
            save_snapshots(snapshots)
    cmd_list()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: snapshot.py {save <json>|list|load <n>|delete <n>|rename <n> <name>}")
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "save":
        if len(sys.argv) < 3:
            print("usage: snapshot.py save '<json>'")
            sys.exit(1)
        cmd_save(sys.argv[2])
    elif cmd == "list":
        cmd_list()
    elif cmd == "load":
        if len(sys.argv) < 3:
            print("usage: snapshot.py load <index>")
            sys.exit(1)
        cmd_load(int(sys.argv[2]))
    elif cmd == "delete":
        if len(sys.argv) < 3:
            print("usage: snapshot.py delete <index>")
            sys.exit(1)
        cmd_delete(int(sys.argv[2]))
    elif cmd == "delete-all":
        cmd_delete_all()
    elif cmd == "rename":
        if len(sys.argv) < 4:
            print("usage: snapshot.py rename <index> <new_name>")
            sys.exit(1)
        cmd_rename(int(sys.argv[2]), sys.argv[3])
    else:
        print(f"unknown: {cmd}")
        sys.exit(1)
