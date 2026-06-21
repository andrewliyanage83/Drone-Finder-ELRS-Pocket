# Drone Finder ELRS — RadioMaster Pocket port

A lost-drone finder Lua script for EdgeTX radios. It reads the ELRS/CRSF
signal telemetry and gives Geiger-style audio feedback plus an on-screen
signal indicator that gets stronger as you get closer to the drone.

This repository is a **port of the original to the RadioMaster Pocket**
(128×64 monochrome display).

## About this fork

This is a derivative work of
[**p3gass/Drone-Finder-ELRS**](https://github.com/p3gass/Drone-Finder-ELRS),
originally by **michalek.me**. All credit for the original concept and code
goes to the upstream author. This fork only adapts it to a different radio.

## Changes from upstream

The original targets color EdgeTX radios (e.g. RadioMaster TX15) and builds
its interface with the LVGL graphics library, which is not available on
monochrome radios. This fork:

- Ports the user interface to the classic monochrome `lcd` API so it runs on
  the **RadioMaster Pocket** and other 128×64 B&W EdgeTX radios.
- Replaces the LVGL circular gauge with a **horizontal signal bar** that fills
  toward 100% as the signal gets stronger (closer to the drone).
- Leaves the telemetry reading and Geiger-style audio logic unchanged.

Ported on 2026-06-21 by Andrew Liyanage.

## Installation

1. Copy `DroneFinder-Pocket.lua` to the `SCRIPTS/TOOLS/` folder on the radio's
   SD card (create the `TOOLS` folder if it does not exist).
2. On the radio, open the **Tools** menu and run the script.
3. Press the scroll-wheel (**ENTER**) to toggle the sound on/off. Press
   **RTN** to exit.

A reading only appears while the drone is powered and the ELRS link is alive.
If the bar stays at 0% with the drone on, check that the `1RSS` / `RQly`
sensors exist in the radio's telemetry list and adjust `readSignal()` if your
sensor names differ.

## License

This program is free software, licensed under the **GNU General Public License
v3.0 (GPL-3.0)**, the same license as the original work. See the
[`LICENSE`](LICENSE) file for the full text.

- Original work: Copyright © michalek.me (p3gass/Drone-Finder-ELRS)
- Modifications (RadioMaster Pocket port): Copyright © 2026 Andrew Liyanage

This is a modified version. You may redistribute and/or modify it under the
terms of the GPL-3.0. There is no warranty, to the extent permitted by law.
