#!/bin/bash
# ==============================================================================
#  ZI-UDP Server Automated Installer & Manager (Hysteria 1 over UDP)
#  Repository: https://github.com/sugitan-byte/ziudp.git
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="/usr/local/bin"
BIN_PATH="${INSTALL_DIR}/hysteria-server"
CONFIG_DIR="/etc/hysteria"
CONFIG_FILE="${CONFIG_DIR}/config.json"
CERT_FILE="${CONFIG_DIR}/cert.crt"
KEY_FILE="${CONFIG_DIR}/private.key"
SERVICE_FILE="/etc/systemd/system/ziudp.service"
CLI_CMD="/usr/local/bin/ziudp"

HYSTERIA_VERSION="v1.3.5"

# Root check
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR] This script must be run as root! Use: sudo bash $0${NC}"
   exit 1
fi

clear
echo -e "${CYAN}${BOLD}"
echo "=========================================================="
echo "         ZI-UDP Server Automated Installer (Hysteria 1)   "
echo "         Repository: https://github.com/sugitan-byte/ziudp"
echo "=========================================================="
echo -e "${NC}"

# Detect Arch
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64)
        BIN_ARCH="amd64"
        ;;
    aarch64|arm64)
        BIN_ARCH="arm64"
        ;;
    *)
        echo -e "${RED}[ERROR] Unsupported architecture: ${ARCH}. Only x86_64 and arm64 are supported.${NC}"
        exit 1
        ;;
esac

# Detect OS & Package Manager
if [ -f /etc/debian_version ]; then
    OS="debian"
    export DEBIAN_FRONTEND=noninteractive
    PACKAGE_MANAGER="apt-get"
elif [ -f /etc/redhat-release ]; then
    OS="redhat"
    PACKAGE_MANAGER="yum"
else
    OS="unknown"
    echo -e "${YELLOW}[WARN] Unsupported or unrecognized Linux distribution. Trying anyway...${NC}"
fi

echo -e "${BLUE}[*] Updating system packages and installing dependencies...${NC}"
if [ "$OS" = "debian" ]; then
    apt-get update -y >/dev/null 2>&1
    apt-get install -y curl wget openssl iptables iptables-persistent netfilter-persistent jq >/dev/null 2>&1 || true
elif [ "$OS" = "redhat" ]; then
    yum install -y curl wget openssl iptables iptables-services jq >/dev/null 2>&1 || true
fi

# Detect Public IP
echo -e "${BLUE}[*] Detecting VPS Public IP address...${NC}"
SERVER_IP=$(curl -s4m5 https://api.ipify.org || curl -s4m5 https://ifconfig.me || curl -s4m5 https://icanhazip.com || echo "")
if [[ -z "$SERVER_IP" ]]; then
    read -rp "Could not detect Public IP automatically. Please enter your Server IP: " SERVER_IP
fi
echo -e "${GREEN}[+] Detected Server IP: ${BOLD}${SERVER_IP}${NC}"

# Interactive Configuration Inputs
echo ""
echo -e "${YELLOW}${BOLD}--- Configuration Settings ---${NC}"

# Internal Port
DEFAULT_INTERNAL_PORT="5667"
read -rp "Enter Internal Hysteria Port [Default: ${DEFAULT_INTERNAL_PORT}]: " INPUT_INTERNAL_PORT
INTERNAL_PORT=${INPUT_INTERNAL_PORT:-$DEFAULT_INTERNAL_PORT}

# Port Hopping Range
DEFAULT_PORT_RANGE="6000:19999"
read -rp "Enter UDP Port Hopping Range [Default: ${DEFAULT_PORT_RANGE}]: " INPUT_PORT_RANGE
PORT_RANGE=${INPUT_PORT_RANGE:-$DEFAULT_PORT_RANGE}

# Domain / SNI
DEFAULT_DOMAIN="udp3.zivpn.com"
read -rp "Enter Server Domain / SNI (or press Enter for ${DEFAULT_DOMAIN}): " INPUT_DOMAIN
SERVER_DOMAIN=${INPUT_DOMAIN:-$DEFAULT_DOMAIN}

# Obfuscation Key
RANDOM_OBFS=$(openssl rand -hex 4)
read -rp "Enter Obfuscation (obfs) Password [Press Enter for: ${RANDOM_OBFS}]: " INPUT_OBFS
OBFS_KEY=${INPUT_OBFS:-$RANDOM_OBFS}

# Auth Password
RANDOM_AUTH=$(openssl rand -hex 8)
read -rp "Enter Client Authentication (auth) Password [Press Enter for: ${RANDOM_AUTH}]: " INPUT_AUTH
AUTH_KEY=${INPUT_AUTH:-$RANDOM_AUTH}

echo ""
echo -e "${BLUE}[*] Downloading Hysteria 1 (${HYSTERIA_VERSION}) for ${BIN_ARCH}...${NC}"
DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/${HYSTERIA_VERSION}/hysteria-linux-${BIN_ARCH}"
mkdir -p "$CONFIG_DIR"
wget -qO "$BIN_PATH" "$DOWNLOAD_URL"
chmod +x "$BIN_PATH"

if [[ ! -f "$BIN_PATH" ]]; then
    echo -e "${RED}[ERROR] Failed to download Hysteria binary! Please check network or download URL.${NC}"
    exit 1
fi
echo -e "${GREEN}[+] Hysteria binary installed to ${BIN_PATH}${NC}"

# Generate Self-signed Certificate
echo -e "${BLUE}[*] Generating self-signed TLS certificates (10-year validity)...${NC}"
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=SG/ST=Singapore/L=Singapore/O=ZIUDP/OU=VPN/CN=${SERVER_DOMAIN}" \
    -keyout "$KEY_FILE" -out "$CERT_FILE" >/dev/null 2>&1
chmod 600 "$KEY_FILE"
chmod 644 "$CERT_FILE"

# Generate Server config.json
echo -e "${BLUE}[*] Creating Hysteria server config...${NC}"
cat <<EOF > "$CONFIG_FILE"
{
  "listen": ":${INTERNAL_PORT}",
  "protocol": "udp",
  "cert": "${CERT_FILE}",
  "key": "${KEY_FILE}",
  "obfs": "${OBFS_KEY}",
  "auth": {
    "mode": "passwords",
    "config": [
      "${AUTH_KEY}"
    ]
  },
  "alpn": "hysteria",
  "recv_window_conn": 1048576,
  "recv_window_client": 393216,
  "max_conn_client": 4096,
  "disable_mtu_discovery": false
}
EOF
chmod 600 "$CONFIG_FILE"

# Configure iptables Port Hopping
echo -e "${BLUE}[*] Configuring iptables UDP Port Forwarding (${PORT_RANGE} -> ${INTERNAL_PORT})...${NC}"
iptables -t nat -D PREROUTING -p udp --dport "$PORT_RANGE" -j REDIRECT --to-ports "$INTERNAL_PORT" 2>/dev/null || true
iptables -t nat -A PREROUTING -p udp --dport "$PORT_RANGE" -j REDIRECT --to-ports "$INTERNAL_PORT"

# Save iptables rules
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1 || true
elif command -v service >/dev/null 2>&1; then
    service iptables save >/dev/null 2>&1 || true
fi

# Kernel Network Performance Tuning (BBR, rmem, wmem)
echo -e "${BLUE}[*] Optimizing Linux network buffer & BBR settings...${NC}"
cat <<EOF > /etc/sysctl.d/99-ziudp.conf
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
EOF
sysctl --system >/dev/null 2>&1 || true

# Setup systemd Service
echo -e "${BLUE}[*] Creating systemd service (ziudp.service)...${NC}"
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=ZI-UDP Server (Hysteria 1)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${CONFIG_DIR}
ExecStart=${BIN_PATH} server -c ${CONFIG_FILE}
Restart=always
RestartSec=3s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ziudp >/dev/null 2>&1
systemctl restart ziudp

# Install CLI Management Script
cat << 'EOFCLI' > "$CLI_CMD"
#!/bin/bash
# ZI-UDP Management CLI
CONFIG_FILE="/etc/hysteria/config.json"
SERVICE_NAME="ziudp"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR] Please run as root! (sudo ziudp)${NC}"
   exit 1
fi

show_menu() {
    clear
    echo -e "${CYAN}${BOLD}=========================================="
    echo "       ZI-UDP Server Management Menu       "
    echo -e "==========================================${NC}"
    echo -e " 1) Show Client Configuration (ZIVPN JSON)"
    echo -e " 2) Add New User Password"
    echo -e " 3) Remove User Password"
    echo -e " 4) Change Obfuscation (obfs) Password"
    echo -e " 5) Check Server Status"
    echo -e " 6) View Live Logs"
    echo -e " 7) Restart Server"
    echo -e " 8) Reconfigure iptables Port Hopping"
    echo -e " 9) Uninstall ZI-UDP Server"
    echo -e " 0) Exit"
    echo -e "${CYAN}------------------------------------------${NC}"
    read -rp "Select an option [0-9]: " CHOICE
    case $CHOICE in
        1) show_config ;;
        2) add_user ;;
        3) remove_user ;;
        4) change_obfs ;;
        5) check_status ;;
        6) view_logs ;;
        7) restart_server ;;
        8) reconfig_iptables ;;
        9) uninstall_ziudp ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option!${NC}"; sleep 1; show_menu ;;
    esac
}

show_config() {
    SERVER_IP=$(curl -s4m5 https://api.ipify.org || curl -s4m5 https://ifconfig.me || echo "YOUR_SERVER_IP")
    OBFS=$(jq -r '.obfs' "$CONFIG_FILE" 2>/dev/null || echo "")
    FIRST_AUTH=$(jq -r '.auth.config[0]' "$CONFIG_FILE" 2>/dev/null || echo "")
    
    echo ""
    echo -e "${GREEN}${BOLD}=== ZIVPN / Ko Ko VPN Client Config (JSON) ===${NC}"
    cat <<EOFCFG
{
  "Country": "My Server 🇸🇬",
  "Region": "SG",
  "Server": "${SERVER_IP}",
  "ServerIP": "${SERVER_IP}",
  "Protocol": "Hysteria1 (UDP)",
  "Obfs": "${OBFS}",
  "Auth": "${FIRST_AUTH}",
  "Ports": [
    "6000-9500",
    "9501-13000",
    "13001-16500",
    "16501-19999"
  ],
  "UpMbps": "50",
  "DownMbps": "200",
  "Socks5Listen": "127.0.0.1:1080-1083",
  "Insecure": true,
  "RecvWindowConn": 1048576,
  "RecvWindow": 393216,
  "Engine": "libuz.so"
}
EOFCFG
    echo ""
    echo -e "${YELLOW}Press any key to return to menu...${NC}"
    read -n 1 -s -r
    show_menu
}

add_user() {
    read -rp "Enter new user password: " NEW_PASS
    if [[ -n "$NEW_PASS" ]]; then
        jq --arg pass "$NEW_PASS" '.auth.config += [$pass]' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        systemctl restart "$SERVICE_NAME"
        echo -e "${GREEN}[+] User '${NEW_PASS}' added successfully!${NC}"
    fi
    sleep 2
    show_menu
}

remove_user() {
    echo -e "${YELLOW}Current Users:${NC}"
    jq -r '.auth.config[]' "$CONFIG_FILE"
    read -rp "Enter password to remove: " REM_PASS
    if [[ -n "$REM_PASS" ]]; then
        jq --arg pass "$REM_PASS" '.auth.config = (.auth.config - [$pass])' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        systemctl restart "$SERVICE_NAME"
        echo -e "${GREEN}[+] User removed successfully!${NC}"
    fi
    sleep 2
    show_menu
}

change_obfs() {
    read -rp "Enter new Obfs key: " NEW_OBFS
    if [[ -n "$NEW_OBFS" ]]; then
        jq --arg obfs "$NEW_OBFS" '.obfs = $obfs' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        systemctl restart "$SERVICE_NAME"
        echo -e "${GREEN}[+] Obfs updated successfully!${NC}"
    fi
    sleep 2
    show_menu
}

check_status() {
    echo ""
    systemctl status "$SERVICE_NAME"
    echo ""
    echo -e "${YELLOW}Press any key to return to menu...${NC}"
    read -n 1 -s -r
    show_menu
}

view_logs() {
    echo -e "${YELLOW}Showing live logs (Press Ctrl+C to stop)...${NC}"
    journalctl -u "$SERVICE_NAME" -f
    show_menu
}

restart_server() {
    systemctl restart "$SERVICE_NAME"
    echo -e "${GREEN}[+] Server restarted!${NC}"
    sleep 1
    show_menu
}

reconfig_iptables() {
    read -rp "Enter UDP Port Hopping Range [Default: 6000:19999]: " NEW_RANGE
    NEW_RANGE=${NEW_RANGE:-"6000:19999"}
    PORT=$(jq -r '.listen' "$CONFIG_FILE" | tr -d ':')
    iptables -t nat -A PREROUTING -p udp --dport "$NEW_RANGE" -j REDIRECT --to-ports "$PORT"
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1 || true
    fi
    echo -e "${GREEN}[+] Port forwarding updated to ${NEW_RANGE} -> ${PORT}!${NC}"
    sleep 2
    show_menu
}

uninstall_ziudp() {
    read -rp "Are you sure you want to completely uninstall ZI-UDP? (y/N): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        rm -f "/etc/systemd/system/ziudp.service"
        rm -rf "/etc/hysteria"
        rm -f "/usr/local/bin/hysteria-server"
        rm -f "/usr/local/bin/ziudp"
        rm -f "/etc/sysctl.d/99-ziudp.conf"
        systemctl daemon-reload
        echo -e "${GREEN}[+] ZI-UDP server has been uninstalled successfully.${NC}"
        exit 0
    fi
    show_menu
}

show_menu
EOFCLI

chmod +x "$CLI_CMD"

# Verify service is running
sleep 1
if systemctl is-active --quiet ziudp; then
    SERVICE_STATUS="${GREEN}${BOLD}RUNNING${NC}"
else
    SERVICE_STATUS="${RED}${BOLD}FAILED (check: journalctl -u ziudp -e)${NC}"
fi

# Split Port Range for display
PORT_START=$(echo "$PORT_RANGE" | cut -d':' -f1)
PORT_END=$(echo "$PORT_RANGE" | cut -d':' -f2)

clear
echo -e "${GREEN}${BOLD}==========================================================${NC}"
echo -e "${GREEN}${BOLD}     ZI-UDP Server Installation Completed Successfully!   ${NC}"
echo -e "${GREEN}${BOLD}==========================================================${NC}"
echo -e " Status              : ${SERVICE_STATUS}"
echo -e " Server IP           : ${BOLD}${SERVER_IP}${NC}"
echo -e " Server Domain / SNI : ${BOLD}${SERVER_DOMAIN}${NC}"
echo -e " Internal Port       : ${BOLD}${INTERNAL_PORT}${NC}"
echo -e " Port Hopping Range  : ${BOLD}${PORT_START}-${PORT_END} (UDP)${NC}"
echo -e " Obfuscation (obfs)  : ${BOLD}${OBFS_KEY}${NC}"
echo -e " Auth Password       : ${BOLD}${AUTH_KEY}${NC}"
echo -e " Management Command  : ${YELLOW}${BOLD}ziudp${NC} (Type 'ziudp' anytime to manage server)"
echo -e "${GREEN}${BOLD}==========================================================${NC}"
echo ""

echo -e "${CYAN}${BOLD}[1] Ko Ko VPN / ZIVPN Client Configuration JSON:${NC}"
echo -e "${YELLOW}Copy and paste this into your App Server Config or NetworkPayload:${NC}"
echo ""
cat <<EOFOUT
{
  "Country": "My Server 🇸🇬",
  "Region": "SG",
  "Server": "${SERVER_DOMAIN}",
  "ServerIP": "${SERVER_IP}",
  "Protocol": "Hysteria1 (UDP)",
  "Obfs": "${OBFS_KEY}",
  "Auth": "${AUTH_KEY}",
  "Ports": [
    "6000-9500",
    "9501-13000",
    "13001-16500",
    "16501-19999"
  ],
  "UpMbps": "50",
  "DownMbps": "200",
  "Socks5Listen": "127.0.0.1:1080-1083",
  "Insecure": true,
  "RecvWindowConn": 1048576,
  "RecvWindow": 393216,
  "Engine": "libuz.so"
}
EOFOUT

echo ""
echo -e "${CYAN}${BOLD}[2] Single-line JSON (For Admin Panel NetworkPayload):${NC}"
echo ""
echo "{\"Server\":\"${SERVER_DOMAIN}\",\"ServerIP\":\"${SERVER_IP}\",\"Protocol\":\"Hysteria1 (UDP)\",\"Obfs\":\"${OBFS_KEY}\",\"Auth\":\"${AUTH_KEY}\",\"Ports\":[\"6000-19999\"],\"UpMbps\":\"50\",\"DownMbps\":\"200\",\"Socks5Listen\":\"127.0.0.1:1080-1083\",\"Insecure\":true,\"RecvWindowConn\":1048576,\"RecvWindow\":393216,\"Engine\":\"libuz.so\"}"
echo ""
echo -e "${GREEN}${BOLD}Enjoy your high-speed ZI-UDP Tunnel!${NC}"
