# ESPHome LVGL Dashboard — Status and Handoff

Last updated: 2026-11-14

Handoff notes for the LVGL dashboard on a Waveshare ESP32-S3-Touch-LCD-7. Read this, then [clock-with-temp.yaml](clock-with-temp.yaml), before changing anything. User-facing setup is in [README.md](README.md).

## Current Status

**Working on the device**, validated on 2026-11-14 with ESPHome 2025.12.3:
- Main screen: clock plus outside, feels-like, and indoor temperatures, color-coded
- Today and next-3-days forecast pages, with color-coded high/low
- Swipe left/right (and tap) navigation, returning home after 90 s idle
- Sun-based text dimming with a morning ramp, reported to Home Assistant as `Text Brightness`
- Firmware about 1.52 MB, 82.8% of the 1.8 MB app partition. Fonts are most of it, so check flash headroom before adding fonts.

## Files

| File | Purpose |
|---|---|
| `clock-with-temp.yaml` | The whole ESPHome config |
| `temperature_color.h` | `temperature_color()` (°F → 0xRRGGBB) and `temperature_markup()` (LVGL recolor markup), pulled in with `esphome: includes:` |
| `fonts/Montserrat-Bold.ttf` | Font used at 216/96/64/48/36/24pt |
| `secrets.yaml.example` | Template for `secrets.yaml` (Wi-Fi, AP, HA entity IDs). `secrets.yaml` is gitignored |
| `test.yaml` | Old minimal config, not used |

Home Assistant side: `templates.yaml` in the `homeassistant-config` repo defines the `sensor.display_*` entities this device reads.

## Hardware

- ESP32-S3 (`esp32s3box` board), 8 MB octal PSRAM, ESP-IDF framework
- Display: `mipi_rgb` model `ESP32-S3-TOUCH-LCD-7-800X480`. The preset drives backlight/enable through CH422G EXIO2 and EXIO6
- I2C `bus_a`: SDA 8, SCL 9 (CH422G and GT911)
- GT911 touch: interrupt on GPIO4, reset on CH422G EXIO1
- Backlight is on/off only, so "brightness" is LVGL text opacity on a black background
- PWR/DONE LEDs are hardware-controlled and can't be dimmed

## How It Works

### Data from Home Assistant
| ESPHome id | HA entity | Notes |
|---|---|---|
| `outdoor_temp` | `!secret ha_outdoor_temp` | °F |
| `indoor_temp` | `!secret ha_indoor_temp` | °F |
| `feels_like_temp` | `!secret ha_feels_like_temp` | Calculated in HA (heat index / wind chill) |
| `minutes_since_sunset` | `sensor.display_minutes_since_sunset` | `-1` while the sun is up |
| `minutes_until_sunrise` | `sensor.display_minutes_until_sunrise` | `-1` while the sun is up |
| forecast | `!secret ha_weather` via `weather.get_forecasts` | Needs the action permission (below) |

Both sun sensors are recalculated every minute from `sun.sun` (`next_setting − 1 day`, `next_rising`), so they're correct whenever the device connects. They don't depend on catching a sunset event.

### Pages and navigation
- `lvgl.pages`: `main_page`, `today_page`, `next_days_page`, with `page_wrap: true`
- `lvgl.top_layer` holds one transparent full-screen `obj` with `on_click` / `on_swipe_left` → `next_display_page`, and `on_swipe_right` → `previous_display_page`
  - It needs `gesture_bubble: false` (or LVGL passes swipes to the parent and the handlers never fire) and `scrollable: false`
- The scripts debounce navigation (300 ms), track `active_page`, and call `lv_indev_wait_release()` so the click LVGL sends after a swipe doesn't advance again
- A 1 s interval returns to `main_page` after `screen_timeout_seconds` without touch

### Forecast (`update_weather_forecast` script)
- Runs on API client connect, on SNTP sync, every `forecast_refresh_interval` (30 min), and from the `Refresh Forecast` button
- `homeassistant.action` with `capture_response: true`. Accepts responses with or without a top-level `"response"` wrapper, and uses the first entry that contains a `forecast` array
- Today = the entry whose date (first 10 chars of `datetime`) matches the device's local date; the next three later dates fill the columns
- Precipitation: `precipitation_probability` if present, else `precipitation` shown as inches. Met.no (`weather.forecast_home`) only provides the amount
- `on_error` logs a warning; the raw response is logged at DEBUG

### Temperature colors
- `temperature_color()` in `temperature_color.h` is the only copy of the color scale: ≤0 blue, 0–32 blue gradient, 32–72 → green, 72–90 → red, ≥90 red, NaN white
- Main screen: `lv_obj_set_style_text_color(..., lv_color_hex(temperature_color(v)))`
- Forecast high/low labels hold two numbers, so they use `temperature_markup()` and `recolor: true`

### Brightness (`text_brightness` template sensor)
- Exposed to HA as `Text Brightness` (%). Updates every minute, and immediately when either sun sensor changes (`component.update`)
- Evening: `night_start_brightness` minus `night_brightness_step` per full hour since sunset, floored at `night_min_brightness`
- Morning: when minutes until sunrise is under `morning_ramp_minutes`, step from the night level to 100% every `morning_step_minutes`
- Day, or no data: 100%
- `on_value` applies opacity to every label in one list. **A new label must get an `id` and be added to that list**, or it won't dim

Default schedule (substitutions): 80% at sunset → 70 → 60 → 50% floor; 60 min before sunrise → 62 → 75 → 87 → 100% at sunrise.

## Build / Flash / Debug

```bash
esphome config clock-with-temp.yaml                       # validate
esphome compile clock-with-temp.yaml                      # build only
esphome run clock-with-temp.yaml --device /dev/cu.usbmodemXXXX   # USB (first flash / recovery)
esphome run clock-with-temp.yaml --device <device-ip>     # OTA
esphome logs clock-with-temp.yaml --device <device-ip>    # logs over the API
```

- Use the device IP for OTA and logs. `esp32.local` has resolved to the wrong address before
- USB recovery: hold BOOT, tap RST, release BOOT, then flash
- Useful log tags: `dashboard` (temperatures every 15 s), `brightness` (since sunset / until sunrise / %), `weather` (forecast results)
- `lvgl took a long time` warnings (~150–240 ms) are expected and harmless

## Gotchas Learned the Hard Way

1. **Action permission**: forecasts need "Allow the device to perform Home Assistant actions" on the device in HA. Without it, HA drops the call silently, so neither `on_success` nor `on_error` runs. Deleting and re-adding the device resets the setting.
2. **Different subnets**: the display is on the IoT VLAN, so HA can't discover it over mDNS. Add it by IP (port 6053) and keep a DHCP reservation. An IP change after OTA showed up as `nan` temperatures.
3. **`nan` in the `brightness` log** means HA doesn't have that sun sensor. Install the current `templates.yaml` and reload template entities.
4. **Flex centering**: a `width: 100%` flex row with percentage-width children packed to the left despite `flex_align_main: CENTER`. The fix was fixed-px children (250) in a `SIZE_CONTENT` row aligned `CENTER`.
5. **Swipes**: LVGL objects bubble gestures to the parent by default (see Pages and navigation).

## Ideas / Next Steps

- Weather icons on the forecast pages
- Show wind/humidity on the today page
- On-device sunrise/sunset via ESPHome's `sun` component (needs lat/long in secrets) to remove the HA template dependency
- Restrict font glyph sets to reclaim flash if more fonts are needed
