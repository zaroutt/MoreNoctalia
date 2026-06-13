#!/usr/bin/env python3
"""Cycle through Noctalia color schemes or switch to wallpaper colors."""
import os, sys, json, glob, re

ACTION = sys.argv[1] if len(sys.argv) > 1 else "cycle"

CONFIG_DIR = os.path.expanduser("~/.config/noctalia")
SCHEMES_DIR = os.path.join(CONFIG_DIR, "colorschemes")

def list_schemes():
    schemes = []
    if os.path.isdir(SCHEMES_DIR):
        for name in sorted(os.listdir(SCHEMES_DIR)):
            path = os.path.join(SCHEMES_DIR, name, f"{name}.json")
            if os.path.isfile(path):
                schemes.append(name)
    return schemes

if ACTION == "list":
    schemes = list_schemes()
    print(json.dumps(schemes))
elif ACTION == "list-full":
    schemes = list_schemes()
    system_dir = sys.argv[2] if len(sys.argv) > 2 else None
    if system_dir and os.path.isdir(system_dir):
        for name in sorted(os.listdir(system_dir)):
            path = os.path.join(system_dir, name, f"{name}.json")
            if os.path.isfile(path) and name not in schemes:
                schemes.append(name)
    result = []
    for name in schemes:
        path = os.path.join(SCHEMES_DIR, name, f"{name}.json")
        if not os.path.isfile(path) and system_dir:
            path = os.path.join(system_dir, name, f"{name}.json")
        primary = ""
        try:
            with open(path) as f:
                scheme = json.load(f)
            variant = scheme.get("dark", scheme.get("light", {}))
            primary = variant.get("mPrimary", "")
        except Exception:
            pass
        result.append({"name": name, "primary": primary})
    settings_path = os.path.join(CONFIG_DIR, "settings.json")
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except Exception:
        settings = {}
    cs = settings.get("colorSchemes", {})
    use_wallpaper = cs.get("useWallpaperColors", True)
    current_scheme = cs.get("predefinedScheme", "")
    print(json.dumps({
        "schemes": result,
        "useWallpaper": use_wallpaper,
        "currentScheme": current_scheme,
    }))
elif ACTION == "info":
    settings_path = os.path.join(CONFIG_DIR, "settings.json")
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except Exception:
        settings = {}
    cs = settings.get("colorSchemes", {})
    info = {
        "useWallpaper": cs.get("useWallpaperColors", True),
        "predefinedScheme": cs.get("predefinedScheme", ""),
        "schemes": list_schemes(),
    }
    print(json.dumps(info))
elif ACTION == "apply":
    name = sys.argv[2]
    system_dir = sys.argv[3] if len(sys.argv) > 3 else None
    # Load scheme file from user directory first, then system
    scheme_path = os.path.join(SCHEMES_DIR, name, f"{name}.json")
    if not os.path.isfile(scheme_path) and system_dir:
        scheme_path = os.path.join(system_dir, name, f"{name}.json")
    if not os.path.isfile(scheme_path):
        print(json.dumps({"error": f"scheme not found: {name}"}))
        sys.exit(1)
    with open(scheme_path) as f:
        scheme = json.load(f)

    # Determine which variant to use
    settings_path = os.path.join(CONFIG_DIR, "settings.json")
    with open(settings_path) as f:
        settings = json.load(f)
    dark_mode = settings.get("colorSchemes", {}).get("darkMode", True)
    variant = scheme.get("dark" if dark_mode else "light", scheme.get("dark", {}))

    # Write to colors.json (noctalia watches this file for in-app color updates)
    colors_path = os.path.join(CONFIG_DIR, "colors.json")
    with open(colors_path, "w") as f:
        json.dump(variant, f, indent=2)

    # Update settings
    settings["colorSchemes"]["useWallpaperColors"] = False
    settings["colorSchemes"]["predefinedScheme"] = name
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)

    # Trigger full template pipeline (Kitty, Ghostty, etc.) the same way
    # direct Settings UI does via ColorSchemeService.setPredefinedScheme()
    import subprocess as _sp
    _sp.run(["quickshell", "ipc", "colorScheme", "set", name],
            capture_output=True, timeout=30)

    print(json.dumps({"applied": name}))
elif ACTION == "wallpaper":
    settings_path = os.path.join(CONFIG_DIR, "settings.json")
    with open(settings_path) as f:
        settings = json.load(f)
    settings["colorSchemes"]["useWallpaperColors"] = True
    settings["colorSchemes"]["predefinedScheme"] = ""
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
    # Trigger full template pipeline by calling generate() via generationMethod IPC
    # Setting to same value triggers onGenerationMethodChanged -> generate() -> generateFromWallpaper()
    import subprocess as _sp
    cur_method = settings.get("colorSchemes", {}).get("generationMethod", "tonal")
    _sp.run(["quickshell", "ipc", "colorScheme", "setGenerationMethod", cur_method],
            capture_output=True, timeout=15)

    print(json.dumps({"applied": "wallpaper"}))
elif ACTION == "rename":
    old = sys.argv[2]
    new = sys.argv[3].strip() if len(sys.argv) > 3 else ""
    if not new or "/" in new or "\\" in new or new in (".", "..") or "\0" in new:
        print(json.dumps({"error": f"invalid name: {new!r}"}))
        sys.exit(1)
    old_dir = os.path.join(SCHEMES_DIR, old)
    new_dir = os.path.join(SCHEMES_DIR, new)
    if not os.path.isdir(old_dir):
        print(json.dumps({"error": f"scheme not found: {old}"}))
        sys.exit(1)
    if old != new:
        if os.path.exists(new_dir):
            print(json.dumps({"error": f"name already exists: {new}"}))
            sys.exit(1)
        os.rename(old_dir, new_dir)
        old_file = os.path.join(new_dir, f"{old}.json")
        new_file = os.path.join(new_dir, f"{new}.json")
        if os.path.exists(old_file):
            os.rename(old_file, new_file)
    settings_path = os.path.join(CONFIG_DIR, "settings.json")
    try:
        with open(settings_path) as f:
            settings = json.load(f)
        cs = settings.get("colorSchemes", {})
        if not cs.get("useWallpaperColors", True) and cs.get("predefinedScheme", "") == old:
            settings["colorSchemes"]["predefinedScheme"] = new
            with open(settings_path, "w") as f:
                json.dump(settings, f, indent=2)
    except Exception:
        pass
    print(json.dumps({"renamed": new}))
elif ACTION == "delete":
    name = sys.argv[2]
    scheme_dir = os.path.join(SCHEMES_DIR, name)
    if os.path.isdir(scheme_dir):
        import shutil
        shutil.rmtree(scheme_dir)
    # If deleted scheme was active, switch to wallpaper
    settings_path = os.path.join(CONFIG_DIR, "settings.json")
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except Exception:
        settings = {}
    cs = settings.get("colorSchemes", {})
    if not cs.get("useWallpaperColors", True) and cs.get("predefinedScheme", "") == name:
        settings["colorSchemes"]["useWallpaperColors"] = True
        settings["colorSchemes"]["predefinedScheme"] = ""
        with open(settings_path, "w") as f:
            json.dump(settings, f, indent=2)
        colors_path = os.path.join(CONFIG_DIR, "colors.json")
        if os.path.exists(colors_path):
            os.utime(colors_path, None)
    print(json.dumps({"deleted": name}))
elif ACTION == "zen-bg":
    import subprocess as _sp
    import time as _time

    ZEN_PROFILE = os.path.expanduser("~/.config/zen/i8sic6qk.Default (release)")
    ZEN_USER_JS = os.path.join(ZEN_PROFILE, "user.js")

    def _write_user_js(enabled, color):
        lines = [
            'user_pref("marionette.enabled", true);',
            'user_pref("mod.sameerasw.zen_bg_color_enabled", true);',
            f'user_pref("mod.sameerasw.zen_transparency_color", "{color}");',
        ]
        with open(ZEN_USER_JS, "w") as f:
            f.write("\n".join(lines) + "\n")

    def _kill_zen():
        try:
            _sp.run(["pkill", "-TERM", "-x", "zen-bin"], timeout=5)
        except Exception:
            pass
        for _ in range(15):
            try:
                procs = _sp.check_output(["pgrep", "-x", "zen-bin"], timeout=2)
                if not procs.strip():
                    break
                _time.sleep(0.3)
            except Exception:
                break
        try:
            _sp.run(["pkill", "-9", "-x", "zen-bin"], timeout=5)
        except Exception:
            pass
        for lockfile in [".parentlock", "lock"]:
            path = os.path.join(ZEN_PROFILE, lockfile)
            if os.path.exists(path):
                try:
                    os.remove(path)
                except Exception:
                    pass
        _time.sleep(1)

    def _start_zen():
        _sp.Popen(["/opt/zen-browser-bin/zen-bin"],
                  stdout=_sp.DEVNULL, stderr=_sp.DEVNULL)

    enabled = sys.argv[2].lower() == "true" if len(sys.argv) > 2 else False

    try:
        colors = json.load(open(os.path.join(CONFIG_DIR, "colors.json")))
    except Exception:
        colors = {}

    _kill_zen()

    if enabled:
        color = colors.get("mShadow", "#1e1e2e")
    else:
        color = "transparent"
    _write_user_js(enabled, color)

    _start_zen()

    print(json.dumps({"applied": True, "enabled": enabled, "color": color}))
elif ACTION == "cycle":
    settings_path = os.path.join(CONFIG_DIR, "settings.json")
    with open(settings_path) as f:
        settings = json.load(f)
    cs = settings.get("colorSchemes", {})
    use_wallpaper = cs.get("useWallpaperColors", True)
    current_name = cs.get("predefinedScheme", "")
    schemes = list_schemes()

    if not schemes:
        print(json.dumps({"applied": "wallpaper"}))
        sys.exit(0)

    if use_wallpaper or not current_name or current_name not in schemes:
        # Switch to first scheme
        next_name = schemes[0]
    else:
        idx = schemes.index(current_name)
        if idx < len(schemes) - 1:
            # Next scheme
            next_name = schemes[idx + 1]
        else:
            # Last scheme → switch to wallpaper
            next_name = "wallpaper"

    if next_name == "wallpaper":
        settings["colorSchemes"]["useWallpaperColors"] = True
        settings["colorSchemes"]["predefinedScheme"] = ""
        with open(settings_path, "w") as f:
            json.dump(settings, f, indent=2)
        colors_path = os.path.join(CONFIG_DIR, "colors.json")
        if os.path.exists(colors_path):
            os.utime(colors_path, None)
        print(json.dumps({"applied": "wallpaper"}))
    else:
        scheme_path = os.path.join(SCHEMES_DIR, next_name, f"{next_name}.json")
        with open(scheme_path) as f:
            scheme = json.load(f)
        dark_mode = cs.get("darkMode", True)
        variant = scheme.get("dark" if dark_mode else "light", scheme.get("dark", {}))
        colors_path = os.path.join(CONFIG_DIR, "colors.json")
        with open(colors_path, "w") as f:
            json.dump(variant, f, indent=2)
        settings["colorSchemes"]["useWallpaperColors"] = False
        settings["colorSchemes"]["predefinedScheme"] = next_name
        with open(settings_path, "w") as f:
            json.dump(settings, f, indent=2)
        print(json.dumps({"applied": next_name}))
else:
    print(json.dumps({"error": f"unknown action: {ACTION}"}))
    sys.exit(1)
