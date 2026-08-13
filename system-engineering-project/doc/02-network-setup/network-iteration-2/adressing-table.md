# Adressing Table - Iteration 2

## IPv4

### Vlan Overview

| VLAN | Subnet | Subnet Mask     | Network Address | Usable IP's                       | Broadcast Address | Hosts |
| :--- | :----- | :-------------- | :-------------- | :-------------------------------- | :---------------- | :---- |
| 1    | /29    | 255.255.255.248 | 192.168.132.224 | 192.168.132.225 - 192.168.132.230 | 192.168.132.231   | 6     |
| 33   | /27    | 255.255.255.224 | 192.168.132.192 | 192.168.132.193 - 192.168.132.222 | 192.168.132.223   | 30    |
| 22   | /26    | 255.255.255.192 | 192.168.132.128 | 192.168.132.129 - 192.168.132.190 | 192.168.132.191   | 62    |
| 11   | /29    | 255.255.255.248 | 192.168.132.232 | 192.168.132.233 - 192.168.132.238 | 192.168.132.239   | 6     |

### Default Gateway & Uplink Interface

- Uplink interface (R1 - G0/0/0): IP via DHCP (172.22.0.0/16)
- Default gateway (class network): 172.22.255.254
- DNS server: 172.22.128.1

> The router acts as a DHCP client on the uplink interface and performs NAT
> towards the class network.  
> The former /30 ISP subnet from iteration 1 has been removed.

### VLAN 1 - Network management

VLAN 1 contains all networkdevices (switch, router and the TFTP server)

| Host        | IP              | Subnet | Subnet Mask     |
| :---------- | :-------------- | :----- | :-------------- |
| Switch      | 192.168.132.226 | /29    | 255.255.255.248 |
| Router      | 192.168.132.225 | /29    | 255.255.255.248 |
| TFTP-server | 192.168.132.227 | /29    | 255.255.255.248 |

### VLAN 11 - DMZ

VLAN 11 consists out of fixed, private IP-adresses and is reachable from the internet.

| Host          | IP              | Subnet | Subnet Mask     |
| :------------ | :-------------- | :----- | :-------------- |
| Reverse-proxy | 192.168.132.234 | /29    | 255.255.255.248 |

### VLAN 22 - Clients

VLAN 22 is used for clients (using DHCP) and has 61 usable adresses.
IP 192.168.132.129 (gateway) is excluded from the DHCP pool.

| First available IP | Last available IP | Subnet | Subnet Mask     |
| :----------------- | :---------------- | :----- | :-------------- |
| 192.168.132.130    | 192.168.132.190   | /26    | 255.255.255.192 |

### VLAN 33 - Internal servers

VLAN 33 contains all internal servers

| Host               | IP              | Subnet | Subnet Mask     |
| :----------------- | :-------------- | :----- | :-------------- |
| Windows Server DC  | 192.168.132.194 | /27    | 255.255.255.224 |
| Database           | 192.168.132.195 | /27    | 255.255.255.224 |
| Webserver          | 192.168.132.196 | /27    | 255.255.255.224 |
| Nextcloud server   | 192.168.132.197 | /27    | 255.255.255.224 |
| Nextcloud database | 192.168.132.198 | /27    | 255.255.255.224 |
| Storage            | 192.168.132.199 | /27    | 255.255.255.224 |
| Database2          | 192.168.132.200 | /27    | 255.255.255.224 |
| Haproxy            | 192.168.132.201 | /27    | 255.255.255.224 |

### Subinterface IP's

| VLAN | IP              | Subnet | Subnetmask      |
| :--- | :-------------- | :----- | :-------------- |
| 1    | 192.168.132.225 | /29    | 255.255.255.248 |
| 33   | 192.168.132.193 | /27    | 255.255.255.224 |
| 22   | 192.168.132.129 | /26    | 255.255.255.192 |
| 11   | 192.168.132.233 | /29    | 255.255.255.248 |
