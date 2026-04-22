#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║                   🌸  Lia  —  Full Installer  🌸                        ║
# ║        Installs every dependency Lia needs, step by step                ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# Supported distros: Ubuntu / Debian / Pop!_OS / Linux Mint
#                    Arch Linux / Manjaro
#                    Fedora / RHEL / CentOS
#                    macOS (Homebrew)
#
# Usage:
#   chmod +x install_lia.sh && ./install_lia.sh
#   ./install_lia.sh --skip-voice-models   # skip large model downloads
#   ./install_lia.sh --skip-ollama         # don't install Ollama
#

set -euo pipefail

# ───────────────────────────────────────────────────────────────────────────────
#  ARGS
# ───────────────────────────────────────────────────────────────────────────────
SKIP_VOICE_MODELS=false
SKIP_OLLAMA=false

for arg in "$@"; do
  case "$arg" in
    --skip-voice-models) SKIP_VOICE_MODELS=true ;;
    --skip-ollama)       SKIP_OLLAMA=true ;;
    -h|--help)
      echo "Usage: $0 [--skip-voice-models] [--skip-ollama]"
      exit 0 ;;
  esac
done

# ───────────────────────────────────────────────────────────────────────────────
#  COLORS & SYMBOLS
# ───────────────────────────────────────────────────────────────────────────────
PINK='\033[38;5;213m'
PURPLE='\033[38;5;183m'
CYAN='\033[38;5;159m'
GREEN='\033[38;5;157m'
YELLOW='\033[38;5;228m'
RED='\033[38;5;210m'
GREY='\033[38;5;245m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

OK="${GREEN}  ✔${RESET}"
FAIL="${RED}  ✘${RESET}"
INFO="${CYAN}  ℹ${RESET}"
WARN="${YELLOW}  ⚠${RESET}"
STEP="${PURPLE}  ▶${RESET}"
SKIP="${GREY}  ⊘${RESET}"

# ───────────────────────────────────────────────────────────────────────────────
#  LOGGING
# ───────────────────────────────────────────────────────────────────────────────
LOG_FILE="/tmp/lia_install_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

log_only() { echo "$@" >> "$LOG_FILE" 2>/dev/null || true; }

# ───────────────────────────────────────────────────────────────────────────────
#  HELPERS
# ───────────────────────────────────────────────────────────────────────────────
has()    { command -v "$1" &>/dev/null; }
is_root(){ [[ $EUID -eq 0 ]]; }

# Run a command, print ok/fail, never abort the whole script
run_step() {
  local label="$1"; shift
  printf "${STEP}  %-55s" "$label"
  if "$@" >> "$LOG_FILE" 2>&1; then
    echo -e "${GREEN}OK${RESET}"
    return 0
  else
    echo -e "${RED}FAILED${RESET}"
    echo -e "${WARN}  See $LOG_FILE for details"
    return 1
  fi
}

# Print a section header
section() {
  echo ""
  echo -e "${PINK}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${PINK}${BOLD}  $1${RESET}"
  echo -e "${PINK}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

pip_install() {
  # Install a pip package — works whether inside venv or system-wide
  if has pip3; then
    pip3 install --quiet "$@" --break-system-packages 2>/dev/null \
    || pip3 install --quiet "$@" 2>/dev/null \
    || pip  install --quiet "$@" --break-system-packages 2>/dev/null \
    || pip  install --quiet "$@" 2>/dev/null
  else
    python3 -m pip install --quiet "$@" --break-system-packages 2>/dev/null \
    || python3 -m pip install --quiet "$@" 2>/dev/null
  fi
}

# ───────────────────────────────────────────────────────────────────────────────
#  DETECT OS
# ───────────────────────────────────────────────────────────────────────────────
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  elif [[ -f /etc/os-release ]]; then
    source /etc/os-release
    case "$ID" in
      ubuntu|debian|linuxmint|pop)  OS="debian" ;;
      arch|manjaro|endeavouros)     OS="arch" ;;
      fedora|rhel|centos|rocky)     OS="fedora" ;;
      *)
        # Check ID_LIKE for derivatives
        case "${ID_LIKE:-}" in
          *debian*|*ubuntu*) OS="debian" ;;
          *arch*)            OS="arch" ;;
          *fedora*|*rhel*)   OS="fedora" ;;
          *)                 OS="unknown" ;;
        esac ;;
    esac
  else
    OS="unknown"
  fi
}

# ───────────────────────────────────────────────────────────────────────────────
#  PACKAGE MANAGER WRAPPERS
# ───────────────────────────────────────────────────────────────────────────────
sys_install() {
  case "$OS" in
    debian)
      if is_root; then
        apt-get install -y -qq "$@"
      else
        sudo apt-get install -y -qq "$@"
      fi ;;
    arch)
      if is_root; then
        pacman -S --noconfirm --needed "$@"
      else
        sudo pacman -S --noconfirm --needed "$@"
      fi ;;
    fedora)
      if is_root; then
        dnf install -y -q "$@"
      else
        sudo dnf install -y -q "$@"
      fi ;;
    macos)
      brew install "$@" ;;
    *)
      echo -e "${WARN}  Unknown OS — skipping system package: $*"
      return 1 ;;
  esac
}

sys_update() {
  case "$OS" in
    debian)
      if is_root; then apt-get update -qq; else sudo apt-get update -qq; fi ;;
    arch)
      if is_root; then pacman -Sy --noconfirm; else sudo pacman -Sy --noconfirm; fi ;;
    fedora)
      if is_root; then dnf check-update -q || true; else sudo dnf check-update -q || true; fi ;;
    macos)
      brew update -q ;;
  esac
}

# ───────────────────────────────────────────────────────────────────────────────
#  TRACK RESULTS
# ───────────────────────────────────────────────────────────────────────────────
declare -a INSTALLED=()
declare -a SKIPPED=()
declare -a FAILED=()

mark_ok()   { INSTALLED+=("$1"); }
mark_skip() { SKIPPED+=("$1"); }
mark_fail() { FAILED+=("$1"); }

# ═══════════════════════════════════════════════════════════════════════════════
#  BANNER
# ═══════════════════════════════════════════════════════════════════════════════
clear
echo ""
echo -e "${PINK}${BOLD}"
echo "  ██╗     ██╗ █████╗      ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗ "
echo "  ██║     ██║██╔══██╗     ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗"
echo "  ██║     ██║███████║     ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝"
echo "  ██║     ██║██╔══██║     ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗"
echo "  ███████╗██║██║  ██║     ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║"
echo "  ╚══════╝╚═╝╚═╝  ╚═╝     ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝"
echo -e "${RESET}"
echo -e "${PURPLE}  ✨  Full dependency installer for Lia — Your AI Companion  ✨${RESET}"
echo ""
echo -e "${DIM}  Log file: $LOG_FILE${RESET}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 0 — DETECT ENVIRONMENT
# ═══════════════════════════════════════════════════════════════════════════════
section "0 / Detecting your system"

detect_os
echo -e "${OK}  OS family:    ${BOLD}$OS${RESET}"
echo -e "${OK}  Architecture: ${BOLD}$(uname -m)${RESET}"
echo -e "${OK}  Kernel:       ${BOLD}$(uname -r)${RESET}"
echo -e "${OK}  User:         ${BOLD}$(whoami)${RESET}"
echo -e "${OK}  Log file:     ${BOLD}$LOG_FILE${RESET}"

if [[ "$OS" == "unknown" ]]; then
  echo -e "${WARN}  Could not detect your Linux distribution."
  echo -e "  System packages will be skipped — pip packages will still be installed."
fi

# Check if we can sudo (needed for system packages)
CAN_SUDO=false
if is_root; then
  CAN_SUDO=true
  echo -e "${INFO}  Running as root — no sudo needed"
elif sudo -n true 2>/dev/null; then
  CAN_SUDO=true
  echo -e "${OK}  sudo is available"
else
  echo -e "${WARN}  sudo not available — system package installation will be skipped"
  echo -e "  Python packages will still be installed for your user"
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 1 — SYSTEM PACKAGE MANAGER UPDATE
# ═══════════════════════════════════════════════════════════════════════════════
section "1 / Refreshing package lists"

if [[ "$CAN_SUDO" == true && "$OS" != "unknown" ]]; then
  run_step "Updating package index" sys_update \
    && mark_ok "package-index" || mark_fail "package-index"
else
  echo -e "${SKIP}  Skipping package index update (no sudo / unknown OS)"
  mark_skip "package-index"
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 2 — CORE SYSTEM TOOLS
# ═══════════════════════════════════════════════════════════════════════════════
section "2 / Core system tools"

install_sys_pkg() {
  local name="$1"; shift
  local pkgs=("$@")
  if [[ "$CAN_SUDO" == false || "$OS" == "unknown" ]]; then
    echo -e "${SKIP}  $name  ${DIM}(no sudo)${RESET}"
    mark_skip "$name"
    return
  fi
  run_step "$name" sys_install "${pkgs[@]}" \
    && mark_ok "$name" || mark_fail "$name"
}

# Debian/Ubuntu package names
declare -A DEB_PKGS=(
  ["curl"]="curl"
  ["wget"]="wget"
  ["git"]="git"
  ["Python 3"]="python3 python3-pip python3-dev"
  ["Build essentials"]="build-essential"
  ["OpenSSL dev headers"]="libssl-dev libffi-dev"
  ["PortAudio (audio I/O)"]="portaudio19-dev libportaudio2"
  ["FFmpeg (audio/video)"]="ffmpeg"
  ["ImageMagick (icon resize)"]="imagemagick"
  ["playerctl (media control)"]="playerctl"
  ["libevdev (typing detection)"]="python3-evdev libevdev-dev"
  ["xdg-utils (browser open)"]="xdg-utils"
  ["lsof (port checking)"]="lsof"
  ["unzip"]="unzip"
)

declare -A ARCH_PKGS=(
  ["curl"]="curl"
  ["wget"]="wget"
  ["git"]="git"
  ["Python 3"]="python python-pip"
  ["Build essentials"]="base-devel"
  ["OpenSSL dev headers"]="openssl"
  ["PortAudio (audio I/O)"]="portaudio"
  ["FFmpeg (audio/video)"]="ffmpeg"
  ["ImageMagick (icon resize)"]="imagemagick"
  ["playerctl (media control)"]="playerctl"
  ["libevdev (typing detection)"]="python-evdev libevdev"
  ["xdg-utils (browser open)"]="xdg-utils"
  ["lsof (port checking)"]="lsof"
  ["unzip"]="unzip"
)

declare -A FEDORA_PKGS=(
  ["curl"]="curl"
  ["wget"]="wget"
  ["git"]="git"
  ["Python 3"]="python3 python3-pip python3-devel"
  ["Build essentials"]="gcc gcc-c++ make"
  ["OpenSSL dev headers"]="openssl-devel libffi-devel"
  ["PortAudio (audio I/O)"]="portaudio portaudio-devel"
  ["FFmpeg (audio/video)"]="ffmpeg"
  ["ImageMagick (icon resize)"]="ImageMagick"
  ["playerctl (media control)"]="playerctl"
  ["libevdev (typing detection)"]="python3-evdev libevdev-devel"
  ["xdg-utils (browser open)"]="xdg-utils"
  ["lsof (port checking)"]="lsof"
  ["unzip"]="unzip"
)

declare -A MACOS_PKGS=(
  ["curl"]="curl"
  ["wget"]="wget"
  ["git"]="git"
  ["Python 3"]="python@3.12"
  ["FFmpeg (audio/video)"]="ffmpeg"
  ["ImageMagick (icon resize)"]="imagemagick"
  ["playerctl (media control)"]="playerctl"
  ["PortAudio (audio I/O)"]="portaudio"
  ["lsof (port checking)"]=""   # built-in on macOS
  ["unzip"]=""                  # built-in on macOS
)

install_all_sys_pkgs() {
  local -n PKG_MAP=$1
  for label in "${!PKG_MAP[@]}"; do
    local pkg_str="${PKG_MAP[$label]}"
    [[ -z "$pkg_str" ]] && { mark_skip "$label"; continue; }
    read -ra pkg_arr <<< "$pkg_str"
    install_sys_pkg "$label" "${pkg_arr[@]}"
  done
}

case "$OS" in
  debian) install_all_sys_pkgs DEB_PKGS ;;
  arch)   install_all_sys_pkgs ARCH_PKGS ;;
  fedora) install_all_sys_pkgs FEDORA_PKGS ;;
  macos)  install_all_sys_pkgs MACOS_PKGS ;;
  *)
    echo -e "${SKIP}  Skipping all system packages (unknown OS)"
    for label in "curl" "wget" "git" "Python 3" "Build essentials" \
                 "OpenSSL dev headers" "PortAudio" "FFmpeg" "ImageMagick" \
                 "playerctl" "libevdev" "xdg-utils" "lsof" "unzip"; do
      mark_skip "$label"
    done ;;
esac

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 3 — VERIFY PYTHON
# ═══════════════════════════════════════════════════════════════════════════════
section "3 / Verifying Python"

PYTHON_OK=false
for py in python3 python python3.12 python3.11 python3.10; do
  if has "$py"; then
    PY_VERSION=$("$py" --version 2>&1 | awk '{print $2}')
    PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
    PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
    if [[ "$PY_MAJOR" -ge 3 && "$PY_MINOR" -ge 10 ]]; then
      PYTHON="$py"
      PYTHON_OK=true
      echo -e "${OK}  Found $py  ${BOLD}v$PY_VERSION${RESET}  ✓"
      mark_ok "Python $PY_VERSION"
      break
    else
      echo -e "${WARN}  $py v$PY_VERSION is too old (need ≥ 3.10)"
    fi
  fi
done

if [[ "$PYTHON_OK" == false ]]; then
  echo -e "${FAIL}  Python 3.10+ not found. Please install it manually and re-run this script."
  FAILED+=("Python 3.10+")
  # Don't abort — pip installs will also fail but let's show the full picture
fi

# Ensure pip is available
if has pip3; then
  PIP="pip3"
elif has pip; then
  PIP="pip"
elif [[ "$PYTHON_OK" == true ]]; then
  PIP="$PYTHON -m pip"
else
  PIP=""
fi

if [[ -n "$PIP" ]]; then
  run_step "Upgrading pip" $PIP install --quiet --upgrade pip --break-system-packages 2>/dev/null || true
  echo -e "${OK}  pip: $($PIP --version 2>/dev/null | head -1)"
  mark_ok "pip"
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 4 — CORE PYTHON DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════════
section "4 / Core Python packages"

install_pip_pkg() {
  local label="$1"; shift
  printf "${STEP}  %-55s" "$label"
  if pip_install "$@" >> "$LOG_FILE" 2>&1; then
    echo -e "${GREEN}OK${RESET}"
    mark_ok "$label"
  else
    echo -e "${RED}FAILED${RESET}"
    echo -e "${WARN}  Run manually: pip3 install $*"
    mark_fail "$label"
  fi
}

# Flask and web server
install_pip_pkg "Flask (web server)"             flask werkzeug
install_pip_pkg "Jinja2 (templating)"            jinja2
install_pip_pkg "itsdangerous (sessions)"        itsdangerous
install_pip_pkg "click (CLI)"                    click

# HTTP / networking
install_pip_pkg "requests (HTTP client)"         requests
install_pip_pkg "urllib3"                        urllib3
install_pip_pkg "certifi (SSL certs)"            certifi
install_pip_pkg "httpx (async HTTP)"             httpx

# System / utilities
install_pip_pkg "psutil (process info)"          psutil
install_pip_pkg "Pillow (image processing)"      Pillow
install_pip_pkg "reportlab (PDF generation)"     reportlab

# PDF reading
install_pip_pkg "PyPDF2 (PDF reader)"            PyPDF2

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 5 — AI PROVIDER PACKAGES
# ═══════════════════════════════════════════════════════════════════════════════
section "5 / AI provider packages"

install_pip_pkg "ollama (local AI)"              ollama
install_pip_pkg "anthropic (Claude API)"         anthropic
install_pip_pkg "groq (Groq API)"                groq
install_pip_pkg "cerebras-cloud-sdk"             cerebras-cloud-sdk

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 6 — TTS (TEXT-TO-SPEECH) ENGINES
# ═══════════════════════════════════════════════════════════════════════════════
section "6 / Text-to-speech engines"

install_pip_pkg "edge-tts (Microsoft TTS)"       edge-tts
install_pip_pkg "piper-tts (offline TTS)"        piper-tts

printf "${STEP}  %-55s" "kokoro-onnx (neural TTS)"
if pip_install kokoro-onnx >> "$LOG_FILE" 2>&1; then
  echo -e "${GREEN}OK${RESET}"
  mark_ok "kokoro-onnx"
else
  echo -e "${YELLOW}OPTIONAL — failed${RESET}"
  echo -e "${INFO}  kokoro-onnx is optional; install manually if you want the Kokoro voice engine"
  mark_skip "kokoro-onnx (optional)"
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 7 — DISCORD & TELEGRAM
# ═══════════════════════════════════════════════════════════════════════════════
section "7 / Discord & Telegram bot packages"

install_pip_pkg "discord.py (Discord bot)"       "discord.py[voice]"
install_pip_pkg "PyNaCl (Discord voice crypto)"  PyNaCl
install_pip_pkg "pyTelegramBotAPI (Telegram)"    pyTelegramBotAPI

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 8 — MEDIA / AUDIO
# ═══════════════════════════════════════════════════════════════════════════════
section "8 / Media and audio packages"

install_pip_pkg "yt-dlp (audio/video download)"  yt-dlp

# python-evdev for typing detection (Linux only)
if [[ "$OS" != "macos" ]]; then
  printf "${STEP}  %-55s" "python-evdev (typing detection)"
  if pip_install evdev >> "$LOG_FILE" 2>&1; then
    echo -e "${GREEN}OK${RESET}"
    mark_ok "evdev"
  else
    echo -e "${YELLOW}OPTIONAL — failed${RESET}"
    echo -e "${INFO}  evdev is optional; needed only for typing detection on Wayland/X11"
    mark_skip "evdev (optional)"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 9 — OLLAMA  (local AI runner)
# ═══════════════════════════════════════════════════════════════════════════════
section "9 / Ollama  (local AI engine)"

if [[ "$SKIP_OLLAMA" == true ]]; then
  echo -e "${SKIP}  Skipping Ollama installation (--skip-ollama)"
  mark_skip "Ollama"
elif has ollama; then
  OLLAMA_VER=$(ollama --version 2>/dev/null || echo "unknown")
  echo -e "${OK}  Ollama already installed: ${BOLD}$OLLAMA_VER${RESET}"
  mark_skip "Ollama (already installed)"
else
  if [[ "$OS" == "macos" ]]; then
    echo -e "${INFO}  On macOS, download the Ollama app from: ${CYAN}https://ollama.com/download${RESET}"
    echo -e "  Or install via Homebrew: ${CYAN}brew install ollama${RESET}"
    mark_skip "Ollama (manual install required on macOS)"
  else
    printf "${STEP}  %-55s" "Downloading & installing Ollama"
    if curl -fsSL https://ollama.ai/install.sh | sh >> "$LOG_FILE" 2>&1; then
      echo -e "${GREEN}OK${RESET}"
      mark_ok "Ollama"
    else
      echo -e "${RED}FAILED${RESET}"
      echo -e "${WARN}  Manual install: ${CYAN}curl -fsSL https://ollama.ai/install.sh | sh${RESET}"
      mark_fail "Ollama"
    fi
  fi
fi

# Pull a default model if Ollama is now available
if has ollama && [[ "$SKIP_OLLAMA" == false ]]; then
  echo ""
  echo -e "${INFO}  Pulling default model  ${BOLD}gemma3:1b${RESET}  (lightweight, ~815 MB)…"
  echo -e "${DIM}  To use a different model, run: ollama pull <model-name>${RESET}"
  printf "${STEP}  %-55s" "ollama pull gemma3:1b"
  if ollama pull gemma3:1b >> "$LOG_FILE" 2>&1; then
    echo -e "${GREEN}OK${RESET}"
    mark_ok "Ollama model: gemma3:1b"
  else
    echo -e "${YELLOW}FAILED${RESET}"
    echo -e "${WARN}  Pull manually later: ${CYAN}ollama pull gemma3:1b${RESET}"
    mark_fail "Ollama model pull"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 10 — PIPER VOICE MODEL  (offline TTS)
# ═══════════════════════════════════════════════════════════════════════════════
section "10 / Piper voice model  (offline TTS)"

PIPER_MODEL="en_US-amy-medium.onnx"
PIPER_JSON="${PIPER_MODEL%.onnx}.onnx.json"
PIPER_BASE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/medium"
PIPER_DEST="$HOME"

_piper_found() {
  for d in "$HOME" "$HOME/.local/share/piper" "/opt/piper-tts/voices" "/opt/piper-tts" "$(pwd)"; do
    [[ -f "$d/$PIPER_MODEL" ]] && return 0
  done
  return 1
}

if [[ "$SKIP_VOICE_MODELS" == true ]]; then
  echo -e "${SKIP}  Skipping Piper model download (--skip-voice-models)"
  mark_skip "Piper voice model"
elif _piper_found; then
  echo -e "${OK}  Piper model already present (en_US-amy-medium)"
  mark_skip "Piper voice model (already present)"
else
  echo -e "${INFO}  Downloading Piper voice model  ${BOLD}en_US-amy-medium${RESET}  (~65 MB)…"
  echo -e "${DIM}  Destination: $PIPER_DEST/${RESET}"
  echo ""
  DL_OK=true

  printf "${STEP}  %-55s" "Downloading $PIPER_MODEL"
  if curl -fL --progress-bar \
      "${PIPER_BASE_URL}/${PIPER_MODEL}" \
      -o "${PIPER_DEST}/${PIPER_MODEL}" 2>> "$LOG_FILE"; then
    echo -e "  ${GREEN}OK${RESET}"
    mark_ok "Piper model .onnx"
  else
    echo -e "  ${RED}FAILED${RESET}"
    DL_OK=false
    mark_fail "Piper model .onnx"
  fi

  printf "${STEP}  %-55s" "Downloading $PIPER_JSON"
  if curl -fsSL \
      "${PIPER_BASE_URL}/${PIPER_JSON}" \
      -o "${PIPER_DEST}/${PIPER_JSON}" 2>> "$LOG_FILE"; then
    echo -e "${GREEN}OK${RESET}"
    mark_ok "Piper model .json"
  else
    echo -e "${RED}FAILED${RESET}"
    DL_OK=false
    mark_fail "Piper model .json"
  fi

  if [[ "$DL_OK" == true ]]; then
    echo -e "${OK}  Piper model saved to: ${BOLD}$PIPER_DEST/${RESET}"
  else
    echo -e "${WARN}  Download failed. Try manually:"
    echo -e "  ${CYAN}curl -L '${PIPER_BASE_URL}/${PIPER_MODEL}' -o ~/${PIPER_MODEL}${RESET}"
    echo -e "  ${CYAN}curl -L '${PIPER_BASE_URL}/${PIPER_JSON}' -o ~/${PIPER_JSON}${RESET}"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 11 — KOKORO VOICE MODEL  (optional, ~350 MB)
# ═══════════════════════════════════════════════════════════════════════════════
section "11 / Kokoro voice model  (optional, ~350 MB)"

KOKORO_MODEL="kokoro-v0_19.onnx"
KOKORO_VOICES="voices.bin"
KOKORO_BASE="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files"

_kokoro_found() {
  for d in "$HOME" "$HOME/.local/share/kokoro" "/opt/kokoro" "$(pwd)"; do
    [[ -f "$d/$KOKORO_MODEL" && -f "$d/$KOKORO_VOICES" ]] && return 0
  done
  return 1
}

if [[ "$SKIP_VOICE_MODELS" == true ]]; then
  echo -e "${SKIP}  Skipping Kokoro model download (--skip-voice-models)"
  mark_skip "Kokoro voice model"
elif _kokoro_found; then
  echo -e "${OK}  Kokoro model already present"
  mark_skip "Kokoro voice model (already present)"
else
  echo -e "${INFO}  The Kokoro model is large (~350 MB total) and optional."
  echo -e "  It is only needed if you enable the Kokoro voice engine inside Lia."
  echo ""
  read -r -p "$(echo -e "  ${YELLOW}Download the Kokoro model now? [y/N]:${RESET} ")" yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    echo ""
    printf "${STEP}  %-55s" "Downloading kokoro-v0_19.onnx (~310 MB)"
    if curl -fL --progress-bar \
        "${KOKORO_BASE}/${KOKORO_MODEL}" \
        -o "${HOME}/${KOKORO_MODEL}" 2>> "$LOG_FILE"; then
      echo -e "  ${GREEN}OK${RESET}"
      mark_ok "Kokoro model .onnx"
    else
      echo -e "  ${RED}FAILED${RESET}"
      mark_fail "Kokoro model .onnx"
    fi

    printf "${STEP}  %-55s" "Downloading voices.bin (~40 MB)"
    if curl -fL --progress-bar \
        "${KOKORO_BASE}/${KOKORO_VOICES}" \
        -o "${HOME}/${KOKORO_VOICES}" 2>> "$LOG_FILE"; then
      echo -e "  ${GREEN}OK${RESET}"
      mark_ok "Kokoro model voices.bin"
    else
      echo -e "  ${RED}FAILED${RESET}"
      mark_fail "Kokoro model voices.bin"
    fi
  else
    echo -e "${SKIP}  Skipping Kokoro. You can download it later from Lia's DevTools → 🔊 Voice Engine."
    mark_skip "Kokoro voice model (user declined)"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 12 — INPUT GROUP  (Wayland/evdev typing detection)
# ═══════════════════════════════════════════════════════════════════════════════
section "12 / Input group  (typing detection)"

if [[ "$OS" == "macos" ]]; then
  echo -e "${SKIP}  Not applicable on macOS"
  mark_skip "input group (macOS)"
elif groups "$USER" 2>/dev/null | grep -qw "input"; then
  echo -e "${OK}  '$USER' is already in the ${BOLD}input${RESET} group — typing detection will work"
  mark_ok "input group"
else
  echo -e "${WARN}  '$USER' is not in the 'input' group."
  echo -e "  Without this, Lia cannot detect keyboard typing on Wayland/X11."
  echo ""
  read -r -p "$(echo -e "  ${YELLOW}Add $USER to the input group now? (requires sudo) [y/N]:${RESET} ")" yn
  if [[ "$yn" =~ ^[Yy]$ ]] && [[ "$CAN_SUDO" == true ]]; then
    if sudo usermod -aG input "$USER" >> "$LOG_FILE" 2>&1; then
      echo -e "${OK}  Added to 'input' group — ${BOLD}you must log out & back in for this to take effect${RESET}"
      mark_ok "input group (needs re-login)"
    else
      echo -e "${FAIL}  Could not add to group. Run manually: ${CYAN}sudo usermod -aG input $USER${RESET}"
      mark_fail "input group"
    fi
  else
    echo -e "${SKIP}  Skipped. Run manually if needed: ${CYAN}sudo usermod -aG input $USER${RESET}"
    mark_skip "input group (manual)"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 13 — DESKTOP SHORTCUT
# ═══════════════════════════════════════════════════════════════════════════════
section "13 / Desktop shortcut"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$APPS_DIR/Lia.desktop"

if [[ "$OS" == "macos" ]]; then
  echo -e "${SKIP}  Desktop shortcuts are managed by macOS — not applicable"
  mark_skip "desktop shortcut (macOS)"
elif [[ -f "$DESKTOP_FILE" ]]; then
  echo -e "${OK}  Desktop shortcut already installed"
  mark_skip "desktop shortcut (already exists)"
else
  mkdir -p "$APPS_DIR"

  # Install icon
  ICON_SRC="$SCRIPT_DIR/icon.png"
  ICON_NAME="lia"
  if [[ -f "$ICON_SRC" ]]; then
    if has convert; then
      for SZ in 16 32 48 64 128 256 512; do
        ICON_DIR="$HOME/.local/share/icons/hicolor/${SZ}x${SZ}/apps"
        mkdir -p "$ICON_DIR"
        convert "$ICON_SRC" -resize "${SZ}x${SZ}" "$ICON_DIR/${ICON_NAME}.png" &>/dev/null || true
      done
      echo -e "${OK}  Icon installed at all standard sizes (16–512px)"
    else
      ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
      mkdir -p "$ICON_DIR"
      cp "$ICON_SRC" "$ICON_DIR/${ICON_NAME}.png"
      echo -e "${OK}  Icon installed at 256px (install ImageMagick for all sizes)"
    fi
    has gtk-update-icon-cache && \
      gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" &>/dev/null || true
  fi

  # Write .desktop file
  cat > "$DESKTOP_FILE" << DEOF
[Desktop Entry]
Name=Lia
Comment=Your AI Companion
Exec=bash -c 'cd "${SCRIPT_DIR}" && ./start_lia.sh'
Icon=${ICON_NAME}
Type=Application
Terminal=true
Categories=Utility;
StartupWMClass=Lia
DEOF
  chmod +x "$DESKTOP_FILE"

  # Refresh launcher databases
  has update-desktop-database && update-desktop-database "$APPS_DIR" &>/dev/null || true
  has xdg-desktop-menu && xdg-desktop-menu forceupdate &>/dev/null || true

  # Desktop shortcut
  if [[ -d "$HOME/Desktop" ]]; then
    cp "$DESKTOP_FILE" "$HOME/Desktop/Lia.desktop"
    chmod +x "$HOME/Desktop/Lia.desktop"
    echo -e "${OK}  Shortcut placed on Desktop"
  fi

  echo -e "${OK}  Desktop shortcut installed → Lia will appear in your app launcher"
  mark_ok "desktop shortcut"
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 14 — VERIFY EVERYTHING
# ═══════════════════════════════════════════════════════════════════════════════
section "14 / Verification"

echo -e "${BOLD}  Checking key tools are reachable:${RESET}"
echo ""

check_tool() {
  local label="$1"
  local cmd="$2"
  local optional="${3:-false}"
  printf "    %-40s" "$label"
  if has "$cmd"; then
    local ver
    ver=$("$cmd" --version 2>/dev/null | head -1 || echo "installed")
    echo -e "${GREEN}✔${RESET}  ${DIM}$ver${RESET}"
  elif [[ "$optional" == true ]]; then
    echo -e "${YELLOW}–${RESET}  ${DIM}optional, not found${RESET}"
  else
    echo -e "${RED}✘${RESET}  ${DIM}not found — check log${RESET}"
  fi
}

check_tool "python3"           python3
check_tool "pip3"              pip3
check_tool "curl"              curl
check_tool "ffmpeg"            ffmpeg            true
check_tool "ollama"            ollama            true
check_tool "imagemagick"       convert           true
check_tool "playerctl"         playerctl         true
check_tool "edge-tts"          edge-tts          true

echo ""
echo -e "${BOLD}  Checking Python packages:${RESET}"
echo ""

check_py_pkg() {
  local label="$1"
  local module="$2"
  local optional="${3:-false}"
  printf "    %-40s" "$label"
  if python3 -c "import $module" &>/dev/null 2>&1; then
    local ver
    ver=$(python3 -c "import $module; print(getattr($module,'__version__','installed'))" 2>/dev/null || echo "ok")
    echo -e "${GREEN}✔${RESET}  ${DIM}$ver${RESET}"
  elif [[ "$optional" == true ]]; then
    echo -e "${YELLOW}–${RESET}  ${DIM}optional, not installed${RESET}"
  else
    echo -e "${RED}✘${RESET}  ${DIM}not installed — run: pip3 install $module${RESET}"
  fi
}

check_py_pkg "flask"           flask
check_py_pkg "requests"        requests
check_py_pkg "psutil"          psutil
check_py_pkg "PIL (Pillow)"    PIL
check_py_pkg "PyPDF2"          PyPDF2
check_py_pkg "reportlab"       reportlab
check_py_pkg "ollama"          ollama
check_py_pkg "anthropic"       anthropic
check_py_pkg "groq"            groq
check_py_pkg "discord"         discord
check_py_pkg "edge_tts"        edge_tts          true
check_py_pkg "piper"           piper             true
check_py_pkg "kokoro_onnx"     kokoro_onnx       true
check_py_pkg "yt_dlp"          yt_dlp
check_py_pkg "telebot"         telebot           true
check_py_pkg "evdev"           evdev             true

# ═══════════════════════════════════════════════════════════════════════════════
#  SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
section "Installation Summary"

echo -e "${GREEN}${BOLD}  ✔  Installed  (${#INSTALLED[@]})${RESET}"
for item in "${INSTALLED[@]}"; do
  echo -e "       ${GREEN}•${RESET}  $item"
done

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  echo ""
  echo -e "${GREY}${BOLD}  ⊘  Skipped  (${#SKIPPED[@]})${RESET}"
  for item in "${SKIPPED[@]}"; do
    echo -e "       ${GREY}•${RESET}  $item"
  done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo ""
  echo -e "${RED}${BOLD}  ✘  Failed  (${#FAILED[@]})${RESET}"
  for item in "${FAILED[@]}"; do
    echo -e "       ${RED}•${RESET}  $item"
  done
  echo ""
  echo -e "${WARN}  Some items failed. Check the log for details:"
  echo -e "  ${CYAN}$LOG_FILE${RESET}"
fi

echo ""
echo -e "${PINK}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ ${#FAILED[@]} -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}  🌸  All done!  Lia is ready to launch.${RESET}"
else
  echo -e "${YELLOW}${BOLD}  🌸  Installation complete with some warnings.${RESET}"
fi

echo ""
echo -e "${BOLD}  To start Lia:${RESET}"
echo -e "    ${CYAN}cd $(dirname "$(realpath "$0")") && ./start_lia.sh${RESET}"
echo ""
echo -e "${BOLD}  Or open it from your app launcher / Desktop shortcut.${RESET}"
echo ""
echo -e "${DIM}  Full log: $LOG_FILE${RESET}"
echo -e "${PINK}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
