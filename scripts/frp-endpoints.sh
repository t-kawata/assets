#!/usr/bin/env bash
set -euo pipefail

cfg="${1:-$HOME/shyme/frp/frpc.toml}"

awk -v OFS='' '
function trim(s) {
  gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
  return s
}
function unquote(s) {
  s = trim(s)
  sub(/^"/, "", s)
  sub(/"$/, "", s)
  return s
}
function flush() {
  if (current_name != "" && current_remote_port != "") {
    if (current_name ~ /^ssh-/) {
      ssh = server_addr ":" current_remote_port
    } else if (current_name ~ /^vnc-/) {
      vnc = server_addr ":" current_remote_port
    }
  }
  current_name = ""
  current_remote_port = ""
}
BEGIN {
  server_addr = ""
  ssh = ""
  vnc = ""
}
{
  line = $0
  sub(/#.*/, "", line)
  line = trim(line)
  if (line == "") next

  if (line ~ /^\[\[proxies\]\]$/) {
    flush()
    next
  }

  if (line ~ /^serverAddr[[:space:]]*=/) {
    split(line, a, "=")
    server_addr = unquote(a[2])
    next
  }

  if (line ~ /^name[[:space:]]*=/) {
    split(line, a, "=")
    current_name = unquote(a[2])
    next
  }

  if (line ~ /^remotePort[[:space:]]*=/) {
    split(line, a, "=")
    current_remote_port = trim(a[2])
    next
  }
}
END {
  flush()
  printf "[VNC] %s, [SSH] %s\n", vnc, ssh
}
' "$cfg"
