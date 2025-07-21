# Check for existing metric alert rules (Azure Monitor)
function Check-MetricAlerts {
    try {
        $alerts = Get-AzMetricAlertRuleV2
        $appInsights = Get-AzApplicationInsights

        $monitoring = $alerts + $appInsights

        return [PSCustomObject]@{
            Result  = ($monitoring.Count -gt 0)
            Details = $monitoring
        }
    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Details = "Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-MetricAlerts