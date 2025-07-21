# Check if automation runbooks exist for incident response
function Check-IncidentRunbooksAudit {
    try {
        $automationAccounts = Get-AzAutomationAccount
        $incidentRunbooks = @()
        $draftRunbooks = @()

        foreach ($account in $automationAccounts) {
            $runbooks = Get-AzAutomationRunbook `
                -AutomationAccountName $account.AutomationAccountName `
                -ResourceGroupName $account.ResourceGroupName

            foreach ($rb in $runbooks) {
                $isIncidentRunbook = $rb.Name -match "incident|remediate|alert"

                if ($isIncidentRunbook) {
                    $record = [PSCustomObject]@{
                        Name              = $rb.Name
                        State             = $rb.State
                        Type              = $rb.RunbookType
                        LastModifiedDate  = $rb.LastModifiedDate
                        ResourceGroup     = $account.ResourceGroupName
                        AutomationAccount = $account.AutomationAccountName
                    }

                    if ($rb.State -eq "Published") {
                        $incidentRunbooks += $record
                    } else {
                        $draftRunbooks += $record
                    }
                }
            }
        }

        return [PSCustomObject]@{
            Result = ($incidentRunbooks.Count -gt 0)
            Summary = @{
                AutomationAccountsScanned = $automationAccounts.Count
                IncidentRunbooksPublished = $incidentRunbooks.Count
                DraftIncidentRunbooks     = $draftRunbooks.Count
            }
            Details = @{
                PublishedRunbooks = $incidentRunbooks
                DraftRunbooks     = $draftRunbooks
            }
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Failed to audit incident runbooks"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-IncidentRunbooksAudit