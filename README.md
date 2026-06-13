# My Noctalia Shell Setup

https://github.com/user-attachments/assets/ddad35bd-c9eb-487b-afdc-a4096de36096

<img width="1920" height="1080" alt="Screenshot 1" src="https://github.com/user-attachments/assets/27f95693-6eae-4000-98e0-351b57c66d3c" />

<img width="1920" height="1080" alt="Screenshot 2" src="https://github.com/user-attachments/assets/123ae18b-ee27-425b-ba8c-a0b33cd1c002" />

<img width="1920" height="1080" alt="Screenshot 3" src="https://github.com/user-attachments/assets/755f6b7c-58fc-40f6-962c-032b904f44f9" />

## About

A heavily customized setup for Noctalia Shell v4 (Quickshell/QML).

The goal of this configuration is to provide a cleaner and more compact desktop experience while keeping the original Noctalia aesthetic.

## Features

### advanced capsule customization
<img width="589" height="713" alt="Screenshot from 2026-06-12 22-19-48" src="https://github.com/user-attachments/assets/3aa8f368-0515-4fd7-9c9d-07484ca5ac81" />
<img width="346" height="858" alt="Screenshot from 2026-06-12 22-13-32" src="https://github.com/user-attachments/assets/15a9a4b9-f286-4d0e-bdd9-c12e5cdbc231" />



### Hover reveal widgets

<img width="589" height="733" alt="Screenshot from 2026-06-12 22-38-07" src="https://github.com/user-attachments/assets/a516f127-385d-48a5-a425-6c7d5de1874a" />


### Easy customization with two widgets

## Quick Config
<img width="342" height="716" alt="Screenshot from 2026-06-12 22-25-58" src="https://github.com/user-attachments/assets/4ff329a7-21d7-4fe2-8043-c4ed93b6f8bb" />

- Niri (1-10): Blur Global, Blur Window, Square Corners, Focus Ring, Niri Shadow, Sync Radius, Sync Shadow, Rainbow Ring, Ring Width, Noise & Sat
- Noctalia (11-18): Widgets, Filled BG, Noctalia Opacity, Kitty Glass, Snap Panels, Settings Mode, Panel Outline, No Colors
- Bar (19-25): Bar Blur, Bar Opacity, Hover Reveal, Bar Outline, Bar Type, Position, Link Dark/Light
- Widgets & Capsules (General) (26-31 + extras): Widget Outline, Capsule Outline, Group, Collapse, Fill, Widget Spacing (cicla inner padding 0→2→4→6→8→0), Content Outline, Capsule       Translucent
- Section Capsules (32-36): Opacity L, Opacity C, Opacity R, Group Spacing (2→4→6→8→10→12), Inner Spacing (0→2→4→6→8)

- It also save all the preference so it can load quickly
  
  <img width="342" height="337" alt="Screenshot from 2026-06-12 22-28-22" src="https://github.com/user-attachments/assets/abd58d86-e4e6-44b7-8d99-3b3b880cdc32" />


  
## Color scheme creator
This modified version now reads the actual color theme and the color of the terminal(Only kitty)
<img width="311" height="896" alt="Screenshot from 2026-06-12 22-27-42" src="https://github.com/user-attachments/assets/3f9bba7f-b0ee-4c0f-a4b0-6c355d99b9ce" />

## Preferences 

- Media mini widget
edited for it only show the album image

- Todo and arch updater
edited for it only show the number




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
git clone https://github.com/zaroutt/MoreNoctalia.git
cd MoreNoctalia

./install.sh
```

This will copy `noctalia/` to `~/.config/noctalia/` and `noctalia-shell/` to `/etc/xdg/quickshell/noctalia-shell/` (sudo required for the latter).


## Warnings

* This setup is provided as-is.
* Some functionality was designed specifically for my personal workflow and system configuration.
* Future Noctalia updates may introduce incompatibilities.
* Expect occasional rough edges, as much of the customization was developed experimentally.

## Credits

* Original shell: https://github.com/noctalia-dev/noctalia-shell
