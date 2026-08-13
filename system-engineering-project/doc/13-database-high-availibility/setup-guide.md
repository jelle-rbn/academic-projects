# Setup guide - Extended GPOs Extension

Author(s): G. Lescur - `guillaume.lescur@student.hogent.be`

This guide describes the step-by-step procedure to deploy the database high availibility extension. It covers the automated steps and the manual steps needed for this.

## Provisioning workflow

The database high availibility extension is provisioned in 3 phases.

### Phase 1 - Provision the database

1. Provision the database using command `vagrant up database`

### Phase 2 - Provision the second database

1. Provision the second database using command `vagrant up database2`.

The first and second database get into a cluster thanks to the `cluster-init.sh` script. This means they communicate with each other and share databases.

### Phase 3 - Provision the haproxy server

1. Provision the haproxy server using command `vagrant up haproxy`

This proxy connects to the database and performs load balancing on the databases


## Verification

Confirm the databases and haproxy are working correctly using these checks:

| Test | Procedure | Expected Result |
| :--- | :--- | :--- |
| **cluster size ckeck** | `mysql -u root -p'WeWillCrushThisProject404' -e "SHOW STATUS LIKE 'wsrep_cluster_size';"` | The value is set on 2 |
| **Load balancing check** | Use this command multiple times: `mysql -h 192.168.132.201 -u domain404 -p'GroupT02ForVictory' -e "SELECT @@hostname;"` | The output switches between database and database2 |
| **Failover test** | Stop one of the databases. Use this command: `mysql -h 192.168.132.201 -u domain404 -p'GroupT02ForVictory' -e "SELECT @@hostname;"` | The output will always be the active database |
