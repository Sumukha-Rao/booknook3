#!/bin/bash
set -eux
exec > >(tee /var/log/user-data.log) 2>&1

# ── EDIT THESE ─────────────────────────────────────────
REPO="https://github.com/Sumukha-Rao/booknook3.git"
DB_HOST="booknook-db.c1qumeos0tka.ap-south-1.rds.amazonaws.com"
DB_USER="admin"
DB_PASSWORD="database"
# ───────────────────────────────────────────────────────

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git curl mysql-client
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

git clone "$REPO" /opt/bookstore
cd /opt/bookstore
npm install --omit=dev

cat > /opt/bookstore/.env <<EOF
DB_HOST=${DB_HOST}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=bookstore
PORT=3000
EOF

cat > /etc/systemd/system/bookstore.service <<'EOF'
[Unit]
Description=Bookstore API
After=network.target

[Service]
WorkingDirectory=/opt/bookstore
EnvironmentFile=/opt/bookstore/.env
ExecStart=/usr/bin/node /opt/bookstore/server.js
Restart=always
RestartSec=5
User=ubuntu

[Install]
WantedBy=multi-user.target
EOF

chown -R ubuntu:ubuntu /opt/bookstore
systemctl daemon-reload
systemctl enable --now bookstore

sleep 5
curl -sf http://localhost:3000/health || echo "HEALTH CHECK FAILED"