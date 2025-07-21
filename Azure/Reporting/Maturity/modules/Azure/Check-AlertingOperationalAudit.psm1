# Check if scheduled query rules (alerts) are configured
function Check-AlertingOperationalAudit {
    try {
        $alerts = Get-AzScheduledQueryRule
        $validAlerts = @()
        $flaggedAlerts = @()

        foreach ($alert in $alerts) {
            $isLinked = $alert.ActionGroupId -ne $null
            $isSevere = $alert.Severity -lt 3
            $isEnabled = $alert.Enabled

            $record = [PSCustomObject]@{
                Name           = $alert.Name
                ResourceGroup  = $alert.ResourceGroupName
                Severity       = $alert.Severity
                ActionGroupSet = $isLinked
                Enabled        = $isEnabled
                Description    = $alert.Description
            }

            if ($isLinked -and $isSevere -and $isEnabled) {
                $validAlerts += $record
            } else {
                $flaggedAlerts += $record
            }
        }

        return [PSCustomObject]@{
            Result = ($validAlerts.Count -gt 0)
            Summary = @{
                TotalAlertsScanned  = $alerts.Count
                AlertsReady         = $validAlerts.Count
                AlertsFlagged       = $flaggedAlerts.Count
            }
            Details = @{
                ActiveAlerts   = $validAlerts
                FlaggedAlerts  = $flaggedAlerts
            }
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Failed to evaluate scheduled query alerts"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-AlertingOperationalAudit