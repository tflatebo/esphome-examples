#pragma once

// Shared temperature color scheme for the dashboard (main screen and forecast pages).
// Pulled into the build via `esphome: includes:` in clock-with-temp.yaml.

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <string>

// Map a temperature in °F to a 0xRRGGBB color:
//   <= 0°F  bright blue
//   0-32°F  blue gradient (freezing)
//   32-72°F blue -> green (comfortable)
//   72-90°F green -> red (warming)
//   >= 90°F bright red
// NaN (no data) maps to white.
inline uint32_t temperature_color(double v) {
  uint8_t r = 255, g = 255, b = 255;
  if (!std::isnan(v)) {
    if (v <= 0.0) {
      r = 0; g = 120; b = 255;
    } else if (v < 32.0) {
      double t = v / 32.0;
      r = 0;
      g = (uint8_t) std::round(120 + 40 * t);
      b = (uint8_t) std::round(255 - 35 * t);
    } else if (v < 72.0) {
      double t = (v - 32.0) / 40.0;
      r = 0;
      g = (uint8_t) std::round(160 + 40 * t);
      b = (uint8_t) std::round(220 - 220 * t);
    } else if (v < 90.0) {
      double t = (v - 72.0) / 18.0;
      r = (uint8_t) std::round(255 * t);
      g = (uint8_t) std::round(200 - 160 * t);
      b = 0;
    } else {
      r = 255; g = 40; b = 0;
    }
  }
  return ((uint32_t) r << 16) | ((uint32_t) g << 8) | b;
}

// Whole-number temperature wrapped in LVGL recolor markup, e.g. "#00c800 48#",
// so several temperatures in one label can each get their own color.
// The label must have `recolor: true`. NaN renders as an uncolored "--".
inline std::string temperature_markup(double v) {
  if (std::isnan(v)) return "--";
  char text[24];
  snprintf(text, sizeof(text), "#%06x %.0f#", (unsigned) temperature_color(v), v);
  return text;
}
