#!/bin/bash

# proxyman.sh
#
# A script to manage system-wide proxy settings on Linux systems (Debian/Ubuntu and RHEL/CentOS/Fedora).
#
# Features:
# - Reads proxy configuration from /etc/proxy.conf (no need to edit this script).
# - Manages:
#   * /etc/environment
#   * /etc/apt/apt.conf (Debian/Ubuntu) or /etc/dnf/dnf.conf (Fedora/RHEL) or /etc/yum.conf (CentOS/RHEL)
#   * /etc/wgetrc
#   * /etc/docker/daemon.json (system-wide Docker daemon)
#   * /etc/systemd/system/docker.service.d/http-proxy.conf (Docker systemd drop-in)
#   * $HOME/.docker/config.json (per-user Docker configuration)
#
# On 'set', creates backups if not already existing:
#   /etc/environment.bak
#   /etc/apt/apt.conf.bak or /etc/dnf/dnf.conf.bak or /etc/yum.conf.bak (depending on system)
#   /etc/wgetrc.bak
#   /etc/docker/daemon.json.bak
#   /etc/systemd/system/docker.service.d/http-proxy.conf.bak
#   ~/.docker/config.json.bak
#
# On 'unset', restores these backups.
#
# After 'set', run:
#   eval "$(sudo ./proxyman.sh export)"
# to load the environment into your current shell without reopening.
#
# After 'unset', run:
#   eval "$(sudo ./proxyman.sh unexport)"
# to remove them from your current shell.
#
# If you prefer, just copy the printed commands or reopen your shell.
#
# Docker per-user proxies:
# Sets proxies in ~/.docker/config.json for the user who invoked sudo.
# If run as root without sudo, uses root's home.
#
# Make sure /etc/proxy.conf contains:
#   HTTP_PROXY=http://proxy.example.com:8080
#   HTTPS_PROXY=http://proxy.example.com:8080
#   NO_PROXY=localhost,127.0.0.1,::1
#
# Run as root (sudo) because we modify system files.

CONFIG_FILE="/etc/proxy.conf"
ENV_FILE="/etc/environment"
WGET_CONF="/etc/wgetrc"
DOCKER_CONF="/etc/docker/daemon.json"
DOCKER_SYSTEMD_DIR="/etc/systemd/system/docker.service.d"
DOCKER_SYSTEMD_PROXY_CONF="${DOCKER_SYSTEMD_DIR}/http-proxy.conf"

ENV_BAK="${ENV_FILE}.bak"
WGET_BAK="${WGET_CONF}.bak"
DOCKER_BAK="${DOCKER_CONF}.bak"
DOCKER_SYSTEMD_BAK="${DOCKER_SYSTEMD_PROXY_CONF}.bak"

if [ -n "$SUDO_USER" ]; then
    USERNAME="$SUDO_USER"
else
    USERNAME="root"
fi
USER_HOME=$(eval echo "~$USERNAME")
USER_DOCKER_DIR="${USER_HOME}/.docker"
USER_DOCKER_CONF="${USER_DOCKER_DIR}/config.json"
USER_DOCKER_BAK="${USER_DOCKER_CONF}.bak"

# Detect package manager
APT_EXISTS=$(command -v apt)
DNF_EXISTS=$(command -v dnf)
YUM_EXISTS=$(command -v yum)

PM_CONF=""
PM_BAK=""

if [ -n "$APT_EXISTS" ]; then
    PM_CONF="/etc/apt/apt.conf"
    PM_BAK="${PM_CONF}.bak"
elif [ -n "$DNF_EXISTS" ]; then
    PM_CONF="/etc/dnf/dnf.conf"
    PM_BAK="${PM_CONF}.bak"
elif [ -n "$YUM_EXISTS" ]; then
    PM_CONF="/etc/yum.conf"
    PM_BAK="${PM_CONF}.bak"
fi

print_help() {
    echo "Usage: $0 {set|unset|list|export|unexport|-h}"
    echo
    echo "Commands:"
    echo "  set       - Set the proxy according to /etc/proxy.conf"
    echo "  unset     - Unset the proxy and restore original configurations"
    echo "  list      - List current proxy settings"
    echo "  export    - Print export commands to load proxy vars into current shell"
    echo "  unexport  - Print unset commands to remove proxy vars from current shell"
    echo "  -h        - Show this help"
    echo
    echo "Ensure that /etc/proxy.conf is configured with HTTP_PROXY, HTTPS_PROXY, NO_PROXY."
    echo
    echo "Examples:"
    echo "  sudo $0 set"
    echo "  eval \"\$(sudo $0 export)\""
    echo "  # Now your current shell has the proxy vars"
    echo
    echo "  sudo $0 unset"
    echo "  eval \"\$(sudo $0 unexport)\""
    echo "  # Now your current shell no longer has the proxy vars"
    echo
    echo "Or just copy the printed commands or reopen your shell."
}

read_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Config file $CONFIG_FILE not found. Please create it with HTTP_PROXY, HTTPS_PROXY, NO_PROXY."
        exit 1
    fi

    # shellcheck disable=SC1090
    source "$CONFIG_FILE"

    if [ -z "$HTTP_PROXY" ] || [ -z "$HTTPS_PROXY" ] || [ -z "$NO_PROXY" ]; then
        echo "Please set HTTP_PROXY, HTTPS_PROXY, NO_PROXY in $CONFIG_FILE"
        exit 1
    fi
}

backup_file_if_needed() {
    local file="$1"
    local backup="$2"
    if [ -n "$file" ]; then
        if [ -f "$file" ] && [ ! -f "$backup" ]; then
            cp "$file" "$backup"
        elif [ ! -f "$file" ] && [ ! -f "$backup" ]; then
            # If file doesn't exist yet, create empty and back up
            mkdir -p "$(dirname "$file")"
            touch "$file"
            cp "$file" "$backup"
        fi
    fi
}

restore_file_if_exists() {
    local file="$1"
    local backup="$2"
    if [ -n "$file" ]; then
        if [ -f "$backup" ]; then
            cp "$backup" "$file"
        else
            rm -f "$file"
        fi
    fi
}

set_user_docker_proxy() {
    mkdir -p "$USER_DOCKER_DIR"
    if [ -f "$USER_DOCKER_CONF" ] && [ ! -f "$USER_DOCKER_BAK" ]; then
        cp "$USER_DOCKER_CONF" "$USER_DOCKER_BAK"
    elif [ ! -f "$USER_DOCKER_CONF" ] && [ ! -f "$USER_DOCKER_BAK" ]; then
        touch "$USER_DOCKER_CONF"
        cp "$USER_DOCKER_CONF" "$USER_DOCKER_BAK"
    fi

    cat > "$USER_DOCKER_CONF" <<EOF
{
  "proxies": {
    "default": {
      "httpProxy": "$HTTP_PROXY",
      "httpsProxy": "$HTTPS_PROXY",
      "noProxy": "$NO_PROXY"
    }
  }
}
EOF

    chown "$USERNAME":"$USERNAME" "$USER_DOCKER_CONF"
}

unset_user_docker_proxy() {
    restore_file_if_exists "$USER_DOCKER_CONF" "$USER_DOCKER_BAK"
}

set_systemd_docker_proxy() {
    backup_file_if_needed "$DOCKER_SYSTEMD_PROXY_CONF" "$DOCKER_SYSTEMD_BAK"

    mkdir -p "$DOCKER_SYSTEMD_DIR"
    cat > "$DOCKER_SYSTEMD_PROXY_CONF" <<EOF
[Service]
Environment="HTTP_PROXY=$HTTP_PROXY"
Environment="HTTPS_PROXY=$HTTPS_PROXY"
Environment="NO_PROXY=$NO_PROXY"
EOF
}

unset_systemd_docker_proxy() {
    restore_file_if_exists "$DOCKER_SYSTEMD_PROXY_CONF" "$DOCKER_SYSTEMD_BAK"
}


set_proxy() {
    read_config

    backup_file_if_needed "$ENV_FILE" "${ENV_BAK}"
    backup_file_if_needed "$WGET_CONF" "${WGET_BAK}"
    backup_file_if_needed "$DOCKER_CONF" "${DOCKER_BAK}"
    backup_file_if_needed "$DOCKER_SYSTEMD_PROXY_CONF" "${DOCKER_SYSTEMD_BAK}"
    if [ -n "$PM_CONF" ]; then
        backup_file_if_needed "$PM_CONF" "$PM_BAK"
    fi

    # /etc/environment
    cp "$ENV_BAK" "$ENV_FILE"
    sed -i '/http_proxy\|https_proxy\|no_proxy\|HTTP_PROXY\|HTTPS_PROXY\|NO_PROXY/d' "$ENV_FILE"
    {
      echo "http_proxy=\"$HTTP_PROXY\""
      echo "https_proxy=\"$HTTPS_PROXY\""
      echo "no_proxy=\"$NO_PROXY\""
      echo "HTTP_PROXY=\"$HTTP_PROXY\""
      echo "HTTPS_PROXY=\"$HTTPS_PROXY\""
      echo "NO_PROXY=\"$NO_PROXY\""
    } >> "$ENV_FILE"

    # Package manager
    if [ -n "$PM_CONF" ] && [ -f "$PM_CONF" ]; then
        if [ -n "$APT_EXISTS" ]; then
            # APT
            cp "$PM_BAK" "$PM_CONF"
            sed -i '/Acquire::.*Proxy/d' "$PM_CONF"
            echo "Acquire::HTTP::Proxy \"$HTTP_PROXY\";" >> "$PM_CONF"
            echo "Acquire::HTTPS::Proxy \"$HTTPS_PROXY\";" >> "$PM_CONF"
        elif [ -n "$DNF_EXISTS" ]; then
            # DNF
            cp "$PM_BAK" "$PM_CONF"
            sed -i '/proxy=/d' "$PM_CONF"
            echo "proxy=$HTTP_PROXY" >> "$PM_CONF"
        elif [ -n "$YUM_EXISTS" ]; then
            # YUM
            cp "$PM_BAK" "$PM_CONF"
            sed -i '/proxy=/d' "$PM_CONF"
            echo "proxy=$HTTP_PROXY" >> "$PM_CONF"
        fi
    fi

    # /etc/wgetrc
    cp "$WGET_BAK" "$WGET_CONF"
    sed -i '/use_proxy\|http_proxy\|https_proxy\|no_proxy/d' "$WGET_CONF"
    {
      echo "use_proxy = on"
      echo "http_proxy = $HTTP_PROXY"
      echo "https_proxy = $HTTPS_PROXY"
      echo "no_proxy = $NO_PROXY"
    } >> "$WGET_CONF"

    # /etc/docker/daemon.json
    cp "$DOCKER_BAK" "$DOCKER_CONF"
    cat > "$DOCKER_CONF" <<EOF
{
  "http-proxy": "$HTTP_PROXY",
  "https-proxy": "$HTTPS_PROXY",
  "no-proxy": "$NO_PROXY"
}
EOF

    # systemd docker proxy
    set_systemd_docker_proxy

    # Per-user docker config
    set_user_docker_proxy

    if command -v docker &>/dev/null; then
        systemctl daemon-reload
        systemctl restart docker
    fi

    echo "Proxy set."
    echo "To apply these vars to your current shell, run:"
    echo "  eval \"\$(sudo $0 export)\""
    echo "or reopen your shell."
    echo
    echo "Or copy and paste these commands to export them now:"
    grep -E '^(http_proxy|https_proxy|no_proxy|HTTP_PROXY|HTTPS_PROXY|NO_PROXY)=' "$ENV_FILE" | sed 's/^/export /'
}

unset_proxy() {
    restore_file_if_exists "$ENV_FILE" "${ENV_BAK}"
    restore_file_if_exists "$WGET_CONF" "${WGET_BAK}"
    restore_file_if_exists "$DOCKER_CONF" "${DOCKER_BAK}"
    restore_file_if_exists "$DOCKER_SYSTEMD_PROXY_CONF" "${DOCKER_SYSTEMD_BAK}"
    if [ -n "$PM_CONF" ]; then
        restore_file_if_exists "$PM_CONF" "$PM_BAK"
    fi
    unset_user_docker_proxy
    unset_systemd_docker_proxy

    if command -v docker &>/dev/null; then
        systemctl daemon-reload
        systemctl restart docker
    fi

    echo "Proxy unset."
    echo "To remove these vars from your current shell, run:"
    echo "  eval \"\$(sudo $0 unexport)\""
    echo "or reopen your shell."
    echo
    echo "Or copy and paste these commands to unset them now:"
    echo "unset http_proxy"
    echo "unset https_proxy"
    echo "unset no_proxy"
    echo "unset HTTP_PROXY"
    echo "unset HTTPS_PROXY"
    echo "unset NO_PROXY"
}

list_proxy() {
    echo "Current proxy settings:"

    echo "Environment ($ENV_FILE):"
    grep -E 'http_proxy=|https_proxy=|no_proxy=' "$ENV_FILE" || echo "No environment proxy set."

    echo
    if [ -n "$PM_CONF" ] && [ -f "$PM_CONF" ]; then
        if [ -n "$APT_EXISTS" ]; then
            echo "APT ($PM_CONF):"
            grep -i 'Acquire::.*Proxy' "$PM_CONF" || echo "No apt proxy set."
        elif [ -n "$DNF_EXISTS" ]; then
            echo "DNF ($PM_CONF):"
            grep -i 'proxy=' "$PM_CONF" || echo "No dnf proxy set."
        elif [ -n "$YUM_EXISTS" ]; then
            echo "YUM ($PM_CONF):"
            grep -i 'proxy=' "$PM_CONF" || echo "No yum proxy set."
        fi
    else
        echo "No apt/dnf/yum proxy set (no supported package manager found or config not present)."
    fi

    echo
    echo "Wget ($WGET_CONF):"
    if [ -f "$WGET_CONF" ]; then
        grep -E 'use_proxy|http_proxy|https_proxy|no_proxy' "$WGET_CONF" || echo "No wget proxy set."
    else
        echo "No wget proxy set."
    fi

    if [ -f "$DOCKER_CONF" ]; then
        echo
        echo "Docker daemon.json ($DOCKER_CONF):"
        cat "$DOCKER_CONF"
    else
        echo
        echo "No Docker daemon proxy set."
    fi

    if [ -f "$DOCKER_SYSTEMD_PROXY_CONF" ]; then
        echo
        echo "Docker systemd drop-in ($DOCKER_SYSTEMD_PROXY_CONF):"
        cat "$DOCKER_SYSTEMD_PROXY_CONF"
    else
        echo
        echo "No Docker systemd drop-in proxy set."
    fi

    if [ -f "$USER_DOCKER_CONF" ]; then
        echo
        echo "User Docker config ($USER_DOCKER_CONF):"
        cat "$USER_DOCKER_CONF"
    else
        echo
        echo "No per-user Docker proxy set."
    fi
}

export_vars() {
    grep -E '^(http_proxy|https_proxy|no_proxy|HTTP_PROXY|HTTPS_PROXY|NO_PROXY)=' "$ENV_FILE" \
        | sed 's/^/export /'
}

unexport_vars() {
    echo "unset http_proxy"
    echo "unset https_proxy"
    echo "unset no_proxy"
    echo "unset HTTP_PROXY"
    echo "unset HTTPS_PROXY"
    echo "unset NO_PROXY"
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)."
    exit 1
fi

case "$1" in
  set)
    set_proxy
    ;;
  unset)
    unset_proxy
    ;;
  list)
    list_proxy
    ;;
  export)
    export_vars
    exit 0
    ;;
  unexport)
    unexport_vars
    exit 0
    ;;
  -h|--help)
    print_help
    ;;
  *)
    echo "Invalid command: $1"
    print_help
    ;;
esac

echo "Done."
