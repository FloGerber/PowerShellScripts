# Check if autoscale settings are configured for resource optimization
function Check-AutoscaleSettings {
    try {
        $profiles = Get-AzAutoscaleSetting
        $validProfiles = $profiles | Where-Object {
            $_.Profiles.Count -gt 0 -and $_.TargetResourceUri
        }

        $details = @()

        foreach ($p in $validProfiles) {
            foreach ($profile in $p.Profiles) {
                foreach ($rule in $profile.Rules) {
                    $details += [PSCustomObject]@{
                        AutoscaleName   = $p.Name
                        TargetResource  = $p.TargetResourceUri
                        Direction       = $rule.ScaleAction.Direction
                        CoolDown        = $rule.ScaleAction.Cooldown
                        MetricTrigger   = $rule.MetricTrigger.MetricName
                        Operator        = $rule.MetricTrigger.Operator
                        Threshold       = $rule.MetricTrigger.Threshold
                        Enabled         = $p.Enabled
                    }
                }
            }
        }

        return [PSCustomObject]@{
            Result  = ($details.Count -gt 0)
            Summary = @{
                TotalSettingsScanned    = $profiles.Count
                ValidAutoscaleSettings  = $validProfiles.Count
                ScalingRulesFound       = $details.Count
            }
            Details = $details
        }

    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Details = "🚨 Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-AutoscaleSettings