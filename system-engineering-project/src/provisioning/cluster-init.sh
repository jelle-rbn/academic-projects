#! /bin/bash
#
# Provisioning script for database cluster config
#
# Author: G. Lescur - guillaume.lescur@student.hogent.be

set -e

PRIMARY_NODE="192.168.132.195"
NODE_IP=$(hostname -I | tr ' ' '\n' | grep 192.168.132 | head -n1)

DB_ROOT_PASSWORD='WeWillCrushThisProject404'
DB_NAME='wordpress'
DB_USER='domain404'
DB_PASSWORD='GroupT02ForVictory'
WEBSERVER_IP='192.168.132.196'
HAPROXY_IP='192.168.132.201'

setsebool -P rsync_full_access 1 || true
setsebool -P mysql_connect_any 1 || true
sudo semanage port -m -t mysqld_port_t -p tcp 4444
sudo semanage port -a -t mysqld_port_t -p tcp 4567 2>/dev/null || true
sudo semanage port -a -t mysqld_port_t -p udp 4567 2>/dev/null || true
sudo semanage port -a -t mysqld_port_t -p tcp 4568 2>/dev/null || true

echo "Starting Galera cluster on $NODE_IP"

# Start cluster
if [ "$NODE_IP" == "$PRIMARY_NODE" ]; then
    echo "Bootstrapping cluster (primary node)"
    sudo systemctl stop mariadb
    sudo systemctl set-environment _WSREP_NEW_CLUSTER='--wsrep-new-cluster'
    sudo systemctl start mariadb
    sudo systemctl unset-environment _WSREP_NEW_CLUSTER

    mysql -u root -p"${DB_ROOT_PASSWORD}" <<EOF
CREATE USER 'sst_user'@'%' IDENTIFIED BY 'YourSSTPassword';
GRANT RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'sst_user'@'%';
FLUSH PRIVILEGES;
EOF
else
    echo "Joining cluster manually"
    sudo systemctl restart mariadb
fi


# Wacht tot MariaDB klaar is
echo "Waiting for MariaDB to be ready..."
sleep 10

is_mysql_root_password_empty() {
  mysqladmin --user=root status > /dev/null 2>&1
}

# Database aanmaken alleen op primary
if [ "$NODE_IP" == "$PRIMARY_NODE" ]; then

    echo "Applying database hardening"

    if is_mysql_root_password_empty; then
    mysql << EOF
  ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
  DELETE FROM mysql.user WHERE User='';
  DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
  FLUSH PRIVILEGES;
EOF
    fi
    echo "Database hardening successfully applied"

    echo "Creating HAProxy check user"

        mysql -u root -p"${DB_ROOT_PASSWORD}" <<EOF
CREATE USER IF NOT EXISTS 'haproxy_check'@'%' IDENTIFIED BY '';
GRANT USAGE ON *.* TO 'haproxy_check'@'%';
FLUSH PRIVILEGES;
EOF

    echo " HAProxy check user created"

    echo "Creating database on primary node"

    mysql -u root -p"${DB_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'${WEBSERVER_IP}' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'${HAPROXY_IP}' IDENTIFIED BY '${DB_PASSWORD}';
FLUSH PRIVILEGES;
EOF

    echo "Database created"
fi

echo "Cluster setup complete"