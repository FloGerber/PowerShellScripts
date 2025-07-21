# Check if configuration drift detection policies or reports are available
function Check-ConfigDriftDetectionAudit {
    try {
        $nonCompliantStates = Get-AzPolicyState | Where-Object {
            $_.ComplianceState -eq "NonCompliant"
        }

        $automationAccounts = Get-AzAutomationAccount
        $dsConfigs = @()

        foreach ($account in $automationAccounts) {
            $configs = Get-AzAutomationDscConfiguration `
                -AutomationAccountName $account.AutomationAccountName `
                -ResourceGroupName $account.ResourceGroupName

            foreach ($cfg in $configs) {
                $dsConfigs += [PSCustomObject]@{
                    Name              = $cfg.Name
                    State             = $cfg.State
                    AutomationAccount = $account.AutomationAccountName
                    ResourceGroup     = $account.ResourceGroupName
                    CreatedTime       = $cfg.CreationTime
                }
            }
        }

        $driftSummary = $nonCompliantStates | Select-Object PolicyAssignmentName, ResourceId, ComplianceState, Timestamp

        return [PSCustomObject]@{
            Result = ($nonCompliantStates.Count -eq 0 -and $dsConfigs.Count -gt 0)
            Summary = @{
                NonCompliantPolicies = $nonCompliantStates.Count
                DSCConfigurations    = $dsConfigs.Count
                AutomationAccounts   = $automationAccounts.Count
            }
            Details = @{
                DriftDetected        = $driftSummary
                DesiredStateConfigs  = $dsConfigs
            }
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Could not assess config drift"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-ConfigDriftDetectionAudit