#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="mine-cloud-bot"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
ENV_FILE="${APP_DIR}/.env"

trap 'echo; echo "[ERROR] Installer stopped near line ${LINENO}. Check the message above." >&2' ERR

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo bash install.sh"
  exit 1
fi

clear || true
cat <<'BANNER'
╔══════════════════════════════════════════════╗
║             MINE CLOUD INSTALLER             ║
║          VPS MANAGER • RGN GAMING             ║
╚══════════════════════════════════════════════╝
BANNER

echo "[1/7] Installing system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3 python3-venv python3-pip python3-dev build-essential \
  libffi-dev libssl-dev git curl ca-certificates openssl

if ! command -v lxc >/dev/null 2>&1; then
  echo "[WARNING] LXC CLI was not found. The Discord bot can start, but VPS deployment commands need a working LXD/LXC host." 
  echo "          This installer will NOT install or reconfigure LXD automatically."
fi

read -r -s -p "Enter Discord Bot Token: " DISCORD_TOKEN
printf '\n'
if [[ -z "${DISCORD_TOKEN}" || "${#DISCORD_TOKEN}" -lt 50 ]]; then
  echo "[ERROR] Token is empty or looks too short. Create/reset a valid bot token and run again."
  exit 1
fi

read -r -p "Enter Owner Discord User ID: " MAIN_ADMIN_ID
if [[ ! "${MAIN_ADMIN_ID}" =~ ^[0-9]{15,25}$ ]]; then
  echo "[ERROR] Owner ID must be a 15-25 digit Discord user ID."
  exit 1
fi

read -r -p "Enter Bot Prefix [!]: " PREFIX
PREFIX="${PREFIX:-!}"
if [[ "${PREFIX}" == *$'\n'* || "${#PREFIX}" -gt 5 ]]; then
  echo "[ERROR] Prefix must be 1-5 characters and cannot contain a newline."
  exit 1
fi

read -r -p "Enter Bot Name [MINE CLOUD]: " BOT_NAME
BOT_NAME="${BOT_NAME:-MINE CLOUD}"
read -r -p "Enter VPS Host Public IP/Domain: " YOUR_SERVER_IP
if [[ -z "${YOUR_SERVER_IP}" || "${YOUR_SERVER_IP}" == *[[:space:]]* ]]; then
  echo "[ERROR] Enter a valid public IP or domain without spaces."
  exit 1
fi
read -r -p "Enter VPS User Role ID (optional, press Enter to auto-create): " VPS_USER_ROLE_ID
if [[ -n "${VPS_USER_ROLE_ID}" && ! "${VPS_USER_ROLE_ID}" =~ ^[0-9]{15,25}$ ]]; then
  echo "[ERROR] Role ID must be a 15-25 digit Discord role ID or left blank."
  exit 1
fi
read -r -p "Enter LXC Storage Pool [default]: " DEFAULT_STORAGE_POOL
DEFAULT_STORAGE_POOL="${DEFAULT_STORAGE_POOL:-default}"
read -r -p 'Web SSH URL format [http://{SERVER_IP}:{PORT}] (Enter for default): ' WEBSSH_URL_FORMAT
WEBSSH_URL_FORMAT="${WEBSSH_URL_FORMAT:-http://{SERVER_IP}:{PORT}}"

# Escape values for a dotenv double-quoted value.
dotenv_quote() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/}
  printf '"%s"' "$value"
}

SECRET_KEY="$(openssl rand -hex 32)"
THUMBNAIL_URL='https://cdn.discordapp.com/attachments/1572197795878928507/1573391970070429927/IMG-20261118-WA0520.jpg?ex=6b01d6f5&is=6b008575&hm=23aa465c40360a4e37c04725e13b7cbf1c2cb63d055b5bab19541ab9c13ecba4&'

 echo "[2/7] Creating private configuration (.env)..."
{
  printf 'DISCORD_TOKEN=%s\n' "$(dotenv_quote "$DISCORD_TOKEN")"
  printf 'BOT_NAME=%s\n' "$(dotenv_quote "$BOT_NAME")"
  printf 'PREFIX=%s\n' "$(dotenv_quote "$PREFIX")"
  printf 'YOUR_SERVER_IP=%s\n' "$(dotenv_quote "$YOUR_SERVER_IP")"
  printf 'MAIN_ADMIN_ID=%s\n' "$(dotenv_quote "$MAIN_ADMIN_ID")"
  printf 'VPS_USER_ROLE_ID=%s\n' "$(dotenv_quote "$VPS_USER_ROLE_ID")"
  printf 'DEFAULT_STORAGE_POOL=%s\n' "$(dotenv_quote "$DEFAULT_STORAGE_POOL")"
  printf 'BOT_VERSION=%s\n' '10.0-MINE-CLOUD'
  printf 'BOT_DEVELOPER=%s\n' 'RGN GAMING'
  printf 'BOT_THUMBNAIL_URL=%s\n' "$(dotenv_quote "$THUMBNAIL_URL")"
  printf 'BOT_ICON_URL=%s\n' "$(dotenv_quote "$THUMBNAIL_URL")"
  printf 'SECRET_KEY=%s\n' "$(dotenv_quote "$SECRET_KEY")"
  printf 'OWNER_IDS=%s\n' "$(dotenv_quote "$MAIN_ADMIN_ID")"
  printf 'LXC_BINARY=lxc\nLXC_BRIDGE=lxdbr0\n'
  printf 'WEBSSH_ENABLED=true\nWEBSSH_HOST=0.0.0.0\nWEBSSH_PORT=5000\n'
  printf 'WEBSSH_SERVER_IP=%s\n' "$(dotenv_quote "$YOUR_SERVER_IP")"
  printf 'WEBSSH_URL_FORMAT=%s\n' "$(dotenv_quote "$WEBSSH_URL_FORMAT")"
  printf 'WEBSSH_SESSION_TTL=1800\nWEBSSH_MAX_SESSIONS=200\nWEBSSH_SESSION_MAX_PER_IP=8\n'
  printf 'WEBSSH_ALLOW_PRIVATE_HOSTS=true\nWEBSSH_ALLOW_MANUAL_TARGETS=false\nWEBSSH_TRUST_PROXY_HEADERS=false\n'
  printf 'WEBSSH_DEFAULT_PIN=true\nWEBSSH_PIN_ATTEMPTS=5\nWEBSSH_CONNECT_TIMEOUT=15\n'
  printf 'DEFAULT_VPS_EXPIRATION_DAYS=30\nEXPIRATION_WARNING_DAYS=3\nEXPIRATION_AUTO_SUSPEND=true\nEXPIRATION_CHECK_INTERVAL=900\n'
  printf 'PUBLIC_VPS_ENABLED=false\nPUBLIC_VPS_MAX_RAM=8\nPUBLIC_VPS_MAX_CPU=2\nPUBLIC_VPS_MAX_DISK=40\nPUBLIC_VPS_EXPIRY_DAYS=3\nPUBLIC_VPS_MAX_PER_USER=1\nPUBLIC_VPS_MAX_PER_IP=1\nPUBLIC_VPS_REQUIRE_VERIFICATION=false\nPUBLIC_VPS_GLOBAL_LIMIT=100\n'
  printf 'PUBLIC_VPS_RENEWAL_ENABLED=false\nPUBLIC_VPS_RENEWAL_DAYS=3\nPUBLIC_VPS_RENEWAL_WINDOW_DAYS=1\nPUBLIC_VPS_COOLDOWN_HOURS=24\nPUBLIC_VPS_REQUIRE_ACCOUNT_AGE=3\n'
  printf 'RATE_LIMIT_COOLDOWN=2\nRATE_LIMIT_BURST=5\nRATE_LIMIT_MAX_VIOLATIONS=5\nRATE_LIMIT_ABUSE_TIMEOUT=120\n'
  printf 'LXC_TIMEOUT_DEFAULT=180\nCOMMAND_TIMEOUT_SECONDS=240\nMANAGE_PANEL_TIMEOUT=300\nCONSOLE_PANEL_TIMEOUT=600\nSTATS_REFRESH_SECONDS=5\nMAX_LIVE_REFRESHES=60\n'
  # Deliberately do not carry over the old HOST_MOTD remote-shell command.
  printf 'HOST_MOTD=\nHOST_MOTD_ALLOW_REMOTE=false\n'
} > "$ENV_FILE"
chmod 600 "$ENV_FILE"

 echo "[3/7] Preparing Python virtual environment..."
python3 -m venv "${APP_DIR}/.venv"
"${APP_DIR}/.venv/bin/python" -m pip install --upgrade pip wheel
"${APP_DIR}/.venv/bin/pip" install -r "${APP_DIR}/requirements.txt"

 echo "[4/7] Checking Python syntax..."
"${APP_DIR}/.venv/bin/python" -m py_compile "${APP_DIR}/bot.py"

 echo "[5/7] Creating systemd service..."
cat > "$SERVICE_FILE" <<SERVICE
[Unit]
Description=MINE CLOUD Discord VPS Manager Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${APP_DIR}
Environment=PYTHONUNBUFFERED=1
ExecStart=${APP_DIR}/.venv/bin/python ${APP_DIR}/bot.py
Restart=always
RestartSec=5
TimeoutStopSec=30
UMask=0077

[Install]
WantedBy=multi-user.target
SERVICE
chmod 644 "$SERVICE_FILE"

 echo "[6/7] Enabling and starting MINE CLOUD..."
if systemctl is-active --quiet bot.service 2>/dev/null; then
  echo "[WARNING] An older bot.service is still active. Stop it manually if it runs this same Discord bot, to avoid duplicate sessions."
fi
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"
sleep 3

 echo "[7/7] Installation result..."
if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo ""
  echo "[SUCCESS] MINE CLOUD service is running."
else
  echo "[WARNING] Service did not stay active. Recent logs:"
  journalctl -u "$SERVICE_NAME" -n 40 --no-pager || true
fi

cat <<INFO

Useful commands:
  systemctl status ${SERVICE_NAME}
  journalctl -u ${SERVICE_NAME} -f
  systemctl restart ${SERVICE_NAME}
  systemctl stop ${SERVICE_NAME}

Web SSH default port: 5000
Open it only through a firewall/reverse-proxy setup you control; use HTTPS for public access.
INFO
