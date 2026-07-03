#!/usr/bin/env bash
# One-time setup for the Esther Pictures Phoenix app VM.
# Idempotent — safe to re-run.
#
# Usage (from the repo, over SSH):
#   scp deploy/setup-app-vm.sh deploy/estherpictures.service <deploy-pubkey> \
#       ubuntu@<vm-ip>:/tmp/
#   ssh ubuntu@<vm-ip> "sudo bash /tmp/setup-app-vm.sh /tmp/<pubkey> /tmp/estherpictures.service"
#
# After running: edit /etc/esther_pictures.env to set SECRET_KEY_BASE and PHX_HOST.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "must run as root (use sudo)" >&2
  exit 1
fi

PUBKEY_FILE="${1:?usage: $0 <pubkey-path> <estherpictures.service-path>}"
SERVICE_FILE="${2:?usage: $0 <pubkey-path> <estherpictures.service-path>}"

[[ -f "$PUBKEY_FILE"  ]] || { echo "pubkey not found: $PUBKEY_FILE" >&2; exit 1; }
[[ -f "$SERVICE_FILE" ]] || { echo "service file not found: $SERVICE_FILE" >&2; exit 1; }

# --- 1. deploy user ---------------------------------------------------------
if ! id -u deploy >/dev/null 2>&1; then
  useradd --system --create-home --shell /bin/bash deploy
  echo "+ created user 'deploy'"
else
  echo "= user 'deploy' already exists"
fi

# --- 2. authorize SSH key ---------------------------------------------------
install -d -o deploy -g deploy -m 700 /home/deploy/.ssh
touch /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys

KEY_CONTENT="$(cat "$PUBKEY_FILE")"
if grep -qxF "$KEY_CONTENT" /home/deploy/.ssh/authorized_keys; then
  echo "= ssh key already authorized for deploy"
else
  echo "$KEY_CONTENT" >> /home/deploy/.ssh/authorized_keys
  echo "+ authorized ssh key for deploy"
fi

# --- 3. release + data tree -------------------------------------------------
install -d -o deploy -g deploy -m 755 /opt/estherpictures
install -d -o deploy -g deploy -m 755 /opt/estherpictures/releases
# Persistent data: SQLite DB + uploaded thumbnails (survive deploys).
install -d -o deploy -g deploy -m 755 /opt/estherpictures/data
install -d -o deploy -g deploy -m 755 /opt/estherpictures/data/uploads
install -d -o deploy -g deploy -m 755 /opt/estherpictures/data/uploads/clips
echo "= /opt/estherpictures tree ready"

# --- 4. environment file stub ----------------------------------------------
if [[ ! -f /etc/esther_pictures.env ]]; then
  cat > /etc/esther_pictures.env <<'EOF'
# Phoenix release env vars. Edit, then `sudo systemctl restart estherpictures`.
PHX_SERVER=true
PHX_HOST=estherpictures.com
PORT=4000

# Generate with: mix phx.gen.secret
SECRET_KEY_BASE=REPLACE_ME

# SQLite database file (created on first migrate).
DATABASE_PATH=/opt/estherpictures/data/esther_pictures.db
POOL_SIZE=5
EOF
  chown root:deploy /etc/esther_pictures.env
  chmod 640 /etc/esther_pictures.env
  echo "+ wrote /etc/esther_pictures.env stub  (SET SECRET_KEY_BASE before first deploy)"
else
  echo "= /etc/esther_pictures.env already exists, leaving alone"
fi

# --- 5. systemd unit --------------------------------------------------------
install -m 644 "$SERVICE_FILE" /etc/systemd/system/estherpictures.service
echo "+ installed /etc/systemd/system/estherpictures.service"

# --- 6. sudoers drop-in (deploy may restart the service) -------------------
cat > /etc/sudoers.d/estherpictures-deploy <<'EOF'
deploy ALL=(root) NOPASSWD: /bin/systemctl restart estherpictures
EOF
chmod 440 /etc/sudoers.d/estherpictures-deploy
visudo -c -f /etc/sudoers.d/estherpictures-deploy >/dev/null
echo "+ installed /etc/sudoers.d/estherpictures-deploy"

# --- 7. enable (don't start; no release yet) -------------------------------
systemctl daemon-reload
systemctl enable estherpictures.service >/dev/null
echo "+ enabled estherpictures.service (starts after first deploy)"

cat <<'EOF'

setup complete.

next steps:
  1. set SECRET_KEY_BASE in /etc/esther_pictures.env (mix phx.gen.secret)
  2. install + configure cloudflared -> 127.0.0.1:4000
  3. add Forgejo repo secrets (DEPLOY_SSH_KEY / DEPLOY_HOST / DEPLOY_USER)
  4. push to main — the workflow builds, ships, migrates, restarts
  5. (optional, once) seed default content: /opt/estherpictures/current/bin/seed
EOF
