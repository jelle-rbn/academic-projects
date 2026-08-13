# Requirements

Author(s): D. Cooreman - `dean.cooreman@student.hogent.be`

This document specifies the requirements and technical procedures for the automated deployment of a database. The setup is designed to be reproducible using Vagrant and integrated bash provisioning scripts.

## Host Requirements

The software can run on a host using Microsoft Windows, any Linux distribution, or macOS.

| Software | Description |
| :--- | :--- |
| [Oracle Virtualbox](https://www.virtualbox.org/) | Virtualisation software used to run the virtual machines |
| [Vagrant](https://developer.hashicorp.com/vagrant) | Command line utility for managing the lifecycle of virtual machines, isolate dependencies and their configuration within a single disposable and consistent environment. |

## Deliverables

- **Disable password logins:** Authentication should only be possible with SSH-keys.
- **Install and enable MariaDB:** MariaDB must be installed, enabled, and running on the target system.  
- **Set up Firewall rules:** The database should only accept connections from the webserver.
- **Database hardening** The database needs to have a root password set and any test-database should be removed.
- **Database and user is created** There is a database and a user created.

## Subtasks

1. Gather information and resources
  - Person in charge of implementation: D. Cooreman
  - Person in charge of testing: N/A
  - Dependancies: N/A

2. Disable password logins
  - Person in charge of implementation: D. Cooreman
  - Person in charge of testing: N/A
  - Dependancies: Subtask 1

3. Environment Setup & Dependencies
  - Person in charge of implementation: D. Cooreman
  - Person in charge of testing: N/A
  - Dependancies: Subtask 1

4. Install and enable MariaDB
  - Person in charge of implementation: D. Cooreman
  - Person in charge of testing: N/A
  - Dependancies: Subtask 3

5. Set up firewall rules
  - Person in charge of implementation: D. Cooreman
  - Person in charge of testing: N/A
  - Dependancies: Subtask 3, 4

6. Database hardening
  - Person in charge of implementation: D. Cooreman
  - Person in charge of testing: N/A
  - Dependancies: Subtask 3, 4

7. Create database ans user is created
  - Person in charge of implementation: D. Cooreman
  - Person in charge of testing: N/A
  - Dependancies: Subtask 3, 4

## Technical Specifications

| Componenet | Requirement / Value |
| :--- | :--- |
| OS | Almalinux (latest version) |
| Database | MariaDB |
| Root Password | Defined in the provisioning script |
| Network Constraint | MySQL restricted to the IP-address of the webserver |

## Time Spent

| Student    | Estimated Effort | Actual effort | Variance remarks |
| :--- | :--- | :--- | :--- |
| D.Cooreman | 10h0m | 07h10n | I could reuse some documentation from the webserver. |

![time](./img/time.png)
