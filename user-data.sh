#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

# ── EDIT THESE FOUR LINES ─────────────────────────────────────────
DB_HOST="bookstore-db.abc123xyz.ap-south-1.rds.amazonaws.com"
DB_USER="admin"
DB_PASSWORD="YourRdsPassword123"
S3_BUCKET="bookstore-code-yourname"     # bucket holding backend.zip
# ──────────────────────────────────────────────────────────────────

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl unzip mysql-client

# Node.js 20 (Ubuntu's default 'nodejs' package is too old)
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# AWS CLI (used only to pull the code from S3)
snap install aws-cli --classic || apt-get install -y awscli

# Pull the backend
mkdir -p /opt/bookstore
aws s3 cp "s3://${S3_BUCKET}/backend.zip" /tmp/backend.zip
unzip -o /tmp/backend.zip -d /opt/bookstore
cd /opt/bookstore
npm install --omit=dev

# Alternative if you'd rather not use S3 — comment out the three lines above and use:
#   git clone https://github.com/<you>/bookstore-backend.git /opt/bookstore
#   cd /opt/bookstore && npm install --omit=dev

cat > /opt/bookstore/.env <<EOF
DB_HOST=${DB_HOST}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=bookstore
PORT=3000
EOF

# Run as a systemd service so it survives reboots and crashes
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

# Give it a moment, then prove it's up (check /var/log/user-data.log if not)
sleep 5
curl -sf http://localhost:3000/health || echo "HEALTH CHECK FAILED"
