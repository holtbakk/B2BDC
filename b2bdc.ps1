<#
.SYNOPSIS
    List all B2B direct connect organizations, or Add with recommended settings.

.DESCRIPTION
    Script to handle B2B direct connect (External Identities, Cross-tenant access settings)
    List all organizations you have added.
    List all (?) relevant (at time of release) educational organizations in Norway.
    Add single organizations based on domain or tenant ID.
    If you want to target a single or multiple OUTBOUND groups (GUID) when adding organization, use -OutboundGroup (Comma-seperated GUIDs if multiple)
    If you want to target a single or multiple INBOUND groups (GUID) when adding organization, use -InboundGroup (Comma-seperated GUIDs if multiple)

.PARAMETER Target
    If you want to add a organization. By domain (format: uio.no), or Tenant ID (format: 463b6811-b0a4-4b2a-b932-72c4c970c5d2)

.PARAMETER OutboundGroup
    Single or comma-seperated list of GUIDs for groups to target outbound access

.PARAMETER InboundGroup
    Single or comma-seperated list of GUIDs for groups to target inbound access

.EXAMPLE
    .\b2bdc.ps1

.EXAMPLE
    .\b2bdc.ps1 -Target uio.no
    
.EXAMPLE
    .\b2bdc.ps1 -Target 463b6811-b0a4-4b2a-b932-72c4c970c5d2 -OutboundGroup bb368b82-5fb0-49bc-913b-ec23ec28daf5

.EXAMPLE
    .\b2bdc.ps1 -Target hiof.no -OutboundGroup bb368b82-5fb0-49bc-913b-ec23ec28daf5 -InboundGroup adf4af42-05ba-4461-a487-1961ee53c345

.NOTES
    Author: Bård Holtbakk, bard.holtbakk@nmbu.no
    Version: 1.2
    Date: 17.02.2026
    Link: https://github.com/holtbakk/B2BDC
    
#>

#Requires -Modules Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Users
#Requires -Version 7.0

param(
    [Parameter(Mandatory=$false)][string]$Target,
    [Parameter(Mandatory=$false)][string[]]$InboundGroup,
    [Parameter(Mandatory=$false)][string[]]$OutboundGroup
)

#  Set necessary scope
$scopes = @("Policy.Read.All", "CrossTenantInformation.ReadBasic.All", "User.Read.All")
if ($Target) { $scopes += "Policy.ReadWrite.CrossTenantAccess" }

#  Connect to MS Graph with scope
$mgContext = try { Get-MgContext } catch { $null }
$hasAllScopes = $mgContext -and (-not ($scopes | Where-Object { $_ -notin $mgContext.Scopes }))
if (-not $hasAllScopes) { Connect-MgGraph -Scopes $scopes -NoWelcome } else { Write-Host "Already connected as $($mgContext.Account)" -ForegroundColor Gray }

# Domain list (KI generated: "Give me a list of domain and name for all ... in Norway")
$domains = @(

    # Universiteter
    "uio.no",           # Universitetet i Oslo
    "uib.no",           # Universitetet i Bergen
    "ntnu.no",          # Norges teknisk-naturvitenskapelige universitet
    "uit.no",           # UiT Norges arktiske universitet
    "nmbu.no",          # Norges miljø- og biovitenskapelige universitet
    "uia.no",           # Universitetet i Agder
    "usn.no",           # Universitetet i Sørøst-Norge
    "inn.no",           # Universitetet i Innlandet
    "oslomet.no",       # OsloMet – storbyuniversitetet
    "nord.no",          # Nord universitet
    "uis.no",           # Universitetet i Stavanger

    # Vitenskapelige høgskoler
    "nhh.no",           # Norges Handelshøyskole
    "bi.no",            # Handelshøyskolen BI
    "nih.no",           # Norges idrettshøgskole
    "nmh.no",           # Norges musikkhøgskole
    "aho.no",           # Arkitektur- og designhøgskolen i Oslo
    "khio.no",          # Kunsthøgskolen i Oslo
    "himolde.no",       # Høgskolen i Molde – vitenskapelig høgskole i logistikk
    "vid.no",           # VID vitenskapelige høgskole
    "mf.no",            # MF vitenskapelig høyskole

    # Statlige høgskoler
    "hvl.no",           # Høgskulen på Vestlandet
    "hiof.no",          # Høgskolen i Østfold
    "samiskhs.no",      # Samisk høgskole / Sámi allaskuvla
    "dmmh.no",          # Dronning Mauds Minne Høgskole
    "hivolda.no",       # Høgskulen i Volda

    # Private høgskoler
    "kristiania.no",    # Høyskolen Kristiania
    "nla.no",           # NLA Høgskolen
    "fih.no",           # Fjellhaug Internasjonale Høgskole

    # Andre (Politiet/Forsvaret)
    "phs.no",           # Politihøgskolen

    # Forskningsinstitutter
    "nibio.no",         # NIBIO – Norsk institutt for bioøkonomi
    "vetinst.no",       # Veterinærinstituttet
    "nofima.no",        # Nofima
    "sintef.no",        # SINTEF
    "ife.no",           # Institutt for energiteknikk (IFE)
    "norceresearch.no", # NORCE
    "nr.no",            # Norsk Regnesentral
    "fni.no",           # Fridtjof Nansens Institutt
    "nupi.no",          # Norsk utenrikspolitisk institutt
    "toi.no",           # Transportøkonomisk institutt
    "simula.no",        # Simula Research Laboratory
    "cicero.oslo.no",   # CICERO – Senter for klimaforskning

    # Sektororganer
    "sikt.no",          # Sikt – Kunnskapssektorens tjenesteleverandør
    "hkdir.no",         # HK-dir – Direktoratet for høyere utdanning og kompetanse
    "nokut.no",         # NOKUT – Nasjonalt organ for kvalitet i utdanningen
    "uhr.no"            # UHR – Universitets- og høgskolerådet
)

# Helper functions

function Test-Guid {
    param([string]$Value)
    $out = [Guid]::Empty
    return [Guid]::TryParse($Value, [ref]$out)
}

function Resolve-TenantId {
    param([string]$Domain)
    try {
        $response = Invoke-RestMethod `
            -Uri "https://login.microsoftonline.com/$Domain/.well-known/openid-configuration" `
            -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($response.issuer -match "https://sts\.windows\.net/([a-f0-9\-]+)/") {
            return $matches[1]
        }
    } catch {}
    return $null
}

function Get-TenantDisplayName {
    param([string]$TenantId)
    try {
        $info = Invoke-MgGraphRequest -Method GET `
            "https://graph.microsoft.com/v1.0/tenantRelationships/findTenantInformationByTenantId(tenantId='$TenantId')"
        return $info.displayName
    } catch {
        return $TenantId
    }
}

function Get-ScopeLabel {
    param($Settings)
    if ($null -eq $Settings) { return "-" }
    if ($Settings.UsersAndGroups.AccessType -eq "blocked") { return "Blocked" }
    $targets = $Settings.UsersAndGroups?.Targets
    if ($targets | Where-Object { $_.Target -eq "AllUsers" }) { return "All" }
    if ($targets -and $targets.Count -gt 0) { return "Limited" }
    return "-"
}

function Get-TrustLabel {
    param($Value)
    if ($null -eq $Value) { return "-" }
    return ($Value -eq $true) ? "Yes" : "No"
}

function Invoke-ConfigurePartner {
    param(
        [string]$TenantId,
        [string]$DisplayName,
        [array]$InboundTargets,
        [array]$OutboundTargets
    )

    $params = @{
        tenantId = $TenantId
        b2bDirectConnectInbound = @{
            usersAndGroups = @{
                accessType = "allowed"
                targets    = $InboundTargets
            }
            applications = @{
                accessType = "allowed"
                targets    = @(
                    @{
                        target     = "Office365"
                        targetType = "application"
                    }
                )
            }
        }
        inboundTrust = @{
            isMfaAccepted                       = $true
            isCompliantDeviceAccepted           = $false
            isHybridAzureADJoinedDeviceAccepted = $false
        }
        b2bDirectConnectOutbound = @{
            usersAndGroups = @{
                accessType = "allowed"
                targets    = $OutboundTargets
            }
            applications = @{
                accessType = "allowed"
                targets    = @(
                    @{
                        target     = "Office365"
                        targetType = "application"
                    }
                )
            }
        }
    }

    try {
        $existing = Get-MgPolicyCrossTenantAccessPolicyPartner -CrossTenantAccessPolicyConfigurationPartnerTenantId $TenantId -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "[skip] Partner already exists. Modify via portal!" -ForegroundColor Yellow
        } else {
            Write-Host "Creating new partner." -ForegroundColor Yellow
            New-MgPolicyCrossTenantAccessPolicyPartner -BodyParameter $params | Out-Null
            Write-Host "[ok] Partner successfully configured: $DisplayName" -ForegroundColor Green

        }
    } catch {
        Write-Host "[err] Partner configuration failed for $DisplayName`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Resolve domain list to tenant IDs
Write-Host "`nResolving tenant IDs for domain list..." -ForegroundColor Cyan
$resolvedList = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($d in $domains) {
    $tid = Resolve-TenantId -Domain $d
    if ($tid) {
        $resolvedList.Add([PSCustomObject]@{ Domain = $d; TenantId = $tid })
    }
}
$scriptIndex = @{}
foreach ($r in $resolvedList) { $scriptIndex[$r.TenantId] = $r }
Write-Host "Resolved $($resolvedList.Count) of $($domains.Count) domains.`n" -ForegroundColor Cyan

# Target specified
if ($Target) {

    $InboundGroup  = $InboundGroup  | Where-Object { $_ -and $_.Trim() -ne "" }
    $OutboundGroup = $OutboundGroup | Where-Object { $_ -and $_.Trim() -ne "" }

    foreach ($g in @($InboundGroup + $OutboundGroup)) {
        if ($g -and -not (Test-Guid $g.Trim())) {
            Write-Host "ERROR: '$g' is not a valid GUID." -ForegroundColor Red
            return
        }
    }

    if ($InboundGroup -and $InboundGroup.Count -gt 0) {
        $InboundTargets = @(foreach ($group in $InboundGroup) {
            @{
                target     = $group.Trim()
                targetType = "group"
            }
        })
    }
    else {
        $InboundTargets = @(
            @{
                target     = "AllUsers"
                targetType = "user"
            }
        )
    }

    if ($OutboundGroup -and $OutboundGroup.Count -gt 0) {
        $OutboundTargets = @(foreach ($group in $OutboundGroup) {
            @{
                target     = $group.Trim()
                targetType = "group"
            }
        })
    }
    else {
        $OutboundTargets = @(
            @{
                target     = "AllUsers"
                targetType = "user"
            }
        )
    }

    Write-Host "`nAction mode: configuring '$Target'..." -ForegroundColor Cyan

    # Resolve tenant ID and display name depending on input type
    if (Test-Guid $Target) {
        $targetTenantId = $Target
        $targetLabel = Get-TenantDisplayName -TenantId $targetTenantId
        Write-Host "Resolved display name: $targetLabel" -ForegroundColor Gray
    } else {
        $targetTenantId = Resolve-TenantId -Domain $Target
        if (-not $targetTenantId) {
            Write-Host "ERROR: Could not resolve tenant ID for '$Target'. Is it a valid Entra tenant?" -ForegroundColor Red
            return
        }
        $targetLabel = $Target
        Write-Host "Resolved tenant ID: $targetTenantId" -ForegroundColor Gray
    }

    Invoke-ConfigurePartner -TenantId $targetTenantId -DisplayName $targetLabel -InboundTargets $InboundTargets -OutboundTargets $OutboundTargets

    if (-not $scriptIndex.ContainsKey($targetTenantId)) {
        Write-Host "`n  Note: '$Target' is not in the `$domains list in the script." -ForegroundColor Yellow
        Write-Host "  Consider adding it so it appears in future display runs." -ForegroundColor Yellow
    }

    return
}

# No target specified, display only

# Fetch guests
Write-Host "Fetching guest users..." -ForegroundColor Cyan
$allGuests = Get-MgUser -All -Filter "userType eq 'Guest'" -Property "mail,userPrincipalName"
$guestCountByDomain = @{}
foreach ($guest in $allGuests) {
    $guestDomain = $null
    if ($guest.Mail -and $guest.Mail -match "@(.+)$") {
        $guestDomain = $matches[1].ToLower()
    } elseif ($guest.UserPrincipalName -match "^.+_(.+)#EXT#@") {
        $guestDomain = $matches[1].ToLower()
    }
    if ($guestDomain) {
        if (-not $guestCountByDomain.ContainsKey($guestDomain)) { $guestCountByDomain[$guestDomain] = 0 }
        $guestCountByDomain[$guestDomain]++
    }
}
Write-Host "Found $($allGuests.Count) guest users.`n" -ForegroundColor Cyan

# Fetch partner configs
Write-Host "Fetching cross-tenant access policy partners..." -ForegroundColor Cyan
$allPartners = Get-MgPolicyCrossTenantAccessPolicyPartner -All
$partnerIndex = @{}
foreach ($p in $allPartners) { $partnerIndex[$p.TenantId] = $p }

# Build unified tenant ID set
$allTenantIds = [System.Collections.Generic.HashSet[string]]::new()
foreach ($r in $resolvedList) { $allTenantIds.Add($r.TenantId) | Out-Null }
foreach ($p in $allPartners)  { $allTenantIds.Add($p.TenantId) | Out-Null }

# Build table
$table = foreach ($tid in $allTenantIds) {

    $inScript = $scriptIndex.ContainsKey($tid)
    $inPortal = $partnerIndex.ContainsKey($tid)
    $partner  = $partnerIndex[$tid]

    $displayName = if ($inScript) {
        $scriptIndex[$tid].Domain
    } else {
        $partner.DisplayName ?? (Get-TenantDisplayName -TenantId $tid)
    }

    $source = if ($inScript -and $inPortal) { "Both"   }
         elseif ($inPortal)                 { "Portal" }
         else                               { "Script" }

    $guestCount = if ($inScript) {
        $d = $scriptIndex[$tid].Domain
        if ($guestCountByDomain.ContainsKey($d)) { $guestCountByDomain[$d] } else { 0 }
    } else { "-" }

    if (-not $inPortal) {
        [PSCustomObject]@{
            "Source"            = $source
            "Domain / Org"      = $displayName
            "B2B Guests"        = $guestCount
            "In: Status"        = "Not configured"
            "In: Users/Groups"  = "-"
            "In: Trust MFA"     = "-"
            "In: Compliant"     = "-"
            "In: HybridJoin"    = "-"
            "Out: Status"       = "Not configured"
            "Out: Users/Groups" = "-"
        }
    } else {
        $inbound  = $partner.B2bDirectConnectInbound
        $outbound = $partner.B2bDirectConnectOutbound
        $trust    = $partner.InboundTrust
        [PSCustomObject]@{
            "Source"            = $source
            "Domain / Org"      = $displayName
            "B2B Guests"        = $guestCount
            "In: Status"        = if ($null -ne $inbound)  { "Custom"  } else { "Default" }
            "In: Users/Groups"  = Get-ScopeLabel -Settings $inbound
            "In: Trust MFA"     = Get-TrustLabel -Value $trust.IsMfaAccepted
            "In: Compliant"     = Get-TrustLabel -Value $trust.IsCompliantDeviceAccepted
            "In: HybridJoin"    = Get-TrustLabel -Value $trust.IsHybridAzureADJoinedDeviceAccepted
            "Out: Status"       = if ($null -ne $outbound) { "Custom"  } else { "Default" }
            "Out: Users/Groups" = Get-ScopeLabel -Settings $outbound
        }
    }
}

$table | Sort-Object @{e="Source"; a=$false}, "Domain / Org" | Format-Table -AutoSize -Wrap

$both        = ($table | Where-Object { $_.Source -eq "Both"   }).Count
$portalOnly  = ($table | Where-Object { $_.Source -eq "Portal" }).Count
$scriptOnly  = ($table | Where-Object { $_.Source -eq "Script" }).Count
$totalGuests = ($table | Where-Object { $_."B2B Guests" -ne "-" } | Measure-Object "B2B Guests" -Sum).Sum

Write-Host "Both: $both  |  Portal only: $portalOnly  |  Script only: $scriptOnly  |  Total B2B guests: $totalGuests" -ForegroundColor Cyan