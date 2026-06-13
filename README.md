# My Noctalia Shell Setup

https://github.com/user-attachments/assets/ddad35bd-c9eb-487b-afdc-a4096de36096

<img width="1920" height="1080" alt="Screenshot 1" src="https://github.com/user-attachments/assets/27f95693-6eae-4000-98e0-351b57c66d3c" />

<img width="1920" height="1080" alt="Screenshot 2" src="https://github.com/user-attachments/assets/123ae18b-ee27-425b-ba8c-a0b33cd1c002" />

<img width="1920" height="1080" alt="Screenshot 3" src="https://github.com/user-attachments/assets/755f6b7c-58fc-40f6-962c-032b904f44f9" />

## About

A heavily customized setup for Noctalia Shell v4 (Quickshell/QML).

The goal of this configuration is to provide a cleaner and more compact desktop experience while keeping the original Noctalia aesthetic.

## Features

### Added

* Quick Config widget 
* Hover-reveal behavior for selected elements
* More customizable capsule system\
* Panels can have outlines

### Modified

#### Color Scheme Creator

* Displays the currently active theme colors
* Shows terminal color palette previews
* Allows changing the primary theme color while automatically generating matching color variations

#### Todo Widget

* Simplified layout showing only task counts

#### Arch Updater Widget

* Simplified layout showing only update counts

#### MediaMini Widget

* Displays only album artwork for a cleaner look

### UI Changes

* Reworked panel animations
* Various adjustments related to blur and opacity effects
* Additional tweaks across multiple widgets and components to improve visual consistency

## Installation

### Option 1 — Replace only the modified files

Copy the following directories into:

```bash
/etc/xdg/quickshell/noctalia-shell
```

* modules
* widgets
* commons
* services

Then copy the configuration files to:

```bash
~/.config/noctalia
```

### Option 2 — Using the install script

Run the provided script to automatically copy all files:

```bash
cd /path/to/tentativa
./install.sh
```

This will copy `noctalia/` to `~/.config/noctalia/` and `noctalia-shell/` to `/etc/xdg/quickshell/noctalia-shell/` (sudo required for the latter).

### Option 3 — Replace the entire setup

If the partial replacement does not work, replace the entire Noctalia Shell folder with the version provided in this repository.

## Notes

All the modifications were created through AI-assisted development. As a result, some changes may not be fully documented and additional files may have been modified beyond those listed above.

The panel animation changes required adjustments to blur, opacity, and widget behavior, which may affect other parts of the shell.

## Warnings

* This setup is provided as-is.
* Some functionality was designed specifically for my personal workflow and system configuration.
* Future Noctalia updates may introduce incompatibilities.
* Expect occasional rough edges, as much of the customization was developed experimentally.

## Credits

* Original shell: https://github.com/noctalia-dev/noctalia-shell
