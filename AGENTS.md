# Notes for coding agents

ESPHome firmware for one Waveshare ESP32-S3-Touch-LCD-7 display in the house. Read
`README.md` first: setup, configuration, how it works, lessons learned. These are the
rules that matter most when changing it.

## Rules

- **One config file:** `clock-with-temp.yaml`. Tunables (timeouts, dimming schedule,
  refresh interval) are `substitutions:` at the top; change those rather than code.
- **The color scale lives in `temperature_color.h`** and is mirrored in
  `custom_templates/displays.jinja` in the `homeassistant-config` repo. Change both
  together.
- **Every label that should dim** needs an `id` and an entry in the `Text Brightness`
  sensor's `on_value` label list.
- **Home Assistant entities** the device reads (`sensor.display_*`, the sun sensors,
  the weather entity) are defined in `packages/displays.yaml` in `homeassistant-config`.
  Don't rename them here without changing them there.
- **Flash is ~83% full** (mostly fonts). Report the new figure after any font or size
  change.
- **Don't commit `secrets.yaml`** (gitignored). New secrets go in
  `secrets.yaml.example` with placeholder values.
- **Validated with ESPHome 2025.12.3.** Don't change component syntax for a newer
  version without saying so.

## Before handing back a change

1. Run `tools/check_config.sh --compile` and get `OK: configuration is valid.` and
   `OK: compiled.` with the flash percentage. It uses `secrets.yaml.example` when
   there's no `secrets.yaml`.
2. For lambda changes you can't exercise on a device, test the logic separately (e.g.
   replicate the C++ or the integer math in a small script) and say what you tested.
3. Tell the user how to flash it (README → "Build and Flash"; over the air by IP:
   `esphome run clock-with-temp.yaml --device <ip>`) and what to check on the screen
   and in `esphome logs` (tags `dashboard`, `brightness`, `weather`).

## Environment notes

- The device is on the IoT VLAN and flashed by the user over the air by IP; agents
  normally can't reach it. Ask the user for logs instead of guessing.
- Related repos: `homeassistant-config` (the HA side: sensors, forecast, dashboard),
  `pixel-clock` (the other display, a TC001).
