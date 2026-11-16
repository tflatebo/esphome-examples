#!/usr/bin/env bash
# Validate clock-with-temp.yaml with ESPHome, and optionally compile it, without
# touching the device.
#
# Usage:  tools/check_config.sh            # validate the config
#         tools/check_config.sh --compile  # validate, then build and report flash use
#
# Checks the working tree as it is (including uncommitted changes). Uses secrets.yaml
# if present, otherwise secrets.yaml.example (placeholder values are fine for checking).
# The first run installs ESPHome into a reusable virtualenv; the build directory is
# kept between runs so later compiles are incremental.
#
# Environment overrides:
#   PYTHON              Python 3.11+ to build the virtualenv with (default: python3)
#   ESPHOME_VERSION     ESPHome version to check with             (default: 2025.12.3)
#   ESPHOME_CHECK_VENV  virtualenv location    (default: ~/.cache/esphome-check-venv)
#   ESPHOME_CHECK_WORK  build directory        (default: ~/.cache/esphome-check-work)
#
# Exit status: 0 if valid (and, with --compile, built), 1 otherwise.

set -euo pipefail

compile=false
case "${1:-}" in
  --compile) compile=true ;;
  "") ;;
  *) echo "Usage: $0 [--compile]" >&2; exit 2 ;;
esac

repo="$(cd "$(dirname "$0")/.." && pwd)"
config="clock-with-temp.yaml"
version="${ESPHOME_VERSION:-2025.12.3}"
venv="${ESPHOME_CHECK_VENV:-$HOME/.cache/esphome-check-venv}"
work="${ESPHOME_CHECK_WORK:-$HOME/.cache/esphome-check-work}"
python="${PYTHON:-python3}"

if [ ! -x "$venv/bin/esphome" ]; then
  echo "Installing ESPHome $version into $venv (first run only)..."
  "$python" -m venv "$venv"
  "$venv/bin/pip" install --quiet --upgrade pip
  "$venv/bin/pip" install --quiet "esphome==$version"
fi

# Copy the working tree over the persistent work dir (keeping its .esphome build cache).
mkdir -p "$work"
tar -C "$repo" --exclude=.git --exclude=.esphome --exclude=tools -cf - . | tar -C "$work" -xf -
if [ ! -f "$repo/secrets.yaml" ]; then
  cp "$repo/secrets.yaml.example" "$work/secrets.yaml"
  echo "(No secrets.yaml; checking with secrets.yaml.example.)"
fi

cd "$work"
echo "Checking $config with ESPHome $("$venv/bin/esphome" version | awk '{print $NF}')..."
if ! "$venv/bin/esphome" config "$config" >config.log 2>&1; then
  echo "FAILED: configuration is invalid." >&2
  grep -v -E "^\s{2,}" config.log | tail -40 >&2
  exit 1
fi
echo "OK: configuration is valid."

if $compile; then
  echo "Compiling (first build takes a few minutes)..."
  if ! "$venv/bin/esphome" compile "$config" >compile.log 2>&1; then
    echo "FAILED: compile errors:" >&2
    grep -E "error|Error|ERROR" compile.log | tail -30 >&2
    exit 1
  fi
  echo "OK: compiled. $(grep -E '^Flash:' compile.log | tail -1)"
fi
