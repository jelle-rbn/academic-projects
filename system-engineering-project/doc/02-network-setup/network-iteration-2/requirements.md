# Requirements Document - Network infrastructure (iteration 2)

_Author: J. Robyn - jelle.robyn@student.hogent.be_

## Deliverables

### VLAN Segmentation

The network must be segmented into the following VLANs:

- VLAN 1 - MANAGEMENT
- VLAN 11 - DMZ
- VLAN 22 - EMPLOYEES (Clients)
- VLAN 33 - SERVERS (Internal)

Each VLAN must be correctly configured on both the switch and router.

---

### Inter-VLAN Routing

The router must perform inter-VLAN routing using subinterfaces (router-on-a-stick).
Each VLAN must have a correctly assigned default gateway:

VLAN 1 -> 192.168.132.225
VLAN 11 -> 192.168.132.233
VLAN 22 -> 192.168.132.129
VLAN 33 -> 192.168.132.193

---

### IP Addressing Compliance

All devices must use IP addresses strictly according to the addressing table.
Subnet masks, ranges, and broadcast addresses must be respected.

---

### DHCP Configuration

The router must act as a DHCP server for VLAN 22:

- DHCP pool must match subnet 192.168.132.128/26
- Default gateway must be 192.168.132.129
- DNS server must be 172.22.128.1
- The gateway address must be excluded from the pool

---

### NAT (PAT) Configuration

The router must perform Port Address Translation (PAT):

- Inside interfaces: all VLAN subinterfaces
- Outside interface: uplink (DHCP assigned IP in 172.22.0.0/16)
- All internal networks must be translated using overload

---

### Default Routing

A default route must be configured:

- Destination: 0.0.0.0/0
- Next hop: 172.22.255.254

---

### ACL-Based Network Security

Access Control Lists must enforce segmentation and least-privilege access:

- VLAN 1 (Management):
  - Only the TFTP server may access network devices (SSH, TFTP, limited ICMP)
- VLAN 11 (DMZ):
  - Only required services (HTTP/HTTPS, DNS) allowed
  - No access to internal networks
- VLAN 22 (Clients):
  - Allowed: DHCP, DNS, HTTP/HTTPS, internal server access
  - Denied: Management VLAN access
- VLAN 33 (Servers):
  - Limited outbound access (DNS, HTTP/HTTPS)
  - No access to management VLAN

---

### Anti-Spoofing Protection

Inbound traffic on the WAN interface must block private IP ranges:

- 10.0.0.0/8
- 172.16.0.0/12
- 192.168.0.0/16

---

### Switch Configuration

- Access ports must be assigned to the correct VLANs
- Trunk port must be configured between switch and router
- Allowed VLANs must be restricted to 1, 11, 22, 33
- Native VLAN must be set to VLAN 1

---

### Unused Port Security

- All unused switch ports must be:
  - Assigned to VLAN 999 (BLACKHOLE)
  - Administratively shut down

---

### Management Network Security

- Management VLAN must only allow access from the TFTP server
- Remote access must be secured via SSH only
- Telnet must be disabled

---

### Connectivity Validation

The following must be verifiable:

- Clients receive DHCP addresses
- Clients can access the internet (via NAT)
- Clients can reach internal servers
- DMZ can only reach allowed services
- Management access is restricted
- Inter-VLAN routing works as intended

---

## Subtasks

1. Gather information and resources
   - Person in charge of implementation: Jelle
   - Person in charge of testing: N/A
   - Dependencies: N/A

2. Network design and planning
   - Person in charge of implementation: Jelle
   - Person in charge of testing: N/A
   - Dependencies: N/A

3. IP addressing and VLAN definition
   - Person in charge of implementation: Jelle
   - Person in charge of testing: <!-- Name: anyone other than the owner! -->
   - Dependencies: subtask 1

4. Switch configuration
   - Person in charge of implementation: Jelle
   - Person in charge of testing: <!-- Name: anyone other than the owner! -->
   - Dependencies: subtask 2

5. Router configuration (routing, DHCP)
   - Person in charge of implementation: Jelle
   - Person in charge of testing: <!-- Name: anyone other than the owner! -->
   - Dependencies: subtask 2

6. NAT implementation
   - Person in charge of implementation: Jelle
   - Person in charge of testing: <!-- Name: anyone other than the owner! -->
   - Dependencies: subtask 3, 4

7. ACL implementation
   - Person in charge of implementation: Jelle
   - Person in charge of testing: <!-- Name: anyone other than the owner! -->
   - Dependencies: subtask 3, 4

8. ACL documentation
   - Person in charge of implementation: Jelle
   - Person in charge of testing: N/A
   - Dependencies: subtask 5

9. Functional validation and testing
   - Person in charge of implementation:
   - Person in charge of testing: <!-- Name: anyone other than the owner! -->
   - Dependencies: subtask 3, 4, 5

## Technical Specifications

| Component                 | Requirement / Value              |
| :------------------------ | :------------------------------- |
| **Router Model**          | Cisco IOS Router                 |
| **Switch Model**          | Cisco Layer 2 Switch             |
| **Routing Method**        | Router-on-a-stick (802.1Q)       |
| **VLANs**                 | 1, 11, 22, 33                    |
| **Management VLAN**       | VLAN 1 (192.168.132.224/29)      |
| **DMZ VLAN**              | VLAN 11 (192.168.132.232/29)     |
| **Client VLAN**           | VLAN 22 (192.168.132.128/26)     |
| **Server VLAN**           | VLAN 33 (192.168.132.192/27)     |
| **WAN Network**           | 172.22.0.0/16 (DHCP assigned IP) |
| **Default Gateway (WAN)** | 172.22.255.254                   |
| **DNS Server**            | 172.22.128.1                     |
| **NAT Type**              | PAT (Overload)                   |
| **Security Model**        | ACL-based segmentation           |
| **Management Access**     | SSH only                         |
| **Unused Ports VLAN**     | VLAN 999 (BLACKHOLE)             |

## Time Spent

| Student       | (Sub)task                        | Estimated effort | Actual effort |
| :------------ | :------------------------------- | ---------------: | ------------: |
| Jelle         | Gather information and resources |           1h 30m |        1h 30m |
| Jelle         | Requirements                     |           1h 30m |           h m |
| Jelle         | Addressing table                 |           1h 00m |        1h 00m |
| Jelle         | Setup guide                      |           0h 30m |        0h 15m |
| Jelle         | Switch configuration             |           0h 30m |        0h 45m |
| Jelle         | NAT configuration                |           0h 30m |        1h 30m |
| Jelle         | ACL configuration                |           4h 00m |           h m |
| Jelle         | ACL documentation                |           1h 30m |           h m |
| Jelle         | Packet tracer build              |           4h 00m |           h m |
| Jelle         | Cheat sheet                      |           1h 00m |        1h 55m |
| Jelle         | Testing network                  |           4h 00m |        1h 00m |
| Jelle         | Test plan                        |           3h 00m |           h m |
| <!-- NAAM --> | Test report                      |              h m |           h m |
| **Total**     |                                  |          **h m** |       **h m** |

### Administration

| Student   | (Sub)task      | Estimated effort | Actual effort |
| :-------- | :------------- | ---------------: | ------------: |
| Jelle     | Administration |           1h 00m |           h m |
| **Total** |                |       **1h 00m** |       **h m** |

### Jira screenshot

![Time spent report]()

**Variance remarks**
