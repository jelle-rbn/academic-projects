# ACL explanation guide for R1-config

_Author: J. Robyn - jelle.robyn@student.hogent.be_

---

## Overall design philosophy

This configuration implements a centralized gateway security model.<br>
Router R1 serves as the enforcement point for traffic moving between different VLANs (Inter-VLAN) and traffic destined for the internet.

- Layer 2 vs Layer 3: Traffic within the same VLAN is handled by the switch at Layer 2 and does not reach the router's ACLs.
- Directional Filtering: ACLs are applied to the sub-interfaces in the `in` direction.<br>
  This ensures traffic is filtered immediately upon entering the router, saving processing power.
- Stateful-like Behavior: Since standard ACLs are stateless, `established` rules are used for TCP,<br>
  and explicit return rules are used for UDP to allow bidirectional communication.

---

## ACL_VLAN1 - Management Network

```
  remark === ALLOW ICMP (LIMITED) ===
  ! From TFTP server <-> management devices
  permit icmp host 192.168.132.227 192.168.132.224 0.0.0.7 echo
  permit icmp 192.168.132.224 0.0.0.7 host 192.168.132.227 echo-reply

  remark === ALLOW TFTP SERVER ACCESS TO INTERNET ===
  permit udp host 192.168.132.227 any eq 53
  permit tcp host 192.168.132.227 any eq 53
  permit tcp host 192.168.132.227 any eq 80
  permit tcp host 192.168.132.227 any eq 443

  remark === ALLOW TFTP SERVER ACCESS TO NETWORK DEVICES ===
  permit udp host 192.168.132.225 host 192.168.132.227 eq 69
  permit udp host 192.168.132.226 host 192.168.132.227 eq 69
  permit udp host 192.168.132.227 host 192.168.132.225 eq 69
  permit udp host 192.168.132.227 host 192.168.132.226 eq 69

  remark === ALLOW DNS FROM MANAGEMENT TO DC ===
  ! Management devices -> DNS server (DC)
  permit udp 192.168.132.224 0.0.0.7 host 192.168.132.194 eq 53
  permit tcp 192.168.132.224 0.0.0.7 host 192.168.132.194 eq 53
  ! Return traffic
  permit tcp any 192.168.132.224 0.0.0.7 established

  remark === DEFAULT DENY ===
  ! Block all other traffic
  deny ip any any log
  exit
```

**Purpose:**<br>
Controls administrative traffic and maintenance operations.

**Explanation:**

- Allows ICMP between the TFTP server and management devices for diagnostics.
- Permits the TFTP server internet access (HTTP/HTTPS/DNS) for updates.
- Enables TFTP (UDP 69) transfers between network devices and the server.
- Centralizes DNS resolution via the Domain Controller (DC).

---

## ACL_VLAN11 - DMZ Network

```
remark === ALLOW ICMP (LIMITED) ===
  ! From DMZ <-> gateway (router interface)
  permit icmp 192.168.132.232 0.0.0.7 host 192.168.132.233 echo
  ! From router -> DMZ (reply)
  permit icmp host 192.168.132.233 192.168.132.232 0.0.0.7 echo-reply

  remark === ALLOW REVERSE PROXY TO INTERNAL WEBSERVER ===
  ! Reverse proxy -> webserver (HTTP/HTTPS)
  permit tcp host 192.168.132.234 host 192.168.132.196 eq 80
  permit tcp host 192.168.132.234 host 192.168.132.196 eq 443
  ! Reverse proxy -> Nextcloud server (HTTP)
  permit tcp host 192.168.132.234 host 192.168.132.197 eq 80
  ! Webserver -> reverse proxy (responses)
  permit tcp host 192.168.132.196 host 192.168.132.234 established
  permit tcp host 192.168.132.197 host 192.168.132.234 established

  remark === ALLOW DNS (ONLY TO DC EXEPT FOR PROXY) ===
  permit udp 192.168.132.232 0.0.0.7 host 192.168.132.194 eq 53
  permit tcp 192.168.132.232 0.0.0.7 host 192.168.132.194 eq 53
  ! DC -> DMZ (responses)
  permit udp host 192.168.132.194 eq 53 192.168.132.232 0.0.0.7
  permit tcp host 192.168.132.194 eq 53 192.168.132.232 0.0.0.7
  ! Reverse proxy DNS -> internet
  permit tcp host 192.168.132.234 any eq 53
  permit udp host 192.168.132.234 any eq 53

  remark === ALLOW WEB ACCESS (UPDATES) ===
  ! DMZ -> internet (HTTP/HTTPS updates)
  permit tcp 192.168.132.232 0.0.0.7 any eq 80
  permit tcp 192.168.132.232 0.0.0.7 any eq 443
  ! Internet -> DMZ (return return traffic from internet)
  permit tcp any 192.168.132.232 0.0.0.7 established

  remark === BLOCK ACCESS FROM DMZ TO INTERNAL NETWORKS ===
  deny ip 192.168.132.232 0.0.0.7 192.168.132.128 0.0.0.127

  remark === BLOCK ACCESS FROM DMZ TO MANAGEMENT VLAN ===
  deny ip 192.168.132.232 0.0.0.7 192.168.132.224 0.0.0.7

  remark === DEFAULT DENY ===
  ! Block all other traffic
  deny ip any any log
  exit
```

**Purpose:**<br>
Isolates publicly accessible services while allowing limited internal backend access.

**Explanation:**

- Allows the Reverse Proxy (`.234`) to reach the internal Webserver and Nextcloud server.
- Strictly limits DNS: DMZ hosts use the internal DC, while the Proxy is allowed external DNS.
- Permits HTTP/HTTPS to the internet for system updates.
- Implicit Security: Blocks all direct access from the DMZ to internal client or management networks.

---

## ACL_VLAN22 - Client Network

```
remark === ALLOW ICMP (LIMITED) ===
  ! Clients -> VLAN 22
  permit icmp 192.168.132.128 0.0.0.63 host 192.168.132.129
  ! Clients -> DC
  permit icmp 192.168.132.128 0.0.0.63 host 192.168.132.194
  ! Clients -> Nextcloud
  permit icmp 192.168.132.128 0.0.0.63 host 192.168.132.197

  remark === DHCP (client -> router) ===
  ! DHCP client -> router (request)
  permit udp any eq 68 any eq 67
  ! DHCP router -> client (response)
  permit udp any eq 67 any eq 68

  remark === ALLOW DNS VIA DC ===
  ! Clients -> DNS server (DC)
  permit udp 192.168.132.128 0.0.0.63 host 192.168.132.194 eq 53
  ! DNS responses to clients
  permit tcp 192.168.132.128 0.0.0.63 host 192.168.132.194 eq 53

  ! remark === ALLOW DNS VIA INTERNET ===
  ! Clients -> internet
  ! permit udp 192.168.132.128 0.0.0.63 any eq 53
  ! permit tcp 192.168.132.128 0.0.0.63 any eq 53

  remark === ALLOW WEB ACCESS ===
  ! Clients -> internet (HTTP)
  permit tcp 192.168.132.128 0.0.0.63 any eq 80
  ! Clients -> internet (HTTPS)
  permit tcp 192.168.132.128 0.0.0.63 any eq 443
  ! Internet -> clients (return traffic)
  permit tcp any 192.168.132.128 0.0.0.63 established

  remark === CLIENTS TO REVERSE PROXY ===
  ! Clients -> reverse proxy
  permit tcp 192.168.132.128 0.0.0.63 host 192.168.132.234 eq 80
  permit tcp 192.168.132.128 0.0.0.63 host 192.168.132.234 eq 443

  remark === ALLOW CLIENTS TO DC (REQUIRED AD PORTS) ===
  ! Clients -> DC
  permit tcp 192.168.132.128 0.0.0.63 host 192.168.132.194 eq 88
  permit tcp 192.168.132.128 0.0.0.63 host 192.168.132.194 eq 389
  permit tcp 192.168.132.128 0.0.0.63 host 192.168.132.194 eq 445
  permit tcp 192.168.132.128 0.0.0.63 host 192.168.132.194 eq 636
  permit udp 192.168.132.128 0.0.0.63 host 192.168.132.194 eq 123
  permit tcp 192.168.132.128 0.0.0.63 host 192.168.132.194 range 49152 65535

  remark === CLIENTS TO STORAGE (SMB) ===
  permit tcp 192.168.132.128 0.0.0.63 host 192.168.132.199 eq 445

  remark === BLOCK ACCESS TO MANAGEMENT VLAN ===
  ! Clients -> block management VLAN
  deny ip 192.168.132.128 0.0.0.63 192.168.132.224 0.0.0.7

  remark === BLOCK CLIENT ACCESS TO SERVERS ===
  ! Clients -> block internal servers
  deny ip 192.168.132.128 0.0.0.63 192.168.132.192 0.0.0.31

  remark === DEFAULT DENY ===
  ! Block all other traffic
  deny ip any any log
  exit
```

**Purpose:**<br>
Implements a least-privilege model for end-users.

**Explanation:**

- DHCP/DNS: Essential services (DHCP to the router, DNS to the DC) are permitted.

- Web Access: HTTP/HTTPS allowed to the internet and the internal Reverse Proxy.

- Active Directory: Explicitly allows necessary ports (Kerberos, LDAP, SMB, NTP) to the DC (`.194`).

- Storage: Direct SMB access allowed to the Storage server (`.199`).

---

## ACL_VLAN33 - Server Network

> **Note:** Intra-VLAN traffic (e.g., Webserver to Database) is handled by the switch and is not filtered by this ACL.
> This ACL manages how servers interact with other networks.

```
remark === ALLOW ICMP (LIMITED) ===
  ! From servers -> gateway
  permit icmp 192.168.132.192 0.0.0.31 host 192.168.132.193 echo
  ! From gateway -> servers (reply)
  permit icmp host 192.168.132.193 192.168.132.192 0.0.0.31 echo-reply

  remark === ALLOW DC SSH TO REVERSE PROXY ===
  ! From DC to reverse proxy
  permit tcp host 192.168.132.194 host 192.168.132.234 eq 22
  ! From reverse proxy to DC (SSH response)
  permit tcp host 192.168.132.234 host 192.168.132.194 established

  remark === ALLOW SERVERS TO DMZ (WEB BACKEND) ===
  permit tcp 192.168.132.192 0.0.0.31 192.168.132.232 0.0.0.7 eq 80
  permit tcp 192.168.132.192 0.0.0.31 192.168.132.232 0.0.0.7 eq 443
  permit tcp 192.168.132.232 0.0.0.7 192.168.132.192 0.0.0.31 established

  remark === ALLOW DC RESPONSES TO CLIENTS (VLAN 22) ===
  ! Let DC / servers answer to client requists
  permit tcp 192.168.132.192 0.0.0.31 192.168.132.128 0.0.0.63 established
  ! Explicit permit rule for DNS (UDP 53)
  permit udp host 192.168.132.194 eq 53 192.168.132.128 0.0.0.63

  remark === ALLOW INTERNET ACCESS (UPDATES) ===
  ! Servers -> internet
  permit tcp 192.168.132.192 0.0.0.31 any eq 80
  permit tcp 192.168.132.192 0.0.0.31 any eq 443
  ! Return traffic
  permit tcp any 192.168.132.192 0.0.0.31 established

  remark === BLOCK ACCESS FROM SERVERS TO MANAGEMENT VLAN ===
  deny ip 192.168.132.192 0.0.0.31 192.168.132.224 0.0.0.7

  remark === BLOCK ACCESS FROM SERVERS TO CLIENT VLAN ===
  deny ip 192.168.132.192 0.0.0.31 192.168.132.128 0.0.0.63

  remark === DEFAULT DENY ===
  ! Block all other traffic
  deny ip any any log
  exit
```

**Purpose:**<br>
To control east-west traffic between servers and limit outbound communication.

**Explanation:**

- ICMP limited to server <-> gateway communication
- Domain Controller management:
  - DC (`192.168.132.194`) can SSH to reverse proxy (`192.168.132.234`)
- DNS is centralized:
  - Servers can only query the DC
- DMZ communication:
  - Servers can act as backend for DMZ (HTTP/HTTPS)
  - Return traffic explicitly allowed
- Application-specific flows:
  - Webserver -> database (3306)
  - Nextcloud -> database (3306)
  - Nextcloud -> DC (LDAP 389)
  - Webserver -> storage (NFS: 2049, RPC: 111 TCP/UDP)
  - Storage -> DC:
    - Kerberos (88)
    - NTP (123)
    - LDAP (389)
    - SMB (445)
  - DC -> storage (SMB 445)
- Internet access:
  - HTTP/HTTPS for updates
  - Return traffic allowed

**Explicit restrictions:**

- Servers cannot access management VLAN
- Servers cannot access client VLAN

**Security intent:**<br>
To minimize lateral movement and service abuse, allowing only explicitly defined application flows.

---

## ACL_OUTSIDE - WAN Protection

```
remark === ALLOW CLASS NETWORK ===
 permit ip 172.22.0.0 0.0.255.255 any

 remark === ALLOW ICMP (LIMITED) ===
 permit icmp any any

 remark === ANTI-SPOOFING ===
 ! Block private IP spoofing (internet -> internal)
 deny ip 10.0.0.0 0.255.255.255 any
 deny ip 172.16.0.0 0.15.255.255 any
 deny ip 192.168.0.0 0.0.255.255 any
 deny ip 127.0.0.0 0.0.0.255 any

 remark === ALLOW INTERNET (NEEDED FOR NAT TRAFFIC) ===
 permit ip any any
```

**Purpose:**<br>
Protects the perimeter and prevents IP spoofing.

**Explanation:**

- Anti-Spoofing: Blocks incoming traffic claiming to be from private (RFC1918) or loopback ranges.
- Class Network: Allows legitimate traffic from the upstream lab network (`172.22.0.0/16`).
- NAT Support: The `permit ip any any` at the end ensures that return traffic for internal hosts (via PAT) is not dropped.

---

**Security intent:**<br>
To mitigate IP spoofing attacks and ensure only valid external traffic enters the network.

## Final remarks

- The ACL design is stateful-like but technically stateless, relying on:
  - Explicit return rules (`established`)
  - Carefully mirrored permit statements for UDP
- DNS is intentionally centralized via the DC, improving:
  - Logging
  - Control
  - Security
- The design strongly limits:
  - Client-to-server access
  - Server-to-client communication
  - DMZ lateral movement
