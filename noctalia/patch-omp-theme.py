#!/usr/bin/env python3
"""
Patch Oh My Posh theme colors from Noctalia color scheme.

Reads OMP colors from a predefined scheme JSON and patches atomic.omp.json
with the colors for the active mode (dark/light).

Usage:
    python3 patch-omp-theme.py --scheme <scheme.json> --mode <dark|light> [--output <atomic.omp.json>]
"""
import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

LOG_FILE = Path.home() / ".cache" / "noctalia" / "omp-patch.log"

DEFAULT_OUTPUT = Path.home() / ".cache" / "oh-my-posh" / "themes" / "atomic.omp.json"
DEFAULT_SCHEME = Path.home() / ".cache" / "noctalia" / "predefined-scheme.json"
SETTINGS_FILE = Path.home() / ".config" / "noctalia" / "settings.json"
COLORSCHEMES_DIR = Path.home() / ".config" / "noctalia" / "colorschemes"
BUILTIN_SCHEMES_DIR = Path("/etc/xdg/quickshell/noctalia-shell/Assets/ColorScheme")

# Map OMP segment types to scheme keys
SEGMENT_MAP = {
    "shell":          ("omp_shell_bg",          "omp_shell_fg"),
    "root":           ("omp_root_bg",           "omp_root_fg"),
    "path":           ("omp_path_bg",           "omp_path_fg"),
    "git":            ("omp_git_bg",            "omp_git_fg"),
    "executiontime":  ("omp_executiontime_bg",  "omp_executiontime_fg"),
    "node":           ("omp_node_bg",           "omp_node_fg"),
    "python":         ("omp_python_bg",         "omp_python_fg"),
    "java":           ("omp_java_bg",           "omp_java_fg"),
    "dotnet":         ("omp_dotnet_bg",         "omp_dotnet_fg"),
    "go":             ("omp_go_bg",             "omp_go_fg"),
    "rust":           ("omp_rust_bg",           "omp_rust_fg"),
    "dart":           ("omp_dart_bg",           "omp_dart_fg"),
    "angular":        ("omp_angular_bg",        "omp_angular_fg"),
    "aurelia":        ("omp_aurelia_bg",        "omp_aurelia_fg"),
    "nx":             ("omp_nx_bg",             "omp_nx_fg"),
    "julia":          ("omp_julia_bg",          "omp_julia_fg"),
    "ruby":           ("omp_ruby_bg",           "omp_ruby_fg"),
    "azfunc":         ("omp_azfunc_bg",         "omp_azfunc_fg"),
    "aws":            ("omp_aws_bg",            "omp_aws_fg"),
    "kubectl":        ("omp_kubectl_bg",        "omp_kubectl_fg"),
    "os":             ("omp_os_bg",             "omp_os_fg"),
    "battery":        ("omp_battery_bg",        "omp_battery_fg"),
    "time":           ("omp_time_bg",           "omp_time_fg"),
    "status":         (None,                    "omp_status_fg"),
}

# Fixed brand colors for language/tech segments.
BRAND_DEFAULTS = {
    "omp_node_bg":           "#303030",
    "omp_node_fg":           "#3C873A",
    "omp_python_bg":         "#306998",
    "omp_python_fg":         "#FFE873",
    "omp_java_bg":           "#0e8ac8",
    "omp_java_fg":           "#ffffff",
    "omp_dotnet_bg":         "#0e0e0e",
    "omp_dotnet_fg":         "#0d6da8",
    "omp_go_bg":             "#ffffff",
    "omp_go_fg":             "#06aad5",
    "omp_rust_bg":           "#f3f0ec",
    "omp_rust_fg":           "#925837",
    "omp_dart_bg":           "#e1e8e9",
    "omp_dart_fg":           "#055b9c",
    "omp_angular_bg":        "#ffffff",
    "omp_angular_fg":        "#ce092f",
    "omp_aurelia_bg":        "#ffffff",
    "omp_aurelia_fg":        "#de1f84",
    "omp_nx_bg":             "#1e293b",
    "omp_nx_fg":             "#ffffff",
    "omp_julia_bg":          "#945bb3",
    "omp_julia_fg":          "#359a25",
    "omp_ruby_bg":           "#ffffff",
    "omp_ruby_fg":           "#9c1006",
    "omp_azfunc_bg":         "#ffffff",
    "omp_azfunc_fg":         "#5398c2",
    "omp_aws_bg":            "#565656",
    "omp_aws_fg":            "#faa029",
    "omp_kubectl_bg":        "#316ce4",
    "omp_kubectl_fg":        "#ffffff",
    "omp_battery_bg":        "#f36943",
    "omp_battery_fg":        "#262626",
}

# MD3-derived defaults for segments that should adapt to the theme.
MD3_FALLBACK_KEYS = {
    "omp_shell_bg":   "mPrimary",
    "omp_shell_fg":   "mOnPrimary",
    "omp_root_bg":    "mError",
    "omp_root_fg":    "mOnError",
    "omp_path_bg":    "mTertiary",
    "omp_path_fg":    "mOnTertiary",
    "omp_git_bg":     "mSurfaceVariant",
    "omp_git_fg":     "mOnSurface",
    "omp_executiontime_bg": "mSurfaceVariant",
    "omp_executiontime_fg": "mOnSurface",
    "omp_os_bg":      "mSurfaceVariant",
    "omp_os_fg":      "mOnSurface",
    "omp_time_bg":    "mSecondary",
    "omp_time_fg":    "mOnSecondary",
    "omp_status_fg":  "mPrimary",
}


def get_default_color(key: str, variant: dict) -> str | None:
    """Return a default color for an OMP key.

    Priority:
    1. Scheme override if present
    2. MD3-derived fallback if available
    3. Fixed brand/default color
    """
    if key in variant and variant[key] and variant[key].startswith("#"):
        return variant[key]
    md3_key = MD3_FALLBACK_KEYS.get(key)
    if md3_key and md3_key in variant and variant[md3_key] and variant[md3_key].startswith("#"):
        return variant[md3_key]
    return BRAND_DEFAULTS.get(key)


def log(message: str):
    """Append a line to the OMP patch log."""
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG_FILE, "a") as f:
            f.write(f"[{datetime.now().isoformat()}] {message}\n")
    except Exception:
        pass


def patch_theme(scheme_path: Path, mode: str, output_path: Path) -> bool:
    """Patch atomic.omp.json with OMP colors from scheme."""
    log(f"START scheme={scheme_path} mode={mode} output={output_path}")
    # Read scheme
    try:
        with open(scheme_path) as f:
            scheme = json.load(f)
    except Exception as e:
        log(f"ERROR reading scheme: {e}")
        print(f"Error reading scheme: {e}", file=sys.stderr)
        return False

    # Get mode variant
    variant = scheme.get(mode, scheme.get("dark", {}))

    # Read OMP theme
    try:
        with open(output_path) as f:
            theme = json.load(f)
    except Exception as e:
        print(f"Error reading OMP theme: {e}", file=sys.stderr)
        return False

    # Determine effective color: scheme override, else MD3 fallback, else brand default

    # Patch segments
    patched = 0
    for block in theme.get("blocks", []):
        for segment in block.get("segments", []):
            seg_type = segment.get("type", "")
            if seg_type not in SEGMENT_MAP:
                continue

            bg_key, fg_key = SEGMENT_MAP[seg_type]

            # Patch background
            if bg_key:
                bg_color = get_default_color(bg_key, variant)
                if bg_color:
                    segment["background"] = bg_color
                    patched += 1

            # Patch foreground
            if fg_key:
                fg_color = get_default_color(fg_key, variant)
                if fg_color:
                    segment["foreground"] = fg_color
                    patched += 1

    if patched == 0:
        log("WARNING no patchable OMP segments found")
        print("No patchable OMP segments found", file=sys.stderr)
        return False

    # Write patched theme
    try:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w") as f:
            json.dump(theme, f, indent=2)
        log(f"OK patched={patched}")
        print(f"Patched {patched} colors in {output_path}")
        return True
    except Exception as e:
        log(f"ERROR writing OMP theme: {e}")
        print(f"Error writing OMP theme: {e}", file=sys.stderr)
        return False


def read_settings() -> dict:
    """Read Noctalia settings."""
    try:
        with open(SETTINGS_FILE) as f:
            return json.load(f)
    except Exception:
        return {}


def detect_mode(settings: dict | None = None) -> str:
    """Detect active mode from Noctalia settings."""
    if settings is None:
        settings = read_settings()
    dark = settings.get("colorSchemes", {}).get("darkMode", True)
    return "dark" if dark else "light"


def detect_scheme_path(settings: dict | None = None) -> Path | None:
    """Detect active scheme path from Noctalia settings.

    Checks user colorschemes dir first, then built-in schemes dir.
    """
    if settings is None:
        settings = read_settings()
    name = settings.get("colorSchemes", {}).get("predefinedScheme", "")
    if not name:
        return None

    # User schemes
    user_path = COLORSCHEMES_DIR / name / f"{name}.json"
    if user_path.exists():
        return user_path

    # Built-in schemes (may have different filename casing)
    if BUILTIN_SCHEMES_DIR.exists():
        for candidate in BUILTIN_SCHEMES_DIR.iterdir():
            if candidate.is_dir() and candidate.name.lower() == name.lower().replace(" ", ""):
                built_in = candidate / f"{candidate.name}.json"
                if built_in.exists():
                    return built_in
            built_in = BUILTIN_SCHEMES_DIR / name / f"{name}.json"
            if built_in.exists():
                return built_in

    return None


def main():
    parser = argparse.ArgumentParser(description="Patch Oh My Posh theme colors")
    parser.add_argument("--scheme", default=None, help="Path to scheme JSON (auto-detected from settings if omitted)")
    parser.add_argument("--mode", choices=["dark", "light"], default=None, help="Color mode (auto-detected if omitted)")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT), help="Path to atomic.omp.json")
    args = parser.parse_args()

    settings = read_settings()
    output_path = Path(args.output)

    # Determine scheme path
    if args.scheme:
        scheme_path = Path(args.scheme)
    else:
        scheme_path = detect_scheme_path(settings)
        if scheme_path is None:
            print("Could not detect active scheme from settings", file=sys.stderr)
            sys.exit(1)

    mode = args.mode if args.mode else detect_mode(settings)

    if not scheme_path.exists():
        log(f"ERROR scheme file not found: {scheme_path}")
        print(f"Scheme file not found: {scheme_path}", file=sys.stderr)
        sys.exit(1)

    if not output_path.exists():
        log(f"ERROR OMP theme not found: {output_path}")
        print(f"OMP theme not found: {output_path}", file=sys.stderr)
        sys.exit(1)

    success = patch_theme(scheme_path, mode, output_path)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
