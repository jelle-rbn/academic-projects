#! /bin/bash
#
# Provisioning script for webserver
#
# Author: D. Cooreman - dean.cooreman@student.hogent.be

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

# Debug mode: set to 1 to show full command output, 0 to suppress it
readonly DEBUG=1

readonly STORAGE_IP="192.168.132.199"
readonly STORAGE_PATH="/export/storage/wordpress"

# Database
readonly DB_NAME="wordpress"
readonly DB_USER="domain404"
readonly DB_PASS="GroupT02ForVictory"
readonly DB_HOST="192.168.132.201"

# Apache
readonly SERVER_NAME="t02-domain404.internal"
readonly SERVER_ALIAS="www.t02-domain404.internal"

# WordPress
readonly ADMIN_USERNAME="bigchief"
readonly ADMIN_PASSWORD="404LetMeIn404"

#------------------------------------------------------------------------------
# Package arrays
#------------------------------------------------------------------------------

readonly php_packages=(
  php
  php-mysqlnd
  php-gd
  php-xml
  php-mbstring
  php-json
  php-curl
  php-zip
)

#------------------------------------------------------------------------------
# "Imports"
#------------------------------------------------------------------------------

# Utility functions
source ${PROVISIONING_SCRIPTS}/util.sh
# Actions/settings common to all servers
source ${PROVISIONING_SCRIPTS}/common.sh

#------------------------------------------------------------------------------
# "Functions"
#------------------------------------------------------------------------------

# Function that installs packages
install_package() {
  while [ "$#" -gt 0 ]; do
    if run dnf install -y -q "$1"; then
      success "$1 installed."
    else
      error "Failed to install $1."
      return 1
    fi
    shift
  done
}

# Runs a command, suppressing output unless DEBUG=1
run() {
  if [ "${DEBUG}" -eq 1 ]; then
    "$@"
  else
    "$@" > /dev/null 2>&1
  fi
}

#------------------------------------------------------------------------------
# Provision server
#------------------------------------------------------------------------------

log "Starting server specific provisioning tasks on ${HOSTNAME}"

log "Installing Apache and NFS utilities"

# Added nfs-utils for network storage
install_package httpd nfs-utils
success "Apache and NFS utilities successfully installed"

log "Enabling the httpd.service"

run systemctl enable --now httpd.service
success "httpd.service successfully enabled"

# --- Added: Network Storage Mount Section ---
log "Configuring network storage mount"

mkdir -p /var/www/html/wordpress

# Ensure the mount is persistent in fstab
if ! grep -q "${STORAGE_PATH}" /etc/fstab; then
  echo "${STORAGE_IP}:${STORAGE_PATH} /var/www/html/wordpress nfs defaults,_netdev 0 0" >> /etc/fstab
fi

# Attempt mount
run mount -a
verify "NFS Storage mounted at /var/www/html/wordpress" mountpoint -q /var/www/html/wordpress
success "Network storage successfully mounted"
# ---------------------------------------------

log "Configuring firewall"

run firewall-cmd --add-service=http --permanent
run firewall-cmd --reload
success "Firewall successfully configured"

log "Installing PHP packages"

install_package "${php_packages[@]}"
run systemctl restart httpd
success "PHP packages successfully installed"

log "Enabling the php-fpm.service"

run systemctl enable --now php-fpm.service
success "php-fpm.service successfully enabled"

log "Downloading and verifying WordPress"

# Download the latest version of WordPress and the checksum
curl -sL -O https://wordpress.org/latest.tar.gz
curl -sL -O https://wordpress.org/latest.tar.gz.sha1

# Verify the checksum
expected_checksum=$(cat latest.tar.gz.sha1)
actual_checksum=$(sha1sum latest.tar.gz | awk '{print $1}')

if [ "$actual_checksum" != "$expected_checksum" ]; then
  error "WordPress checksum verification failed!"
  error "Expected : $expected_checksum"
  error "Actual   : $actual_checksum"
  exit 1
fi
success "WordPress successfully downloaded and verified"

log "Installing WordPress"

# Extract WordPress
tar -zxf latest.tar.gz

# Logic Change: Copy content into the mount instead of moving the directory
# This ensures we don't break the NFS mount point.
cp -R wordpress/* /var/www/html/wordpress/

# Clean up downloaded archive and checksum
rm -rf wordpress latest.tar.gz latest.tar.gz.sha1
success "WordPress successfully installed on network storage"

log "Configuring WordPress"

# Copy the example config file
cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php

# Inject database credentials
sed -i "s/database_name_here/$DB_NAME/" /var/www/html/wordpress/wp-config.php
sed -i "s/username_here/$DB_USER/"      /var/www/html/wordpress/wp-config.php
sed -i "s/password_here/$DB_PASS/"      /var/www/html/wordpress/wp-config.php
sed -i "s/localhost/$DB_HOST/"          /var/www/html/wordpress/wp-config.php

# Fetch fresh salt keys from the WordPress API
salt_keys=$(curl -sL https://api.wordpress.org/secret-key/1.1/salt/)

if [ -z "$salt_keys" ]; then
  error "Failed to fetch WordPress salt keys from API"
  exit 1
fi

# Remove the placeholder salt lines
sed -i "/define( 'AUTH_KEY'/d"         /var/www/html/wordpress/wp-config.php
sed -i "/define( 'SECURE_AUTH_KEY'/d"  /var/www/html/wordpress/wp-config.php
sed -i "/define( 'LOGGED_IN_KEY'/d"    /var/www/html/wordpress/wp-config.php
sed -i "/define( 'NONCE_KEY'/d"        /var/www/html/wordpress/wp-config.php
sed -i "/define( 'AUTH_SALT'/d"        /var/www/html/wordpress/wp-config.php
sed -i "/define( 'SECURE_AUTH_SALT'/d" /var/www/html/wordpress/wp-config.php
sed -i "/define( 'LOGGED_IN_SALT'/d"   /var/www/html/wordpress/wp-config.php
sed -i "/define( 'NONCE_SALT'/d"       /var/www/html/wordpress/wp-config.php

# Insert the fresh keys in place of the marker left by wp-config-sample.php
sed -i "/#@-/r /dev/stdin" /var/www/html/wordpress/wp-config.php << EOF
$salt_keys
EOF

success "WordPress successfully configured"

log "Configuring WordPress for reverse proxy"

# Insert HTTPS detection and WP_HOME/WP_SITEURL before the require_once line
sed -i "s|require_once ABSPATH . 'wp-settings.php';|/* Reverse proxy settings */\nif (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) \&\& \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {\n    \$_SERVER['HTTPS'] = 'on';\n}\n\ndefine('WP_HOME',    'https://${SERVER_NAME}');\ndefine('WP_SITEURL', 'https://${SERVER_NAME}');\n\nrequire_once ABSPATH . 'wp-settings.php';|" \
    /var/www/html/wordpress/wp-config.php
success "Reverse proxy settings successfully configured"

log "Configuring Apache VirtualHost"

# Serve WordPress in place of the default Apache page
cat > /etc/httpd/conf.d/wordpress.conf << EOF
<VirtualHost *:80>
    ServerName ${SERVER_NAME}
    ServerAlias ${SERVER_ALIAS}
    DocumentRoot /var/www/html/wordpress

    <Directory /var/www/html/wordpress>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

run systemctl restart httpd
success "Apache VirtualHost successfully configured"

log "Setting permissions for Apache on WordPress files"

chown -R apache:apache /var/www/html/wordpress
chown apache:apache /var/www/html/wordpress/wp-config.php

chmod -R 755 /var/www/html/wordpress
chmod 640 /var/www/html/wordpress/wp-config.php
success "Permissions successfully set"

log "Installing WP-CLI"

curl -sL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp
chmod +x /usr/local/bin/wp
success "WP-CLI successfully installed"

log "Running WordPress install via WP-CLI"

run /usr/local/bin/wp core install \
    --path=/var/www/html/wordpress \
    --url="https://${SERVER_NAME}" \
    --title="G02 - System Engineering Project" \
    --admin_user="${ADMIN_USERNAME}" \
    --admin_password="${ADMIN_PASSWORD}" \
    --admin_email="${ADMIN_USERNAME}@${SERVER_NAME}" \
    --skip-email \
    --allow-root

# Force site title even if WP was already installed
run /usr/local/bin/wp option update blogname "G02 - System Engineering Project" \
    --path=/var/www/html/wordpress --allow-root
success "WordPress core successfully installed"

log "Installing and activating Astra theme"

run /usr/local/bin/wp theme install astra \
    --path=/var/www/html/wordpress \
    --activate \
    --allow-root
success "Astra theme successfully installed and activated"

log "Importing logo and setting it as custom logo"

LOGO_ID=$(/usr/local/bin/wp media import \
  /vagrant/provisioning/files/webserver/D404W.png \
  --title="Domain404 Logo" \
  --path=/var/www/html/wordpress \
  --allow-root --porcelain 2>/dev/null || true)

if [ -z "${LOGO_ID}" ]; then
  warn "Logo import returned no attachment ID — custom_logo will not be set."
else
  run /usr/local/bin/wp theme mod set custom_logo "${LOGO_ID}" \
    --path=/var/www/html/wordpress --allow-root
  success "Custom logo set (ID=${LOGO_ID})."
fi

log "Configuring Astra theme settings"

# Astra stores its settings as a serialised option — easier to patch via wp option
/usr/local/bin/wp option patch insert astra-settings header-bg-color-responsive \
  '{"desktop":"#0274BD","tablet":"#0274BD","mobile":"#0274BD"}' \
  --format=json --path=/var/www/html/wordpress --allow-root > /dev/null 2>&1 || true

/usr/local/bin/wp option patch insert astra-settings primary-color \
  '"#0274BD"' --format=json \
  --path=/var/www/html/wordpress --allow-root > /dev/null 2>&1 || true

/usr/local/bin/wp option patch insert astra-settings link-color \
  '"#0274BD"' --format=json \
  --path=/var/www/html/wordpress --allow-root > /dev/null 2>&1 || true
success "Astra theme settings successfully configured"

log "Removing default Sample Page and cleaning up nav menu"

# Delete the default Sample Page WordPress creates
SAMPLE_ID=$(/usr/local/bin/wp post list --post_type=page --name=sample-page \
  --field=ID --path=/var/www/html/wordpress --allow-root 2>/dev/null || true)

if [ -n "${SAMPLE_ID}" ]; then
  run /usr/local/bin/wp post delete "${SAMPLE_ID}" --force \
    --path=/var/www/html/wordpress --allow-root
  success "Sample Page deleted (ID=${SAMPLE_ID})."
fi

# Remove it from any nav menus (|| true guards against pipefail on no match)
MENU_ITEMS=$(/usr/local/bin/wp menu item list --fields=ID,title --format=csv \
  --path=/var/www/html/wordpress --allow-root 2>/dev/null || true)

if [ -n "${MENU_ITEMS}" ]; then
  echo "${MENU_ITEMS}" | grep -i 'sample' | cut -d',' -f1 | while read -r ITEM_ID; do
    [ -n "${ITEM_ID}" ] && run /usr/local/bin/wp menu item delete "${ITEM_ID}" \
      --path=/var/www/html/wordpress --allow-root || true
  done || true
fi
success "Default Sample Page and nav menu cleaned up"

log "Injecting Domain404 CSS via child plugin (mu-plugin)"

# Use an mu-plugin so the CSS is theme-independent and survives theme switches
mkdir -p /var/www/html/wordpress/wp-content/mu-plugins

cat > /var/www/html/wordpress/wp-content/mu-plugins/domain404-theme.php << 'EOF'
<?php
/**
 * Plugin Name: Domain404 Theme CSS
 * Description: Injects Domain404 brand styling - auto-loaded as mu-plugin.
 */
add_action('wp_head', function() { ?>
<style>
/* ── Variables ────────────────────────────────────────────────────────── */
:root {
  --blue:       #0274BD;
  --blue-dk:    #025a94;
  --blue-lt:    #e8f4fc;
  --black:      #1a1a2e;
  --text:       #222222;
  --muted:      #6b7280;
  --border:     #e2e8f0;
  --bg:         #f8fafc;
  --white:      #ffffff;
  --card-shad:  0 1px 3px rgba(0,0,0,.08), 0 1px 2px rgba(0,0,0,.05);
}

/* ── Reset / base ─────────────────────────────────────────────────────── */
*, *::before, *::after { box-sizing: border-box; }
html, body {
  background: var(--white) !important;
  color: var(--text) !important;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif !important;
  font-size: 16px !important;
  line-height: 1.6 !important;
  margin: 0 !important; padding: 0 !important;
}

/* ── Header ───────────────────────────────────────────────────────────── */
#masthead,
.site-header,
.main-header-bar,
.ast-primary-header-bar {
  background: var(--black) !important;
  border-bottom: 4px solid var(--blue) !important;
  box-shadow: 0 4px 16px rgba(0,0,0,.35) !important;
  width: 100% !important;
  max-width: 100vw !important;
  padding: 20px 0 !important;
  margin: 0 !important;
}

/* Inner container — transparent so blue shows edge to edge */
.main-header-bar .ast-container,
.ast-primary-header-bar .ast-container,
.main-header-bar-inner {
  background: transparent !important;
  max-width: 1280px !important;
  margin: 0 auto !important;
  padding: 0 48px !important;
  display: flex !important;
  align-items: center !important;
  width: 100% !important;
}

/* ── Kill Astra's extra header bands ──────────────────────────────────── */
.ast-below-header-bar,
.ast-above-header-bar,
.ast-below-header,
.ast-above-header,
.ast-desktop-below-header-section,
.ast-desktop-above-header-section {
  display: none !important;
  height: 0 !important;
  padding: 0 !important;
  margin: 0 !important;
  border: none !important;
  background: transparent !important;
}
.site-header::after,
.main-header-bar::after,
#masthead::after {
  display: none !important;
  content: none !important;
}

/* ── Logo ─────────────────────────────────────────────────────────────── */
.ast-site-identity,
.site-branding {
  display: flex !important;
  align-items: center !important;
  gap: 18px !important;
  padding: 0 !important;
}
.ast-logo-svg-container,
.custom-logo-link {
  display: flex !important;
  align-items: center !important;
  max-width: none !important;
  width: auto !important;
}
.custom-logo-link img,
.custom-logo-link .custom-logo,
img.custom-logo,
.ast-logo-img,
.site-header img.custom-logo,
#masthead img {
  height: 120px !important;
  width: auto !important;
  max-width: none !important;
  max-height: none !important;
  min-height: 120px !important;
  display: block !important;
  object-fit: contain !important;
}

/* ── Site title beside logo ───────────────────────────────────────────── */
.ast-site-title, .site-title,
.ast-site-title a, .site-title a {
  color: var(--white) !important;
  font-size: 2.1rem !important;
  font-weight: 700 !important;
  letter-spacing: .02em !important;
  text-decoration: none !important;
  line-height: 1.1 !important;
  display: inline !important;
}
.site-description, .ast-site-description {
  color: rgba(255,255,255,.72) !important;
  font-size: .75rem !important;
  letter-spacing: .07em !important;
  text-transform: uppercase !important;
  margin-top: 2px !important;
}

/* ── Navigation ───────────────────────────────────────────────────────── */
.ast-nav-menu a,
.main-navigation a,
#site-navigation a,
.main-header-menu a {
  color: var(--white) !important;
  font-weight: 500 !important;
  font-size: .93rem !important;
  letter-spacing: .02em !important;
  transition: opacity .15s !important;
  text-decoration: none !important;
}
.ast-nav-menu a:hover,
.main-navigation a:hover,
#site-navigation a:hover {
  opacity: .78 !important;
  color: var(--white) !important;
}
.ast-nav-menu .current-menu-item > a {
  border-bottom: 2px solid rgba(255,255,255,.85) !important;
  padding-bottom: 2px !important;
}

/* ── Content area ─────────────────────────────────────────────────────── */
.site-content, #content,
.ast-container, .content-area,
.ast-grid-common-layout, #primary {
  background: var(--white) !important;
}
.ast-container { max-width: 1280px !important; margin: 0 auto !important; padding: 0 32px !important; }

/* ── Blog grid wrapper ────────────────────────────────────────────────── */
.ast-archive-page-wrap,
.ast-blog-grid-wrapper,
.ast-blog-layout-1-grid {
  padding: 32px 0 !important;
}

/* ── Post cards ───────────────────────────────────────────────────────── */
article.type-post,
.ast-article-post,
.post-grid-post {
  background: var(--white) !important;
  border: 1px solid var(--border) !important;
  border-radius: 10px !important;
  box-shadow: var(--card-shad) !important;
  transition: box-shadow .2s, border-color .2s, transform .2s !important;
  overflow: hidden !important;
  margin-bottom: 24px !important;
}
article.type-post:hover {
  box-shadow: 0 8px 24px rgba(2,116,189,.13) !important;
  border-color: var(--blue) !important;
  transform: translateY(-2px) !important;
}

/* Card header accent bar */
article.type-post::before {
  content: "" !important;
  display: block !important;
  height: 4px !important;
  background: var(--blue) !important;
  width: 100% !important;
}

.entry-header { padding: 20px 22px 0 !important; }
.entry-content, .entry-summary { padding: 10px 22px 22px !important; color: var(--text) !important; }

/* ── Category pill ────────────────────────────────────────────────────── */
.ast-post-categories a,
.cat-links a, .entry-meta .cat-links a {
  background: var(--blue-lt) !important;
  color: var(--blue) !important;
  font-size: .7rem !important;
  font-weight: 700 !important;
  text-transform: uppercase !important;
  letter-spacing: .07em !important;
  padding: 3px 9px !important;
  border-radius: 4px !important;
  text-decoration: none !important;
  display: inline-block !important;
  margin-bottom: 8px !important;
}

/* ── Post titles ──────────────────────────────────────────────────────── */
h1, h2, h3, h4, h5, h6,
.entry-title, .entry-title a,
.ast-post-title, .ast-post-title a {
  color: var(--black) !important;
  font-weight: 700 !important;
}
.entry-title a:hover, .ast-post-title a:hover {
  color: var(--blue) !important;
}

/* ── Body links ───────────────────────────────────────────────────────── */
.entry-content a, .entry-summary a {
  color: var(--blue) !important;
}
.entry-content a:hover { color: var(--blue-dk) !important; }

/* ── Meta line ────────────────────────────────────────────────────────── */
.entry-meta, .ast-blog-single-element,
.posted-on, .byline, .post-author {
  color: var(--muted) !important;
  font-size: .82rem !important;
}
.entry-meta a { color: var(--blue) !important; text-decoration: none !important; }

/* ── Single post ──────────────────────────────────────────────────────── */
.single article {
  border: none !important;
  box-shadow: none !important;
  border-radius: 0 !important;
  padding: 0 !important;
}
.single article::before { display: none !important; }

/* ── Page background strip ────────────────────────────────────────────── */
.site { background: var(--bg) !important; }
#primary { background: var(--white) !important; padding: 32px 0 !important; }

/* ── Buttons ──────────────────────────────────────────────────────────── */
.ast-button, button,
input[type="submit"],
.wp-block-button__link,
#submit, .submit {
  background: var(--blue) !important;
  color: var(--white) !important;
  border: none !important;
  border-radius: 6px !important;
  padding: 10px 24px !important;
  font-weight: 600 !important;
  font-size: .9rem !important;
  cursor: pointer !important;
  transition: background .2s, box-shadow .2s !important;
}
.ast-button:hover, button:hover,
input[type="submit"]:hover, #submit:hover {
  background: var(--blue-dk) !important;
  box-shadow: 0 4px 12px rgba(2,116,189,.35) !important;
}

/* ── Forms ────────────────────────────────────────────────────────────── */
input[type="text"], input[type="email"],
input[type="url"], input[type="password"],
textarea, select {
  background: var(--white) !important;
  color: var(--text) !important;
  border: 1px solid var(--border) !important;
  border-radius: 5px !important;
  padding: 9px 14px !important;
  width: 100% !important;
  font-size: .95rem !important;
}
input:focus, textarea:focus {
  border-color: var(--blue) !important;
  outline: none !important;
  box-shadow: 0 0 0 3px rgba(2,116,189,.15) !important;
}
label { color: var(--text) !important; font-weight: 500 !important; font-size: .88rem !important; }

/* ── Comments ─────────────────────────────────────────────────────────── */
#comments { border-top: 2px solid var(--border) !important; padding-top: 28px !important; }
.comment-list .comment {
  background: var(--bg) !important;
  border: 1px solid var(--border) !important;
  border-radius: 8px !important;
  padding: 18px !important;
  margin-bottom: 14px !important;
}
.comment-author .fn { color: var(--blue) !important; font-weight: 600 !important; }
.comment-metadata a { color: var(--muted) !important; font-size: .8rem !important; }
#respond {
  background: var(--bg) !important;
  border: 1px solid var(--border) !important;
  border-radius: 8px !important;
  padding: 24px !important;
  margin-top: 24px !important;
}
.comment-reply-title { color: var(--black) !important; }

/* ── Footer ───────────────────────────────────────────────────────────── */
#colophon,
.site-footer,
.ast-small-footer,
.footer-widget-area,
.ast-footer-copyright,
.ast-footer-wrap,
[id*="colophon"],
[class*="footer"] {
  background-color: var(--black) !important;
  color: #9ca3af !important;
}

#colophon,
.site-footer {
  border-top: 5px solid var(--blue) !important;
  padding: 0 !important;
  margin: 0 !important;
  width: 100% !important;
}

.ast-small-footer {
  padding: 32px 40px !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  flex-wrap: wrap !important;
  gap: 24px !important;
  max-width: 1280px !important;
  margin: 0 auto !important;
  width: 100% !important;
  box-sizing: border-box !important;
}

.ast-footer-copyright {
  background-color: transparent !important;
  color: #9ca3af !important;
  font-size: .88rem !important;
  letter-spacing: .01em !important;
  text-align: center !important;
}
.ast-footer-copyright a,
#colophon a,
.site-footer a {
  color: #60a5d4 !important;
  text-decoration: none !important;
  font-weight: 500 !important;
  transition: color .15s !important;
}
.ast-footer-copyright a:hover,
#colophon a:hover,
.site-footer a:hover {
  color: var(--white) !important;
  text-decoration: underline !important;
}
</style>
<?php }, 999);
EOF

chown apache:apache /var/www/html/wordpress/wp-content/mu-plugins/domain404-theme.php
success "Domain404 CSS mu-plugin successfully injected"

log "Configuring SELinux"

# Allow Apache to connect to the remote database
ensure_sebool httpd_can_network_connect_db

# --- Added: SELinux for Network Storage ---
# Allow Apache to use network storage (NFS)
ensure_sebool httpd_use_nfs
# -------------------------------------------

# Allow WordPress to write to the wp-content directory
run semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/html/wordpress/wp-content(/.*)?" || true
# Apply all registered contexts to the filesystem
run restorecon -R /var/www/html/
success "SELinux successfully configured"

log "Installing nmap for the demo"

install_package nmap
success "nmap successfully installed"

log "Applying network fix"

bash ${PROVISIONING_SCRIPTS}/networkfix.sh

echo ""
echo "  +-------------------------------------------------+"
echo "  |                                                 |"
echo "  |        WordPress Webserver — Ready!             |"
echo "  |                                                 |"
echo "  |  Host  : ${HOSTNAME}                              |"
echo "  |  Group : t02-domain404.internal                 |"
echo "  |                                                 |"
echo "  +-------------------------------------------------+"
echo ""