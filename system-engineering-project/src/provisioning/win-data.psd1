# -----------------------------------------------------------------------------
# win-data.psd1  --  Windows Infrastructure Data
# -----------------------------------------------------------------------------
# Pure PowerShell Data File: no executable code, no variable references.
# Loaded by win-config.ps1, which derives computed values and exposes
# everything to the stage scripts as flat variables.
# -----------------------------------------------------------------------------

@{

# -- Domain-wide settings -----------------------------------------------------
Domain = @{
    Name            = 'ad.t02-domain404.internal'
    NetbiosName     = 'DOMAIN404'
    # Windows Server 2022 functional level for both forest and domain
    Mode            = 'WinThreshold'
    # Directory Services Restore Mode password -- store this somewhere safe
    DSRMPassword    = 't02-domain404'
    DNSForwarders   = @(
        '1.1.1.1'       # Cloudflare primary
        '1.0.0.1'       # Cloudflare secondary
        '8.8.8.8'       # Google primary
        '8.8.4.4'       # Google secondary
    )
}

# -- Define the service accounts used during provisioning ---------------------
DomainJoinAccount  = 'SVC_DomainJoin'
CertificateAccount = 'SVC_PKIAdmin'

# -- Domain Controller --------------------------------------------------------
DC = @{
    Hostname            = 'windowsdc'
    IP                  = '192.168.132.194'
    Gateway             = '192.168.132.193'
	ProxyCertKeySource  = 'C:\provisioning\files\windowsdc\proxy_cert_key'
    ProfileShareName    = 'profiles'
    HomeShareName       = 'homefolders'
    HomeDriveLetter     = 'H'
}

# -- Windows Client -----------------------------------------------------------
Client = @{
    Hostname              = 'L-26-00001'
    IP                    = 'DHCP'
    Gateway               = '192.168.132.129'
    AdminUsername         = 'vagrant'
    AdminPassword         = 'vagrant'
    NetworkAdapterPattern = 'Ethernet'
    DNSServers            = @(
        '192.168.132.194'   # Domain Controller single source of truth
    )
    RSATFeatures          = @(
        'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'  # AD Users & Computers, Sites
        'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0'  # Group Policy Management Console
        # 'Rsat.Dns.Tools~~~~0.0.1.0'                     # DNS Manager
        # 'Rsat.FileServices.Tools~~~~0.0.1.0'            # File Services tools
        # 'Rsat.ServerManager.Tools~~~~0.0.1.0'           # Server Manager
    )
}

Servers = @(
    @{ Hostname = 'database';      IP = '192.168.132.195' }
    @{ Hostname = 'webserver';     IP = '192.168.132.196' }
    @{ Hostname = 'reverse-proxy'; IP = '192.168.132.234'; SshUsername = 'vagrant' }
    @{ Hostname = 'tftp';          IP = '192.168.132.227' }
	@{ Hostname = 'storage';       IP = '192.168.132.199' }
    @{ Hostname = 'database2'; IP = '192.168.132.200' } 
    @{ Hostname = 'haproxy'; IP = '192.168.132.201' }
    @{ Hostname = 'nextcloud-database'; IP = '192.168.132.198' } 
    @{ Hostname = 'nextcloud-server'; IP = '192.168.132.197' }
)

# -- Active Directory - Organisational Units ----------------------------------
#
# Literal DC strings since psd1 cannot reference variables.
OUs = @(

    # Tier 0 -- Root OU
    @{ Name = 'D404';               Path = 'DC=ad,DC=t02-domain404,DC=internal' }

    # Tier 1 -- Top-level OUs under D404
    @{ Name = 'Admin';              Path = 'OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'Users';              Path = 'OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'Computers';          Path = 'OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'Groups';             Path = 'OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'Guests';             Path = 'OU=D404,DC=ad,DC=t02-domain404,DC=internal' }

    # Admin sub-OUs
    @{ Name = 'T0-Domain';          Path = 'OU=Admin,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'T1-Server';          Path = 'OU=Admin,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'T2-Workstation';     Path = 'OU=Admin,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'ServiceAccounts';    Path = 'OU=Admin,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'PAW';                Path = 'OU=Admin,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }

    # Users sub-OUs
    @{ Name = 'Generic';            Path = 'OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'Management';         Path = 'OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'HR';                 Path = 'OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'IT';                 Path = 'OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'Development';        Path = 'OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = '_Staging';           Path = 'OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = '_Decommissioned';    Path = 'OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }

    # Computers sub-OUs
    @{ Name = 'Workstations';       Path = 'OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'Servers';            Path = 'OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'Kiosks';             Path = 'OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = '_Staging';           Path = 'OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = '_Decommissioned';    Path = 'OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }

    # Workstations sub-OUs
    @{ Name = 'Management';         Path = 'OU=Workstations,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'HR';                 Path = 'OU=Workstations,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'IT';                 Path = 'OU=Workstations,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'Development';        Path = 'OU=Workstations,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }

    # Servers sub-OUs
    @{ Name = 'Infrastructure';     Path = 'OU=Servers,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'Application';        Path = 'OU=Servers,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'DMZ';                Path = 'OU=Servers,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }

    # Kiosks sub-OUs
    @{ Name = 'Internal';           Path = 'OU=Kiosks,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'External';           Path = 'OU=Kiosks,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }

    # Groups sub-OUs
    @{ Name = 'ACL';                Path = 'OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'Role';               Path = 'OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'GPO';                Path = 'OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'Distribution';       Path = 'OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
    @{ Name = 'Application';        Path = 'OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal' }
)

# -- Active Directory - User Accounts -----------------------------------------
Users = @(

    # -- Service Accounts -----------------------------------------------------
    # SVC_DomainJoin
    # Purpose: joining pre-staged computer objects to the domain.
    @{
        SamAccountName        = 'SVC_DomainJoin'
        DisplayName           = 'Service Account - Domain Join'
        GivenName             = 'DomainJoin'
        Surname               = 'ServiceAccount'
        Password              = 'Str0ng-J0in-P@ss!'   # keep in sync with DomainJoin block above
        ChangePasswordAtLogon = $false
        OU                    = 'OU=ServiceAccounts,OU=Admin,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Groups                = @()
        ProfilePath           = ''
        Description           = 'Service Account Created by Vagrant during Domain Controller Provisioning'
    }
	
	# SVC_PKIAdmin
	# Purpose: Dedicated account for installing the Enterprise CA. 
	# Requires Enterprise Admins for initial setup.
	@{
		SamAccountName        = 'SVC_PKIAdmin'
		DisplayName           = 'Service Account - PKI Administrator'
		GivenName             = 'PKI'
		Surname               = 'Admin'
		Password              = 'Str0ng-PKI-P@ss!' 
		ChangePasswordAtLogon = $false
		OU                    = 'OU=ServiceAccounts,OU=Admin,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
		Groups                = @('Domain Admins', 'Enterprise Admins') 
		ProfilePath           = ''
		Description           = 'Service Account Created by Vagrant for CA Provisioning'
	}

    # -- Tier 0 - Domain admin accounts ---------------------------------------
    @{
        SamAccountName = 'ADD_JMA8601'
        DisplayName    = 'Domain Admin - Johan Magerman'
        GivenName      = 'Johan'
        Surname        = 'Magerman'
        Password       = 'vagrant'
        OU             = 'OU=T0-Domain,OU=Admin,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Groups         = @('Domain Admins')
        ProfilePath    = '\\windowsdc\Profiles\%username%'
        Description    = 'Domain Admin Account Created by Vagrant during Domain Controller Provisioning'
    }
    @{
        SamAccountName = 'ADD_DCO9001'
        DisplayName    = 'Domain Admin - Dean Cooreman'
        GivenName      = 'Dean'
        Surname        = 'Cooreman'
        Password       = 'vagrant'
        OU             = 'OU=T0-Domain,OU=Admin,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Groups         = @('Domain Admins')
        ProfilePath    = '\\windowsdc\Profiles\%username%'
        Description    = 'Domain Admin Account Created by Vagrant during Domain Controller Provisioning'
    }
    @{
        SamAccountName = 'ADD_JRO8901'
        DisplayName    = 'Domain Admin - Jelle Robyn'
        GivenName      = 'Jelle'
        Surname        = 'Robyn'
        Password       = 'vagrant'
        OU             = 'OU=T0-Domain,OU=Admin,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Groups         = @('Domain Admins')
        ProfilePath    = '\\windowsdc\Profiles\%username%'
        Description    = 'Domain Admin Account Created by Vagrant during Domain Controller Provisioning'
    }
    @{
        SamAccountName = 'ADD_GLE0301'
        DisplayName    = 'Domain Admin - Guillaume Lescur'
        GivenName      = 'Guillaume'
        Surname        = 'Lescur'
        Password       = 'vagrant'
        OU             = 'OU=T0-Domain,OU=Admin,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Groups         = @('Domain Admins')
        ProfilePath    = '\\windowsdc\Profiles\%username%'
        Description    = 'Domain Admin Account Created by Vagrant during Domain Controller Provisioning'
    }

    # -- Regular user accounts ------------------------------------------------
    @{
        SamAccountName        = 'JMA8601'
        DisplayName           = 'Johan Magerman'
        GivenName             = 'Johan'
        Surname               = 'Magerman'
        Password              = 'vagrant'
        OU                    = 'OU=IT,OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Groups                = @()
        ProfilePath           = '\\windowsdc\Profiles\%username%'
        ChangePasswordAtLogon = $false
        EmailAddress          = 'johan.magerman@t02-domain404.internal'
        Title                 = 'System Engineer'
        Department            = 'IT'
        Company               = 'Domain 404'
        Description           = 'Created by Vagrant during Domain Controller Provisioning'
    }
    @{
        SamAccountName = 'DCO9001'
        DisplayName    = 'Dean Cooreman'
        GivenName      = 'Dean'
        Surname        = 'Cooreman'
        Password       = 'vagrant'
        OU             = 'OU=IT,OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Groups         = @()
        ProfilePath    = '\\windowsdc\Profiles\%username%'
        EmailAddress   = 'dean.cooreman@t02-domain404.internal'
        Title          = 'System Engineer'
        Department     = 'IT'
        Company        = 'Domain 404'
        Description    = 'Created by Vagrant during Domain Controller Provisioning'

    }
    @{
        SamAccountName = 'JRO8901'
        DisplayName    = 'Jelle Robyn'
        GivenName      = 'Jelle'
        Surname        = 'Robyn'
        Password       = 'vagrant'
        OU             = 'OU=IT,OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Groups         = @()
        ProfilePath    = '\\windowsdc\Profiles\%username%'
        EmailAddress   = 'jelle.robyn@t02-domain404.internal'
        Title          = 'System Engineer'
        Department     = 'IT'
        Company        = 'Domain 404'
        Description    = 'Created by Vagrant during Domain Controller Provisioning'

    }
    @{
        SamAccountName = 'GLE0301'
        DisplayName    = 'Guillaume Lescur'
        GivenName      = 'Guillaume'
        Surname        = 'Lescur'
        Password       = 'vagrant'
        OU             = 'OU=IT,OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Groups         = @()
        ProfilePath    = '\\windowsdc\Profiles\%username%'
        EmailAddress   = 'guillaume.lescur@t02-domain404.internal'
        Title          = 'System Engineer'
        Department     = 'IT'
        Company        = 'Domain 404'
        Description    = 'Created by Vagrant during Domain Controller Provisioning'

    }
)

# -- Active Directory - Pre-staged Computer Accounts --------------------------
#
# Computer objects are created on the DC BEFORE the machine joins the domain.
# Default OU Location for clients: _Staging.
Computers = @(

    @{
        Name        = 'L-26-00001'
        Path        = 'OU=_Staging,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Description = 'Vagrant Windows 10 client'
    }
    @{
        Name        = 'storage'
        Path        = 'OU=Infrastructure,OU=Servers,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Description = 'Vagrant AlmaLinux storage server'
    }
)

# -- Active Directory - Security Groups ---------------------------------------
Groups = @(

    # -- Service-account deny group -------------------------------------------
    # Members of this group are blocked from interactive and RDP logon on all
    # computers in OU=Computers via GPO-Block-SvcAccount-Logon.
    @{
        Name        = 'GRP_SVC_All'
        Path        = 'OU=GPO,OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Description = 'All service accounts. GPO denies interactive and RDP logon on all computers.'
        Scope       = 'Global'
        Category    = 'Security'
        Members     = @('SVC_DomainJoin', 'SVC_PKIAdmin')
    }

    # -- Department logon groups -----------------------------------------------
    # Each group is linked to the matching workstation sub-OU via GPO.
    # SeInteractiveLogonRight on that OU is set to:
    #   Administrators + Domain Admins + this group (all others are denied).
    @{
        Name        = 'GRP_Logon_IT'
        Path        = 'OU=GPO,OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Description = 'IT users. Permitted to log on interactively to OU=IT workstations.'
        Scope       = 'Global'
        Category    = 'Security'
        Members     = @('JMA8601', 'DCO9001', 'JRO8901', 'GLE0301')
    }
    @{
        Name        = 'GRP_Logon_HR'
        Path        = 'OU=GPO,OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Description = 'HR users. Permitted to log on interactively to OU=HR workstations.'
        Scope       = 'Global'
        Category    = 'Security'
        Members     = @()    }
    @{
        Name        = 'GRP_Logon_Management'
        Path        = 'OU=GPO,OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Description = 'Management users. Permitted to log on interactively to OU=Management workstations.'
        Scope       = 'Global'
        Category    = 'Security'
        Members     = @()    }
    @{
        Name        = 'GRP_Logon_Development'
        Path        = 'OU=GPO,OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Description = 'Development users. Permitted to log on interactively to OU=Development workstations.'
        Scope       = 'Global'
        Category    = 'Security'
        Members     = @()    }
    @{
        Name        = 'GRP_RestrictedUsers'
        Path        = 'OU=GPO,OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
        Description = 'Users with restricted workstation environment (no control panel, locked background, etc.)'
        Scope       = 'Global'
        Category    = 'Security'
        Members     = @('GLE0301')
    }
	
	# -- Storage group --------------------------------------------------------
    # Users that are member of this group will get a Homefolder created on the storage server
	@{
		Name        = 'GRP_Storage_Users'
		Path        = 'OU=ACL,OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
		Description = 'Users with a home folder on the storage server.'
		Scope       = 'Global'
		Category    = 'Security'
		Members     = @('JMA8601', 'DCO9001', 'JRO8901', 'GLE0301')
	}
)
}
