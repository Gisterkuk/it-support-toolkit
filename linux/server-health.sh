#!/usr/bin/env bash
# server-health.sh - quick health check for a Linux server, in one screen.
#
# Shows host and uptime, load vs CPU count, memory, disk usage, failed systemd
# services, Docker containers that are not running, recent reboots and listening
# ports. Flags anything over the thresholds.
#
# Read-only. Works without root (some details, like process names on ports, need sudo).
# Skips any section whose tool is not installed.
#
# Usage:
#   ./server-health.sh
#   DISK_WARN=80 MEM_WARN=85 ./server-health.sh
#
# Exit code: 0 = no warnings, 1 = at least one warning (handy for cron or monitoring).

set -uo pipefail

DISK_WARN="${DISK_WARN:-85}"   # warn when a filesystem is this % full or more
MEM_WARN="${MEM_WARN:-90}"     # warn when memory in use is this % or more

WARNINGS=0

section() { printf '\n== %s ==\n' "$1"; }
warn()    { printf 'WARN: %s\n' "$1"; WARNINGS=$((WARNINGS + 1)); }
have()    { command -v "$1" >/dev/null 2>&1; }

section "Host"
printf 'Hostname : %s\n' "$(hostname)"
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  printf 'OS       : %s\n' "${PRETTY_NAME:-unknown}"
fi
printf 'Kernel   : %s\n' "$(uname -r)"
if have uptime; then
  printf 'Uptime   : %s\n' "$(uptime -p 2>/dev/null || uptime)"
fi

section "CPU load"
cpus=1
if have nproc; then cpus=$(nproc); fi
if [ -r /proc/loadavg ]; then
  read -r load1 load5 load15 _ < /proc/loadavg
  printf 'Load (1/5/15 min): %s %s %s on %s CPU(s)\n' "$load1" "$load5" "$load15" "$cpus"
  # A 5-minute load above the number of CPUs means work is queuing.
  if awk -v l="$load5" -v c="$cpus" 'BEGIN { exit !(l > c) }'; then
    warn "5-minute load ($load5) is higher than the CPU count ($cpus)"
  fi
fi

section "Memory"
if [ -r /proc/meminfo ]; then
  total_kb=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
  avail_kb=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)
  if [ -z "$avail_kb" ]; then
    # Old kernels have no MemAvailable: approximate with free + buffers + cache.
    avail_kb=$(awk '/^(MemFree|Buffers|Cached):/ { s += $2 } END { print s + 0 }' /proc/meminfo)
  fi
  if [ -n "$total_kb" ] && [ -n "$avail_kb" ] && [ "$total_kb" -gt 0 ]; then
    used_pct=$(( (total_kb - avail_kb) * 100 / total_kb ))
    printf 'In use: %s%% (%s MB available of %s MB)\n' "$used_pct" "$((avail_kb / 1024))" "$((total_kb / 1024))"
    if [ "$used_pct" -ge "$MEM_WARN" ]; then
      warn "memory in use is ${used_pct}%"
    fi
  fi
fi

section "Disks"
df -P -h -x tmpfs -x devtmpfs -x overlay -x squashfs 2>/dev/null || df -P -h
# Read the "Use%" column and the mount point from the end of each line, so device
# names or mount points with spaces do not shift the columns.
while IFS=$'\t' read -r pct mount; do
  case "$pct" in ''|*[!0-9]*) continue ;; esac
  if [ "$pct" -ge "$DISK_WARN" ]; then
    warn "$mount is ${pct}% full"
  fi
done < <(df -P -x tmpfs -x devtmpfs -x overlay -x squashfs 2>/dev/null | awk 'NR > 1 {
  for (i = NF; i > 1; i--) {
    if ($i ~ /^[0-9]+%$/) {
      mnt = $(i + 1)
      for (j = i + 2; j <= NF; j++) mnt = mnt " " $j
      print substr($i, 1, length($i) - 1) "\t" mnt
      break
    }
  }
}')

if have systemctl && [ -d /run/systemd/system ]; then
  section "Failed services"
  failed=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{ print $1 }')
  if [ -n "$failed" ]; then
    printf '%s\n' "$failed"
    while read -r unit; do
      warn "service $unit has failed (see: journalctl -u $unit -n 50)"
    done <<< "$failed"
  else
    echo "None."
  fi
fi

if have docker && docker info >/dev/null 2>&1; then
  section "Docker containers"
  docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
  while read -r name status; do
    [ -z "$name" ] && continue
    case "$status" in
      Up*unhealthy*) warn "container $name is unhealthy (see: docker logs --tail 50 $name)" ;;
      Up*) ;;
      *) warn "container $name is not running: $status" ;;
    esac
  done < <(docker ps -a --format '{{.Names}} {{.Status}}')
fi

if have last; then
  section "Last reboots"
  last -x reboot 2>/dev/null | head -n 3 || true
fi

if have ss; then
  section "Listening ports"
  ss -tuln 2>/dev/null | awk 'NR == 1 || /LISTEN|UNCONN/' | head -n 20
fi

section "Summary"
if [ "$WARNINGS" -eq 0 ]; then
  echo "OK: no warnings."
  exit 0
fi
echo "$WARNINGS warning(s) found."
exit 1
