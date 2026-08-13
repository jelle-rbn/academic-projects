# Setup guide for first startup - Iteration 2

_Author: J. Robyn - jelle.robyn@student.hogent.be_

This guide is used to configure intial startup for a Cisco router and switch thrue a serial console connection using PuTTY.<br>
The flow of this guide is as follows:

1. Configure PuTTY for console connection

2. Connect to the router and perform "[Bootstrap](#router-bootstrap)"

3. Connect to the switch and perform "[Bootstrap](#switch-bootstrap)"

4. Connect to the router and download 2-R1-config.txt

5. Connect to the switch and download 2-S1-config.txt

## PuTTY - serial console connection setup

1. Check device manager for COM port (Ports -> USB Serial Port)

2. Open the PuTTY application

3. Under the _Connection Type_ field, click the **Serial** radio button

4. In the _Category_ navigation field, choose **Serial**

5. In the _Serial line to connect to_ field, enter the COM port that your device is connected to (default = COM1)

6. In the _Speed (baud)_ field, enter the digital transmission speed that is compatible with the switch (common is 9600, for 300 and 500 series speed = **115200**)

7. In the _Data bits_ field, enter the number of data bits used for each character (recommended value is **8**)

8. In the _Stop bits_ field, enter the number of bits to be sent at the end of every character (recommended value is **1**)<br>
   The stop bit informs the machine that it has reached the end of a byte

9. In the _Parity_ drop-down menu, select the method of detecting errors in transmission (recommended method is **None**)

10. In the _Flow Control_ drop-down menu, select the method of preventing data overflow (recommended method is **None**)

> For more information: [Access the CLI via PuTTY](https://www.cisco.com/c/en/us/support/docs/smb/switches/Cisco-Business-Switching/kmgmt-2837-access-the-cli-via-putty-using-a-console-connection-on-cbs-350.pdf)

## Router "Bootstrap"

```
# Reset router (if asked to save current config -> 'no')
erase startup-config
reload

enable
configure terminal

# Hostname
hostname R1

# Fysical interface to switch (VLAN1 = untagged)
interface GigabitEthernet 0/0/1
 ip address 192.168.132.225 255.255.255.248
 no shutdown
exit

# Set TFTP source on physical interface
ip tftp source-interface GigabitEthernet 0/0/1

# Test: ping laptop/TFTP-server (192.168.132.227)
ping 192.168.132.227
```

## Switch "Bootstrap"

```
# Reset switch (if asked to save current config -> 'no')
erase startup-config
delete flash:vlan.dat
reload

enable
configure terminal

# Hostname
hostname S1

# Create VLANs
vlan 11
 name DMZ
vlan 22
 name EMPLOYEES
vlan 33
 name SERVERS
vlan 999
 name BLACKHOLE
exit

# Management IP
interface vlan 1
 ip address 192.168.132.226 255.255.255.248
 no shutdown
exit

# Port to TFTP server
interface FastEthernet 0/1
 switchport mode access
 switchport access vlan 1
 no shutdown
exit

# Trunk to router
interface GigabitEthernet 0/1
 switchport mode trunk
 no shutdown
exit
```

## Retrieve config from TFTP

> **Make sure:**<br>
> TFTP server is running<br>
> Service is active: `systemctl status tftpd`<br>
> Port is open: `ss -u -a | grep 69`

Connect console cable to **Router**:

```
copy tftp://192.168.132.227/R1-config.cfg running-config
```

Wait for `[OK]` confirmation

Connect console cable to **Switch**:

```
copy tftp://192.168.132.227/S1-config.cfg running-config
```

Wait for `[OK]` confirmation

## Upload config to TFTP

From the **Router**:

```
copy running-config tftp://192.168.132.227/router.cfg
```

From the **Switch**:

```
copy running-config tftp://192.168.132.227/switch.cfg
```
