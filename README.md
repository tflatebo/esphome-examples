# ESPHome LVGL Dashboard

A beautiful, eye-readable dashboard for ESP32-S3 displays showing time and temperature data with color-coded values and automatic nighttime dimming.

## Overview

This project implements a clean, modern dashboard on a 7-inch touchscreen display using ESPHome and LVGL. It displays:

- **Massive digital clock** - Synced via SNTP (Internet time) in warm amber color
- **Three temperature displays** - Outside, Feels-like, and Indoor
- **Color-coded temperatures** - Blue (cold) → Green (comfortable) → Red (hot)
- **Feels-like calculation** - Automatic heat index and wind chill based on weather conditions
- **Automatic nighttime dimming** - Text dims to 50% between 10pm-6am (background stays black)

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
- **Automatic Nighttime Dimming**:
  - Text opacity reduces to 50% between 10pm-6am
  - Background remains pure black for OLED-like effect
  - Smooth transitions every minute
- **Flex Layout**: CSS-like positioning for easy customization
  - No manual coordinate calculations
  - Adjustable padding and gaps
- **Optimized Update Intervals**:
  - Clock and temperatures update every 15 seconds
  - Brightness check every 1 minute

### Sensors & Calculations
- **Home Assistant Integration**: Pulls data from existing HA sensors
- **Feels-like Temperature**: Automatically calculates:
  - Heat index when ≥80°F with humidity data
  - Wind chill when ≤50°F with wind data
  - Falls back to ambient temperature otherwise
- **NaN Safety**: Displays `--°F` until sensor data is available

## Hardware Requirements

- **MCU**: ESP32-S3 with PSRAM (8MB recommended)
- **Display**: Waveshare ESP32-S3-TOUCH-LCD-7 (800x480)
  - 7-inch MIPI RGB display
  - Capacitive touch (GT911 driver - optional)
- **Power**: USB-C or appropriate power supply
- **Network**: WiFi connection for SNTP and Home Assistant

## Software Requirements

- [ESPHome](https://esphome.io/) 2025.12.3 or newer
- [Home Assistant](https://www.home-assistant.io/) (for sensor data)
- Python 3.8+ (for ESPHome)

### Home Assistant Sensors Required

Configure these entities in your Home Assistant:
- `sensor.garage_temp_sensor_air_temperature` - Outdoor temperature (°F)
- `sensor.garage_temp_sensor_humidity` - Outdoor humidity (%)
- `sensor.kstp_wind_speed` - Wind speed (mph)
- `sensor.bedroom_temperature` - Indoor temperature (°F)

## Installation

### 1. Clone or Download

```bash
git clone <your-repo-url>
cd esphome-examples
```

### 2. Configure WiFi and Passwords

Edit [clock-with-temp.yaml](clock-with-temp.yaml) and update:

```yaml
wifi:
  ssid: "Your-WiFi-SSID"
  password: "Your-WiFi-Password"
```

### 3. Update Sensor Entities

If your Home Assistant sensor names differ, update the `entity_id` values in the `sensor:` section:

```yaml
sensor:
  - platform: homeassistant
    id: outdoor_temp
    entity_id: sensor.YOUR_OUTDOOR_TEMP_SENSOR
```

### 4. Validate Configuration

```bash
esphome config clock-with-temp.yaml
```

Expected output: `Configuration is valid!`

### 5. Build and Flash

First-time flash via USB:

```bash
esphome run clock-with-temp.yaml --device /dev/ttyACM0
```

Subsequent updates can use OTA:

```bash
esphome run clock-with-temp.yaml
```

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
- Temperature values: 96pt
- Labels (Outside/Feels like/Indoor): 24pt

To adjust sizes, modify the `font:` section and corresponding `style_definitions`.

### Nighttime Dimming

Automatic dimming occurs between 10pm-6am at 50% opacity. To customize:

```yaml
# Change hours: 10pm (22) and 6am (6)
bool is_nighttime = (hour >= 22 || hour < 6);

# Change dimming level (0-255):
# 127 = 50%, 77 = 30%, 178 = 70%
uint8_t opacity = is_nighttime ? 127 : 255;
```

### Temperature Display Spacing

Uses flex layout with CSS-like padding:

```yaml
pad_column: 40  # Horizontal spacing between columns
pad_row: 10     # Vertical spacing within columns
```

### Color Temperature Ranges

Edit the interpolation ranges in the interval lambda to customize color transitions:

```yaml
if (v <= 0.0) { r = 0; g = 120; b = 255; }  // Very cold
# ... modify ranges as desired
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
├── status.md              # Development notes and handoff
├── README.md              # This file
├── fonts/
│   └── Montserrat-Bold.ttf  # Custom font for large text (216pt, 96pt, 24pt)
└── config/                # ESPHome config directory
```

## Troubleshooting

### Display Shows `--°F`

**Cause**: Home Assistant sensors not connected or returning NaN.

**Fix**:
1. Check ESPHome logs: `esphome logs clock-with-temp.yaml`
2. Look for `States: outdoor=...` debug lines
3. Verify HA API connection and sensor entity IDs

### WiFi Won't Connect

**Fix**:
1. Verify SSID and password in `clock-with-temp.yaml`
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
1. Verify time is syncing: check logs for "Time synchronized"
2. Ensure timezone is set correctly
3. Look for `brightness:` log entries showing hour and opacity values

## Customization Ideas

### Adjust Dimming Schedule

Modify the nighttime hours or dimming percentage in the auto-dimming interval lambda.

### Add More Sensors

Add additional `homeassistant` platform sensors and display them with new LVGL labels using flex layout.

### Enable Touchscreen

Configure the GT911 touch driver in [clock-with-temp.yaml](clock-with-temp.yaml), then add LVGL button widgets for interaction.

### Multiple Pages

Add LVGL pages for graphs, weather forecasts, or other data using `lvgl.pages`.

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

- **Firmware Size**: ~1.3-1.5 MB (larger fonts increase size)
- **PSRAM Usage**: 8MB detected and used for LVGL framebuffers
- **Update Cycle**: 15 seconds for clock and temperature data, 1 minute for brightness
- **Build Time**: First build ~5-8 minutes (large font generation), subsequent builds ~45-90 seconds

## Technical Highlights

- **Flex Layout**: Modern CSS-like positioning eliminates manual coordinate calculations
- **Software Dimming**: LVGL opacity control provides smooth nighttime dimming without hardware modifications
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
- Adding touchscreen support and UI controls
- Implementing multiple display pages
- Creating weather forecast integrations
- Adding graphs for temperature trends
- Implementing adaptive brightness based on ambient light sensor

---

Built with ESPHome 2025.12.3 | Last updated: 2025-12-30
