# Check if Redis or CDN caches are deployed
function Check-CachingStrategyAudit {
    try {
        $redisCaches = @()
        $cdnProfiles = @()
        $frontDoors  = @()

        # --- Redis ---
        try {
            $redis = Get-AzRedisCache
            foreach ($r in $redis) {
                $redisCaches += [PSCustomObject]@{
                    Type     = "Redis"
                    Name     = $r.Name
                    Location = $r.Location
                    Sku      = $r.Sku.Name
                }
            }
        } catch {}

        # --- CDN ---
        try {
            $cdn = Get-AzCdnProfile | Where-Object { $_.Sku.Name -match "Standard|Premium" }
            foreach ($c in $cdn) {
                $cdnProfiles += [PSCustomObject]@{
                    Type     = "CDN"
                    Name     = $c.Name
                    Location = $c.Location
                    Sku      = $c.Sku.Name
                }
            }
        } catch {}

        # --- Front Door ---
        try {
            $fd = Get-AzFrontDoor
            foreach ($f in $fd) {
                foreach ($rule in $f.Properties.RoutingRules) {
                    if ($rule.CacheConfiguration.QueryStringCachingBehavior -ne "IgnoreQueryString") {
                        $frontDoors += [PSCustomObject]@{
                            Type     = "FrontDoor"
                            Name     = $f.Name
                            Location = $f.Location
                            RuleName = $rule.Name
                            Caching  = $rule.CacheConfiguration.QueryStringCachingBehavior
                        }
                    }
                }
            }
        } catch {}

        $cachingLayers = $redisCaches + $cdnProfiles + $frontDoors

        return [PSCustomObject]@{
            Result = ($cachingLayers.Count -gt 0)
            Summary = @{
                RedisCaches   = $redisCaches.Count
                CDNProfiles   = $cdnProfiles.Count
                FrontDoorRules= $frontDoors.Count
            }
            Details = $cachingLayers
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Failed to evaluate caching strategy"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-CachingStrategyAudit