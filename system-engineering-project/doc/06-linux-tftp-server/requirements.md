# Requirements Document - Linux TFTP Server

_Author: J. Robyn - jelle.robyn@student.hogent.be_

## Deliverables

- **TFTP Service Installation:** The TFTP server package (`tftp-server`) and client (`tftp`) must be successfully installed on AlmaLinux 10
- **Custom Startup Parameters:** The service must be configured with specific flags: `-c` (create new files), `-p` (no additional permission checks), and `-s` (secure chroot) via a `systemd` drop-in file
- **Directory Structure:** A functional root directory at `/var/lib/tftpboot` with a dedicated sub-directory `/upload` for incoming files
- **Access Control:** The `tftp` daemon must have the necessary ownership (`tftp:tftp`) and permissions to read from the root and write to the upload directory.
- **Network & Socket Activation:** The `tftp.socket` must be active and listening, with `Firewalld` configured to allow traffic on port 69/UDP

## Subtasks

1. Gather information and resources
   - Person in charge of implementation: Jelle
   - Person in charge of testing: N/A
   - Dependancies: N/A

2. Provisioning development
   - Person in charge of implementation: Jelle
   - Person in charge of testing: Johan
   - Dependancies: `util.sh`, `common.sh`

3. Service installation and configuration
   - Person in charge of implementation: Jelle
   - Person in charge of testing: Johan
   - Dependancies: subtask 2

4. Security and network configuration
   - Person in charge of implementation: Jelle
   - Person in charge of testing: N/A
   - Dependancies: subtask 2, 3

5. Technical documentation
   - Person in charge of implementation: Jelle
   - Person in charge of testing: N/A
   - Dependancies: subtask 2, 3, 4, 5, 6

6. Test plan / functional validation
   - Person in charge of implementation: Jelle
   - Person in charge of testing: Johan
   - Dependancies: subtask 2, 3

7. Testing / testing report
   - Person in charge of testing: Johan
   - Dependancies: subtask 2, 3, 4, 5, 6

## Technical Specifications

| Component         | Requirement / Value                           |
| :---------------- | :-------------------------------------------- |
| **OS**            | AlmaLinux 10                                  |
| **TFTP Root**     | `/var/lib/tftpboot` (Permissions: 755)        |
| **Upload Path**   | `/var/lib/tftpboot/upload` (Permissions: 770) |
| **Service Flags** | `-c` `-p` `-s`                                |
| **Activation**    | Socket-based activation (`tftp.socket`)       |
| **Firewall Zone** | Default zone with `tftp` service allowed      |

## Time Spent

| Student   | (Sub)task                          | Estimated effort | Actual effort |
| :-------- | :--------------------------------- | ---------------: | ------------: |
| Jelle     | Gather information and resources   |           2h 00m |        1h 20m |
| Jelle     | Provisioning development           |           4h 00m |        6h 45m |
| Jelle     | Service installation and resources |           0h 30m |        0h 35m |
| Jelle     | Security and network configuration |           0h 30m |        0h 30m |
| Jelle     | Technical documentation            |           1h 30m |        6h 25m |
| Jelle     | Test plan v1                       |           2h 30m |        7h 05m |
| Johan     | Testing and test report v1         |           2h 00m |        4h 00m |
| Jelle     | Test plan v2                       |           0h 30m |        0h 20m |
|           | Testing and test report v2         |                  |               |
| **Total** |                                    |      **13h 00m** |   **27h 00m** |

### Administration

| Student   | (Sub)task      | Estimated effort | Actual effort |
| :-------- | :------------- | ---------------: | ------------: |
| Jelle     | Administration |           0h 30m |        0h 30m |
| **Total** |                |      **00h 30m** |   **00h 30m** |

## Time spent - Jira screenshot

![Time spent report](../08-linux-tftp-server/img/TFTP_time_spent_report.png)

**Variance remarks**

_Gather information and resources:_<br>
Most of the resources were found before starting the provisioning.
I had to research some additional information on how to best test a TFTP server afterwards.

_Provisioning development:_<br>
Writing scripts is fairly new to me, so I knew that creating one from scratch would be time-consuming.
The provisioning skeleton was very helpful for this task. Moving forward from the skeleton, it was a matter of following a logical flow.
For instance, you cannot set permissions if the directory or file has not yet been created.
After establishing the backbone of the script, the rest of the writing process went fairly smoothly.

ANNEX: After creating the reverse-proxy provisioning script, I reworked the TFTP script with some minor adjustments.

_Technical documentation:_
Documenting the process of installing and testing was a very time-consuming process.
As a result, the estimated time was underestimated. It feels strange to spend more time documenting than actually configuring or testing the server.
In comparison, the execution time to install or test the server while following the documentation is next to nothing compared to the effort necessary to
write documentation that is as complete as possible.

_Test plan_
The test plan initially contained tests for downloading and uploading files from an AlmaLinux client.
This client was used in the test due to a lack of available Cisco devices.
Although these tests were quite straightforward, a lot of issues occurred because of firewall and permission rules.
After a lot of searching and debugging, I concluded these tests were not representative of the use of Cisco networking equipment.
Apparently, Cisco routers and / or switches do not use such strict firewall rules or permissions.
