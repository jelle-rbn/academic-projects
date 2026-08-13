#! /bin/bash
#
# Provisioning script for spoofed Nginx
# This version contains the patched server headers wich do not contain server name and / or version
#
# Author: J. Robyn - jelle.robyn@student.hogent.be

#------------------------------------------------------------------------------
# Bash settings
#------------------------------------------------------------------------------

# Enable "Bash strict mode"
set -o errexit   # abort on nonzero exitstatus
set -o nounset   # abort on unbound variable
set -o pipefail  # don't mask errors in piped commands

#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

# Get latest stable Nginx version
# If not found, use hard coded fallback
NGINX_VERSION=$(curl -s http://nginx.org/en/download.html | \
grep -oP 'nginx-\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1)

if [ -z "$NGINX_VERSION" ]; then
    NGINX_VERSION="1.28.3"
fi

# Installation directory
INSTALL_DIR="/usr/local/src"

#------------------------------------------------------------------------------
# "Imports"
#------------------------------------------------------------------------------

# Utility functions
source ${PROVISIONING_SCRIPTS}/util.sh

# Actions/settings common to all servers
source ${PROVISIONING_SCRIPTS}/common.sh

#------------------------------------------------------------------------------
# Install and patch Nginx
#------------------------------------------------------------------------------

log "Removing existing Nginx files (if applicable)..."
sudo dnf remove -y nginx nginx-core > /dev/null 2>&1 || true

log "Installing build dependencies..."
sudo dnf install -y gcc make pcre2-devel zlib-devel openssl-devel wget tar > /dev/null

log "Using Nginx version: $NGINX_VERSION"

cd ${INSTALL_DIR}

log "Downloading Nginx source..."
if [ ! -f "nginx-${NGINX_VERSION}.tar.gz" ]; then
    sudo wget -q "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" > /dev/null
fi

log "Unpacking source..."

sudo rm -rf "nginx-${NGINX_VERSION}"
sudo tar -xzf "nginx-${NGINX_VERSION}.tar.gz"

cd "nginx-${NGINX_VERSION}"

log "Patching Server header..."

sed -i 's#static u_char ngx_http_server_string\[\].*#static u_char ngx_http_server_string[] = "Server: A potato" CRLF;#' src/http/ngx_http_header_filter_module.c
sed -i 's#static u_char ngx_http_server_full_string\[\].*#static u_char ngx_http_server_full_string[] = "Server: A potato" CRLF;#' src/http/ngx_http_header_filter_module.c
sed -i 's#static u_char ngx_http_server_build_string\[\].*#static u_char ngx_http_server_build_string[] = "Server: ... Is this a server?" CRLF;#' src/http/ngx_http_header_filter_module.c

log "Configuring build..."

sudo ./configure \
  --sbin-path=/usr/sbin/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --pid-path=/var/run/nginx.pid \
  --with-pcre-jit \
  --with-http_ssl_module \
  --with-http_v2_module \
  --without-http_autoindex_module > /dev/null

log "Compiling..."

sudo make -j"$(nproc)" > /dev/null

log "Installing..."

sudo make install > /dev/null

log "Creating Nginx user..."

sudo useradd -r -s /sbin/nologin nginx || true

log "Creating directories..."
sudo mkdir -p /etc/nginx/conf.d
sudo mkdir -p /var/log/nginx
sudo mkdir -p /var/cache/nginx

log "Setting up permissions..."

sudo chown -R nginx:nginx /var/log/nginx || true

log "Creating Systemd service..."

sudo tee /etc/systemd/system/nginx.service > /dev/null <<EOF
[Unit]
Description=Custom NGINX (Spoofed Server Header)
After=network.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/usr/sbin/nginx -s quit
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

log "Reloading systemd..."

sudo systemctl daemon-reexec
sudo systemctl daemon-reload

log "Creating nginx.conf..."

sudo tee /etc/nginx/nginx.conf > /dev/null <<'EOF'
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout 65;

    include /etc/nginx/conf.d/*.conf;
}
EOF

log "Activating service..."

sudo systemctl enable nginx  > /dev/null 2>&1
sudo systemctl restart nginx > /dev/null 2>&1

success "Nginx with spoofed server header succesfully installed!"