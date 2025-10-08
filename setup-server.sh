#!/bin/bash
set -euo pipefail

# ========== COLORS & LOGGING ==========
log() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1" >&2; exit 1; }

# ========== REQUIRE ROOT ==========
if [[ $EUID -ne 0 ]]; then
  error "Please run this script as root (sudo bash setup-server.sh)"
fi

# ========== ARGUMENTS ==========
ENV=""
WITH_DB=false
WITH_SSL=false

usage() {
  echo "Usage: $0 [--env dev|prod] [--with-db] [--with-ssl]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2 ;;
    --with-db) WITH_DB=true; shift ;;
    --with-ssl) WITH_SSL=true; shift ;;
    *) usage ;;
  esac
done

if [[ -z "$ENV" ]]; then usage; fi

# ========== LOAD ENV FILE ==========
ENV_FILE=".env.$ENV"
if [[ ! -f "$ENV_FILE" ]]; then
  error "Environment file $ENV_FILE not found!"
fi

set -a
source "$ENV_FILE"
set +a

log "Environment loaded: $ENV"
log "Domain: $DOMAIN"
log "User: $USER_NAME"

# ========== SYSTEM PREPARATION ==========
log "Updating system packages..."
apt update -y && apt upgrade -y

log "Creating user $USER_NAME..."
id "$USER_NAME" &>/dev/null || adduser --disabled-password --gecos "" "$USER_NAME"
usermod -aG sudo "$USER_NAME"

# ========== INSTALL NGINX ==========
log "Installing Nginx..."
apt install nginx -y
ufw allow 'Nginx HTTP'
ufw allow 'Nginx HTTPS'

mkdir -p /var/www/$DOMAIN/html
cat >/etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root /var/www/$DOMAIN/html;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
    client_max_body_size 100M;
}
EOF

ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN
nginx -t && systemctl reload nginx
log "Nginx configured for $DOMAIN"

# ========== OPTIONAL SSL ==========
if [ "$WITH_SSL" = true ]; then
  log "Installing Certbot and setting up HTTPS..."
  snap install core && snap refresh core
  snap install --classic certbot
  ln -sf /snap/bin/certbot /usr/bin/certbot
  certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos -m $EMAIL || true
fi

# ========== OPTIONAL POSTGRES ==========
if [ "$WITH_DB" = true ]; then
  log "Installing PostgreSQL..."
  apt install postgresql -y
  ufw allow 5432/tcp
  sed -i "s/#listen_addresses.*/listen_addresses = '*'/g" /etc/postgresql/*/main/postgresql.conf
  echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/*/main/pg_hba.conf
  systemctl restart postgresql
fi

# ========== JAVA & APP SETUP ==========
log "Installing Java..."
apt install default-jdk -y

mkdir -p "$APP_DIR" "$LOG_DIR"
chown -R "$USER_NAME":"$USER_NAME" "$APP_DIR" "$LOG_DIR"

cat >/etc/systemd/system/$APP_NAME.service <<EOF
[Unit]
Description=$APP_NAME Application
After=syslog.target

[Service]
User=$USER_NAME
Restart=always
RestartSec=20
ExecStart=/usr/bin/java -jar -Dspring.profiles.active=$SPRING_PROFILE -Djasypt.encryptor.password=$ENCRYPTION_KEY $APP_DIR/$JAR_NAME
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

chmod 0644 /etc/systemd/system/$APP_NAME.service
systemctl daemon-reload
systemctl enable $APP_NAME.service
log "Systemd service created successfully."

# ========== FINISH ==========
log "Installation complete!"
log "Domain: $DOMAIN"
log "User: $USER_NAME"
log "App JAR: $APP_DIR/$JAR_NAME"
