# D404 — Active Directory Naming Conventions

> **Author:** Johan Magerman  
> **Version:** 1.0  
> **Domain:** `ad.t02-domain404.local`

---

## 1. User Accounts

### 1.1 Standard User Accounts

Standard accounts are created for every named employee. The format is:

```
[first letter of firstname][first two letters of lastname][last two digits of birth year][two-digit sequence number]
```

| Component | Rule | Example (Johan Magerman, born 1986) |
|---|---|---|
| First name | First letter, uppercase | `J` |
| Last name | First two letters, uppercase | `MA` |
| Birth year | Last two digits | `86` |
| sequence number | Collision suffix | `01` |
| **Result** | | `JMA8601` |

**Edge cases:**

- Last name shorter than 2 characters → pad with `x` (e.g. `O` → `OX`)
- Accented or special characters → strip diacritics (e.g. `é` → `E`, `ü` → `U`)
- Always uppercase, no spaces or special characters

---

### 1.2 Privileged Admin Accounts

Each admin tier gets a **dedicated account**, separate from the user's standard account. Never use a standard user account for administrative tasks.

| Tier | Prefix | Scope | Example |
|---|---|---|---|
| T0 — Domain Admin | `ADD_` | Full domain control | `ADD_JMA8601` |
| T1 — Server Admin | `ADS_` | Server management only | `ADS_JMA8601` |
| T2 — Workstation Admin | `ADW_` | Workstation management only | `ADW_JMA8601` |

> **Rule:** Admin accounts are always based on the owner's standard username.  
> `ADD_JMA8601` belongs to the same person as `JMA8601`.

---

### 1.3 Generic Accounts

Shared accounts not tied to a specific person. Used for shared mailboxes, reception desks, display accounts, etc.

```
USR_[descriptor]
```

| Example | Use case |
|---|---|
| `USR_reception` | Front desk shared login |
| `USR_helpdesk` | Shared helpdesk mailbox |
| `USR_display` | Lobby display screen |

> **Rule:** Descriptor in lower, no spaces, use underscores if needed (e.g. `USR_it_helpdesk`).

---

### 1.4 Service Accounts

Accounts used exclusively by applications, scripts, or automated processes. No human should interactively log in with these.

```
SVC_[descriptor]
```

| Example | Use case |
|---|---|
| `SVC_backup` | Backup agent service |
| `SVC_monitoring` | Monitoring tool |
| `SVC_deploy` | Deployment pipeline |

> **Rule:** Service accounts live in `Admin\ServiceAccounts`.  
> They must have strong passwords, no interactive login rights, and be documented in the service register.

---

### 1.5 Account Type Summary

| Type | Format | Example | OU Location |
|---|---|---|---|
| Standard user | `[F][LL][yy][nn]` | `JMA8601` | `Users\[Department]` |
| Domain admin | `ADD_[username]` | `ADD_JMA8601` | `Admin\T0-Domain` |
| Server admin | `ADS_[username]` | `ADS_JMA8601` | `Admin\T1-Server` |
| Workstation admin | `ADW_[username]` | `ADW_JMA8601` | `Admin\T2-Workstation` |
| Generic | `USR_[descriptor]` | `USR_reception` | `Users\Generic` |
| Service account | `SVC_[descriptor]` | `SVC_backup` | `Admin\ServiceAccounts` |

---

## 2. Computer Objects

### 2.1 Format

```
[Type]-[YY]-[00000]
```

| Component | Rule | Example |
|---|---|---|
| Type | Single uppercase letter (see table below) | `L` |
| YY | Last two digits of purchase year | `25` |
| 00000 | 5-digit sequence number, resets to `00001` each January | `00042` |
| **Result** | | `L-25-00042` |

---

### 2.2 Device Type Prefixes

| Prefix | Device Type |
|---|---|
| `L` | Laptop |
| `D` | Desktop |
| `T` | Tablet |
| `S` | Server |
| `K` | Kiosk |
| `P` | PAW (Privileged Access Workstation) |
| `V` | Virtual Machine |

---

### 2.3 Sequence Number Rules

- Sequence resets to `00001` on **1 January each year**
- Sequence is **per year**, not per device type — all types share the same counter within a year
- The sequence is tracked in the asset register; always check before assigning the next number
- **Never reuse** a sequence number, even if the device is decommissioned

**Examples:**

| Computer name | Meaning |
|---|---|
| `L-25-00001` | First asset registered in 2025, a laptop |
| `S-25-00003` | Third asset registered in 2025, a server |
| `D-26-00001` | First asset registered in 2026, a desktop |

---

### 2.4 Computer Object OU Placement

| Device type | OU path |
|---|---|
| Laptop / Desktop | `Computers\Workstations\[Department]` |
| Server | `Computers\Servers\[Infrastructure / Application / DMZ]` |
| Kiosk | `Computers\Kiosks\[Internal / External]` |
| PAW | `Admin\PAW` |
| Virtual Machine | `Computers\Servers\[Infrastructure / Application / DMZ]` |
| New / unassigned | `Computers\_Staging` |
| Retired | `Computers\_Decommissioned` |