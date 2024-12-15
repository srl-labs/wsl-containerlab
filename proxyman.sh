#!/bin/bash

# proxyman.sh
#
# Quick Start:
# 1. Run: sudo ./proxyman.sh set
# 2. Then run: eval "$(sudo ./proxyman.sh export)" to apply to current shell
# 3. To remove: sudo ./proxyman.sh unset; eval "$(sudo ./proxyman.sh unexport)"
# 4. To completely clean up: sudo ./proxyman.sh purge
#
# This script manages system-wide proxy settings on Linux systems (Debian/Ubuntu and RHEL/CentOS/Fedora).
#
# Features:
# - Reads from /etc/proxy.conf or prompts interactively if missing.
# - Configures proxies for:
#   * /etc/profile.d/custom_export.sh (to set env vars)
#   * Package manager (apt/dnf/yum)
#   * /etc/wgetrc
#   * Docker daemon (daemon.json + systemd drop-in)
#   * Per-user Docker config (~/.docker/config.json)
#
# On 'set', creates backups of configs (except custom_export.sh).
# On 'unset', restores from backups and removes custom_export.sh.
# On 'purge', removes all settings and backups.
#
# After setting proxy:
#   eval "$(sudo ./proxyman.sh export)" to apply proxy vars to current shell.
#
# After unsetting proxy:
#   eval "$(sudo ./proxyman.sh unexport)" to remove them from current shell.
#
# Run as root (sudo) because we modify system files.

##########################
# ANSI colors for better UX
##########################
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BOLD="\e[1m"
RESET="\e[0m"

##########################
# Configuration file paths
##########################
CONFIG_FILE="/etc/proxy.conf"
WGET_CONF="/etc/wgetrc"
DOCKER_CONF="/etc/docker/daemon.json"
DOCKER_SYSTEMD_DIR="/etc/systemd/system/docker.service.d"
DOCKER_SYSTEMD_PROXY_CONF="${DOCKER_SYSTEMD_DIR}/http-proxy.conf"

# This is the new file for environment variables:
CUSTOM_EXPORT_FILE="/etc/profile.d/custom_export.sh"

##########################
# Backup file paths
##########################
WGET_BAK="${WGET_CONF}.bak"
DOCKER_BAK="${DOCKER_CONF}.bak"
DOCKER_SYSTEMD_BAK="${DOCKER_SYSTEMD_PROXY_CONF}.bak"

# Determine the user who invoked sudo (or root if not sudoed)
if [ -n "$SUDO_USER" ]; then
    USERNAME="$SUDO_USER"
else
    USERNAME="root"
fi
USER_HOME=$(eval echo "~$USERNAME")
USER_DOCKER_DIR="${USER_HOME}/.docker"
USER_DOCKER_CONF="${USER_DOCKER_DIR}/config.json"
USER_DOCKER_BAK="${USER_DOCKER_CONF}.bak"

##########################
# Detect package manager
##########################
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

##########################
# Print help message
##########################
print_help() {
    echo -e "${BOLD}Usage:${RESET} $0 {set|unset|list|export|unexport|purge|-h}"
    echo
    echo -e "${BOLD}Commands:${RESET}"
    echo "  set       - Set the proxy (from /etc/proxy.conf or interactively)"
    echo "  unset     - Unset the proxy and restore original configurations, removing $CUSTOM_EXPORT_FILE"
    echo "  purge     - Completely remove all proxy settings and backups"
    echo "  list      - List current proxy settings"
    echo "  export    - Print export commands for current shell"
    echo "  unexport  - Print unset commands for current shell"
    echo "  -h        - Show this help"
    echo
    echo "If /etc/proxy.conf is missing, you will be prompted interactively."
    echo
    echo "Examples:"
    echo "  sudo $0 set"
    echo "  eval \"\$(sudo $0 export)\""
    echo "  # Current shell now has proxy vars."
    echo
    echo "  sudo $0 unset"
    echo "  eval \"\$(sudo $0 unexport)\""
    echo "  # Current shell no longer has proxy vars."
    echo
    echo "  sudo $0 purge"
    echo "  # Remove all proxy settings and backups permanently."
}

##########################
# read_config:
# Load proxy vars from /etc/proxy.conf or prompt user if missing.
##########################
read_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}$CONFIG_FILE not found.${RESET}"
        echo -e "Would you like to set proxy interactively? [y/N]"
        read -r ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            echo "Enter HTTP proxy (e.g. http://proxy.example.com:8080):"
            read -r HTTP_PROXY
            echo "Enter HTTPS proxy (e.g. http://proxy.example.com:8080):"
            read -r HTTPS_PROXY

            DEFAULT_NO_PROXY="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,172.17.0.0/16"
            echo "Enter NO_PROXY [default: ${DEFAULT_NO_PROXY}]:"
            read -r NO_PROXY
            if [ -z "$NO_PROXY" ]; then
                NO_PROXY="$DEFAULT_NO_PROXY"
            fi

            if [ -z "$HTTP_PROXY" ] || [ -z "$HTTPS_PROXY" ] || [ -z "$NO_PROXY" ]; then
                echo -e "${RED}All required values (HTTP_PROXY, HTTPS_PROXY, NO_PROXY) must be provided.${RESET}"
                exit 1
            fi

            echo "Save these settings to $CONFIG_FILE for future runs? [y/N]"
            read -r save_ans
            if [[ "$save_ans" =~ ^[Yy]$ ]]; then
                cat > "$CONFIG_FILE" <<EOF
HTTP_PROXY=$HTTP_PROXY
HTTPS_PROXY=$HTTPS_PROXY
NO_PROXY=$NO_PROXY
EOF
                echo -e "${GREEN}Saved to $CONFIG_FILE.${RESET}"
            fi
        else
            echo -e "${RED}Please create $CONFIG_FILE or run again to set interactively.${RESET}"
            exit 1
        fi
    else
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    fi

    if [ -z "$HTTP_PROXY" ] || [ -z "$HTTPS_PROXY" ] || [ -z "$NO_PROXY" ]; then
        echo -e "${RED}HTTP_PROXY, HTTPS_PROXY, NO_PROXY must be set.${RESET}"
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

##########################
# maybe_reload_docker:
# Checks if docker is available and if containers are running.
# If containers are running, prompt user before restarting docker.
##########################
maybe_reload_docker() {
    if command -v docker &>/dev/null; then
        CONTAINERS=$(docker ps -q)
        if [ -n "$CONTAINERS" ]; then
            echo -e "${YELLOW}Docker service is running with active containers.${RESET}"
            echo "Restarting Docker will interrupt these containers."
            echo "Do you want to restart Docker now so changes take effect? [y/N]"
            read -r docker_ans
            if [[ ! "$docker_ans" =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}Skipping Docker restart. Changes won't take effect until Docker is restarted manually.${RESET}"
                return
            fi
        fi
        systemctl daemon-reload
        systemctl restart docker
    fi
}

##########################
# set_proxy:
# Now stores env vars in CUSTOM_EXPORT_FILE instead of /etc/environment
##########################
set_proxy() {
    read_config

    # Backup other files if needed (no backup for CUSTOM_EXPORT_FILE)
    backup_file_if_needed "$WGET_CONF" "${WGET_BAK}"
    backup_file_if_needed "$DOCKER_CONF" "${DOCKER_BAK}"
    backup_file_if_needed "$DOCKER_SYSTEMD_PROXY_CONF" "${DOCKER_SYSTEMD_BAK}"
    if [ -n "$PM_CONF" ]; then
        backup_file_if_needed "$PM_CONF" "$PM_BAK"
    fi

    # Create/update /etc/profile.d/custom_export.sh
    mkdir -p /etc/profile.d
    cat > "$CUSTOM_EXPORT_FILE" <<EOF
export http_proxy="$HTTP_PROXY"
export https_proxy="$HTTPS_PROXY"
export no_proxy="$NO_PROXY"
export HTTP_PROXY="$HTTP_PROXY"
export HTTPS_PROXY="$HTTPS_PROXY"
export NO_PROXY="$NO_PROXY"
EOF

    # Update package manager configs
    if [ -n "$PM_CONF" ] && [ -f "$PM_CONF" ]; then
        if [ -n "$APT_EXISTS" ]; then
            cp "$PM_BAK" "$PM_CONF"
            sed -i '/Acquire::.*Proxy/d' "$PM_CONF"
            echo "Acquire::HTTP::Proxy \"$HTTP_PROXY\";" >> "$PM_CONF"
            echo "Acquire::HTTPS::Proxy \"$HTTPS_PROXY\";" >> "$PM_CONF"
        elif [ -n "$DNF_EXISTS" ]; then
            cp "$PM_BAK" "$PM_CONF"
            sed -i '/proxy=/d' "$PM_CONF"
            echo "proxy=$HTTP_PROXY" >> "$PM_CONF"
        elif [ -n "$YUM_EXISTS" ]; then
            cp "$PM_BAK" "$PM_CONF"
            sed -i '/proxy=/d' "$PM_CONF"
            echo "proxy=$HTTP_PROXY" >> "$PM_CONF"
        fi
    fi

    # Update /etc/wgetrc
    cp "$WGET_BAK" "$WGET_CONF"
    sed -i '/use_proxy\|http_proxy\|https_proxy\|no_proxy/d' "$WGET_CONF"
    {
      echo "use_proxy = on"
      echo "http_proxy = $HTTP_PROXY"
      echo "https_proxy = $HTTPS_PROXY"
      echo "no_proxy = $NO_PROXY"
    } >> "$WGET_CONF"

    # Update Docker configs
    cp "$DOCKER_BAK" "$DOCKER_CONF"
    cat > "$DOCKER_CONF" <<EOF
{
  "http-proxy": "$HTTP_PROXY",
  "https-proxy": "$HTTPS_PROXY",
  "no-proxy": "$NO_PROXY"
}
EOF

    set_systemd_docker_proxy
    set_user_docker_proxy

    # Maybe reload docker
    maybe_reload_docker

    echo -e "${GREEN}Proxy set successfully.${RESET}"
    echo -e "System-wide files updated."
    echo
    echo -e "${YELLOW}To apply these vars to your current shell, run:${RESET}"
    echo "  eval \"\$(sudo $0 export)\""
    echo "or reopen your shell."
    echo
    echo "Or copy and paste these commands to export them now:"
    grep -E '^(export http_proxy|export https_proxy|export no_proxy|export HTTP_PROXY|export HTTPS_PROXY|export NO_PROXY)=' "$CUSTOM_EXPORT_FILE"
}

##########################
# unset_proxy:
# Removes proxy config and restores backups. Also removes $CUSTOM_EXPORT_FILE.
##########################
unset_proxy() {
    # Remove the custom export file
    rm -f "$CUSTOM_EXPORT_FILE"

    restore_file_if_exists "$WGET_CONF" "${WGET_BAK}"
    restore_file_if_exists "$DOCKER_CONF" "${DOCKER_BAK}"
    restore_file_if_exists "$DOCKER_SYSTEMD_PROXY_CONF" "${DOCKER_SYSTEMD_BAK}"
    if [ -n "$PM_CONF" ]; then
        restore_file_if_exists "$PM_CONF" "$PM_BAK"
    fi
    unset_user_docker_proxy
    unset_systemd_docker_proxy

    # Maybe reload docker
    maybe_reload_docker

    echo -e "${GREEN}Proxy unset successfully.${RESET}"
    echo "Original configurations restored."
    echo
    echo -e "${YELLOW}To remove these vars from your current shell, run:${RESET}"
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

    echo "From $CUSTOM_EXPORT_FILE:"
    if [ -f "$CUSTOM_EXPORT_FILE" ]; then
        grep -E 'export (http_proxy|https_proxy|no_proxy)' "$CUSTOM_EXPORT_FILE" || echo "No environment proxy set."
    else
        echo "No environment proxy set."
    fi

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
        echo "No apt/dnf/yum proxy set."
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
    # Print export commands from CUSTOM_EXPORT_FILE instead of ENV_FILE
    if [ -f "$CUSTOM_EXPORT_FILE" ]; then
        grep -E '^(export http_proxy|export https_proxy|export no_proxy|export HTTP_PROXY|export HTTPS_PROXY|export NO_PROXY)=' "$CUSTOM_EXPORT_FILE"
    fi
}

unexport_vars() {
    echo "unset http_proxy"
    echo "unset https_proxy"
    echo "unset no_proxy"
    echo "unset HTTP_PROXY"
    echo "unset HTTPS_PROXY"
    echo "unset NO_PROXY"
}

purge_backups() {
    rm -f "${WGET_BAK}" "${DOCKER_BAK}" "${DOCKER_SYSTEMD_BAK}"
    rm -f "${USER_DOCKER_BAK}"
    if [ -n "$PM_BAK" ]; then
        rm -f "$PM_BAK"
    fi
    echo -e "${GREEN}All backups removed.${RESET}"
}

purge_all() {
    echo -e "${RED}WARNING: This will remove all proxy settings and all backups permanently.${RESET}"
    echo "Are you sure? [y/N]"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Purge cancelled."
        exit 0
    fi

    unset_proxy
    purge_backups
    echo -e "${GREEN}Purge completed.${RESET} All proxy settings and backups removed."
}

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo).${RESET}"
    exit 1
fi

case "$1" in
  set)
    set_proxy
    ;;
  unset)
    unset_proxy
    ;;
  purge)
    purge_all
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
    echo -e "${RED}Invalid command: $1${RESET}"
    print_help
    ;;
esac

echo "Done."
