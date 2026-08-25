#!/bin/sh
set -eu

REPO=${REPO:-3899/SimAdminHub}
GH_PROXY=${GH_PROXY:-https://gh-proxy.com/}
GH_PROXY_FALLBACKS=${GH_PROXY_FALLBACKS:-https://ghproxy.net/ https://githubproxy.cc/}
SCRIPT_URL=${SCRIPT_URL:-https://raw.githubusercontent.com/${REPO}/main/uninstall.sh}
PURGE=false

usage() {
  cat <<'EOF'
Usage: uninstall.sh [options]

Options:
  --purge     Also permanently remove Hub data, backups, configuration,
              Host Agent identity and the Docker volume
  -h, --help  Show this help

Without --purge, application data and configuration are preserved.
EOF
}

download_with_proxies() {
  source_url=$1
  destination=$2
  for proxy in $GH_PROXY $GH_PROXY_FALLBACKS ""; do
    candidate=${proxy}${source_url}
    echo "Downloading $candidate"
    if curl -fsSL "$candidate" -o "$destination"; then
      return 0
    fi
    echo 'Download failed, trying the next address.' >&2
  done
  return 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --purge)
      PURGE=true
      shift
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

if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 || {
    echo 'Root privileges are required and sudo is unavailable.' >&2
    exit 1
  }
  command -v curl >/dev/null 2>&1 || {
    echo 'curl is required.' >&2
    exit 1
  }
  elevated_script=$(mktemp)
  trap 'rm -f "$elevated_script"' 0 HUP INT TERM
  download_with_proxies "$SCRIPT_URL" "$elevated_script"
  if [ "$PURGE" = true ]; then
    sudo -E sh "$elevated_script" --purge
  else
    sudo -E sh "$elevated_script"
  fi
  exit
fi

if command -v systemctl >/dev/null 2>&1; then
  for service in \
    simadmin-host-agent-control.path \
    simadmin-host-agent-control.service \
    simadmin-host-agent.service \
    simadminhub.service
  do
    systemctl disable --now "$service" >/dev/null 2>&1 || true
  done
fi

if command -v docker >/dev/null 2>&1; then
  container_id=$(docker ps -aq --filter 'name=^/simadminhub$' 2>/dev/null || true)
  if [ -n "$container_id" ]; then
    docker rm -f "$container_id" >/dev/null
  fi
fi

rm -f \
  /etc/systemd/system/simadminhub.service \
  /etc/systemd/system/simadmin-host-agent.service \
  /etc/systemd/system/simadmin-host-agent-control.service \
  /etc/systemd/system/simadmin-host-agent-control.path \
  /usr/local/bin/simadminhub \
  /usr/local/bin/simadmin-host-agent \
  /usr/local/libexec/simadminhub-host-agent-control
rm -rf /opt/simadminhub

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload
  systemctl reset-failed >/dev/null 2>&1 || true
fi

if [ "$PURGE" = true ]; then
  rm -rf \
    /etc/simadminhub \
    /etc/simadmin-host-agent \
    /var/lib/simadminhub \
    /var/lib/simadmin-host-agent
  if command -v docker >/dev/null 2>&1; then
    docker volume rm simadminhub >/dev/null 2>&1 || true
  fi
  userdel simadminhub >/dev/null 2>&1 || true
  groupdel simadminhub >/dev/null 2>&1 || true
  echo 'SimAdminHub, Host Agent, configuration and data were removed.'
else
  echo 'SimAdminHub and Host Agent were removed.'
  echo 'Configuration and data were preserved in:'
  echo '  /etc/simadminhub'
  echo '  /etc/simadmin-host-agent'
  echo '  /var/lib/simadminhub'
  echo '  /var/lib/simadmin-host-agent'
  echo '  Docker volume: simadminhub'
  echo 'Run uninstall.sh --purge only when these data are no longer needed.'
fi
