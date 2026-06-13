#!/usr/bin/env python3
import fcntl
import json
import os
import re
import subprocess
import sys
import tempfile

CONFIG = "/home/za/.config/niri/config.kdl"
RULES = "/home/za/.config/niri/cfg/rules.kdl"
LOCK_FILE = "/tmp/niri-toggle.lock"
SHADOW_STATE_FILE = "/tmp/niri-shadow.json"
OPACITY_STATE_FILE = "/tmp/niri-blur-opacity.json"
NOCTALIA_SETTINGS = "/home/za/.config/noctalia/settings.json"
COLORS_FILE = "/home/za/.config/noctalia/colors.json"


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

def set_corner_radius(config_val, rules_val):
    with open(LOCK_FILE, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            # Update rules.kdl (simple — single window-rule)
            try:
                rc = open(RULES).read()
                rc = re.sub(r'(geometry-corner-radius )\d+', f'\\g<1>{rules_val}', rc)
                atomic_write(RULES, rc)
            except FileNotFoundError:
                pass

            # Update config.kdl (only active window-rule, skip /-commented)
            try:
                c = open(CONFIG).read()
                def replace_corner(m):
                    inner = m.group(1)
                    inner = re.sub(r'geometry-corner-radius \d+', f'geometry-corner-radius {config_val}', inner)
                    return f'window-rule {{{inner}}}'
                c = re.sub(r'(?<!/-)window-rule\s*\{([^}]*)\}', replace_corner, c, flags=re.DOTALL)
                atomic_write(CONFIG, c)
            except FileNotFoundError:
                pass

            subprocess.run(["niri", "msg", "action", "load-config-file"])
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)

def set_niri_blur(value):
    onoff = "on" if value == "true" else "off"
    with open(LOCK_FILE, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            c = open(CONFIG).read()
            # 1. Toggle per-window blur inside background-effect blocks
            def replace_blur(m):
                inner = m.group(1)
                if 'blur' in inner:
                    return f'background-effect {{{inner.replace("blur true", f"blur {value}").replace("blur false", f"blur {value}")}}}'
                else:
                    return f'background-effect {{\n        blur {value}\n{inner}}}'
            c = re.sub(r'background-effect\s*\{([^}]*)\}', replace_blur, c)
            # 2. Toggle global blur block
            m = re.search(r'blur\s*\{([^}]*)\}', c)
            if m:
                c = c[:m.start()] + f'blur {{\n    {onoff}\n}}' + c[m.end():]
            atomic_write(CONFIG, c)
            subprocess.run(["niri", "msg", "action", "load-config-file"])
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)

def toggle_focus_ring():
    with open(LOCK_FILE, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            c = open(CONFIG).read()
            def toggle(m):
                block = m.group(0)
                if re.search(r'^\s*on\s*$', block, re.MULTILINE):
                    return re.sub(r'^(\s*)on(\s*)$', r'\1off\2', block, count=1, flags=re.MULTILINE)
                elif re.search(r'^\s*off\s*$', block, re.MULTILINE):
                    return re.sub(r'^(\s*)off(\s*)$', r'\1on\2', block, count=1, flags=re.MULTILINE)
                else:
                    # No on/off state found, add 'off' after the opening brace
                    return block.replace('focus-ring {', 'focus-ring {\n        off', 1)
                return block
            c = re.sub(r'focus-ring \{[^}]*\}', toggle, c, flags=re.DOTALL)
            atomic_write(CONFIG, c)
            subprocess.run(["niri", "msg", "action", "load-config-file"])
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)

def set_focus_ring(state):
    if state not in ["on", "off"]:
        print(f"Invalid state: {state}. Must be 'on' or 'off'")
        return
    with open(LOCK_FILE, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            c = open(CONFIG).read()
            def setter(m):
                block = m.group(0)
                return re.sub(r'^\s*(on|off)\s*$', f'    {state}', block, count=1, flags=re.MULTILINE)
            c = re.sub(r'focus-ring \{[^}]*\}', setter, c, flags=re.DOTALL)
            atomic_write(CONFIG, c)
            subprocess.run(["niri", "msg", "action", "load-config-file"])
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)

def set_focus_ring_width(width):
    widths = [1, 2, 3, 4, 5]
    if width not in widths:
        return widths[0]
    with open(LOCK_FILE, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            c = open(CONFIG).read()
            if re.search(r'width\s+\d+', c):
                c = re.sub(r'width\s+\d+', f'width {width}', c)
            else:
                c = re.sub(r'(focus-ring\s*\{)', rf'\1\n        width {width}', c)
            atomic_write(CONFIG, c)
            subprocess.run(["niri", "msg", "action", "load-config-file"])
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)

def get_focus_ring_width():
    try:
        c = open(CONFIG).read()
        m = re.search(r'width\s+(\d+)', c)
        if m:
            print(m.group(1))
        else:
            print("3")
    except Exception:
        print("3")

def set_focus_ring_gradient(state):
    if state not in ["on", "off"]:
        print(f"Invalid state: {state}. Must be 'on' or 'off'")
        return
    gradient_line = '        active-gradient from="#ff0080" to="#00d4ff" angle=45 relative-to="workspace-view"\n'
    with open(LOCK_FILE, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            c = open(CONFIG).read()
            def add_gradient(m):
                block = m.group(0)
                if 'active-gradient' in block:
                    return re.sub(
                        r'active-gradient[^\n]*\n?',
                        gradient_line,
                        block
                    )
                return re.sub(
                    r'(active-color\s+"#[0-9a-fA-F]+"\n)',
                    r'\1' + gradient_line,
                    block,
                    count=1
                )
            def remove_gradient(m):
                block = m.group(0)
                block = re.sub(r'\n?\s*active-gradient[^\n]*', '', block)
                try:
                    with open(COLORS_FILE) as jf:
                        colors = json.load(jf)
                    primary = colors.get("mPrimary", "#67abe4")
                except Exception:
                    primary = "#67abe4"
                block = re.sub(r'(active-color\s+")#[^"\n]+(")', rf'\g<1>{primary}\g<2>', block)
                return block
            if state == "on":
                c = re.sub(r'focus-ring \{[^}]*\}', add_gradient, c, flags=re.DOTALL)
            else:
                c = re.sub(r'focus-ring \{[^}]*\}', remove_gradient, c, flags=re.DOTALL)
            atomic_write(CONFIG, c)
            subprocess.run(["niri", "msg", "action", "load-config-file"])
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)

def sync_focus_ring_color():
    """Read mPrimary from colors.json and update niri focus-ring active-color."""
    try:
        with open(LOCK_FILE, 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            try:
                c = open(CONFIG).read()
                try:
                    colors = json.load(open(COLORS_FILE))
                    primary = colors.get("mPrimary", "#67abe4")
                except Exception:
                    primary = "#67abe4"
                def update_color(m):
                    block = m.group(0)
                    block = re.sub(r'(active-color\s+")#[^"\n]+(")', rf'\g<1>{primary}\g<2>', block)
                    return block
                c = re.sub(r'focus-ring \{[^}]*\}', update_color, c, flags=re.DOTALL)
                atomic_write(CONFIG, c)
                subprocess.run(["niri", "msg", "action", "load-config-file"])
            finally:
                fcntl.flock(lock, fcntl.LOCK_UN)
    except Exception as e:
        print(f"sync-focus-ring-color failed: {e}", file=sys.stderr)

def get_shadow_state():
    try:
        c = open(CONFIG).read()
        m = re.search(r'shadow\s*\{([^}]*)\}', c, re.DOTALL)
        if m:
            return "on" if re.search(r'^\s*on\s*$', m.group(1), re.MULTILINE) else "off"
    except:
        pass
    return "off"

def set_blur_and_opacity(state):
    """Explicitly set blur state: 'on' or 'off'"""
    if state not in ["on", "off"]:
        print(f"Invalid state: {state}. Must be 'on' or 'off'")
        return
    
    blur_state = state
    blur_value = "true" if state == "on" else "false"
    opacity = "0.85" if state == "on" else "1.0"
    kitty_opacity = "0.5" if state == "on" else "1.0"
    
    with open(LOCK_FILE, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            c = open(CONFIG).read()

            # 1. Set global blur block
            c = re.sub(
                r'blur\s*\{([^}]*)\}',
                f'blur {{\n    {blur_state}\n}}',
                c
            )

            # 2. Set per-window blur inside background-effect
            def replace_blur(m):
                inner = m.group(1)
                if 'blur' in inner:
                    return f'background-effect {{{inner.replace("blur true", f"blur {blur_value}").replace("blur false", f"blur {blur_value}")}}}'
                else:
                    return f'background-effect {{\n        blur {blur_value}\n{inner}}}'
            c = re.sub(r'background-effect\s*\{([^}]*)\}', replace_blur, c)

            # 3. Set opacity in global window-rule (find by open-maximized)
            lines = c.split('\n')
            for i, line in enumerate(lines):
                if 'open-maximized' in line:
                    # Found the global window-rule, now find the opacity line or insert it
                    # Look backwards for draw-border-with-background
                    for j in range(i-1, max(0, i-10), -1):
                        if 'draw-border-with-background' in lines[j]:
                            # Check if next line has opacity
                            if j+1 < len(lines) and 'opacity' in lines[j+1]:
                                # Replace existing opacity
                                lines[j+1] = f'    opacity {opacity}'
                            else:
                                # Insert opacity after draw-border-with-background
                                lines.insert(j+1, f'    opacity {opacity}')
                            break
                    break
            c = '\n'.join(lines)

            atomic_write(CONFIG, c)
            subprocess.run(["niri", "msg", "action", "load-config-file"])

            # 4. Set kitty background_opacity
            KITTY_CONFIG = "/home/za/.config/kitty/kitty.conf"
            try:
                kitty_c = open(KITTY_CONFIG).read()
                kitty_c = re.sub(
                    r'^(\s*background_opacity\s+)[0-9.]+',
                    f'\\g<1>{kitty_opacity}',
                    kitty_c,
                    flags=re.MULTILINE
                )
                atomic_write(KITTY_CONFIG, kitty_c)
                # Reload kitty
                subprocess.run(["pkill", "-SIGUSR1", "-x", "kitty"])
            except FileNotFoundError:
                pass

        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)

def toggle_noise_saturation():
    with open(LOCK_FILE, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            c = open(CONFIG).read()
            noise_m = re.search(r'noise\s+([0-9.]+)', c)
            noise_val = float(noise_m.group(1)) if noise_m else 0.0

            if noise_val == 0.0:
                new_noise = "0.15"
            else:
                new_noise = "0"

            # Replace or add noise
            if re.search(r'noise\s+', c):
                c = re.sub(r'noise\s+[0-9.]+', f'noise {new_noise}', c)
            else:
                c = re.sub(r'(blur\s*\{\s*\n\s*on\s*\n)', f'\\1    noise {new_noise}\n\n', c)

            # Replace or add saturation
            if re.search(r'saturation\s+', c):
                c = re.sub(r'saturation\s+[0-9.]+', 'saturation 1', c)
            else:
                c = re.sub(r'(noise\s+[0-9.]+\s*\n)', f'\\1    saturation 1\n\n', c)

            atomic_write(CONFIG, c)
            subprocess.run(["niri", "msg", "action", "load-config-file"])
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)

def corner_sync(radius_ratio_str):
    try:
        rr = float(radius_ratio_str)
    except:
        rr = 0.8
    if rr == 0.0:
        set_corner_radius(0, 0)
    else:
        set_corner_radius(14, 20)

def toggle_global_blur():
    with open(LOCK_FILE, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            c = open(CONFIG).read()
            m = re.search(r'blur\s*\{([^}]*)\}', c, re.DOTALL)
            if m:
                block = m.group(1)
                lines = block.split('\n')
                found = None
                extras = []
                for line in lines:
                    if re.search(r'^\s*on\s*$', line):
                        found = True
                    elif re.search(r'^\s*off\s*$', line):
                        found = False
                    elif line.strip():
                        extras.append(line)

                if found:
                    opacities = re.findall(r'opacity\s+([0-9.]+)', c)
                    atomic_write(OPACITY_STATE_FILE, json.dumps(opacities))
                    c = re.sub(r'opacity\s+[0-9.]+', 'opacity 1.0', c)
                    new_state = "off"
                else:
                    try:
                        saved = json.loads(open(OPACITY_STATE_FILE).read())
                        def restore(m2):
                            return f'opacity {saved.pop(0)}'
                        c = re.sub(r'opacity\s+[0-9.]+', restore, c)
                    except:
                        pass
                    new_state = "on"

                new_block = '\n    ' + new_state + '\n'
                if extras:
                    new_block += '\n'.join(extras) + '\n'
                m2 = re.search(r'blur\s*\{([^}]*)\}', c, re.DOTALL)
                if m2:
                    c = c[:m2.start()] + 'blur {' + new_block + '}' + c[m2.end():]
            else:
                c += '\n\nblur {\n    on\n}\n'
            atomic_write(CONFIG, c)
            subprocess.run(["niri", "msg", "action", "load-config-file"])
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)

def toggle_window_blur():
    with open(LOCK_FILE, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            c = open(CONFIG).read()
            def toggle(m):
                inner = m.group(1)
                if re.search(r'blur\s+true', inner):
                    inner = re.sub(r'\s*blur\s+true\n?', '\n', inner)
                    inner = re.sub(r'xray\s+true', 'xray false', inner)
                    return f'background-effect {{{inner}}}'
                else:
                    inner = re.sub(r'\s*blur\s+(true|false)\n?', '\n', inner)
                    inner = re.sub(r'xray\s+false', 'xray true', inner)
                    return f'background-effect {{\n        blur true\n{inner}}}'
            c = re.sub(r'background-effect\s*\{([^}]*)\}', toggle, c)
            atomic_write(CONFIG, c)
            subprocess.run(["niri", "msg", "action", "load-config-file"])
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)

def set_kitty_opacity(value):
    KITTY_CONFIG = "/home/za/.config/kitty/kitty.conf"
    try:
        kitty_c = open(KITTY_CONFIG).read()
        kitty_c = re.sub(
            r'^(\s*background_opacity\s+)[0-9.]+',
            f'\\g<1>{value}',
            kitty_c,
            flags=re.MULTILINE
        )
        atomic_write(KITTY_CONFIG, kitty_c)
        subprocess.run(["pkill", "-SIGUSR1", "-x", "kitty"])
        return True
    except FileNotFoundError:
        return False

def cycle_kitty_opacity():
    KITTY_CONFIG = "/home/za/.config/kitty/kitty.conf"
    try:
        kitty_c = open(KITTY_CONFIG).read()
        m = re.search(r'background_opacity\s+([0-9.]+)', kitty_c)
        current = float(m.group(1)) if m else 1.0
        next_val = "0.0" if current >= 1.0 else ("0.5" if current >= 0.25 else "1.0")
        set_kitty_opacity(next_val)
    except FileNotFoundError:
        pass

def _parse_shadow_block():
    try:
        c = open(CONFIG).read()
    except:
        return None
    m = re.search(r'shadow\s*\{([^}]*)\}', c, re.DOTALL)
    if not m:
        return None
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

def write_shadow_props():
    props = _parse_shadow_block()
    if not props:
        props = {"on": False, "color": "#000000", "softness": 6,
                 "spread": 0, "offsetX": 0, "offsetY": 4}
    atomic_write(SHADOW_STATE_FILE, json.dumps(props))
    write_shadow_to_settings(props)
    # Print to stdout for QML process handler to capture
    print(json.dumps(props))

def get_shadow_props():
    props = _parse_shadow_block()
    if not props:
        props = {"on": False, "color": "#000000", "softness": 6,
                 "spread": 0, "offsetX": 0, "offsetY": 4}
    print(json.dumps(props))

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

def sync_shadow_to_focus_ring():
    with open(LOCK_FILE, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            c = open(CONFIG).read()
            m = re.search(r'focus-ring\s*\{[^}]*active-color\s+"([^"]+)"', c, re.DOTALL)
            if not m:
                return
            active_color = m.group(1)
            def set_color(m2):
                return re.sub(r'color\s+"[^"]*"', f'color "{active_color}"', m2.group(0))
            c = re.sub(r'shadow\s*\{[^}]*\}', set_color, c, flags=re.DOTALL)
            atomic_write(CONFIG, c)
            subprocess.run(["niri", "msg", "action", "load-config-file"])
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)
    write_shadow_props()

def toggle_shadow():
    with open(LOCK_FILE, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            c = open(CONFIG).read()
            m = re.search(r'shadow\s*\{([^}]*)\}', c, re.DOTALL)
            if m:
                block = m.group(1)
                if re.search(r'^\s*on\s*$', block, re.MULTILINE):
                    new_block = re.sub(r'^(\s*)on(\s*)$', r'\1off\2', block, count=1, flags=re.MULTILINE)
                elif re.search(r'^\s*off\s*$', block, re.MULTILINE):
                    new_block = re.sub(r'^(\s*)off(\s*)$', r'\1on\2', block, count=1, flags=re.MULTILINE)
                else:
                    # Neither on nor off found (e.g. bare or commented block) — insert "on"
                    new_block = re.sub(r'^(\s*)(?:$|//)', r'\1on\n\1', block, count=1, flags=re.MULTILINE)
                c = c[:m.start()] + 'shadow {' + new_block + '}' + c[m.end():]
            atomic_write(CONFIG, c)
            subprocess.run(["niri", "msg", "action", "load-config-file"])
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)
    write_shadow_props()

def get_focus_ring_gradient_state():
    try:
        c = open(CONFIG).read()
        if re.search(r'active-gradient\s+from=', c):
            print("on")
        else:
            print("off")
    except Exception:
        print("off")

if __name__ == "__main__":
    # ── diagnostic log: capture every call to find blur-window-toggle trigger ──
    import time as _t
    try:
        with open("/tmp/niri-toggle-calls.log", "a") as lf:
            lf.write(f"[{_t.strftime('%H:%M:%S')}] PID={os.getpid()} PPID={os.getppid()} CMD={' '.join(sys.argv)}\n")
    except:
        pass

    if len(sys.argv) < 2:
        print("usage: niri-toggle.py {square|round|focus-ring|set-focus-ring <on|off>|focus-ring-gradient <on|off>|get-focus-ring-gradient|focus-ring-width <1-5>|get-focus-ring-width|blur-off|blur-on|blur-global-toggle|blur-window-toggle|noise-toggle|glass-cycle|glass-set <opacity>|shadow-toggle|shadow-sync|shadow-get|sync-focus-ring-color|corner-sync <ratio>}")
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "square":
        set_corner_radius(0, 0)
    elif cmd == "round":
        set_corner_radius(14, 20)
    elif cmd == "focus-ring":
        toggle_focus_ring()
    elif cmd == "set-focus-ring":
        if len(sys.argv) < 3:
            print("usage: niri-toggle.py set-focus-ring <on|off>")
            sys.exit(1)
        set_focus_ring(sys.argv[2])
    elif cmd == "focus-ring-gradient":
        if len(sys.argv) < 3:
            print("usage: niri-toggle.py focus-ring-gradient <on|off>")
            sys.exit(1)
        set_focus_ring_gradient(sys.argv[2])
    elif cmd == "get-focus-ring-gradient":
        get_focus_ring_gradient_state()
    elif cmd == "focus-ring-width":
        if len(sys.argv) < 3:
            print("usage: niri-toggle.py focus-ring-width <1|2|3|4|5>")
            sys.exit(1)
        set_focus_ring_width(int(sys.argv[2]))
    elif cmd == "get-focus-ring-width":
        get_focus_ring_width()
    elif cmd == "blur-off":
        set_blur_and_opacity("off")
    elif cmd == "blur-on":
        set_blur_and_opacity("on")
    elif cmd == "noise-toggle":
        toggle_noise_saturation()
    elif cmd == "blur-global-toggle":
        toggle_global_blur()
    elif cmd == "blur-window-toggle":
        toggle_window_blur()
    elif cmd == "glass-cycle":
        cycle_kitty_opacity()
    elif cmd == "glass-set":
        if len(sys.argv) < 3:
            print("usage: niri-toggle.py glass-set <opacity>")
            sys.exit(1)
        set_kitty_opacity(sys.argv[2])
    elif cmd == "corner-sync":
        if len(sys.argv) < 3:
            print("usage: niri-toggle.py corner-sync <radius_ratio>")
            sys.exit(1)
        corner_sync(sys.argv[2])
    elif cmd == "shadow-toggle":
        toggle_shadow()
    elif cmd == "shadow-sync":
        sync_shadow_to_focus_ring()
    elif cmd == "shadow-get":
        get_shadow_props()
    elif cmd == "sync-focus-ring-color":
        sync_focus_ring_color()
    else:
        print(f"unknown: {cmd}")
        sys.exit(1)
