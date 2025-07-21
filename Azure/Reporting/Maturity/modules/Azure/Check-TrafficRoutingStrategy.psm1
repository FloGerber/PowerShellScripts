# Check if Traffic Manager profiles exist for geo-distribution
function Check-TrafficRoutingStrategy {
    try {
        $frontDoors     = Get-AzFrontDoor
        $trafficProfiles = Get-AzTrafficManagerProfile

        $routingInsights = @()

        foreach ($fd in $frontDoors) {
            $routingInsights += [PSCustomObject]@{
                Type           = "FrontDoor"
                Name           = $fd.Name
                ResourceGroup  = $fd.ResourceGroupName
                RoutingMethod  = "Performance or Latency-based"
                EndpointCount  = $fd.FrontendEndpoints.Count
            }
        }

        foreach ($tm in $trafficProfiles) {
            $routingInsights += [PSCustomObject]@{
                Type           = "TrafficManager"
                Name           = $tm.Name
                ResourceGroup  = $tm.ResourceGroupName
                RoutingMethod  = $tm.TrafficRoutingMethod
                EndpointCount  = $tm.Endpoints.Count
            }
        }

        $totalRouting = $frontDoors.Count + $trafficProfiles.Count

        return [PSCustomObject]@{
            Result  = ($routingInsights.Count -gt 0)
            Summary = @{
                TotalProfilesChecked    = $totalRouting
                ProfilesWithRouting     = $routingInsights.Count
                FrontDoorProfiles       = $frontDoors.Count
                TrafficManagerProfiles  = $trafficProfiles.Count
            }
            Details = $routingInsights
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Details = "🚨 Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-TrafficRoutingStrategy