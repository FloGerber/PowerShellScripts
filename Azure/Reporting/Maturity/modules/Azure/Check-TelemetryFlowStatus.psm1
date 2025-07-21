# Check if telemetry is centralized via Log Analytics workspaces
function Check-TelemetryFlowStatus {
    try {
        # Detect resources with diagnostics capability
        $providers = Get-AzResourceProvider
        $diagnosticCapableTypes = $providers.ResourceTypes | Where-Object {
            $_.Locations -and $_.ApiVersions -and $_.ResourceType -match "/virtualMachines$|/sites$|/servers$|/vaults$|/storageAccounts$|/managedClusters$|/networkWatchers$"
        } | ForEach-Object { "$($_.ProviderNamespace)/$($_.ResourceType)" }

        $resources = Get-AzResource | Where-Object { $diagnosticCapableTypes -contains $_.Type }

        $telemetryCovered = @()
        $telemetryMissing = @()

        foreach ($res in $resources) {
            try {
                $diag = Get-AzDiagnosticSetting -ResourceId $res.ResourceId
                $logsFlowing = $diag.Logs | Where-Object { $_.Enabled -eq $true }
                $metricsFlowing = $diag.Metrics | Where-Object { $_.Enabled -eq $true }

                if ($diag.WorkspaceId -and ($logsFlowing.Count -gt 0 -or $metricsFlowing.Count -gt 0)) {
                    $telemetryCovered += [PSCustomObject]@{
                        ResourceName  = $res.Name
                        ResourceType  = $res.Type
                        LogsEnabled   = $logsFlowing.Count
                        MetricsEnabled= $metricsFlowing.Count
                        WorkspaceId   = $diag.WorkspaceId
                    }
                } else {
                    $telemetryMissing += [PSCustomObject]@{
                        ResourceName  = $res.Name
                        ResourceType  = $res.Type
                        Reason        = "Diagnostic setting exists but not actively sending logs or metrics"
                    }
                }
            } catch {
                # Resource has no diagnostic setting at all
                $telemetryMissing += [PSCustomObject]@{
                    ResourceName  = $res.Name
                    ResourceType  = $res.Type
                    Reason        = "No diagnostic setting configured"
                }
            }
        }

        return [PSCustomObject]@{
            Result = ($telemetryCovered.Count -gt 0)
            Summary = @{
                ResourcesScanned        = $resources.Count
                ActiveTelemetrySources  = $telemetryCovered.Count
                MissingTelemetrySources = $telemetryMissing.Count
            }
            Details = @{
                TelemetryActive   = $telemetryCovered
                TelemetryMissing  = $telemetryMissing
            }
        }

    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Summary = "🚨 Telemetry flow check failed"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-TelemetryFlowStatus