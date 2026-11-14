# ESPHome LVGL Dashboard

A beautiful, eye-readable dashboard for ESP32-S3 displays showing time and temperature data with color-coded values and automatic nighttime dimming.

## Overview

This project implements a touchscreen dashboard on a 7-inch display using ESPHome and LVGL. It displays:

- **Home screen** - Clock plus outside, feels-like, and indoor temperatures
- **Today's forecast** - Condition, color-coded high/low, and precipitation (chance, or amount when the weather source has no chance)
- **Next three days** - Daily condition, color-coded high/low, and precipitation
- **Touch navigation** - Swipe left/right (or tap) between screens; returns home after 90 seconds
- **Color-coded temperatures** - Blue (cold) → Green (comfortable) → Red (hot)
- **Home Assistant data aliases** - Uses the generic `sensor.display_*` entities configured for the TC001
- **Sun-based dimming** - Starts at 80% at sunset, drops 10 percentage points hourly to 50%, then steps back up to 100% over the hour before sunrise
- **Brightness in Home Assistant** - The current text brightness is reported as a `Text Brightness` sensor on the device page

![Dashboard Layout](https://img.shields.io/badge/Layout-800x480-blue) ![ESPHome](https://img.shields.io/badge/ESPHome-2025.12.3-green)

## Features

### Display Elements
- **Time Display**: Extra-large 216pt warm amber font at the top showing HH:MM format in US/Central timezone
  - Optimized for nighttime viewing with minimal blue light
- **Temperature Grid**: Three columns using flex layout showing outdoor, feels-like, and indoor temperatures
  - Values displayed as whole numbers (no decimals) in 96pt font
  - Labels in 24pt font
- **Smart Color Coding**:
  - ≤0°F: Bright blue (very cold)
  - 0-32°F: Blue gradient (freezing)
  - 32-72°F: Blue to green gradient (comfortable)
  - 72-90°F: Green to red gradient (warm)
  - ≥90°F: Bright red (very hot)

### Advanced Features
- **Sun-based dimming**:
  - Text opacity starts at 80% at sunset and steps down 10 percentage points each hour to 50%
  - Over the 60 minutes before sunrise it steps back up every 15 minutes (50% → 62% → 75% → 87%), reaching 100% at sunrise
  - The background remains black; dimming is applied to text
  - Computed by the `Text Brightness` template sensor every minute and immediately whenever Home Assistant sends new sunrise/sunset values, so it is correct right after a reboot at night
- **Automatic home-screen return**: Touch interaction resets the 90-second inactivity timer
- **Configurable intervals and dimming**: Adjust refresh, timeout, and brightness values in one `substitutions` block
- **Flex Layout**: CSS-like positioning for easy customization
  - No manual coordinate calculations
  - Adjustable padding and gaps
- **Optimized Update Intervals**:
  - Clock and temperatures update every 15 seconds
  - Forecast refreshes every 30 minutes
  - Brightness recalculated every minute (and on new sun data)

### Sensors & Calculations
- **Home Assistant Integration**: Pulls data from existing HA sensors
- **Feels-like Temperature**: Reads `sensor.display_feels_like_temperature`, calculated centrally in Home Assistant
- **Weather Forecast**: Requests daily forecasts from `weather.forecast_home`; a `Refresh Forecast` button on the device page requests one immediately
- **Shared color scale**: `temperature_color.h` maps °F to a color for both the main screen and the forecast pages
- **NaN Safety**: Displays `--°F` until sensor data is available

## Hardware Requirements

- **MCU**: ESP32-S3 with PSRAM (8MB recommended)
- **Display**: Waveshare ESP32-S3-TOUCH-LCD-7 (800x480)
  - 7-inch MIPI RGB display with GT911 capacitive touch
- **Power**: USB-C or appropriate power supply
- **Network**: WiFi connection for SNTP and Home Assistant

## Software Requirements

- [ESPHome](https://esphome.io/) 2025.12.3 or newer
- [Home Assistant](https://www.home-assistant.io/) (for sensor data)
- Python 3.8+ (for ESPHome)

### Home Assistant Sensors Required

The example uses the generic entities from the TC001 Home Assistant setup (`templates.yaml` in the `homeassistant-config` repo). Besides the temperature aliases, dimming needs two template sensors derived from `sun.sun`:

| Entity | Value |
|---|---|
| `sensor.display_minutes_since_sunset` | Minutes since sunset while the sun is down, `-1` otherwise |
| `sensor.display_minutes_until_sunrise` | Minutes until sunrise while the sun is down, `-1` otherwise |

Configure the temperature aliases and weather entity in `secrets.yaml` (see Installation step 2).

## Installation

### 1. Clone or Download

```bash
git clone <your-repo-url>
cd esphome-examples
```

### 2. Configure Secrets File

Copy the example secrets file and edit it with your credentials:

```bash
cp secrets.yaml.example secrets.yaml
```

Edit `secrets.yaml` with your actual values:

```yaml
# WiFi Configuration
wifi_ssid: "Your-WiFi-SSID"
wifi_password: "Your-WiFi-Password"

# Fallback Access Point
ap_ssid: "ESP32-Fallback"
ap_password: "YourFallbackPassword"

# Generic Home Assistant display entities
ha_outdoor_temp: "sensor.display_outdoor_temperature"
ha_indoor_temp: "sensor.display_indoor_temperature"
ha_feels_like_temp: "sensor.display_feels_like_temperature"
ha_weather: "weather.forecast_home"
```

**Important**: The `secrets.yaml` file is excluded from git to protect your credentials. Never commit it to version control.

The Home Assistant ESPHome device entry must be allowed to perform Home Assistant actions so the ESP32 can call `weather.get_forecasts`: **Settings → Devices & Services → ESPHome → (device) → Configure → "Allow the device to perform Home Assistant actions"**. This setting resets if the device is deleted and re-added.

If Home Assistant and the display are on different subnets/VLANs, mDNS discovery won't find the device. Add it manually by IP (port 6053) and give it a DHCP reservation so the address doesn't change.

### 3. Validate Configuration

```bash
esphome config clock-with-temp.yaml
```

Expected output: `Configuration is valid!`

### 4. Build and Flash

First-time flash via USB:

```bash
esphome run clock-with-temp.yaml --device /dev/ttyACM0
```

Subsequent updates can use OTA. Prefer the device's IP over `esp32.local`, which can resolve to a different device:

```bash
esphome run clock-with-temp.yaml --device <device-ip>
```

`temperature_color.h` must sit next to `clock-with-temp.yaml`; it is pulled in with `esphome: includes:`.

## Configuration

### Timezone

Default is US Central Time (`America/Chicago`). To change:

```yaml
time:
  - platform: sntp
    id: sntp_time
    timezone: "America/New_York"  # Or your timezone
```

See [TZ database](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) for timezone strings.

### Update Intervals

Clock and temperatures refresh every 15 seconds:

```yaml
interval:
  - interval: 15s  # Change to 5s, 30s, 60s, etc.
```

### Font Sizes

The dashboard uses custom Montserrat Bold fonts:
- Clock: 216pt (extra large for across-the-room visibility)
- Temperature values and today's forecast high/low: 96pt
- Next-3-days high/low: 64pt
- Page titles and today's condition: 48pt
- Next-3-days dates: 36pt
- Labels, conditions, and precipitation: 24pt

To adjust sizes, modify the `font:` section and corresponding `style_definitions`.

### Sun-Based Dimming and Screen Timing

Edit the `substitutions` at the top of `clock-with-temp.yaml`:

```yaml
forecast_refresh_interval: 30min
screen_timeout_seconds: "90"
night_start_brightness: "80"
night_brightness_step: "10"
night_min_brightness: "50"
morning_ramp_minutes: "60"   # start brightening this long before sunrise
morning_step_minutes: "15"   # step size; should divide morning_ramp_minutes evenly
```

Brightness is text opacity on the black background. Home Assistant supplies minutes since sunset and minutes until sunrise (both `-1` while the sun is up). The `Text Brightness` sensor applies the evening steps, then during the morning ramp steps from the night level to 100% in equal increments, never going darker than the evening schedule.

### Temperature Display Spacing

Uses flex layout with CSS-like padding:

```yaml
pad_column: 40  # Horizontal spacing between columns
pad_row: 10     # Vertical spacing within columns
```

### Color Temperature Ranges

The color scale lives in one place, `temperature_color()` in [temperature_color.h](temperature_color.h), and is used by both the main screen and the forecast pages. Forecast labels contain two temperatures, so `temperature_markup()` wraps each in LVGL recolor markup (`#rrggbb 42#`); those labels set `recolor: true`.

```cpp
if (v <= 0.0) { r = 0; g = 120; b = 255; }  // Very cold
// ... modify ranges as desired
else { r = 255; g = 40; b = 0; }  // Very hot
```

### Clock Color

Current: Warm amber (`0xFF9933`) for optimal nighttime viewing

Other nighttime-friendly options:
- Pure amber: `0xFFBF00`
- Orange: `0xFF7F00`
- Soft red: `0xCC3300`

## Project Structure

```
esphome-examples/
├── clock-with-temp.yaml    # Main ESPHome configuration
├── temperature_color.h    # Shared temperature color scale (C++ helper)
├── secrets.yaml           # Your credentials (not in git - create from .example)
├── secrets.yaml.example   # Template for secrets file
├── status.md              # Development notes and handoff
├── README.md              # This file
├── .gitignore             # Excludes secrets.yaml from version control
├── LICENSE                # MIT License
├── fonts/
│   └── Montserrat-Bold.ttf  # Custom font for 216/96/64/48/36/24pt text
└── config/                # ESPHome config directory
```

## Troubleshooting

### Display Shows `--°F`

**Cause**: Home Assistant sensors not connected or returning NaN.

**Fix**:
1. Check ESPHome logs: `esphome logs clock-with-temp.yaml`
2. Look for `dashboard` temperature logs
3. Verify HA API connection and sensor entity IDs

### Build Fails - Missing Secrets File

**Cause**: `secrets.yaml` file not found or not configured.

**Fix**:
1. Copy the template: `cp secrets.yaml.example secrets.yaml`
2. Edit `secrets.yaml` with your actual credentials
3. Ensure the file is in the same directory as `clock-with-temp.yaml`

### WiFi Won't Connect

**Fix**:
1. Verify SSID and password in `secrets.yaml`
2. Check serial output: `esphome logs clock-with-temp.yaml --device /dev/ttyACM0`
3. Ensure 2.4GHz WiFi (ESP32 doesn't support 5GHz)

### LVGL Long Operation Warnings

**Cause**: Complex lambdas taking >10ms to execute.

**Fix**: These warnings are generally harmless. If UI stutters, consider:
- Increasing update interval to 30s or 60s
- Simplifying color calculation logic

### Build Fails - PSRAM Error

**Fix**: Ensure PSRAM is enabled in [clock-with-temp.yaml](clock-with-temp.yaml):

```yaml
psram:
  mode: octal
  speed: 80MHZ
```

### Out of Memory During Build

**Fix**: The firmware uses large custom fonts. Ensure your ESP32-S3 has sufficient flash (4MB+). Consider:
- Reducing font sizes
- Decreasing LVGL buffer size (currently 40%)

### Nighttime Dimming Not Working

**Fix**:
1. Check the `brightness` log line: `Since sunset: … min, until sunrise: … min, brightness: …%`
2. `nan` for either value means Home Assistant doesn't have that sensor. Install the current `templates.yaml` and reload template entities
3. Compare with the `Text Brightness` sensor history in Home Assistant

### Forecast Pages Stay Empty

**Fix**:
1. Enable "Allow the device to perform Home Assistant actions" on the device in Home Assistant
2. Press `Refresh Forecast` and look for `weather` log lines. `weather.get_forecasts failed: …` gives Home Assistant's reason; no line at all usually means the action permission is off
3. Confirm the entity works in **Developer Tools → Actions** with `weather.get_forecasts`, `type: daily`
4. For the raw response, set `logger: level: DEBUG`

### Temperatures Show `nan` After an OTA Update

**Cause**: The device came back on a different IP and Home Assistant is still pointed at the old one.

**Fix**: Update the ESPHome integration entry with the new IP and add a DHCP reservation.

## Customization Ideas

### Adjust Dimming Schedule

Change the `night_*` and `morning_*` values in `substitutions`.

### Add More Sensors

Add additional `homeassistant` platform sensors and display them with new LVGL labels using flex layout.

### Touchscreen Navigation

The GT911 touchscreen is configured in [clock-with-temp.yaml](clock-with-temp.yaml) with its interrupt (GPIO4) and reset (CH422G EXIO1) pins. A single transparent object on LVGL's `top_layer` handles navigation for all pages: swipe left or tap to advance, swipe right to go back. It has `gesture_bubble: false`, without which LVGL sends swipes to the parent and the handlers never fire. After a swipe, the navigation scripts call `lv_indev_wait_release()` so the click on release doesn't advance a second page. After the configured inactivity timeout, the display returns to the home screen.

### Forecast Source

Change `ha_weather` in `secrets.yaml` to another Home Assistant weather entity that provides daily forecasts. The forecast screen shows the current day's entry and the next three later dates returned by `weather.get_forecasts`.

### Different Fonts

Replace `fonts/Montserrat-Bold.ttf` with any TTF font, or download additional weights from [Google Fonts](https://fonts.google.com/).

## Development Commands

```bash
# Validate configuration
esphome config clock-with-temp.yaml

# Build firmware (no flash)
esphome compile clock-with-temp.yaml

# Build and flash via USB
esphome run clock-with-temp.yaml --device /dev/ttyACM0

# View logs
esphome logs clock-with-temp.yaml

# Clean build files
esphome clean clock-with-temp.yaml
```

## Performance Notes

- **Firmware Size**: ~1.52 MB, about 83% of the 1.8 MB app partition (fonts are most of it)
- **PSRAM Usage**: 8MB detected and used for LVGL framebuffers
- **Update Cycle**: 15 seconds for clock and temperature data, 30 minutes for forecasts (plus on connect and on demand), 1 minute for brightness (plus on new sun data)
- **Build Time**: First build ~5-8 minutes (large font generation), subsequent builds ~45-90 seconds

## Technical Highlights

- **Flex Layout**: Modern CSS-like positioning eliminates manual coordinate calculations
- **Software Dimming**: LVGL text opacity follows Home Assistant's sun state without hardware modifications
- **Optimized Updates**: Separate intervals for time, temperature, and brightness checks
- **Color Accuracy**: Temperature color-coding maintained during dimming via text opacity
- **Simplified Code**: Removed duplicate heat index calculations and unused widgets

## License

This project uses:
- **ESPHome**: MIT License
- **LVGL**: MIT License
- **Montserrat Font**: SIL Open Font License 1.1

## Acknowledgments

- **Font**: [Montserrat](https://github.com/JulietaUla/Montserrat) by Julieta Ulanovsky
- **Framework**: [ESPHome](https://esphome.io/) by the ESPHome team
- **Graphics**: [LVGL](https://lvgl.io/) embedded graphics library

## Support

For issues or questions:
1. Check [ESPHome Documentation](https://esphome.io/)
2. Review [status.md](status.md) for detailed implementation notes
3. Consult [LVGL Documentation](https://docs.lvgl.io/)

## Contributing

Improvements welcome! Consider:
- Adding weather icons to the forecast pages
- Adding graphs for temperature trends
- Implementing adaptive brightness based on ambient light sensor

---

Built with ESPHome 2025.12.3 | Last updated: 2026-11-14
