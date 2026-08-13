# Requirements Document - Extension: Hardened Nginx reverse-proxy server

_Author: J. Robyn - jelle.robyn@student.hogent.be_

## Deliverables

### IMPORTANT: Implementation Strategy Change!

**The system now uses runtime header manipulation instead of source-level modification!**

- Header spoofing is implemented via the `headers-more-nginx-module`
- This approach improves maintainability and portability
- No direct modification of Nginx core source code is required

### Custom Nginx Build

The reverse proxy server must have the Nginx package successfully installed on AlmaLinux 10.<br>
Nginx must be compiled from source instead of installed via `DNF`.

- Latest stable version must be dynamically fetched
- The headers-more module must be included at compile time
- Installed binary must reside in `/opt/nginx/sbin/nginx`

### Service Management

- Nginx must be managed via `systemd`
- Service must be:
  - enabled at boot
  - actively running
- Custom `systemd` unit file must be created

### Firewall Configuration

Firewalld must be:

- Installed and enabled
- Configured to permanently allow:
  - `http` (80/TCP)
  - `https` (443/TCP)

Changes must persist across reboots.

### SELinux Compatibility

- SELinux must remain in enforcing mode
- Boolean must be enabled:
  - `httpd_can_network_connect = on`

### SSL Configuration

- Self-signed TLS certificate must be generated
- Stored in:
  - `/etc/nginx/ssl/nginx-selfsigned.crt`
  - `/etc/nginx/ssl/nginx-selfsigned.key`
  - Private key must have restricted permissions (600)

### HTTP Request Handling (Stealth Mode)

A default server block must:

- listen on port 80
- return HTTP status 444 (drop connection)
- Legitimate domain traffic must:
  - be redirected (301) to HTTPS

### Reverse Proxy Configuration

- HTTPS traffic must be proxied to backend server
- Proxy headers must be explicitly defined:
  - `Host`
  - `X-Real-IP`
  - `X-Forwarded-*`
- Proxy must intercept backend errors (`proxy_intercept_errors on`)

### TLS Hardening

- Only allow:
  - TLS 1.2
  - TLS 1.3
- Enable HTTP/2
- Disable `server_tokens`

### Header Manipulation / Deception

The system must implement multi-layer header spoofing:

- Header manipulation must be implemented using the headers-more-nginx-module
- The following directives must be used:
  - `more_set_headers`
  - `more_clear_headers`
- Remove upstream headers:
  - `Server`
  - `X-Powered-By`
- Inject fake headers:
  - `Server: Microsoft-IIS/10.0`
  - `X-Powered-By: ASP.NET`

### Custom Error Pages

- Default Nginx error pages must be replaced
- Custom pages must:
  - not contain any reference to Nginx
  - be stored in `/var/ErrorPages/`
- Nginx must be configured with `error_page` directives
- Error page location must be marked `internal`

### Default Server Behaviour

- All unknown hostnames must:
  - be handled by `default_server`
  - return `444`
- Prevent exposure of default Nginx responses

### Configuration Validation

- Nginx configuration must pass:

```bash
nginx -t
```

- Service reload/restart only allowed after successful validation

### Provisioning Requirements

- Script must be:
  - idempotent
  - non-interactive
  - suitable for automated provisioning (Vagrant)
- Output must be:
  - minimal (silent install)
  - structured via logging functions

## Security Objectives

### Fingerprint Obfuscation

The system must reduce detectability by:

- Overriding runtime headers using the `headers-more-nginx-module`
- Removing default error signatures

### Active Fingerprint Resistance

The system must:

- Return inconsistent or non-standard responses (444)
- Avoid predictable server behavior
- Limit identifiable protocol patterns

### Information Disclosure Prevention

- No exposure of:
  - Nginx version
  - Nginx name
  - backend technology stack

### Attack Surface Reduction

- Only required modules must be compiled (minimal build)
- Remove default configurations
- Restrict response behavior

## Additional Notes

- Behaviour must remain functionally identical to standard reverse proxy for legitimate users
- Hardening measures must not break proxy functionality
- Deception techniques must be:
  - transparent to users
  - disruptive to scanners

## Subtasks

1. Gather information and resources
   - Person in charge of implementation: Jelle
   - Person in charge of testing: N/A
   - Dependancies: N/A

2. Provisioning development
   - Person in charge of implementation: Jelle
   - Person in charge of testing: Guillamue
   - Dependancies: `util.sh`, `common.sh`

3. Service installation and configuration
   - Person in charge of implementation: Jelle
   - Person in charge of testing: Guillamue
   - Dependancies: subtask 2

4. Technical documentation
   - Person in charge of implementation: Jelle
   - Person in charge of testing: N/A
   - Dependancies: subtask 2, 3, 5

5. Test plan / functional validation
   - Person in charge of implementation: Jelle
   - Person in charge of testing: Guillamue
   - Dependancies: subtask 2, 3

6. Testing / functional validation
   - Person in charge of implementation:
   - Person in charge of testing: Guillamue
   - Dependancies: subtask 2, 3, 4, 5

## Technical Specifications

| Component                 | Requirement / Value                    |
| :------------------------ | :------------------------------------- |
| **OS**                    | AlmaLinux 10                           |
| **Web Server Software**   | Custom-built Nginx                     |
| **Build Method**          | Source compilation                     |
| **Reverse Proxy Backend** | `http://192.168.102.131`               |
| **Proxy IP**              | `192.168.102.132`                      |
| **Domain Name**           | Configurable (`domain_name`)           |
| **Nginx Config Path**     | `/etc/nginx/conf.d/reverse_proxy.conf` |
| **SSL Certificate Path**  | `/etc/nginx/ssl/nginx-selfsigned.crt`  |
| **SSL Key Path**          | `/etc/nginx/ssl/nginx-selfsigned.key`  |
| **Error Pages Path**      | `/var/ErrorPages/`                     |

## Time Spent

| Student   | (Sub)task                              | Estimated effort | Actual effort |
| :-------- | :------------------------------------- | ---------------: | ------------: |
| Jelle     | Gather information and resources       |           4h 00m |        5h 00m |
| Jelle     | Provisioning development               |          15h 00m |        8h 20m |
| Jelle     | Service installation and configuration |           4h 00m |        7h 35m |
| Jelle     | Technical documentation                |           4h 00m |        9h 00m |
| Jelle     | Test plan                              |           4h 00m |       3 h 55m |
| Guillaume | Testing and test report                |          1 h 30m |       2 h 30m |
| **Total** |                                        |      **31h 00m** |   **36h 20m** |

### Administration

| Student   | (Sub)task      | Estimated effort | Actual effort |
| :-------- | :------------- | ---------------: | ------------: |
| Jelle     | Administration |           1h 00m |        1h 00m |
| **Total** |                |       **1h 00m** |    **1h 00m** |

## Time spent - Jira screenshot

![Time spent report](../07-linux-reverse-proxy/img/)

**Variance remarks**

_Gather information and resources:_<br>
Extra time was needed to research the headers-more-nginx-module.
At first, it seemed not directly available for RHEL-based systems, so alternative approaches had to be explored.
This caused a small increase in time.

_Provisioning development:_<br>
The first approach was to modify the Nginx source code to change headers.
Although this seemed straightforward, it did not fully work, as some server information was still visible.
During this phase, custom error pages were also introduced to reduce information leakage during scanning.

After several attempts, this approach was abandoned and replaced with the headers-more module.
The custom error pages were kept, as they significantly reduce the risk of exposing information.
Because part of the work had to be redone, the total time was lower than expected but included some lost effort.

_Service installation and configuration:_<br>
This phase took longer due to the switch in approach.
The Nginx build process had to be reworked to include the module, and extra time was needed to configure systemd, SELinux, and the firewall correctly.
Testing and fixing issues also added to the total time.

_Technical documentation:_
More time was needed because the implementation changed during the project. All documentation had to be updated to match the final solution, which increased the workload.

_Test plan:_
The original test plan was not suitable for the hardened reverse proxy setup.
A new test plan had to be (partially) created, including tests for HTTPS, reverse proxy behaviour, and security features like header manipulation and default-deny responses.
