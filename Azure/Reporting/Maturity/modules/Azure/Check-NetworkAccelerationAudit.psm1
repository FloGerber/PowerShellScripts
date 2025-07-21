# Check if Front Door or CDN acceleration is configured
function Check-NetworkAccelerationAudit {
    try {
        $cdnAccelerators = @()
        $frontDoorAccelerators = @()

        # --- CDN Profiles ---
        try {
            $cdnProfiles = Get-AzCdnProfile | Where-Object { $_.Sku.Name -match "Standard|Premium" }
            foreach ($cdn in $cdnProfiles) {
                $cdnAccelerators += [PSCustomObject]@{
                    Type     = "CDN"
                    Name     = $cdn.Name
                    Location = $cdn.Location
                    Sku      = $cdn.Sku.Name
                }
            }
        } catch {}

        # --- Front Door Rules ---
        try {
            $frontDoors = Get-AzFrontDoor
            foreach ($fd in $frontDoors) {
                foreach ($rule in $fd.Properties.RoutingRules) {
                    if ($rule.CacheConfiguration -and $rule.CacheConfiguration.QueryStringCachingBehavior -ne "IgnoreQueryString") {
                        $frontDoorAccelerators += [PSCustomObject]@{
                            Type         = "FrontDoor"
                            Name         = $fd.Name
                            RuleName     = $rule.Name
                            Location     = $fd.Location
                            CachingStyle = $rule.CacheConfiguration.QueryStringCachingBehavior
                        }
                    }
                }
            }
        } catch {}

        $totalAccelerators = $cdnAccelerators + $frontDoorAccelerators

        return [PSCustomObject]@{
            Result = ($totalAccelerators.Count -gt 0)
            Summary = @{
                CDNProfilesFound      = $cdnAccelerators.Count
                FrontDoorRulesMatched = $frontDoorAccelerators.Count
            }
            Details = $totalAccelerators
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Failed to evaluate network acceleration"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-NetworkAccelerationAudit