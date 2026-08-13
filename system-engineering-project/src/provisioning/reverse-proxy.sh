#! /bin/bash
#
# Provisioning script for hardened reverse-proxy
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

# Location of provisioning scripts and files
readonly PROVISIONING_SCRIPTS="/vagrant/provisioning"
# Location of files to be copied to this server
readonly PROVISIONING_FILES="${PROVISIONING_SCRIPTS}/files/${HOSTNAME}"

export PROVISIONING_SCRIPTS PROVISIONING_FILES

# Network settings
readonly webserver_ip="192.168.132.196"
readonly nextcloud_ip="192.168.132.197"
readonly domain_name="t02-domain404.internal"
readonly domain_alias="www.t02-domain404.internal"
readonly nextcloud_domain="nextcloud.t02-domain404.internal"

# Nginx paths
readonly nginx_conf_path="/opt/nginx/conf/nginx.conf"
readonly ssl_cert_dir="/etc/nginx/ssl/"
readonly ssl_cert="${ssl_cert_dir}/nginx_selfsigned.crt"
readonly ssl_key="${ssl_cert_dir}/nginx_selfsigned.key"

# Certificate information
# SAN cert covers both domains with a single certificate
readonly ssl_subject="/C=BE/ST=Oost-Vlaanderen/L=Gent/O=t02/CN=${domain_name}"

# Custom error pages
readonly ERROR_PAGES_SRC="${PROVISIONING_FILES}/ErrorPages"
readonly ERROR_PAGES_DST="/var/ErrorPages"


#------------------------------------------------------------------------------
# "Imports"
#------------------------------------------------------------------------------

# Utility functions
source ${PROVISIONING_SCRIPTS}/util.sh

# Actions/settings common to all servers
source ${PROVISIONING_SCRIPTS}/common.sh

#------------------------------------------------------------------------------
# Provision server
#------------------------------------------------------------------------------

info "Starting server specific provisioning tasks on ${HOSTNAME}"
info "Using provisioning directory: ${PROVISIONING_SCRIPTS}"


# 1. INSTALL CUSTOM NGINX

log "Starting installation of Nginx..."

log "Installing dependencies, this might take a while..."

dnf groupinstall "Development Tools" -y > /dev/null
dnf install firewalld -y -q > /dev/null
dnf install pcre2-devel zlib-ng-compat-devel openssl-devel git wget -y > /dev/null

log "Creating Nginx user and group..."
groupadd -r nginx || true
useradd -r -g nginx -s /sbin/nologin -c "nginx user" nginx || true

log "Preparing build environment..."

# Remove old directories (if present)
rm -rf /tmp/nginx-1.28.3 /tmp/headers-more-nginx-module

cd /tmp

log "Downloading modules and source..."

# Clone module to correct directory
rm -rf headers-more-nginx-module # Cleanup if directory already exists
git clone https://github.com/openresty/headers-more-nginx-module.git > /dev/null

wget -q http://nginx.org/download/nginx-1.28.3.tar.gz
tar -xzf nginx-1.28.3.tar.gz
cd nginx-1.28.3/

log "Configuring Nginx..."
./configure --prefix=/opt/nginx \
      --add-module=/tmp/headers-more-nginx-module \
      --with-http_ssl_module \
      --with-http_v2_module > /dev/null

log "Compiling and installing..."
make -j$(nproc) > /dev/null
make install > /dev/null

success "Nginx successfully installed in /opt/nginx"


# 2. DEPLOY ERROR PAGES

log "Deploying custom error pages..."

mkdir -p "${ERROR_PAGES_DST}"

if [ -d "${ERROR_PAGES_SRC}" ]; then
    # Copy only if changed
    rsync -a --delete "${ERROR_PAGES_SRC}/" "${ERROR_PAGES_DST}/"

    # Permissions
    chown -R nginx:nginx "${ERROR_PAGES_DST}" || true
    chmod -R 755 "${ERROR_PAGES_DST}"

    success "Error pages deployed."
else
    warn "No error pages found at ${ERROR_PAGES_SRC}"
fi


# 3. START & ENABLE NGINX

log "Starting and enabling Nginx..."

log "Creating systemd service file..."
cat <<EOF > /lib/systemd/system/nginx.service
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/opt/nginx/logs/nginx.pid
ExecStartPre=/opt/nginx/sbin/nginx -t
ExecStart=/opt/nginx/sbin/nginx
ExecReload=/opt/nginx/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

log "Starting and enabling services..."

systemctl enable --now nginx > /dev/null 2>&1
systemctl enable --now firewalld > /dev/null 2>&1


# 4. CHECK STATUS AND CONFIGURE FIREWALL

log "Verifying service status..."

if systemctl is-active --quiet nginx; then

    log "Status OK, configuring firewall..."

    # Remove standard services that are not used
    firewall-cmd --permanent --remove-service=cockpit > /dev/null 2>&1
    # Add HTTP and HTTPS service to the default zone
    firewall-cmd --permanent --add-service={http,https} > /dev/null
    # Apply changes
    firewall-cmd --reload > /dev/null

else
    error "Nginx service is not running. Check logs with journalctl -u nginx"
    exit 1
fi


# 5. SELINUX

log "Applying SELinux content..."

# Allow Nginx to make connection with the backend server
# Without this setting, Nginx will throw a '502 bad gateway'
ensure_sebool "httpd_can_network_connect"


# 6. GENERATE SELF-SIGNED CERTIFICATE

if [ ! -f "${ssl_cert}" ]; then
    log "Generating self-signed certificates..."

    mkdir -p ${ssl_cert_dir}

    # The SAN extension makes the cert valid for both virtual hosts so clients
    # don't get a hostname mismatch warning on the Nextcloud subdomain.
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:4096 \
        -keyout "${ssl_key}" \
        -out "${ssl_cert}" \
        -subj "${ssl_subject}" \
        -addext "subjectAltName=DNS:${domain_name},DNS:${domain_alias},DNS:${nextcloud_domain}" \
        2> /dev/null
    chmod 600 "${ssl_key}"

    success "Certificates generated."
else
    warn "Certificates already exist, skipping generation."
fi

# req -x509        -> self-signed
# -nodes           -> no password for private key
# -days 365        -> days the certificate is valid
# -newkey rsa:4096 -> new key with 4096 bits encryption
# -keyout & -out   -> determines where the private key (.key) and public certificate (.crt) are stored
# -subj            -> automatically fills in the data (such as country, name, etc.)
# -addext SAN      -> covers both domain_name and nextcloud_domain in one cert


# 7. NGINX CONFIG

log "Writing Nginx configuration..."

TEMP_NGINX=$(mktemp)

cat <<EOF > "${TEMP_NGINX}"

user nginx;
worker_processes auto;
pid logs/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    
    # Global Hardening: set custom header information
    more_set_headers "Server: Microsoft-IIS/10.0";
    more_clear_headers "X-Powered-By";
    more_clear_headers "Link";
    more_clear_headers "X-Pingback";

    # Default server: drop unknown requests
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        return 444;
    }

# WordPress / main site

server {
    listen 80;
    listen [::]:80;
    server_name ${domain_name} ${domain_alias};
    
    # Redirect all HTTP traffic to HTTPS
    return 301 https://\$host\$request_uri;

    # Security: hide Nginx version
    server_tokens off;
}

server {
    # Activate HTTP/2 over TLS
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name ${domain_name} ${domain_alias};

    # SSL Certificates
    ssl_certificate "${ssl_cert}";
    ssl_certificate_key "${ssl_key}";

    # Security: hide Nginx version
    server_tokens off;

    # Custom error pages
    error_page 502 503 504 /ErrorPages/HTTP502.html;
    error_page 400 /ErrorPages/HTTP400.html;
    error_page 401 /ErrorPages/HTTP401.html;
    error_page 402 /ErrorPages/HTTP402.html;
    error_page 403 /ErrorPages/HTTP403.html;
    error_page 404 /ErrorPages/HTTP404.html;
    error_page 500 /ErrorPages/HTTP500.html;

    location / {
        proxy_pass http://${webserver_ip};

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Intercept backend errors for custom error pages
        proxy_intercept_errors on;
    }
        location /ErrorPages/ {
            alias ${ERROR_PAGES_DST}/;
            internal;
    }
}

# Nextcloud

server {
    listen 80;
    listen [::]:80;
    server_name ${nextcloud_domain};
    return 301 https://\$host\$request_uri;
    server_tokens off;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name ${nextcloud_domain};

    ssl_certificate     "${ssl_cert}";
    ssl_certificate_key "${ssl_key}";
    server_tokens off;

    # Nextcloud needs large uploads and longer timeouts
    client_max_body_size 512M;
    proxy_read_timeout   360s;
    proxy_send_timeout   360s;

    # Custom error pages
    error_page 502 503 504 /ErrorPages/HTTP502.html;
    error_page 404 /ErrorPages/HTTP404.html;

    # Required headers for Nextcloud behind a proxy
    location / {
        proxy_pass http://${nextcloud_ip};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Connection "";
        proxy_http_version 1.1;
        
        proxy_intercept_errors on;
    }

    # Nextcloud well-known redirects (CalDAV / CardDAV auto-discovery)
    location = /.well-known/carddav {
        return 301 \$scheme://\$host/remote.php/dav/;
    }
    location = /.well-known/caldav {
        return 301 \$scheme://\$host/remote.php/dav/;
    }

    location /ErrorPages/ {
        alias ${ERROR_PAGES_DST}/;
        internal;
    }
}
}
EOF

if files_differ "${TEMP_NGINX}" "${nginx_conf_path}"; then
    install -m 644 -o root -g root "${TEMP_NGINX}" "${nginx_conf_path}"
    
    # Syntax check voor herstart
    if /opt/nginx/sbin/nginx -t > /dev/null 2>&1; then
        systemctl restart nginx
        success "Nginx configuration updated and service restarted."
    else
        error "Nginx syntax check failed! Check ${nginx_conf_path}"
    fi
else
    success "Nginx configuration is up to date."
fi
rm -f "${TEMP_NGINX}"


# 8. Add key for SSH trust with domain controller

log "Configuring SSH Trust for Domain Controller..."
# Append the public key to the vagrant user's authorized_keys
cat ${PROVISIONING_FILES}/proxy_cert_key.pub >> /home/vagrant/.ssh/authorized_keys
chmod 600 /home/vagrant/.ssh/authorized_keys


# 9. Import network fix script

bash ${PROVISIONING_SCRIPTS}/networkfix.sh


# 10. REBOOT CHECK

# Check if reboot is required (= kernel update), -r flag = reboot
# This command compares the active kernel to the new installed version
info "--- Provisioning finished, reverse proxy server ready! ---"

if ! needs-restarting -r > /dev/null 2>&1; then
    warn "------------------------------------------------------------------"
    warn " KERNEL UPDATE DETECTED: System requires a reboot!"
    warn " The server will reboot in 5 seconds."
    warn " You WILL be disconnected! To check when the server is back:"
    warn " run: 'vagrant ssh' or 'ping ${domain_name}'"
    warn "------------------------------------------------------------------"
    
    # Countdown
    for i in {5..1}; do
        log "Rebooting in $i..."
        sleep 1
    done
    
    log "Rebooting now."
    reboot
else
    success "No reboot required. Nginx is spoofed and operational!"
    info "You can verify the headers with: curl -I https://${domain_name} --insecure"
fi
