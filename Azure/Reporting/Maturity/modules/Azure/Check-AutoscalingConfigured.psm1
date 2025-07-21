# Check if autoscaling is configured for workloads
function Check-AutoscalingConfigured {
    try {
        $settings = Get-AzAutoscaleSetting
        $demandBased = @()

        foreach ($setting in $settings) {
            foreach ($profile in $setting.Profiles) {
                foreach ($rule in $profile.Rules) {
                    if ($rule.MetricTrigger.MetricName -match "Cpu|Memory") {
                        $demandBased += [PSCustomObject]@{
                            TargetResourceId = $setting.TargetResourceId
                            AutoscaleSetting = $setting.Name
                            ProfileName      = $profile.Name
                            MetricName       = $rule.MetricTrigger.MetricName
                            Direction        = $rule.ScaleAction.Direction
                            Cooldown         = $rule.ScaleAction.Cooldown
                        }
                    }
                }
            }
        }

        return [PSCustomObject]@{
            Result  = ($demandBased.Count -gt 0)
            Summary = @{
                AutoscaleSettingsScanned = $settings.Count
                DemandBasedProfiles      = $demandBased.Count
            }
            Details = $demandBased
        }

    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Summary = "🚨 Failed to check autoscaling configuration"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-AutoscalingConfigured