# Check if cost forecasting or budget tools are configured
function Check-CostManagerUsage {
    try {
        # Try Azure Resource Graph first
        $budgets = Search-AzGraph -Query "Resources | where type =~ 'microsoft.costmanagement/budgets'"
        $budgetCount = if ($budgets) { $budgets.Count } else { 0 }

        if ($budgetCount -gt 0) {
            return [PSCustomObject]@{
                Result      = $true
                MethodUsed  = "ResourceGraph"
                Summary     = "✅ Budgets found using Resource Graph."
                BudgetCount = $budgetCount
                Details     = $budgets | Select-Object name, location, properties.amount, properties.timePeriod
            }
        } else {
            # Fallback: Use REST API directly
            $context = Get-AzContext
            $subId = $context.Subscription.Id
            $accessToken = Get-AzAccessToken -ResourceUrl "https://management.azure.com/"
            $plainToken = ConvertFrom-SecureString -SecureString $accessToken.Token -AsPlainText

            $uri = "https://management.azure.com/subscriptions/$subId/providers/Microsoft.CostManagement/budgets?api-version=2023-03-01"

            $headers = @{ Authorization = "Bearer $plainToken" }
            $restResponse = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

            $restBudgets = $restResponse.value
            $restCount = if ($restBudgets) { $restBudgets.Count } else { 0 }

            return [PSCustomObject]@{
                Result      = ($restCount -gt 0)
                MethodUsed  = "REST API"
                Summary     = if ($restCount -gt 0) {
                    "✅ Budgets found using REST fallback."
                } else {
                    "❌ No budgets found via Graph or REST."
                }
                BudgetCount = $restCount
                Details     = $restBudgets | Select-Object name, location, @{Name="amount"; Expression={ $_.properties.amount } }, @{Name="period"; Expression={ $_.properties.timePeriod } }
            }
        }

    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Summary = "🚨 Budget check failed."
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-CostManagerUsage