# Cheat Sheet - Network iteration 2

_Author: J. Robyn - jelle.robyn@student.hogent.be_

## Router

| Command                       | Description                                                |
| ----------------------------- | ---------------------------------------------------------- |
| `show ip interface brief`     | Quick overview of all interfaces, IP addresses, and status |
| `show running-config`         | Display the active configuration                           |
| `show ip route`               | View the routing table (verify default route)              |
| `show ip nat translations`    | Show active NAT/PAT translations                           |
| `show ip nat statistics`      | Display NAT statistics                                     |
| `show access-lists`           | View ACLs and hit counters                                 |
| `show ip interface g0/0/1.22` | Verify ACL application on interface                        |
| `show ip dhcp binding`        | Show DHCP leases assigned to clients                       |
| `show ip dhcp pool`           | Display DHCP pool status                                   |
| `debug ip dhcp server events` | DHCP debugging (use with caution)                          |
| `ping <ip>`                   | Test connectivity                                          |
| `traceroute <ip>`             | Analyze routing path                                       |
| `clear ip nat translation *`  | Clear NAT table                                            |
| `no ip access-group ...`      | Temporarily remove ACL for troubleshooting                 |

---

## Switch

| Command                          | Description                           |
| -------------------------------- | ------------------------------------- |
| `show vlan brief`                | Display VLANs and assigned ports      |
| `show interfaces trunk`          | Verify trunk configuration (critical) |
| `show running-config`            | Display current configuration         |
| `show mac address-table`         | View learned MAC addresses            |
| `show interfaces status`         | Interface link status overview        |
| `show spanning-tree`             | Spanning Tree status                  |
| `show interface g0/1 switchport` | Check access/trunk mode               |
| `ping 192.168.132.225`           | Test connectivity to router           |
| `show ip interface brief`        | Verify management IP                  |
| `show cdp neighbors`             | Discover connected Cisco devices      |

---

## Linux

| Command                      | Description                    |
| ---------------------------- | ------------------------------ |
| `ip a`                       | Display IP address information |
| `ip route`                   | Show routing table             |
| `ping <ip>`                  | Test connectivity              |
| `traceroute <ip>`            | Analyze network path           |
| `nslookup google.com`        | Test DNS resolution            |
| `dig google.com`             | Detailed DNS query             |
| `curl http://<ip>`           | Test web server connectivity   |
| `ss -tuln`                   | Show listening ports           |
| `systemctl status <service>` | Check service status           |
| `journalctl -xe`             | View system logs               |
| `tcpdump -i eth0`            | Capture network traffic        |
| `dhclient -v`                | Renew DHCP lease               |

---

## Windows (clients)

| Command                            | Description                              |
| ---------------------------------- | ---------------------------------------- |
| `ipconfig /all`                    | Display IP, gateway, and DNS information |
| `ipconfig /release`                | Release current IP address               |
| `ipconfig /renew`                  | Request new DHCP lease                   |
| `ping <ip>`                        | Test connectivity                        |
| `tracert <ip>`                     | Trace routing path                       |
| `nslookup google.com`              | Test DNS resolution                      |
| `netstat -an`                      | Show active connections                  |
| `arp -a`                           | Display ARP table                        |
| `route print`                      | Show routing table                       |
| `Test-NetConnection <ip> -Port 80` | Test port connectivity (PowerShell)      |

---

## Standard ACL configuration

> Standard ACL number range is 0 to 99 and 1300 to 1999.<br>
> Standard ACLs should be placed as close to the destination as possible.

### Numbered standard IPv4 ACL

```
R1(config)# no access-list 10
R1(config)# access-list 10 remark <DISCRIBE ACE>
R1(config)# access-list 10 permit/deny host <IP>

R1(config)# interface Serial 0/1/0
R1(config-if)# ip access-group 10 out
R1(config-if)# end
```

### Named standard IPv4 ACL

```
R1(config)# ip access-list standard PERMIT-ACCESS
R1(config-std-nacl)# remark <DISCRIBE ACE>
R1(config-std-nacl)# permit/deny host <IP>

R1(config)# interface Serial 0/1/0
R1(config-if)# ip access-group PERMIT-ACCESS out
R1(config-if)# end
```

### Modify standard ACL: sequence numbers method

```
R1(config)# ip access-list standard 1
R1(config-std-nacl)# no 10
R1(config-std-nacl)# 10 deny host 192.168.10.10
R1(config-std-nacl)# end
```

### Modify standard ACL: named ACL

```
R1(config)# ip access-list standard NO-ACCESS
R1(config-std-nacl)# 15 deny 192.168.10.5
R1(config-std-nacl)# end
```

### Secure VTY access

```
R1(config)# username <NAME> secret <PASSWORD>
R1(config)# ip access-list standard <NAME ACL>
R1(config-std-nacl)# remark <DISCRIBE ACL>
R1(config-std-nacl)# permit host <IP>
R1(config-std-nacl)# deny any
R1(config-std-nacl)# exit
R1(config)# line vty 0 4
R1(config-line)# login local
R1(config-line)# transport input ssh
R1(config-line)# access-class <NAME ACL> in
```

> Verify with `show access-lists`

---

## Extended ACL configuration

> Extended ACL number range is 100 to 199 and 2000 to 2699.<br>
> Extended ACLs should be placed as close to the source as possible.

### Numbered extended IPv4 ACL

```
R1(config)# access-list 110 permit tcp 192.168.10.0 0.0.0.255 any eq www
R1(config)# access-list 110 permit tcp 192.168.10.0 0.0.0.255 any eq 443
R1(config)# interface g0/0/0
R1(config-if)# ip access-group 110 in
```

### TCP established extended ACL

```
R1(config)# access-list 120 permit tcp any 192.168.10.0 0.0.0.255 established
R1(config)# interface g0/0/0
R1(config-if)# ip access-group 120 out
```

### Named extended IPv4 ACL

```
R1(config)# ip access-list extended SURFING
R1(config-ext-nacl)# Remark Permits inside HTTP and HTTPS traffic
R1(config-ext-nacl)# permit tcp 192.168.10.0 0.0.0.255 any eq 80
R1(config-ext-nacl)# permit tcp 192.168.10.0 0.0.0.255 any eq 443
R1(config-ext-nacl)# exit

R1(config)# ip access-list extended BROWSING
R1(config-ext-nacl)# Remark Only permit returning HTTP and HTTPS traffic
R1(config-ext-nacl)# permit tcp any 192.168.10.0 0.0.0.255 established
R1(config-ext-nacl)# exit
R1(config)# interface g0/0/0
R1(config-if)# ip access-group SURFING in
R1(config-if)# ip access-group BROWSING out
```

### Edit extended ACL

```
R1(config)# ip access-list extended SURFING
R1(config-ext-nacl)# no 10
R1(config-ext-nacl)# 10 permit tcp 192.168.10.0 0.0.0.255 any eq www
R1(config-ext-nacl)# end
```

### Verify ACLs

| Command                                          | Description                                                             |
| ------------------------------------------------ | ----------------------------------------------------------------------- |
| `show ip int <INTERFACE> \| include access list` | Verify if an interface has an ACL applied to it                         |
| `show run \| begin ip access-list`               | Validate what was configured (command also displays configured remarks) |
| `show access-lists`                              | Show the contents of current access lists                               |
| `clear access-list counters`                     | Clear the ACL statistics                                                |

---

## Troubleshooting

### Basic troubleshooting flow

| Step | Check                                            |
| ---- | ------------------------------------------------ |
| 1    | Does the device have an IP address?              |
| 2    | Is the subnet correct?                           |
| 3    | Is the default gateway correct?                  |
| 4    | Can you ping the gateway?                        |
| 5    | Is DNS working?                                  |
| 6    | Is external connectivity working (e.g. 8.8.8.8)? |
| 7    | Could it be an ACL or NAT issue?                 |

### VLAN / Trunk Issues

| Problem                    | Check                                      |
| -------------------------- | ------------------------------------------ |
| No inter-VLAN connectivity | Router subinterfaces configured correctly? |
| VLAN not working           | `show vlan brief`                          |
| Trunk misconfiguration     | `show interfaces trunk`                    |
| Native VLAN mismatch       | Must be VLAN 1 in your setup               |
| Wrong VLAN on port         | `switchport access vlan X`                 |

### DHCP Issues

| Problem                    | Check                   |
| -------------------------- | ----------------------- |
| Client does not receive IP | `show ip dhcp binding`  |
| DHCP pool exhausted        | `show ip dhcp pool`     |
| DHCP blocked by ACL        | Verify UDP ports 67/68  |
| Incorrect gateway          | Check `default-router`  |
| VLAN mismatch              | Client in correct VLAN? |

### ACL Issues

| Problem              | Check                                    |
| -------------------- | ---------------------------------------- |
| Traffic blocked      | `show access-lists` (check hit counters) |
| Wrong direction      | `in` vs `out`                            |
| ACL too restrictive  | Temporarily allow `permit ip any any`    |
| ICMP blocked         | Ping fails                               |
| Rule order incorrect | ACLs are processed top-down              |

### NAT Issues

| Problem               | Check                        |
| --------------------- | ---------------------------- |
| No internet access    | `show ip nat translations`   |
| NAT misconfiguration  | Inside vs outside interfaces |
| NAT ACL incorrect     | Verify ACL 1                 |
| Missing default route | `show ip route`              |
