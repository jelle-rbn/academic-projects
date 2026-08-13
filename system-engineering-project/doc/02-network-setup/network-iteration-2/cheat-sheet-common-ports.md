# Cheat Sheet - Common Ports

This cheat sheet covers the most important network port numbers.

- [1. Well-known ports (0-1023)](#1-well-known-ports-0-1023)
- [2. Commonly used registered ports (1024-49151)](#2-commonly-used-registered-ports-1024-49151)
- [3. Common Ports by Service Category](#3-common-ports-by-service-category)
  - [3.1 - Web Services](#31---web-services)
  - [3.2 - Mail Services](#32---mail-services)
  - [3.3 - Remote Access and Management](#33---remote-access-and-management)
  - [3.4 - Directory / Authentication](#34---directory--authentication)
  - [3.5 - File Transfer and Sharing](#35---file-transfer-and-sharing)
  - [3.6 - Network Core](#36---network-core)
  - [3.7 - Network Management and Monitoring](#37---network-management-and-monitoring)
  - [3.8 - Communication, VoIP, and Chat](#38---communication-voip-and-chat)
  - [3.9 - Legacy and Testing](#39---legacy-and-testing)

## 1. Well-known ports (0-1023)

| Port | Service          | Protocol       | Description                                                      |
| ---- | ---------------- | -------------- | ---------------------------------------------------------------- |
| 7    | Echo             | TCP, UDP       | Echo service                                                     |
| 19   | CHARGEN          | TCP, UDP       | Character Generator Protocol, rarely used due to vulnerabilities |
| 20   | FTP-data         | TCP, SCTP      | FTP data transfer                                                |
| 21   | FTP              | TCP, UDP, SCTP | FTP command control                                              |
| 22   | SSH/SCP/SFTP     | TCP, UDP, SCTP | Secure Shell, secure logins & file transfers                     |
| 23   | Telnet           | TCP            | Unencrypted text communications                                  |
| 25   | SMTP             | TCP            | Email routing between mail servers                               |
| 42   | WINS Replication | TCP, UDP       | Microsoft WINS service                                           |
| 43   | WHOIS            | TCP, UDP       | Domain information lookup                                        |
| 49   | TACACS           | UDP            | Remote authentication service                                    |
| 53   | DNS              | TCP, UDP       | Domain Name System                                               |
| 67   | DHCP/BOOTP       | UDP            | Server port                                                      |
| 68   | DHCP/BOOTP       | UDP            | Client port                                                      |
| 69   | TFTP             | UDP            | Trivial File Transfer Protocol                                   |
| 70   | Gopher           | TCP            | Document retrieval protocol                                      |
| 79   | Finger           | TCP            | User information retrieval                                       |
| 80   | HTTP             | TCP, UDP, SCTP | Web protocol                                                     |
| 88   | Kerberos         | TCP, UDP       | Authentication system                                            |
| 110  | POP3             | TCP            | Email retrieval                                                  |
| 123  | NTP              | UDP            | Time synchronization                                             |
| 135  | Microsoft RPC    | TCP, UDP       | RPC Endpoint Mapper                                              |
| 137  | NetBIOS-ns       | TCP, UDP       | Name service                                                     |
| 138  | NetBIOS-dgm      | TCP, UDP       | Datagram service                                                 |
| 139  | NetBIOS-ssn      | TCP, UDP       | Session service                                                  |
| 143  | IMAP             | TCP, UDP       | Email access                                                     |
| 161  | SNMP             | UDP            | Network management                                               |
| 162  | SNMP-trap        | UDP            | SNMP traps                                                       |
| 179  | BGP              | TCP            | Border Gateway Protocol                                          |
| 194  | IRC              | UDP            | Chat protocol                                                    |
| 389  | LDAP             | TCP, UDP       | Directory service                                                |
| 427  | SLP              | TCP            | Service discovery                                                |
| 443  | HTTPS            | TCP, UDP, SCTP | Secure HTTP                                                      |
| 445  | SMB              | TCP, UDP       | File sharing                                                     |
| 500  | IPSec / IKE      | UDP            | Security protocol                                                |
| 512  | rexec            | TCP            | Remote execution                                                 |
| 513  | rlogin           | TCP            | Remote login                                                     |
| 514  | syslog           | UDP            | Logging                                                          |
| 515  | LPD/LPR          | TCP            | Printing                                                         |
| 520  | RIP              | UDP            | Routing                                                          |
| 540  | UUCP             | TCP            | Unix communication                                               |
| 548  | AFP              | TCP            | Apple file protocol                                              |
| 554  | RTSP             | TCP, UDP       | Streaming                                                        |
| 587  | SMTP             | TCP            | Email submission                                                 |
| 631  | IPP              | TCP            | Printing                                                         |
| 636  | LDAP over SSL    | TCP, UDP       | Secure LDAP                                                      |
| 873  | rsync            | TCP            | File sync                                                        |
| 989  | FTPS             | TCP            | Secure FTP data                                                  |
| 990  | FTPS             | TCP            | Secure FTP control                                               |
| 993  | IMAPS            | TCP            | Secure IMAP                                                      |
| 995  | POP3S            | TCP, UDP       | Secure POP3                                                      |

## 2. Commonly used registered ports (1024-49151)

| Port      | Service         | Protocol | Description           |
| --------- | --------------- | -------- | --------------------- |
| 1025      | Microsoft RPC   | TCP      | Remote Procedure Call |
| 1080      | SOCKS Proxy     | TCP/UDP  | Proxy protocol        |
| 1194      | OpenVPN         | TCP, UDP | VPN                   |
| 1214      | KAZAA           | TCP      | File sharing          |
| 1241      | Nessus          | TCP, UDP | Security scanner      |
| 1311      | Dell OpenManage | TCP      | Server management     |
| 1337      | WASTE           | TCP      | P2P file sharing      |
| 1701      | L2TP            | TCP      | VPN                   |
| 1720      | H.323           | TCP      | VoIP                  |
| 1723      | PPTP            | TCP, UDP | VPN                   |
| 1812      | RADIUS          | UDP      | Authentication        |
| 1813      | RADIUS          | UDP      | Accounting            |
| 1900      | UPnP            | UDP      | Plug and Play         |
| 2000      | Cisco SCCP      | TCP      | Call control          |
| 2049      | NFS             | UDP      | File sharing          |
| 2082      | cPanel          | TCP, UDP | Hosting panel         |
| 2083      | cPanel SSL      | TCP, UDP | Secure panel          |
| 2222      | DirectAdmin     | TCP      | Hosting panel         |
| 2302      | Gaming          | UDP      | HALO                  |
| 2483      | Oracle          | TCP, UDP | Database              |
| 3050      | Interbase DB    | TCP, UDP | Database              |
| 3074      | Xbox Live       | TCP, UDP | Gaming                |
| 3128      | HTTP Proxy      | TCP      | Proxy                 |
| 3260      | iSCSI           | TCP, UDP | Storage               |
| 3306      | MySQL           | TCP      | Database              |
| 3389      | RDP             | TCP      | Remote desktop        |
| 3689      | DAAP            | TCP      | Apple iTunes          |
| 3690      | SVN             | TCP, UDP | Version control       |
| 4444      | Blaster         | TCP, UDP | Worm                  |
| 4500      | IPSec NAT       | UDP      | VPN                   |
| 5000      | UPnP            | TCP      | Plug and Play         |
| 5001      | iperf           | TCP      | Bandwidth tool        |
| 5060      | SIP             | TCP, UDP | VoIP                  |
| 5061      | SIP-TLS         | TCP      | Secure VoIP           |
| 5222      | XMPP            | TCP, UDP | Messaging             |
| 5353      | mDNS            | UDP      | Multicast DNS         |
| 5432      | PostgreSQL      | TCP      | Database              |
| 5800      | VNC HTTP        | TCP      | Remote desktop        |
| 5900      | VNC             | TCP, UDP | Remote desktop        |
| 6000      | X11             | TCP      | GUI system            |
| 6112      | Diablo          | TCP, UDP | Gaming                |
| 6379      | Redis           | TCP      | NoSQL                 |
| 6500      | GameSpy         | TCP, UDP | Gaming                |
| 6588      | HTTP Proxy      | TCP      | Proxy                 |
| 6667      | IRC             | TCP      | Chat                  |
| 6697      | IRC SSL         | TCP      | Secure chat           |
| 6881-6999 | BitTorrent      | TCP, UDP | File sharing          |
| 7000      | Cassandra       | TCP      | Database cluster      |
| 7001      | Cassandra SSL   | TCP      | Secure cluster        |
| 7199      | Cassandra JMX   | TCP      | Management            |
| 8000      | HTTP Alt        | TCP      | Web apps              |
| 8080      | HTTP Proxy      | TCP      | Proxy                 |
| 8118      | Privoxy         | TCP      | Filtering proxy       |
| 8200      | VMware          | TCP, UDP | Virtualization        |
| 8500      | ColdFusion      | TCP, UDP | App server            |
| 8767      | Teamspeak       | UDP      | VoIP                  |
| 9042      | Cassandra       | TCP      | NoSQL                 |
| 9100      | Printer         | TCP      | Printing              |
| 9999      | Urchin          | TCP, UDP | Analytics             |
| 10000     | Webmin          | TCP, UDP | Admin tool            |
| 10161     | SNMP Secure     | TCP      | Network management    |
| 11371     | OpenPGP         | TCP, UDP | Keyserver             |
| 12345     | NetBus          | TCP      | Trojan                |
| 13720     | NetBackup       | TCP, UDP | Backup                |
| 14567     | Battlefield     | UDP      | Gaming                |
| 20000     | Usermin         | TCP, UDP | Webmail               |
| 24800     | Synergy         | TCP, UDP | Device sharing        |
| 27015     | Half-Life       | UDP      | Gaming                |
| 27017     | MongoDB         | TCP      | NoSQL                 |
| 27374     | Sub7            | TCP, UDP | Trojan                |
| 28960     | Call of Duty    | TCP, UDP | Gaming                |
| 31337     | Back Orifice    | TCP, UDP | Trojan                |
| 33434+    | traceroute      | UDP      | Network diagnostic    |

## 3. Common Ports by Service Category

### 3.1 - Web Services

| Port | Service |
| ---- | ------- |
| 80   | HTTP    |
| 443  | HTTPS   |

### 3.2 - Mail Services

| Port | Service |
| ---- | ------- |
| 25   | SMTP    |
| 110  | POP3    |
| 143  | IMAP    |

### 3.3 - Remote Access and Management

| Port | Service |
| ---- | ------- |
| 22   | SSH/SCP |
| 23   | Telnet  |
| 3389 | RDP     |

### 3.4 - Directory / Authentication

| Port | Service                    |
| ---- | -------------------------- |
| 88   | Kerberos                   |
| 389  | LDAP                       |
| 464  | Kerberos password settings |
| 636  | LDAPS                      |

### 3.5 - File Transfer and Sharing

| Port   | Service |
| ------ | ------- |
| 20, 21 | FTP     |
| 69     | TFTP    |
| 445    | SMB     |

### 3.6 - Network Core

| Port   | Service      |
| ------ | ------------ |
| 53     | DNS          |
| 67, 68 | DHCP / BOOTP |
| 123    | NTP          |

### 3.7 - Network Management and Monitoring

| Port | Service |
| ---- | ------- |
| 161  | SNMP    |

### 3.8 - Communication, VoIP, and Chat

| Port | Service      |
| ---- | ------------ |
| 194  | IRC          |
| 1720 | H.323        |
| 5060 | SIP          |
| 5061 | SIP over TLS |

### 3.9 - Legacy and Testing

| Port | Service |
| ---- | ------- |
| 7    | Echo    |
| 23   | Telnet  |
