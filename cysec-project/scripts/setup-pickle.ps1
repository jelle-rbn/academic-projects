# =========================
# Python Pickle Vulnerable Server Setup
# =========================

Start-Transcript -Path C:\pickle-setup-log.txt

Write-Host "[+] Creating working directory..."
New-Item -ItemType Directory -Path C:\vulnserver -Force

# =========================
# INSTALL PYTHON (if needed)
# =========================

Write-Host "[+] Checking Python installation..."

$python = Get-Command python -ErrorAction SilentlyContinue

if (-not $python) {
    Write-Host "[+] Downloading Python installer..."

    $url = "https://www.python.org/ftp/python/3.11.6/python-3.11.6-amd64.exe"
    $installer = "C:\python-installer.exe"

    Invoke-WebRequest -Uri $url -OutFile $installer

    Write-Host "[+] Installing Python silently..."

    Start-Process $installer -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait

    Write-Host "[+] Python installed"
}
else {
    Write-Host "[+] Python already installed"
}

# =========================
# CREATE VULNERABLE SERVER
# =========================

Write-Host "[+] Writing vulnerable Python server..."

$code = @"
import pickle
from http.server import BaseHTTPRequestHandler, HTTPServer

class VulnHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers['Content-Length'])
        data = self.rfile.read(length)

        # Vulnerable deserialization
        obj = pickle.loads(data)

        self.send_response(200)
        self.end_headers()

server = HTTPServer(('0.0.0.0', 8000), VulnHandler)
server.serve_forever()
"@

$code | Out-File -Encoding ASCII C:\vulnserver\vuln_server.py

# =========================
# FIREWALL RULE
# =========================

Write-Host "[+] Opening port 8000..."
New-NetFirewallRule -DisplayName "PickleVuln 8000" `
    -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow

# =========================
# START SERVER
# =========================

Write-Host "[+] Starting vulnerable Python server via WMI (to prevent hanging)..."

$pythonPath = "C:\Program Files\Python311\python.exe" 
if (-not (Test-Path $pythonPath)) {
    $pythonPath = (Get-ChildItem "C:\Program Files\Python*\python.exe" | Select-Object -First 1).FullName
}

$cmd = "`"$pythonPath`" C:\vulnserver\vuln_server.py"
Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd | Out-Null

Write-Host "[+] Python process started in background."
Write-Host "[+] DONE - Python vulnerable server running on port 8000"

Stop-Transcript