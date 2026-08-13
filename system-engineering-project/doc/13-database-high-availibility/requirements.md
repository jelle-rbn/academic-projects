# Requirements

Author(s): G. Lescur - `guillaume.lescur@student.hogent.be`

This document specifies the requirements and technical procedures for the automated deployment of the high availibility database. The setup is designed to be reproducible using Vagrant and integrated bash provisioning scripts.

## Host Requirements

The software can run on a host using Microsoft Windows, any Linux distribution, or macOS.

| Software | Description |
| :--- | :--- |
| [Oracle Virtualbox](https://www.virtualbox.org/) | Virtualisation software used to run the virtual machines |
| [Vagrant](https://developer.hashicorp.com/vagrant) | Command line utility for managing the lifecycle of virtual machines, isolate dependencies and their configuration within a single disposable and consistent environment. |

## Deliverables

- **Database cluster:** The database is set up as a cluster with multiple nodes
- **Load balancer:** A load balancer splits queries between the nodes of the cluster
- **Failover:** When one of the nodes is not active, it's tasks get taken over by another node

## Subtasks

1. Research
  - Person in charge of implementation: G. Lescur
  - Person in charge of testing: N/A
  - Dependancies: N/A

2. Implementation
  - Person in charge of implementation: G. Lescur
  - Person in charge of testing: N/A
  - Dependancies: Subtask 1

3. Testing
  - Person in charge of implementation: G. Lescur
  - Person in charge of testing: N/A
  - Dependancies: Subtask 2

4. Documentation
  - Person in charge of implementation: G. Lescur
  - Person in charge of testing: N/A
  - Dependancies: Subtask 3

## Technical Specifications

| Componenet | Requirement / Value |
| :--- | :--- |
| OS | Almalinux (latest version) |
| Database | MariaDB (2-node setup for high availibility) |
| Database Nodes | DB1 + DB2 (synchronized or identical configuration) |
| Load Balancer | HAProxy (TCP mode for MySQL/MariaDB) |
| Root Password | Defined in the provisioning script (applied on both DB nodes) |
| Network Constraint | MySQL/MariaDB only accessible via HAProxy IP-address and webserver IP-address |
| Database Access Rule | Direct access to DB nodes is blocked for clients |
| Connection Flow | Webserver → HAProxy → MariaDB cluster |
| Port | 3306 (MySQL/MariaDB standard port) |
| HAProxy Mode | TCP load balancing (no HTTP layer) |
| Load Balancing Method | Round-robin (or least connections if required) |
| Health Checks | Enabled for DB1 and DB2 via HAProxy TCP checks |
| Firewall Rules | Only HAProxy allowed to connect to DB servers on port 3306 |
| Redundancy Goal | Continue service if one DB node fails |

## Time Spent

| Student | (Sub)task                      | Estimated effort | Actual effort |
| :---- | :------------------------------- | ---------------: | ------------: |
| Guillaume | Research                         |           4h 00m |       2h 30m  |
| Guillaume | Implementation                   |           10h 00m|       15h 00m |
| Guillaume | Testing                          |           8h 00m |       11h 45m |
| Guillaume | Documentation                    |           4h 00m |       4h 45m  |
| Guillaume | Test plan v1                     |           2h 00m |       4h 00m  |
| Guillaume | Testing and test report v1       |              h m |           h m |
| **Total** |                              |       **28h 00m** |       **34h 00m** |

**Variance remarks**

Implememtation and testing were more work than I expected. With a lot of trial and error, this took up quite some time
