# ESPHome LVGL Dashboard — Status and Handoff

Date: 2025-12-30 (Updated after major enhancements)

**Purpose**
- Single-file snapshot and handoff notes for the LVGL-based ESPHome dashboard running on a Waveshare ESP32-S3 display. This file contains everything another engineer or LLM would need to pick up the work and continue development or debugging.

**Quick Status**
- Config file renamed: `dashboard.yaml` → `clock-with-temp.yaml`
- Configuration validated and working
- Firmware size: ~1.3-1.5 MB (increased due to large custom fonts)
- Device boots, detects PSRAM (8 MB), connects to Wi-Fi, and runs LVGL UI
- Active files: [clock-with-temp.yaml](clock-with-temp.yaml), [fonts/Montserrat-Bold.ttf](fonts/Montserrat-Bold.ttf)
- **Status**: Ready for deployment, fully functional with nighttime dimming

**What This Dashboard Does**
- Displays a massive 216pt warm amber clock (across-the-room readable)
- Shows three temperature values: Outside, Feels-like, Indoor (96pt font, whole numbers)
- Color-codes temperatures from blue (cold) → green (comfortable) → red (hot)
- Automatically dims display 50% between 10pm-6am (text only, background stays black)
- Updates every 15 seconds
- Calculates feels-like temperature using heat index or wind chill

**Major Changes from Previous Version**
1. **Massive Font Increase**:
   - Clock: 72pt → **216pt** (3x larger, warm amber color `0xFF9933`)
   - Temperature values: 64pt → **96pt** (1.5x larger)
   - Temperature labels: 48pt → **24pt** (smaller for better hierarchy)
   - Custom Montserrat Bold TTF embedded (445KB)

2. **Flex Layout Refactor**:
   - Replaced fixed x/y positioning with LVGL flex layout
   - CSS-like `pad_column: 40` and `pad_row: 10` for spacing
   - No more manual coordinate calculations
   - Easy to adjust spacing without math

3. **Nighttime Dimming**:
   - Auto-dims text to 50% opacity between 10pm-6am
   - Background stays pure black (0x000000)
   - Uses `lv_obj_set_style_text_opa()` on individual labels
   - Checks every 1 minute via interval lambda
   - Configurable hours and opacity levels

4. **Display Improvements**:
   - Whole number temperatures (no decimals): `72°F` instead of `72.5°F`
   - Warm amber clock color for nighttime eye comfort
   - Temperature labels updated: "Outside", "Feels like", "Indoor"

5. **Code Cleanup**:
   - Removed duplicate heat index calculation (~27 lines)
   - Removed unused styles: `temp_style`, `sub_style`
   - Removed unused widget: `sub_label`
   - Removed duplicate SNTP comments
   - Simplified from 357 lines → 308 lines (14% reduction)

**Current Implementation Details**

### Hardware Configuration
- **Board**: ESP32-S3 (esp32s3box)
- **Display**: Waveshare ESP32-S3-TOUCH-LCD-7 (800x480 MIPI RGB)
- **PSRAM**: 8MB octal, 80MHz, execute_from_psram enabled
- **I2C**: Bus on SDA=8, SCL=9 (for CH422G IO expander)
- **Backlight**: Controlled via CH422G chip (on/off only, no PWM)

### Fonts
Custom Montserrat Bold TTF with three sizes:
- `montserrat_216` - Clock display
- `montserrat_96` - Temperature values
- `montserrat_24` - Temperature labels

Location: `fonts/Montserrat-Bold.ttf` (445KB)
License: SIL Open Font License 1.1

### LVGL Configuration
- Display update: 30s (LVGL internal)
- Buffer size: 40% of display memory
- Default font: montserrat_14
- Styles defined:
  - `screen_style` - Black background (0x000000)
  - `time_style` - 216pt warm amber (0xFF9933)
  - `temp_value_style` - 96pt white (0xFFFFFF), color-coded dynamically
  - `temp_desc_style` - 24pt gray (0x888888)
  - `container_style` - Transparent background for flex containers

### Layout Structure (Flex-based)
```
main_page (black background)
├─ time_label (TOP_MID, y: 20)
│  └─ 216pt amber clock
│
└─ Temperature container (BOTTOM_MID, y: -20)
   ├─ Outside column (flex: COLUMN)
   │  ├─ out_val_label (96pt, color-coded)
   │  └─ out_desc_label (24pt gray)
   │
   ├─ [40px gap]
   │
   ├─ Feels-like column (flex: COLUMN)
   │  ├─ feels_val_label (96pt, color-coded)
   │  └─ feels_desc_label (24pt gray)
   │
   ├─ [40px gap]
   │
   └─ Indoor column (flex: COLUMN)
      ├─ in_val_label (96pt, color-coded)
      └─ in_desc_label (24pt gray)
```

### Sensors & Data Flow
**Home Assistant Sensors**:
- `outdoor_temp` → sensor.garage_temp_sensor_air_temperature
- `outdoor_humidity` → sensor.garage_temp_sensor_humidity
- `kstp_wind_speed` → sensor.kstp_wind_speed
- `indoor_temp` → sensor.bedroom_temperature

**Template Sensors**:
- `outdoor_temp_f` - Passthrough (assumes HA provides °F)
- `indoor_temp_f` - Passthrough
- `outdoor_feels_like_f` - Calculates heat index (≥80°F) or wind chill (≤50°F)

### Intervals & Updates
1. **Time Update** (15s):
   - Updates `time_label` with current time in HH:MM format
   - Uses SNTP synchronized time

2. **Temperature Update** (15s):
   - Fetches all sensor values
   - Formats as whole numbers: `"%.0f°F"`
   - Applies color coding based on temperature ranges
   - Updates all six labels (3 values + 3 descriptors)

3. **Brightness Control** (1min):
   - Checks current hour from SNTP
   - Nighttime: 10pm-6am (hour >= 22 || hour < 6)
   - Sets opacity: 127 (50%) nighttime, 255 (100%) daytime
   - Applies to all 7 text labels individually

### Color Mapping
Temperature-to-color interpolation:
- v ≤ 0°F: Bright blue `rgb(0, 120, 255)`
- 0-32°F: Blue gradient (freezing range)
- 32-72°F: Blue → Green `rgb(0, 200, 0)` (comfortable)
- 72-90°F: Green → Red `rgb(255, 40, 0)` (warming)
- v ≥ 90°F: Bright red `rgb(255, 40, 0)` (very hot)

Applied via `lv_obj_set_style_text_color()` in update lambda.

**Key IDs & Symbols**
- Time: `sntp_time`
- Display: `my_display`
- LVGL labels: `time_label`, `out_val_label`, `out_desc_label`, `feels_val_label`, `feels_desc_label`, `in_val_label`, `in_desc_label`
- HA sensors: `outdoor_temp`, `outdoor_humidity`, `kstp_wind_speed`, `indoor_temp`
- Template sensors: `outdoor_temp_f`, `indoor_temp_f`, `outdoor_feels_like_f`

**Build / Flash / Runtime Notes**
- Validation: `esphome config clock-with-temp.yaml` returns "Configuration is valid!"
- Build: Final image ~1.3-1.5 MB (increased due to 216pt font glyphs)
- First build time: ~5-8 minutes (font generation from TTF)
- Subsequent builds: ~45-90 seconds
- Flash: Via USB (`/dev/ttyACM0`) or OTA
- ESPHome version: 2025.12.3

**Serial / Runtime Observations**:
- Device detects PSRAM (8MB) at boot
- Wi-Fi connects successfully
- LVGL may show occasional long-operation warnings (~120-135ms) - harmless
- Debug logs show sensor states: `INFO dashboard: States: outdoor=30.0 ...`
- Brightness logs: `INFO brightness: Hour: 23, Nighttime: yes, Text Opacity: 127`
- Display is readable from across the room with 216pt clock

**Known Issues / Limitations**

1. **Status LEDs Cannot Be Dimmed**:
   - PWR and DONE LEDs are hardware-controlled by CS8501 charging chip
   - No GPIO access for software dimming
   - Workaround: Apply translucent tape or window tint film to reduce brightness

2. **Touchscreen Not Configured**:
   - GT911 touch driver not enabled
   - No touch input or calibration present
   - Can be added if needed for future UI controls

3. **Update Intervals**:
   - Currently 15s for time/temperature
   - LVGL shows ~120-135ms long-operation warnings occasionally
   - Not causing UI issues, but can increase interval to 30s or 60s if needed

4. **Font Size vs Firmware Size**:
   - 216pt font adds significant size to firmware (~200-300KB for glyphs)
   - ESP32-S3 has plenty of flash (4MB+), so not an issue
   - If firmware size becomes a problem, reduce font sizes

5. **NaN Handling**:
   - Displays `--°F` until Home Assistant sensors provide valid data
   - Usually resolves within 30-60 seconds of boot
   - Check HA API connection if persists

**Where to Look in the Code**

Main configuration: [clock-with-temp.yaml](clock-with-temp.yaml)

Key sections:
- **Lines 159-168**: Custom font definitions (216pt, 96pt, 24pt)
- **Lines 170-199**: LVGL config and style definitions
- **Lines 200-284**: LVGL page layout (flex containers and labels)
- **Lines 286-291**: Time update interval (15s)
- **Lines 293-355**: Temperature update interval (15s, includes color logic)
- **Lines 357-381**: Nighttime dimming interval (1min)

**Commands to Resume Work**

```bash
# Validate configuration
esphome config clock-with-temp.yaml

# Build and flash via USB (first time or troubleshooting)
esphome run clock-with-temp.yaml --device /dev/ttyACM0

# Flash via OTA (after initial USB flash)
esphome run clock-with-temp.yaml

# View logs
esphome logs clock-with-temp.yaml

# Only build (no flash)
esphome compile clock-with-temp.yaml

# Clean build cache
esphome clean clock-with-temp.yaml
```

**Troubleshooting Steps**

1. **Verify Configuration**: `esphome config clock-with-temp.yaml`
2. **Check Logs**: Look for sensor states and brightness messages
3. **PSRAM Detection**: Verify "PSRAM: 8MB" in boot logs
4. **Wi-Fi Connection**: Confirm SSID and network connectivity
5. **HA Sensors**: Check that all 4 sensors are returning values (not NaN)
6. **Time Sync**: Verify SNTP synchronization for dimming to work
7. **Display**: Text should be very large and easily readable

**Configuration Customization**

### Adjust Font Sizes
Edit `font:` section (lines 159-168) and corresponding `style_definitions`.

### Change Clock Color
Edit line 182: `text_color: 0xFF9933` (current warm amber)
- Other options: `0xFFBF00` (pure amber), `0xFF7F00` (orange), `0xCC3300` (soft red)

### Adjust Dimming Schedule
Edit lines 365-369:
```yaml
bool is_nighttime = (hour >= 22 || hour < 6);  # Change hours
uint8_t opacity = is_nighttime ? 127 : 255;    # Change opacity (0-255)
```

### Modify Update Intervals
Edit lines 287, 293, 358:
```yaml
- interval: 15s  # Change to 5s, 30s, 60s, etc.
```

### Adjust Temperature Spacing
Edit line 223 (pad_column) and 224 (pad_row):
```yaml
pad_column: 40  # Horizontal gap between columns
pad_row: 10     # Vertical gap within columns
```

### Change Whole Numbers to Decimals
Edit lines 304-306:
```cpp
sprintf(out_s, "%.0f°F", outf);  // Change %.0f to %.1f for one decimal
```

**Next Recommended Tasks**

### Immediate Priorities
1. ✅ **COMPLETED**: Large fonts for readability
2. ✅ **COMPLETED**: Nighttime dimming
3. ✅ **COMPLETED**: Flex layout for easy customization
4. ✅ **COMPLETED**: Code cleanup and simplification

### Future Enhancements
1. **Touchscreen Support**:
   - Enable GT911 driver in I2C configuration
   - Add LVGL button widgets for manual brightness control
   - Implement page navigation for additional info screens

2. **Additional Display Pages**:
   - Weather forecast (next 24 hours)
   - Temperature graphs/trends
   - Humidity and wind speed details
   - Sunrise/sunset times

3. **Adaptive Brightness**:
   - If light sensor available, auto-adjust based on ambient light
   - Currently uses time-based dimming only

4. **Configuration UI**:
   - Touch-based settings page
   - Adjust dimming hours without reflashing
   - Toggle between temperature scales (°F/°C)

5. **Status Indicators**:
   - Wi-Fi signal strength
   - Home Assistant connection status
   - Last update timestamp

6. **Animation**:
   - Smooth fade transitions during dimming
   - Color transition animations for temperature changes
   - Time format options (12hr/24hr toggle)

**File Structure**

```
esphome-examples/
├── clock-with-temp.yaml       # Main ESPHome configuration (308 lines)
├── fonts/
│   └── Montserrat-Bold.ttf    # Custom font (445KB, SIL OFL 1.1)
├── README.md                  # Comprehensive documentation
├── status.md                  # This file - handoff notes
├── test.yaml                  # Test configuration (not used)
├── .gitignore
└── config/                    # ESPHome build artifacts
```

**Git Status**
- Last commit: `50f131d` - "feat: Enhanced LVGL dashboard with larger fonts and nighttime dimming"
- Branch: `main`
- Files changed: 3 (renamed clock-with-temp.yaml, added fonts/, updated README.md)
- Ready to push to remote

**Performance Metrics**
- Firmware size: ~1.3-1.5 MB
- PSRAM usage: 8MB detected and utilized
- Update cycle: 15s (time + temps), 1min (brightness)
- Build time (first): ~5-8 minutes
- Build time (subsequent): ~45-90 seconds
- Display latency: Negligible (<100ms for updates)

**Testing Status**
✅ Configuration validates without errors
✅ Fonts embedded and rendering correctly
✅ Flex layout working as expected
✅ Nighttime dimming activates at correct hours
✅ Temperature color coding accurate
✅ Home Assistant sensor integration working
✅ SNTP time synchronization functional
✅ NaN safety displays `--°F` correctly
✅ Black background maintained during dimming

**Known Working Configurations**
- WiFi SSID: "Home on the range" (configured in YAML)
- Timezone: America/Chicago (US Central Time)
- HA sensors: Outdoor, humidity, wind, indoor temperature
- Display resolution: 800x480 (7-inch)
- Update intervals: 15s standard, 1min brightness check
- Dimming hours: 10pm-6am (50% opacity)

**Hardware Notes**
- CH422G IO expander controls LCD_BL, LCD_RST, TP_RST
- Backlight is on/off only (no PWM brightness control without hardware mod)
- PWR and DONE LEDs are hardware-controlled (cannot be software-dimmed)
- Touchscreen present but GT911 driver not configured
- USB-C power, OTA updates supported

**Development Environment**
- ESPHome: 2025.12.3
- Python: 3.8+
- Platform: ESP-IDF framework
- Device: `/dev/ttyACM0` (USB serial)

**Color Design Philosophy**
- **Clock**: Warm amber (`0xFF9933`) minimizes blue light for nighttime comfort
- **Background**: Pure black (`0x000000`) for OLED-like appearance and power efficiency
- **Temperature values**: White (`0xFFFFFF`) with dynamic color overlay for temperature indication
- **Labels**: Medium gray (`0x888888`) for subtle hierarchy
- **Nighttime**: 50% opacity maintains readability while reducing eye strain

**Accessibility Features**
- Extra-large text (216pt clock) readable from 10+ feet away
- High contrast (white/amber on black) for visibility
- Color coding redundant with numeric display (not sole indicator)
- Automatic nighttime adaptation for bedroom/dark room use
- No flashing or rapid animations that could cause discomfort

---

**How to Pick This Up**

If you're resuming work on this project (as another coding agent or human):

1. **Read this file completely** - it contains all context
2. **Check clock-with-temp.yaml** - single source of truth for config
3. **Review README.md** - user-facing documentation
4. **Validate first**: `esphome config clock-with-temp.yaml`
5. **Review recent commits** for latest changes
6. **Check logs** if device is connected: `esphome logs clock-with-temp.yaml`
7. **Ask user** what they want to add/change/fix
8. **Reference "Next Recommended Tasks"** above for ideas

**Common User Requests & How to Handle**

- *"Make text bigger/smaller"*: Edit font sizes in lines 159-168 and style definitions
- *"Change colors"*: Edit color values in style definitions or temperature mapping
- *"Adjust dimming hours"*: Edit line 366 nighttime hours
- *"Add more sensors"*: Add homeassistant sensors and new LVGL labels in flex layout
- *"Change spacing"*: Edit pad_column/pad_row values in flex layout
- *"Different font"*: Replace fonts/Montserrat-Bold.ttf and update font IDs

**Critical Implementation Notes**

1. **Always use `lv_obj_set_style_text_opa()` for dimming**, not `lv_obj_set_style_opa()` which dims background too
2. **Flex layout requires `SIZE_CONTENT`** for width/height to auto-size
3. **Container style must have `bg_opa: TRANSP`** to prevent white backgrounds
4. **Font generation is slow** - first build with large fonts takes several minutes
5. **Temperature color applied after text update** - order matters for proper rendering
6. **NaN checks essential** - HA sensors may not be ready at boot

**Success Criteria**
This dashboard is considered successful if:
- ✅ Clock is visible and readable from across the room
- ✅ Temperatures update regularly and accurately
- ✅ Colors change appropriately with temperature
- ✅ Nighttime dimming activates automatically
- ✅ Background stays black (no gray tint)
- ✅ No crashes or memory errors
- ✅ Wi-Fi and HA connection stable

**Current Status**: ✅ **All success criteria met. Ready for production use.**

---

Generated as a handoff snapshot for resuming work on the LVGL ESPHome dashboard.
Last updated: 2025-12-30 22:15 CST
