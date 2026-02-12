<#PSScriptInfo
.VERSION
    0.0.1
.GUID
    ee3f3ac4-6641-44b7-8e9e-8614033a0e69
.AUTHOR
    fgerber@evoila.com
.COMPANYNAME
    evoila Austria & CEE GmbH
.COPYRIGHT
    © 2025 evoila GmbH. All rights reserved.
.PROJECTURI
    https://evoila.com/
.ICONURI
    https://evoila.com/wp-content/uploads/2024/10/PNG-Glyphe-Full-Color.png
.TAGS
    ExchangeOnline
    EntraID
.EXTERNALMODULEDEPENDENCIES 
    ExchangeOnlineManagement,
    Microsoft.Graph
.RELEASENOTES
    Inital Release
#>
<#
#Requires -Module ExchangeOnlineManagement
# #Requires -Module Microsoft.Graph.Entra
#>
#requires -Version 7.2
<# 
.SYNOPSIS
    Sync multiple Entra ID attributes (Built-in, Schema Extension, Custom Security Attributes)
    to Exchange Online mailbox CustomAttribute1..15 using a hashtable map.

.DESCRIPTION
    - Accepts a hashtable mapping Entra sources to EXO CustomAttribute numbers (1-15).
    - Supported source key formats:
        * Built-in: "employeeId"
        * Schema Extension: "extension_{appIdWithoutDashes}_{AttributeName}"
        * Custom Security Attribute: "CSA:{SetName}:{AttributeName}"
    - Fetches all needed Graph properties for each user in a single call.
    - Applies only changed attributes, batching per mailbox into one Set-EXOMailbox call.
    - Supports dry-run, group scoping, multivalue joining, clearing empty, and CSV logging.

.PARAMETER AttributeMap
    Hashtable of source -> target mappings as described above.

.PARAMETER MappingJsonPath
    Optional path to a JSON file containing a mapping object of { "sourceKey": targetNumber, ... }.
    Used if -AttributeMap is not supplied.

.PARAMETER RecipientTypeDetails
    EXO RecipientTypeDetails to include (default: UserMailbox, SharedMailbox, RoomMailbox, EquipmentMailbox).

.PARAMETER GroupObjectId
    Optional Entra group (ObjectId) to scope processing to its *user* members.

.PARAMETER ClearWhenEmpty
    If set, clears EXO CustomAttributeN when the source value is null/empty.

.PARAMETER DryRun
    If set, no changes are written; actions are logged as "Planned (DryRun)".

.PARAMETER Delimiter
    Delimiter to join multivalue sources (default: "; ").

.PARAMETER LogPath
    Path for CSV log output.

.NOTES
    Requires: ExchangeOnlineManagement (v3+), Microsoft.Graph (meta module).
    Scopes:
        - Always: User.Read.All, Directory.Read.All
        - If any CSA mapping is present: CustomSecAttribute.Read.All

.EXAMPLES
    # Example 1: Inline map
    $Map = @{
        "employeeId" = 1
        "department" = 2
        "extension_4a1f8b9e12ab4fcd8c900123456789ab_CostCenter" = 10
        "CSA:HR:Grade" = 5
    }
    .\Sync-EntraToEXO-Attributes.ps1 -AttributeMap $Map -DryRun

    # Example 2: Load mapping from JSON file
    .\Sync-EntraToEXO-Attributes.ps1 -MappingJsonPath .\mapping.json -ClearWhenEmpty
#>

[CmdletBinding()]
param(
    [Hashtable]$AttributeMap,

    [string]$MappingJsonPath,

    [string[]]$RecipientTypeDetails = @('UserMailbox', 'SharedMailbox', 'RoomMailbox', 'EquipmentMailbox'),

    [string]$GroupObjectId,

    [switch]$ClearWhenEmpty,

    [switch]$DryRun,

    [string]$Delimiter = '; ',

    [string]$LogPath = ("./Sync-EntraToEXO-Log-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
)

begin {
    Write-Host "== Entra → EXO Custom Attributes Sync (Multi-Map) ==" -ForegroundColor Cyan

    # --- Load mapping from JSON if not provided inline ---
    if (-not $AttributeMap -and $MappingJsonPath) {
        if (-not (Test-Path -LiteralPath $MappingJsonPath)) {
            throw "Mapping JSON file not found: $MappingJsonPath"
        }
        try {
            $jsonText = Get-Content -LiteralPath $MappingJsonPath -Raw -ErrorAction Stop
            write-host $jsonText
            $AttributeMap = $jsonText | ConvertFrom-Json -AsHashtable
            Write-Host $AttributeMap
        }
        catch {
            throw "Failed to parse mapping JSON: $($_.Exception.Message)"
        }
    }

    if (-not $AttributeMap -or $AttributeMap.Count -eq 0) {
        throw "No mappings supplied. Provide -AttributeMap or -MappingJsonPath."
    }

    # --- Parse and validate mappings ---
    # Supported key formats:
    #   - Built-in: "employeeId"
    #   - Schema Extension: "extension_{appidnodashes}_{attr}"
    #   - CSA: "CSA:SetName:AttributeName"
    $script:ParsedMappings = New-Object System.Collections.Generic.List[object]
    $script:NeedsCSA = $false

    foreach ($key in $AttributeMap.Keys) {
        Write-Host $key
        $target = $AttributeMap[$key]

        Write-Host $target 

        if ($null -eq $target -or -not ($target -In 1..15)) {
            throw "Invalid target for mapping '$key'. Value must be an integer 1..15."
        }

        # CSA format
        if ($key -match '^CSA:([^:]+):([^:]+)$') {
            $script:ParsedMappings.Add([PSCustomObject]@{
                    SourceKey  = $key
                    SourceType = 'CustomSecurityAttribute'
                    CsaSet     = $Matches[1]
                    CsaAttr    = $Matches[2]
                    Property   = $null
                    Target     = $target
                })
            $script:NeedsCSA = $true
            continue
        }

        # Schema extension format
        if ($key -match '^extension_') {
            $script:ParsedMappings.Add([PSCustomObject]@{
                    SourceKey  = $key
                    SourceType = 'SchemaExtension'
                    CsaSet     = $null
                    CsaAttr    = $null
                    Property   = $key
                    Target     = $target
                })
            continue
        }

        # Default: Built-in property
        $script:ParsedMappings.Add([PSCustomObject]@{
                SourceKey  = $key
                SourceType = 'BuiltIn'
                CsaSet     = $null
                CsaAttr    = $null
                Property   = $key
                Target     = $target
            })
    }

    Write-Host ("Loaded {0} attribute mapping(s)." -f $ParsedMappings.Count) -ForegroundColor Cyan

    # --- Prepare Graph $select properties for one-shot retrieval per user ---
    $script:SelectProps = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $null = $SelectProps.Add('id')
    $null = $SelectProps.Add('displayName')
    $null = $SelectProps.Add('userPrincipalName')

    foreach ($m in $ParsedMappings) {
        switch ($m.SourceType) {
            'BuiltIn' {
                $null = $SelectProps.Add($m.Property)
            }
            'SchemaExtension' {
                # Schema extensions must be included by their full extension property name
                $null = $SelectProps.Add($m.Property)
            }
            'CustomSecurityAttribute' {
                # CSA is a single logical projection
                $null = $SelectProps.Add('customSecurityAttributes')
            }
        }
    }

    # --- Ensure modules exist ---
    $needed = @('ExchangeOnlineManagement', 'Microsoft.Graph')
    foreach ($m in $needed) {
        if (-not (Get-Module -ListAvailable -Name $m)) {
            Write-Warning "Module '$m' not found. Install it with: Install-Module $m -Scope CurrentUser"
        }
    }

    # --- Connect to Exchange Online ---
    try {
        Write-Host "Connecting to Exchange Online..." -ForegroundColor Yellow
        Connect-ExchangeOnline -ShowBanner:$false | Out-Null
    }
    catch {
        throw "Failed to connect to Exchange Online: $($_.Exception.Message)"
    }

    # --- Connect to Microsoft Graph with appropriate scopes ---
    $scopes = @('User.Read.All', 'Directory.Read.All')
    if ($NeedsCSA) { $scopes += 'CustomSecAttribute.Read.All' }

    try {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes $scopes | Out-Null
        Select-MgProfile -Name 'v1.0'
    }
    catch {
        throw "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    }

    # --- Prepare logging ---
    $script:Log = New-Object System.Collections.Generic.List[object]

    # --- Build EXO property list for recipient retrieval (CustomAttribute1..15) ---
    $script:ExoCustomAttrProps = 1..15 | ForEach-Object { "CustomAttribute$_" }

    Write-Host "Setup complete. Beginning data retrieval..." -ForegroundColor Green
}

process {
    try {
        # 1) Fetch recipients from EXO within scope
        Write-Host "Fetching recipients from Exchange Online..." -ForegroundColor Yellow
        $exoRecipients = @()
        foreach ($type in $RecipientTypeDetails) {
            $exoRecipients += Get-EXORecipient -ResultSize Unlimited -RecipientTypeDetails $type -Properties $ExoCustomAttrProps
        }

        if ($GroupObjectId) {
            Write-Host "Filtering recipients by Entra group membership: $GroupObjectId" -ForegroundColor Yellow
            try {
                $groupMembers = Get-MgGroupMember -GroupId $GroupObjectId -All -ErrorAction Stop |
                Where-Object { $_.ODataType -eq '#microsoft.graph.user' }
                $memberIds = $groupMembers.Id
                $exoRecipients = $exoRecipients | Where-Object { $_.ExternalDirectoryObjectId -in $memberIds }
            }
            catch {
                throw "Failed to read group membership: $($_.Exception.Message)"
            }
        }

        if (-not $exoRecipients -or $exoRecipients.Count -eq 0) {
            Write-Host "No recipients found for the given scope." -ForegroundColor Yellow
            return
        }

        $total = $exoRecipients.Count
        Write-Host "Processing $total recipient(s)..." -ForegroundColor Green

        $i = 0
        foreach ($r in $exoRecipients) {
            $i++
            $percent = [math]::Round(($i / $total * 100), 1)
            Write-Progress -Activity "Syncing attributes..." -Status "$i of $total ($percent%)" -PercentComplete $percent

            $recipientIdentity = $r.Identity
            $recipientUpn = $r.PrimarySmtpAddress
            $recipientType = $r.RecipientTypeDetails
            $entraId = $r.ExternalDirectoryObjectId

            if ([string]::IsNullOrWhiteSpace($entraId)) {
                foreach ($m in $ParsedMappings) {
                    $Log.Add([PSCustomObject]@{
                            Timestamp             = (Get-Date)
                            RecipientIdentity     = $recipientIdentity
                            PrimarySmtpAddress    = $recipientUpn
                            RecipientTypeDetails  = $recipientType
                            EntraObjectId         = $null
                            SourceKey             = $m.SourceKey
                            SourceType            = $m.SourceType
                            TargetCustomAttribute = "CustomAttribute$($m.Target)"
                            ExistingTargetValue   = $r.("CustomAttribute$($m.Target)")
                            NewTargetValue        = $null
                            Action                = 'Skipped'
                            Status                = 'Skipped'
                            Error                 = 'No ExternalDirectoryObjectId on recipient.'
                        })
                }
                continue
            }

            # 2) Read the user from Graph with all required select properties
            $u = $null
            try {
                $select = ($SelectProps.ToArray() -join ',')
                $u = Get-MgUser -UserId $entraId -Property $select
            }
            catch {
                foreach ($m in $ParsedMappings) {
                    $Log.Add([PSCustomObject]@{
                            Timestamp             = (Get-Date)
                            RecipientIdentity     = $recipientIdentity
                            PrimarySmtpAddress    = $recipientUpn
                            RecipientTypeDetails  = $recipientType
                            EntraObjectId         = $entraId
                            SourceKey             = $m.SourceKey
                            SourceType            = $m.SourceType
                            TargetCustomAttribute = "CustomAttribute$($m.Target)"
                            ExistingTargetValue   = $r.("CustomAttribute$($m.Target)")
                            NewTargetValue        = $null
                            Action                = 'Read failed'
                            Status                = 'Error'
                            Error                 = "Graph read failed: $($_.Exception.Message)"
                        })
                }
                continue
            }

            # 3) Evaluate all mappings for this user and stage EXO changes
            $changes = @{}   # will hold properties for Set-EXOMailbox
            $anyChange = $false

            foreach ($m in $ParsedMappings) {
                $targetName = "CustomAttribute$($m.Target)"
                $existing = $r.$targetName
                $sourceVal = $null

                try {
                    switch ($m.SourceType) {
                        'BuiltIn' {
                            if ($u.PSObject.Properties.Match($m.Property).Count -gt 0) {
                                $sourceVal = $u.$m.Property
                            }
                            else {
                                $sourceVal = $u.AdditionalProperties[$m.Property]
                            }
                        }
                        'SchemaExtension' {
                            $sourceVal = $u.AdditionalProperties[$m.Property]
                        }
                        'CustomSecurityAttribute' {
                            $csa = $u.CustomSecurityAttributes
                            if ($csa -and $csa.ContainsKey($m.CsaSet)) {
                                $set = $csa[$m.CsaSet]
                                if ($set -and $set.ContainsKey($m.CsaAttr)) {
                                    $sourceVal = $set[$m.CsaAttr]
                                }
                            }
                        }
                    }
                }
                catch {
                    $Log.Add([PSCustomObject]@{
                            Timestamp             = (Get-Date)
                            RecipientIdentity     = $recipientIdentity
                            PrimarySmtpAddress    = $recipientUpn
                            RecipientTypeDetails  = $recipientType
                            EntraObjectId         = $entraId
                            SourceKey             = $m.SourceKey
                            SourceType            = $m.SourceType
                            TargetCustomAttribute = $targetName
                            ExistingTargetValue   = $existing
                            NewTargetValue        = $null
                            Action                = 'Eval failed'
                            Status                = 'Error'
                            Error                 = "Mapping evaluation failed: $($_.Exception.Message)"
                        })
                    continue
                }

                # Normalize to string if needed
                if ($null -ne $sourceVal) {
                    if ($sourceVal -is [System.Collections.IEnumerable] -and -not ($sourceVal -is [string])) {
                        $sourceVal = ($sourceVal | ForEach-Object { $_.ToString() }) -join $Delimiter
                    }
                    else {
                        $sourceVal = [string]$sourceVal
                    }
                }

                $action = 'No change'
                $newValue = $null
                $status = 'Skipped'

                if ([string]::IsNullOrWhiteSpace($sourceVal)) {
                    if ($ClearWhenEmpty -and -not [string]::IsNullOrWhiteSpace($existing)) {
                        $action = "Clear $targetName"
                        $newValue = ""  # clearing with empty string
                        $status = $DryRun ? 'Planned (DryRun)' : 'Updated'
                        $changes[$targetName] = $newValue
                        $anyChange = $true
                    }
                }
                else {
                    if ($existing -ne $sourceVal) {
                        # case-insensitive compare by default
                        $action = "Set $targetName"
                        $newValue = $sourceVal
                        $status = $DryRun ? 'Planned (DryRun)' : 'Updated'
                        $changes[$targetName] = $newValue
                        $anyChange = $true
                    }
                    else {
                        $action = 'Already up to date'
                        $status = 'Skipped'
                    }
                }

                # Log per-mapping outcome
                $Log.Add([PSCustomObject]@{
                        Timestamp             = (Get-Date)
                        RecipientIdentity     = $recipientIdentity
                        PrimarySmtpAddress    = $recipientUpn
                        RecipientTypeDetails  = $recipientType
                        EntraObjectId         = $entraId
                        SourceKey             = $m.SourceKey
                        SourceType            = $m.SourceType
                        TargetCustomAttribute = $targetName
                        ExistingTargetValue   = $existing
                        NewTargetValue        = $newValue
                        Action                = $action
                        Status                = $status
                        Error                 = $null
                    })
            }

            # 4) Apply staged changes once per mailbox
            if ($anyChange -and -not $DryRun) {
                try {
                    $splat = @{ Identity = $recipientIdentity }
                    foreach ($k in $changes.Keys) { $splat[$k] = $changes[$k] }
                    Set-EXOMailbox @splat | Out-Null
                }
                catch {
                    # Update the previously added log entries for this recipient to "Error" if they were marked Updated/Planned
                    foreach ($entry in $Log | Where-Object { $_.RecipientIdentity -eq $recipientIdentity -and $_.Status -eq 'Updated' }) {
                        $entry.Status = 'Error'
                        $entry.Error = "EXO write failed: $($_.Exception.Message)"
                    }
                }
            }
        }

        # 5) Write log
        $Log | Export-Csv -Path $LogPath -NoTypeInformation -Encoding UTF8
        Write-Host "Done. Log saved to: $LogPath" -ForegroundColor Green
    }
    finally {
        Write-Progress -Activity "Syncing attributes..." -Completed
    }
}

end {
    try { Disconnect-ExchangeOnline -Confirm:$false | Out-Null } catch {}
    try { Disconnect-MgGraph | Out-Null } catch {}
}
