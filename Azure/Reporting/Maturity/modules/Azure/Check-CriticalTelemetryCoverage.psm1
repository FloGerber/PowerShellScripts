# Check for established performance metrics or baselines
function Check-CriticalTelemetryCoverage {
    try {
        # --- Define blacklist for resource types that don't emit metrics ---
        $resourceTypeBlacklist = @(
            "Microsoft.Resources/deployments",
            "Microsoft.Resources/templateSpecs",
            "Microsoft.DevTestLab/labs",
            "Microsoft.Authorization/policyAssignments",
            "Microsoft.Web/certificates"
        )

        # --- Identify critical resources via tags or naming conventions ---
        $criticalResources = Get-AzResource | Where-Object {
            ($_.Tags["criticality"] -eq "high" -or $_.Name -match "prod|core|critical") -and
            ($resourceTypeBlacklist -notcontains $_.ResourceType)
        }

        $monitored = @()
        $unmonitored = @()

        foreach ($res in $criticalResources) {
            try {
                $metrics = Get-AzMetricDefinition -ResourceId $res.ResourceId -ErrorAction SilentlyContinue
                if ($metrics.Count -gt 0) {
                    $metricNames = $metrics | ForEach-Object { $_.Name.Value }
                    $monitored += [PSCustomObject]@{
                        ResourceName = $res.Name
                        ResourceType = $res.ResourceType
                        Location     = $res.Location
                        MetricsFound = $metricNames
                    }
                } else {
                    $unmonitored += [PSCustomObject]@{
                        ResourceName = $res.Name
                        ResourceType = $res.ResourceType
                        Location     = $res.Location
                        Reason       = "No performance metrics exposed"
                    }
                }
            } catch {
                $unmonitored += [PSCustomObject]@{
                    ResourceName = $res.Name
                    ResourceType = $res.ResourceType
                    Location     = $res.Location
                    Reason       = "Error retrieving metric definitions"
                }
            }
        }

        return [PSCustomObject]@{
            Result = ($unmonitored.Count -eq 0)
            Summary = @{
                CriticalResourcesChecked = $criticalResources.Count
                WithMetrics              = $monitored.Count
                MissingMetrics           = $unmonitored.Count
            }
            Details = @{
                TelemetryEnabled   = $monitored
                TelemetryMissing   = $unmonitored
            }
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Failed to audit critical telemetry coverage"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-CriticalTelemetryCoverage