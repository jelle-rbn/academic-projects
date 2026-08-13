#! /bin/bash
#
# Provisioning script for the Nextcloud server.
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

readonly NEXTCLOUD_VERSION="31.0.4"

# Debug mode: set to 1 to show full command output, 0 to suppress it
readonly DEBUG=1

# Valkey
readonly valkey_password='domain404'

# Admin Account
readonly nc_admin_user='admin'
readonly nc_admin_pass='admin404'

# Regular user
readonly nc_user='linustorvalds'
readonly nc_user_display_name='Linus Torvalds'
readonly nc_user_pass='IDidntMadeAnyMoneyFromLinux'

# Database
readonly db_host='192.168.132.198'
readonly db_name='nextcloud'
readonly db_user='nextcloud'
readonly db_password='GroupT02ForVictory'

# Trusted access
readonly nc_server_ip='192.168.132.197'
readonly nc_domain='nextcloud.t02-domain404.internal'
readonly nc_proxy_ip='192.168.132.234'

#------------------------------------------------------------------------------
# Package arrays
#------------------------------------------------------------------------------

readonly dependencies=(
  epel-release
  yum-utils
  unzip
  curl
  wget
  bash-completion
  policycoreutils-python-utils
  plocate
  bzip2
)

readonly php_required=(
  php
  php-fpm
  php-curl
  php-dom
  php-gd
  php-xml
  php-mbstring
  php-zip
  php-zlib
  php-posix
  php-pdo
  php-mysqlnd
)

readonly php_recommended=(
  php-intl
  php-sodium
  php-sysvsem
  php-opcache
  php-apcu
  php-redis
  php-ldap
  php-gmp
  php-exif
  php-imagick
  php-pecl-imagick
  php-pcntl
  php-phar
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

# Wrapper for Nextcloud's occ CLI tool. Executed as the apache user
occ() {
  runuser -u apache -- php /var/www/html/nextcloud/occ "$@"
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

log "Installing dependencies"

install_package "${dependencies[@]}"
success "Dependencies successfully installed."

log "Installing Apache webserver"

install_package httpd
success "Apache webserver successfully installed."

log "Configuring Apache"

cat >> /etc/httpd/conf.d/nextcloud.conf << 'EOF'
<VirtualHost *:80>
  DocumentRoot /var/www/html/nextcloud
  ServerName nextcloud-server

  <FilesMatch \.php$>
    SetHandler "proxy:unix:/run/php-fpm/www.sock|fcgi://localhost"
  </FilesMatch>

  <Directory /var/www/html/nextcloud>
    Require all granted
    AllowOverride All
    Options FollowSymLinks MultiViews

    <IfModule mod_dav.c>
      Dav off
    </IfModule>

  </Directory>
</VirtualHost>
EOF
run systemctl enable httpd.service
success "Apache successfully configured"

log "Installing PHP"

# Install EPEL and Remi repository
install_package "https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm"
install_package "https://rpms.remirepo.net/enterprise/remi-release-10.rpm"
# Enable PHP 8.2 module from Remi
run dnf module reset php -y
run dnf module install -y php:remi-8.2
# Required modules
install_package "${php_required[@]}"
# Recommended modules
install_package "${php_recommended[@]}"
success "PHP successfully installed"

log "Enabling php-fpm service and starting Apache"
run systemctl enable --now php-fpm.service
run systemctl restart httpd.service
success "php-fpm service enabled and Apache started"

log "Configuring PHP"

for ini in /etc/php.ini /etc/php-fpm.d/www.conf; do
    [ -f "$ini" ] || continue
    sed -i "s/^memory_limit.*/memory_limit = 512M/" "$ini"
    sed -i "s/^max_execution_time.*/max_execution_time = 360/" "$ini"
    sed -i "s/^upload_max_filesize.*/upload_max_filesize = 512M/" "$ini"
    sed -i "s/^post_max_size.*/post_max_size = 512M/" "$ini"
done
success "PHP successfully configured"

log "Installing Valkey"

install_package valkey
success "Valkey successfully installed"

log "Configuring Valkey"

# Enable and start valkey
run systemctl enable --now valkey
# Bind to localhost for security
sed -i "s/^bind .*/bind 127.0.0.1/" /etc/valkey/valkey.conf
# Set a password
sed -i "s/^# requirepass .*/requirepass '${valkey_password}'/" /etc/valkey/valkey.conf
# Restart to apply changes
run systemctl restart valkey
success "Valkey successfully configured"

log "Downloading and verifying Nextcloud"

# Download Nextcloud archive and checksum
curl -sL -O "https://download.nextcloud.com/server/releases/nextcloud-${NEXTCLOUD_VERSION}.tar.bz2"
curl -sL -O "https://download.nextcloud.com/server/releases/nextcloud-${NEXTCLOUD_VERSION}.tar.bz2.sha256"
# verifying checksum
if ! grep "\.tar\.bz2$" "nextcloud-${NEXTCLOUD_VERSION}.tar.bz2.sha256" | sha256sum -c > /dev/null 2>&1; then
    log "Nextcloud checksum verification FAILED!"
    exit 1
fi
success "Nextcloud successfully downloaded and verified"

log "Installing Nextcloud"

# Extract the archive
tar -xjf "nextcloud-${NEXTCLOUD_VERSION}.tar.bz2"
# Copy to Apache web root
cp -R nextcloud/ /var/www/html/
# Create data directory
mkdir -p /var/www/html/nextcloud/data
# Set correct ownership for Apache
chown -R apache:apache /var/www/html/nextcloud
# Clean up downloaded files
rm -f "nextcloud-${NEXTCLOUD_VERSION}.tar.bz2"
rm -f "nextcloud-${NEXTCLOUD_VERSION}.tar.bz2.sha256"
success "Nextcloud successfully installed"

log "Configuring firewall"
 
run firewall-cmd --add-service=http --permanent
run firewall-cmd --add-service=https --permanent
run firewall-cmd --reload
success "Firewall successfully configured"

log "Configuring SELinux"

# Allow Apache to make outbound network connections
run setsebool -P httpd_can_network_connect on
# Allow Apache to connect to a remote database
run setsebool -P httpd_can_network_connect_db on
# Allow Apache to send mail
run setsebool -P httpd_can_sendmail on
# Apply the exact file contexts prescribed by the official Nextcloud docs.
# The || true guards prevent errexit from aborting if a context already exists.
run semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/data(/.*)?' || true
run semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/config(/.*)?' || true
run semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/apps(/.*)?' || true
run semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/.htaccess' || true
run semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/.user.ini' || true
run semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/3rdparty/aws/aws-sdk-php/src/data/logs(/.*)?' || true
# Apply all registered contexts to the filesystem in one pass
run restorecon -R '/var/www/html/nextcloud/'
success "SELinux successfully configured"

log "Configuring Nextcloud"
 
run occ maintenance:install \
    --database "mysql" \
    --database-host "${db_host}" \
    --database-name "${db_name}" \
    --database-user "${db_user}" \
    --database-pass "${db_password}" \
    --admin-user "${nc_admin_user}" \
    --admin-pass "${nc_admin_pass}" \
    --data-dir "/var/www/html/nextcloud/data"
success "Nextcloud successfully configured"

log "Configuring trusted domains"
 
# Index 0 – direct IP access (useful for testing)
run occ config:system:set trusted_domains 0 --value="${nc_server_ip}"
# Index 1 – hostname through the reverse proxy
run occ config:system:set trusted_domains 1 --value="${nc_domain}"
# Tell Nextcloud it lives behind an HTTPS reverse proxy
run occ config:system:set overwrite.cli.url --value="https://${nc_domain}"
run occ config:system:set overwriteprotocol --value="https"
# Trust the reverse-proxy IP for X-Forwarded-For headers
run occ config:system:set trusted_proxies 0 --value="${nc_proxy_ip}"
success "Trusted domains successfully configured"

log "Configuring Valkey caching"
 
run occ config:system:set redis host --value="127.0.0.1"
run occ config:system:set redis port --value=6379 --type=integer
run occ config:system:set redis password --value="${valkey_password}"
run occ config:system:set memcache.local --value="\OC\Memcache\APCu"
run occ config:system:set memcache.distributed --value="\OC\Memcache\Redis"
run occ config:system:set memcache.locking --value="\OC\Memcache\Redis"
success "Valkey caching successfully configured"

log "Creating regular Nextcloud user"

OC_PASS="${nc_user_pass}" run occ user:add \
    --password-from-env \
    --display-name="${nc_user_display_name}" \
    "${nc_user}"
success "Regular user ${nc_user} successfully created"

log "Configuring LDAP/AD authentication"

# Enable the LDAP app
run occ app:enable user_ldap
# Create a new LDAP configuration
run occ ldap:create-empty-config
# Configure LDAP connection to the Windows DC
run occ ldap:set-config s01 ldapHost "192.168.132.194"
run occ ldap:set-config s01 ldapPort "389"
run occ ldap:set-config s01 ldapBase "DC=ad,DC=t02-domain404,DC=internal"
run occ ldap:set-config s01 ldapBaseUsers "OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal"
run occ ldap:set-config s01 ldapBaseGroups "OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal"
run occ ldap:set-config s01 ldapAgentName "SVC_DomainJoin@ad.t02-domain404.internal"
run occ ldap:set-config s01 ldapAgentPassword "Str0ng-J0in-P@ss!"
run occ ldap:set-config s01 ldapUserFilter "(&(objectClass=person)(objectCategory=person))"
run occ ldap:set-config s01 ldapUserDisplayName "displayName"
run occ ldap:set-config s01 ldapLoginFilter "(&(objectClass=person)(sAMAccountName=%uid))"
run occ ldap:set-config s01 ldapGroupFilter "(objectClass=group)"
run occ ldap:set-config s01 ldapGroupDisplayName "cn"
run occ ldap:set-config s01 ldapGroupMemberAssocAttr "member"
run occ ldap:set-config s01 ldapEmailAttribute "mail"
run occ ldap:set-config s01 ldapConfigurationActive "1"
success "LDAP/AD authentication successfully configured"

log "Creating calendar for ${nc_user}"

run occ dav:create-calendar "${nc_user}" "Domain404 Calendar"
success "Calendar successfully created."

log "Installing Nextcloud Forms app"

run occ app:install forms
success "Forms app successfully installed."

log "Applying network fix"
 
bash ${PROVISIONING_SCRIPTS}/networkfix.sh

echo ""
echo "  +-------------------------------------------------+"
echo "  |                                                 |"
echo "  |        Nextcloud server — Ready!                |"
echo "  |                                                 |"
echo "  |  Host  : ${HOSTNAME}                       |"
echo "  |  Group : t02-domain404.internal                 |"
echo "  |                                                 |"
echo "  +-------------------------------------------------+"
echo ""
