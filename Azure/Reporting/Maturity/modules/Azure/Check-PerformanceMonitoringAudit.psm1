# Check if diagnostics and telemetry are enabled
function Check-PerformanceMonitoringAudit {
    try {
        $resources = Get-AzResource
        $diagnostics = @()
        $noDiagnostics = @()

        foreach ($res in $resources) {
            try {
                $diag = Get-AzDiagnosticSetting -ResourceId $res.ResourceId -ErrorAction SilentlyContinue

                if ($diag) {
                    $diagnostics += [PSCustomObject]@{
                        ResourceName       = $res.Name
                        ResourceType       = $res.ResourceType
                        Location           = $res.Location
                        DiagnosticsEnabled = $diag.Enabled
                        LogsEnabled        = ($diag.Logs.Count -gt 0)
                        MetricsEnabled     = ($diag.Metrics.Count -gt 0)
                        AppInsightsTarget  = $diag.ApplicationInsightsId
                        LogAnalyticsTarget = $diag.WorkspaceId
                    }
                } else {
                    $noDiagnostics += [PSCustomObject]@{
                        ResourceName = $res.Name
                        ResourceType = $res.ResourceType
                        Location     = $res.Location
                        Reason       = "No diagnostic setting configured"
                    }
                }
            } catch {
                # Could not retrieve diagnostics
                $noDiagnostics += [PSCustomObject]@{
                    ResourceName = $res.Name
                    ResourceType = $res.ResourceType
                    Location     = $res.Location
                    Reason       = "Error retrieving diagnostic setting"
                }
            }
        }

        $appInsights = Get-AzApplicationInsights
        $logWorkspaces = Get-AzOperationalInsightsWorkspace

        return [PSCustomObject]@{
            Result = ($diagnostics.Count -gt 0)
            Summary = @{
                ResourcesScanned       = $resources.Count
                ResourcesWithTelemetry = $diagnostics.Count
                ResourcesWithout       = $noDiagnostics.Count
                AppInsightsFound       = $appInsights.Count
                LogWorkspacesFound     = $logWorkspaces.Count
            }
            Details = @{
                WithDiagnostics    = $diagnostics
                WithoutDiagnostics = $noDiagnostics
                AppInsights        = $appInsights
                LogWorkspaces      = $logWorkspaces
            }
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Failed to audit telemetry wiring"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-PerformanceMonitoringAudit