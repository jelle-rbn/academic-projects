# Requirements Document - Nginx reverse-proxy server

_Author: J. Robyn - jelle.robyn@student.hogent.be_

## Deliverables

**Nginx Installation:** The reverse proxy server must have the Nginx package successfully installed on AlmaLinux 10.

**Service Management:** The Nginx service must be enabled and started via `systemd`, ensuring automatic startup at boot.
The service status must be active (running).

**Firewall Configuration:** Firewalld must be installed, enabled, and configured to permanently allow:

- `http` (port 80/TCP)
- `https` (port 443/TCP)
  Changes must persist across reboots.

**SELinux Compatibility:** SELinux must remain in enforcing mode.
The boolean `httpd_can_network_connect` must be permanently enabled to allow reverse proxy functionality.

**SSL Configuration:** A self-signed TLS certificate must be generated and stored in:

- `/etc/nginx/ssl/nginx-selfsigned.crt`
- `/etc/nginx/ssl/nginx-selfsigned.key`
  The private key must have restricted permissions.

**HTTP to HTTPS Redirection:**
All incoming HTTP requests on port 80 must be permanently redirected (301) to HTTPS.

**Reverse Proxy Configuration:** Nginx must proxy incoming HTTPS requests to the internal backend web server (`http://...`)

**Secure TLS Settings:** Only allow TLS 1.2 and TLS 1.3, enable HTTP/2, disable server_tokens, etc.

**Configuration Validation:**
The Nginx configuration must pass `nginx -t` validation before reload.

## Subtasks

1. Gather information and resources
   - Person in charge of implementation: Jelle
   - Person in charge of testing: N/A
   - Dependancies: N/A

2. Provisioning development
   - Person in charge of implementation: Jelle
   - Person in charge of testing: <!-- Name: anyone other than the owner! -->
   - Dependancies: `util.sh`, `common.sh`

3. Service installation and configuration
   - Person in charge of implementation: Jelle
   - Person in charge of testing: <!-- Name: anyone other than the owner! -->
   - Dependancies: subtask 2

4. Technical documentation
   - Person in charge of implementation: Jelle
   - Person in charge of testing: N/A
   - Dependancies: subtask 2, 3, 5

5. Test plan / functional validation
   - Person in charge of implementation: Jelle
   - Person in charge of testing: <!-- Name: anyone other than the owner! -->
   - Dependancies: subtask 2, 3

6. Test plan / functional validation
   - Person in charge of implementation:
   - Person in charge of testing: <!-- Name: anyone other than the owner! -->
   - Dependancies: subtask 2, 3, 4, 5

## Technical Specifications

| Component                 | Requirement / Value                    |
| :------------------------ | :------------------------------------- |
| **OS**                    | AlmaLinux 10                           |
| **Web Server Software**   | Nginx (latest available via DNF)       |
| **Reverse Proxy Backend** | `http://192.168.102.131`               |
| **Proxy IP**              | `192.168.102.132`                      |
| **Domain Name**           | Configurable (`domain_name`)           |
| **Nginx Config Path**     | `/etc/nginx/conf.d/reverse_proxy.conf` |
| **SSL Certificate Path**  | `/etc/nginx/ssl/nginx-selfsigned.crt`  |
| **SSL Key Path**          | `/etc/nginx/ssl/nginx-selfsigned.key`  |

## Time Spent

| Student       | (Sub)task                              | Estimated effort | Actual effort |
| :------------ | :------------------------------------- | ---------------: | ------------: |
| Jelle         | Gather information and resources       |           1h 15m |        2h 00m |
| Jelle         | Provisioning development               |           4h 00m |        5h 50m |
| Jelle         | Service installation and configuration |           0h 30m |        0h 30m |
| Jelle         | Technical documentation                |           3h 00m |        8h 05m |
| Jelle         | Test plan v1                           |           3h 00m |        5h 00m |
| <!-- NAAM --> | Testing and test report v1             |                  |               |
| **Total**     |                                        |      **12h 15m** |   **21h 25m** |

### Administration

| Student   | (Sub)task      | Estimated effort | Actual effort |
| :-------- | :------------- | ---------------: | ------------: |
| Jelle     | Administration |           0h 30m |        0h 30m |
| **Total** |                |       **0h 30m** |    **0h 30m** |

## Time spent - Jira screenshot

![Time spent report](../07-linux-reverse-proxy/img/Reverse%20proxy_time_spent_report.png)

**Variance remarks**

_Gather information and resources:_<br>
Ran into alot of different (minor) issues, wich required me to search for applicable solutions.
The documentation I found was more then often overwelming, but only a small section was usefull for the specific case.
Searching between all this information whas rather time consuming.

_Provisioning development:_<br>
Following the creation of the TFTP server, writing scripts still doesn't feel like my strong suit.
This was my first time provisioning, installing and deploying a proxy server.
Needless to say, there was a lot of "back-and-forth" while writing this script.

_Service installation and configuration:_<br>
Once installing, the output of the script gave feedback that the syntax used for HTTP/2 in Nginx was deprecated:

```shell
reverse-proxy: nginx: [warn] the "listen ... http2" directive is deprecated, use the "http2" directive instead in /etc/nginx/conf.d/reverseproxy.conf:12
reverse-proxy: nginx: [warn] the "listen ... http2" directive is deprecated, use the "http2" directive instead in /etc/nginx/conf.d/reverseproxy.conf:13
```

Whilst the "base" of the script was solid, I chose to implent some fancy code.
For example:

- the usage of colorised [LOG] messages
- A reboot check to inform if the system needs to be rebooted due to a kernel update
- suppress all output (reason for this was the massive message output of the `dnf upgrade` and `dnf install comments`)

The idea of creating a boot check came from suppressing the message output.
Whilst it is much more pleasant to watch a silent install, important information like kernel updates could go unnoticed.

After researching "how to configure" OpenSSL, the process was quite straightforward.
The structure of the configuration is consistent with the examples found in the documentation.

_Technical documentation:_
This time, the estimated time required to write the test plan was quite accurate.
This is because the script for the TFTP server had already been created.
The flow of the test plan was already established, which decreased the time necessary to write the plan for the reverse-proxy server.

_Test plan_
After completing the test plan for the TFTP server, I allocated more time to work on the reverse proxy server.
However, my estimation was still quite inaccurate. Researching, implementing, and documenting various test cases is extremely time-consuming, especially when balancing comprehensive coverage with the need to avoid testing trivial scenarios.

For instance, I initially wrote a test to verify if provisioning would succeed after deleting a specific directory.
Following feedback on the TFTP server, I realized this test was redundant; if the provisioning were to fail, it would have been immediately apparent during the initial setup
