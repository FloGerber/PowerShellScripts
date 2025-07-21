# Check for usage of Azure Functions (serverless footprint)
function Check-ServerlessFunctionAppUsage {
    try {
        $functionApps = Get-AzFunctionApp
        $consumptionApps = @()

        foreach ($app in $functionApps) {
            $appConfig = Get-AzFunctionApp -ResourceGroupName $app.ResourceGroupName -Name $app.Name
            if ($appConfig.Sku -eq "Dynamic") {
                $consumptionApps += $appConfig
            }
        }

        return [PSCustomObject]@{
            Result  = ($consumptionApps.Count -gt 0)
            Summary = @{
                TotalFunctionApps      = $functionApps.Count
                ConsumptionBasedApps   = $consumptionApps.Count
            }
            Details = $consumptionApps | Select-Object Name, Location, Sku, ResourceGroupName
        }

    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Summary = "🚨 Could not retrieve Function App data."
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-ServerlessFunctionAppUsage