#!/bin/sh
set -eu

REPO=${REPO:-3899/SimAdminHub}
GH_PROXY=${GH_PROXY:-https://gh-proxy.com/}
GH_PROXY_FALLBACKS=${GH_PROXY_FALLBACKS:-https://ghproxy.net/ https://githubproxy.cc/}
SCRIPT_URL=${SCRIPT_URL:-https://raw.githubusercontent.com/${REPO}/main/install.sh}
RELEASE_BASE=${RELEASE_BASE:-https://github.com/${REPO}/releases}
COMPONENT=all
VERSION=latest
HUB_URL=

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --component all|hub|host-agent  Installed components (default: all)
  --hub-url URL                   Hub URL for a Host Agent-only installation
  --version VERSION               Release version, with or without leading v
  -h, --help                      Show this help

Environment:
  GH_PROXY URL                    Primary GitHub download prefix
  GH_PROXY_FALLBACKS "URL URL"    Fallback prefixes before direct download
EOF
}

download_with_proxies() {
  source_url=$1
  destination=$2
  case "$source_url" in
    https://github.com/*|https://raw.githubusercontent.com/*|https://objects.githubusercontent.com/*|https://api.github.com/*)
      for proxy in $GH_PROXY $GH_PROXY_FALLBACKS ""; do
        candidate=${proxy}${source_url}
        echo "Downloading $candidate"
        if curl -fsSL "$candidate" -o "$destination"; then
          return 0
        fi
        echo 'Download failed, trying the next address.' >&2
      done
      ;;
    *)
      curl -fsSL "$source_url" -o "$destination"
      return $?
      ;;
  esac
  return 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --component)
      [ "$#" -ge 2 ] || { echo '--component requires a value' >&2; exit 2; }
      COMPONENT=$2
      shift 2
      ;;
    --hub-url)
      [ "$#" -ge 2 ] || { echo '--hub-url requires a value' >&2; exit 2; }
      HUB_URL=$2
      shift 2
      ;;
    --version)
      [ "$#" -ge 2 ] || { echo '--version requires a value' >&2; exit 2; }
      VERSION=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

case "$COMPONENT" in
  all|hub|host-agent) ;;
  *) echo "Unsupported component: $COMPONENT" >&2; exit 2 ;;
esac
if [ "$COMPONENT" != host-agent ] && [ -n "$HUB_URL" ]; then
  echo '--hub-url is only valid with --component host-agent' >&2
  exit 2
fi

if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 || { echo 'Root privileges are required and sudo is unavailable.' >&2; exit 1; }
  command -v curl >/dev/null 2>&1 || { echo 'curl is required.' >&2; exit 1; }
  ELEVATED_SCRIPT=$(mktemp)
  trap 'rm -f "$ELEVATED_SCRIPT"' 0 HUP INT TERM
  download_with_proxies "$SCRIPT_URL" "$ELEVATED_SCRIPT"
  if [ -n "$HUB_URL" ]; then
    sudo -E sh "$ELEVATED_SCRIPT" --component "$COMPONENT" --version "$VERSION" --hub-url "$HUB_URL"
  else
    sudo -E sh "$ELEVATED_SCRIPT" --component "$COMPONENT" --version "$VERSION"
  fi
  exit
fi

for command in bash curl mktemp tar uname; do
  command -v "$command" >/dev/null 2>&1 || { echo "Required command not found: $command" >&2; exit 1; }
done

case "$(uname -m)" in
  x86_64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=aarch64 ;;
  armv7l|armv7|armhf) ARCH=armv7 ;;
  *) echo "Unsupported host architecture: $(uname -m)" >&2; exit 1 ;;
esac

ARCHIVE=simadminhub-${ARCH}.tar.gz
if [ "$VERSION" = latest ]; then
  DOWNLOAD_URL=${RELEASE_BASE}/latest/download/${ARCHIVE}
else
  case "$VERSION" in v*) TAG=$VERSION ;; *) TAG=v$VERSION ;; esac
  DOWNLOAD_URL=${RELEASE_BASE}/download/${TAG}/${ARCHIVE}
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' 0 HUP INT TERM
download_with_proxies "$DOWNLOAD_URL" "$WORK/$ARCHIVE"
tar -tzf "$WORK/$ARCHIVE" >/dev/null
tar -xzf "$WORK/$ARCHIVE" -C "$WORK"
PACKAGE_ROOT=$WORK/simadminhub-${ARCH}
[ -f "$PACKAGE_ROOT/install.sh" ] || { echo "Installer is missing from $ARCHIVE." >&2; exit 1; }

set -- --component "$COMPONENT"
if [ -n "$HUB_URL" ]; then
  set -- "$@" --hub-url "$HUB_URL"
fi
bash "$PACKAGE_ROOT/install.sh" "$@"
