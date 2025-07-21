# Check if usage quotas are actively monitored
function Check-QuotaAlertingConfigured {
    try {
        $quotaAlertRules = Get-AzMetricAlertRuleV2 | Where-Object {
            $_.Criteria.AllOf.Any({
                $_.MetricName -match 'Used.*Quota|Current.*Usage|Percentage.*Used|Limit.*Remaining'
            }) -and $_.Enabled
        }

        $alertsByResource = @()
        foreach ($alert in $quotaAlertRules) {
            $alertsByResource += [PSCustomObject]@{
                AlertName      = $alert.Name
                ResourceGroup  = $alert.ResourceGroupName
                TargetResource = $alert.Scopes[0]
                MetricTracked  = ($alert.Criteria.AllOf | Select-Object -First 1).MetricName
                Threshold      = ($alert.Criteria.AllOf | Select-Object -First 1).Threshold
                Evaluation     = $alert.EvaluationFrequency
                ActionGroup    = ($alert.Actions | Select-Object -First 1).ActionGroupId
            }
        }

        return [PSCustomObject]@{
            Result  = ($alertsByResource.Count -gt 0)
            Summary = @{
                QuotaMetricsMonitored = $alertsByResource.Count
                TotalAlertRulesScanned = (Get-AzMetricAlertRuleV2).Count
            }
            Details = $alertsByResource
        }
    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Details = "🚨 Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-QuotaAlertingConfigured