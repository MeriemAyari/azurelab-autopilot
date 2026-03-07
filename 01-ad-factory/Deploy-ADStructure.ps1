# ===============================================
# Deploy-ADStructure.ps1 - AD Factory Deployment
# ===============================================
# Project : AD Factory - AzureLab-Autopilot
# Author  : github.com/your-username
# Version : 1.1.0
# License : MIT
#
# USAGE:
#   Simulate : .\Deploy-ADStructure.ps1 -WhatIf
#   Deploy   : .\Deploy-ADStructure.ps1
#   Custom   : .\Deploy-ADStructure.ps1 -ConfigPath "C:\client-acme.json"
# ===============================================

param(
    [string]$ConfigPath = ".\config.json",
    [switch]$WhatIf
)

Import-Module ActiveDirectory -ErrorAction Stop
Import-Module DnsServer       -ErrorAction Stop
Import-Module DHCPServer      -ErrorAction Stop

# -----------------------------------------------
# HELPERS
# -----------------------------------------------

function Write-Step { param([string]$s) Write-Host "`n[$(Get-Date -f 'HH:mm:ss')] $s" -ForegroundColor Cyan }
function Write-OK   { param([string]$s) Write-Host "  [OK]   $s" -ForegroundColor Green }
function Write-WARN { param([string]$s) Write-Host "  [WARN] $s" -ForegroundColor Yellow }
function Write-FAIL { param([string]$s) Write-Host "  [FAIL] $s" -ForegroundColor Red }
function Write-INFO { param([string]$s) Write-Host "  [INFO] $s" -ForegroundColor Gray }

function Invoke-Action {
    param([string]$Description, [scriptblock]$Action)
    if ($WhatIf) {
        Write-INFO "[Simulation] $Description"
    } else {
        try { & $Action } catch { Write-FAIL "$Description : $_" }
    }
}

# -----------------------------------------------
# LOAD CONFIG
# -----------------------------------------------

Write-Step "Loading configuration from: $ConfigPath"

if (-not (Test-Path $ConfigPath)) {
    Write-FAIL "Configuration file not found: $ConfigPath"
    exit 1
}

$config  = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$domain  = $config.forest.rootDomain
$netbios = $config.forest.netbiosName

Write-OK "Configuration loaded successfully"
Write-INFO "Target domain  : $domain"
Write-INFO "Sites defined  : $($config.sites.Count)"
Write-INFO "OUs defined    : $($config.organizationalUnits.Count)"
Write-INFO "Users defined  : $($config.users.Count)"

# -----------------------------------------------
# STEP 1/8 - FOREST & DOMAIN
# -----------------------------------------------

Write-Step "[ STEP 1/8 ] Forest & Domain Installation"
Write-INFO "Domain  : $domain"
Write-INFO "NetBIOS : $netbios"

$dcExists = Get-ADDomainController -Filter * -ErrorAction SilentlyContinue

if (-not $dcExists) {
    Invoke-Action "Install-ADDSForest $domain" {
        Install-ADDSForest `
            -DomainName                    $domain `
            -DomainNetbiosName             $netbios `
            -SafeModeAdministratorPassword (ConvertTo-SecureString $config.forest.safeModePassword -AsPlainText -Force) `
            -DomainMode                    Windows2016Domain `
            -ForestMode                    Windows2016Forest `
            -InstallDNS `
            -Force
        Write-OK "Forest installed: $domain (reboot incoming)"
    }
} else {
    Write-OK "Server is already a Domain Controller - skipping"
}

# -----------------------------------------------
# STEP 2/8 - SITES & SERVICES
# -----------------------------------------------

Write-Step "[ STEP 2/8 ] Configuring AD Sites & Services"
Write-INFO "Defining $($config.sites.Count) site(s)"

$newSites = 0
foreach ($site in $config.sites) {
    $exists = Get-ADReplicationSite -Identity $site.name -ErrorAction SilentlyContinue
    if (-not $exists) {
        Invoke-Action "Create site $($site.name)" {
            New-ADReplicationSite -Name $site.name
            New-ADReplicationSubnet -Name $site.subnet -Site $site.name
            Write-OK "Site created: $($site.name) [$($site.subnet)]"
            $newSites++
        }
    } else {
        Write-WARN "Site already exists, skipping: $($site.name)"
    }
}

# -----------------------------------------------
# STEP 3/8 - ORGANIZATIONAL UNITS
# -----------------------------------------------

Write-Step "[ STEP 3/8 ] Building OU Structure"
Write-INFO "Creating $($config.organizationalUnits.Count) OU(s)"

$newOUs = 0
foreach ($ou in $config.organizationalUnits) {
    $exists = Get-ADOrganizationalUnit -Filter "Name -eq '$($ou.name)'" -SearchBase $ou.path -ErrorAction SilentlyContinue
    if (-not $exists) {
        Invoke-Action "Create OU $($ou.name)" {
            New-ADOrganizationalUnit `
                -Name        $ou.name `
                -Path        $ou.path `
                -Description "Managed by AD Factory" `
                -ProtectedFromAccidentalDeletion $true
            Write-OK "OU created: OU=$($ou.name),$($ou.path)"
            $newOUs++
        }
    } else {
        Write-WARN "OU already exists, skipping: $($ou.name)"
    }
}

# -----------------------------------------------
# STEP 4/8 - SECURITY GROUPS
# -----------------------------------------------

Write-Step "[ STEP 4/8 ] Creating Security Groups"
Write-INFO "Creating $($config.groups.Count) group(s)"

$newGroups = 0
foreach ($grp in $config.groups) {
    if (-not $grp.name -or -not $grp.ou) { Write-WARN "Incomplete group definition, skipping"; continue }

    $exists = Get-ADGroup -Filter "Name -eq '$($grp.name)'" -ErrorAction SilentlyContinue
    if (-not $exists) {
        Invoke-Action "Create group $($grp.name)" {
            New-ADGroup `
                -Name          $grp.name `
                -GroupScope    $grp.scope `
                -GroupCategory $grp.category `
                -Path          $grp.ou `
                -Description   "Managed by AD Factory"
            Write-OK "Group created: $($grp.name) [$($grp.scope)]"
            $newGroups++
        }
    } else {
        Write-WARN "Group already exists, skipping: $($grp.name)"
    }
}

# -----------------------------------------------
# STEP 5/8 - USER ACCOUNTS
# -----------------------------------------------

Write-Step "[ STEP 5/8 ] Provisioning User Accounts"
Write-INFO "Creating $($config.users.Count) user(s)"

$newUsers = 0
foreach ($user in $config.users) {
    if (-not $user.samAccountName -or -not $user.ou) { Write-WARN "Incomplete user definition, skipping"; continue }

    $exists = Get-ADUser -Filter "SamAccountName -eq '$($user.samAccountName)'" -ErrorAction SilentlyContinue
    if (-not $exists) {
        Invoke-Action "Create user $($user.samAccountName)" {
            New-ADUser `
                -Name                  "$($user.firstName) $($user.lastName)" `
                -GivenName             $user.firstName `
                -Surname               $user.lastName `
                -SamAccountName        $user.samAccountName `
                -UserPrincipalName     "$($user.samAccountName)@$domain" `
                -Path                  $user.ou `
                -AccountPassword       (ConvertTo-SecureString $user.password -AsPlainText -Force) `
                -Enabled               $true `
                -ChangePasswordAtLogon $true `
                -Description           "Provisioned by AD Factory"

            foreach ($grp in $user.groups) {
                Add-ADGroupMember -Identity $grp -Members $user.samAccountName -ErrorAction SilentlyContinue
                Write-INFO "  Membership: $($user.samAccountName) -> $grp"
            }

            Write-OK "User created: $($user.samAccountName)@$domain"
            $newUsers++
        }
    } else {
        Write-WARN "User already exists, skipping: $($user.samAccountName)"
    }
}

# -----------------------------------------------
# STEP 6/8 - PASSWORD POLICY (PSO)
# -----------------------------------------------

Write-Step "[ STEP 6/8 ] Applying Fine-Grained Password Policy"

$psoExists = Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'PSO-Corporate'" -ErrorAction SilentlyContinue
if (-not $psoExists) {
    Invoke-Action "Create PSO-Corporate" {
        $gpo = $config.gpo
        New-ADFineGrainedPasswordPolicy `
            -Name                            "PSO-Corporate" `
            -Precedence                      10 `
            -MinPasswordLength               $gpo.passwordPolicy.minLength `
            -MaxPasswordAge                  ([TimeSpan]::FromDays($gpo.passwordPolicy.maxAge)) `
            -MinPasswordAge                  ([TimeSpan]::FromDays($gpo.passwordPolicy.minAge)) `
            -PasswordHistoryCount            $gpo.passwordPolicy.historyCount `
            -ComplexityEnabled               $gpo.passwordPolicy.complexity `
            -LockoutThreshold                $gpo.lockoutPolicy.threshold `
            -LockoutDuration                 ([TimeSpan]::FromMinutes($gpo.lockoutPolicy.duration)) `
            -LockoutObservationWindow        ([TimeSpan]::FromMinutes($gpo.lockoutPolicy.observationWindow)) `
            -ReversibleEncryptionEnabled     $false `
            -ProtectedFromAccidentalDeletion $true

        Add-ADFineGrainedPasswordPolicySubject -Identity "PSO-Corporate" -Subjects "GRP_Admins"
        Write-OK "PSO-Corporate created and linked to GRP_Admins"
        Write-INFO "  Min length : $($gpo.passwordPolicy.minLength) chars"
        Write-INFO "  Lockout    : after $($gpo.lockoutPolicy.threshold) failed attempts"
    }
} else {
    Write-WARN "PSO-Corporate already exists, skipping"
}

# -----------------------------------------------
# STEP 7/8 - DNS
# -----------------------------------------------

Write-Step "[ STEP 7/8 ] Configuring DNS"

$newDns = 0
foreach ($fwd in $config.dns.forwarders) {
    Invoke-Action "Add DNS forwarder $fwd" {
        $fwdExists = Get-DnsServerForwarder | Where-Object { $_.IPAddress -eq $fwd }
        if (-not $fwdExists) {
            Add-DnsServerForwarder -IPAddress $fwd -ErrorAction Stop
            Write-OK "DNS forwarder added: $fwd"
            $newDns++
        } else {
            Write-WARN "DNS forwarder already exists: $fwd"
        }
    }
}

foreach ($record in $config.dns.records) {
    Invoke-Action "Add DNS record $($record.name)" {
        $recExists = Get-DnsServerResourceRecord -ZoneName $record.zone -Name $record.name -ErrorAction SilentlyContinue
        if (-not $recExists) {
            Add-DnsServerResourceRecordA -ZoneName $record.zone -Name $record.name -IPv4Address $record.ip
            Write-OK "DNS A record: $($record.name).$($record.zone) -> $($record.ip)"
        } else {
            Write-WARN "DNS record already exists: $($record.name)"
        }
    }
}

Invoke-Action "Enable DNS scavenging" {
    Set-DnsServerScavenging -ScavengingState $true -ScavengingInterval "7.00:00:00" -ApplyOnAllZones
    Write-OK "DNS scavenging enabled (7-day interval)"
}

# -----------------------------------------------
# STEP 8/8 - DHCP
# -----------------------------------------------

Write-Step "[ STEP 8/8 ] Configuring DHCP"
Write-INFO "Creating $($config.dhcp.scopes.Count) scope(s)"

Invoke-Action "Authorize DHCP server in AD" {
    try {
        Add-DhcpServerInDC -DnsName $config.dhcp.server -IpAddress $config.dhcp.ip -ErrorAction Stop
        Write-OK "DHCP server authorized in Active Directory"
    } catch {
        Write-WARN "DHCP server already authorized: $_"
    }
}

$newScopes = 0
foreach ($scope in $config.dhcp.scopes) {
    $parts   = $scope.startRange -split '\.'
    $scopeId = "$($parts[0]).$($parts[1]).$($parts[2]).0"

    $exists = Get-DhcpServerv4Scope -ScopeId $scopeId -ErrorAction SilentlyContinue
    if (-not $exists) {
        Invoke-Action "Create DHCP scope $($scope.name)" {
            Add-DhcpServerv4Scope `
                -Name       $scope.name `
                -StartRange $scope.startRange `
                -EndRange   $scope.endRange `
                -SubnetMask $scope.subnetMask `
                -State      Active

            Set-DhcpServerv4OptionValue `
                -ScopeId   $scopeId `
                -Router    $scope.defaultGateway `
                -DnsServer $scope.dnsServer

            Write-OK "DHCP scope created: $($scope.name) [$($scope.startRange) - $($scope.endRange)]"
            Write-INFO "  Gateway : $($scope.defaultGateway)"
            Write-INFO "  DNS     : $($scope.dnsServer)"
            $newScopes++
        }
    } else {
        Write-WARN "DHCP scope already exists, skipping: $($scope.name)"
    }
}

# DHCP Failover - use -Mode (not -Type)
if ($config.dhcp.failover.enabled) {
    $failoverExists = Get-DhcpServerv4Failover -Name "DHCP-Failover" -ErrorAction SilentlyContinue
    if (-not $failoverExists) {
        Invoke-Action "Configure DHCP failover -> $($config.dhcp.failover.partnerServer)" {
            $scopeIds = $config.dhcp.scopes | ForEach-Object {
                $p = $_.startRange -split '\.'
                "$($p[0]).$($p[1]).$($p[2]).0"
            }
            Add-DhcpServerv4Failover `
                -Name                "DHCP-Failover" `
                -PartnerServer       $config.dhcp.failover.partnerServer `
                -ScopeId             $scopeIds `
                -Mode                HotStandby `
                -StandbyPercent      $config.dhcp.failover.standbyPercent `
                -AutoStateTransition $true `
                -Force
            Write-OK "DHCP failover configured (HotStandby) -> $($config.dhcp.failover.partnerServer)"
        }
    } else {
        Write-WARN "DHCP failover already configured, skipping"
    }
}

# -----------------------------------------------
# DEPLOYMENT REPORT
# -----------------------------------------------

$status = if ($WhatIf) { "SIMULATION ONLY - No changes applied" } else { "DEPLOYED SUCCESSFULLY" }
$color  = if ($WhatIf) { "Yellow" } else { "Green" }

Write-Host ""
Write-Host "  +-----------------------------------------------+" -ForegroundColor White
Write-Host "  |        AD FACTORY - DEPLOYMENT REPORT        |" -ForegroundColor White
Write-Host "  +-----------------------------------------------+" -ForegroundColor White
Write-Host "  | Domain      : $domain" -ForegroundColor White
Write-Host "  | Sites       : $($config.sites.Count) site(s)" -ForegroundColor White
Write-Host "  | OUs         : $($config.organizationalUnits.Count) unit(s)" -ForegroundColor White
Write-Host "  | Groups      : $($config.groups.Count) group(s)" -ForegroundColor White
Write-Host "  | Users       : $($config.users.Count) account(s)" -ForegroundColor White
Write-Host "  | DNS Records : $($config.dns.records.Count) record(s)" -ForegroundColor White
Write-Host "  | DHCP Scopes : $($config.dhcp.scopes.Count) scope(s)" -ForegroundColor White
Write-Host "  +-----------------------------------------------+" -ForegroundColor White
Write-Host "  | Status      : $status" -ForegroundColor $color
Write-Host "  +-----------------------------------------------+" -ForegroundColor White
Write-Host ""