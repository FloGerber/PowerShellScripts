# Check if Microsoft Defender for Cloud is enabled
function Check-DefenderEnabled {
    try {
        $defenderPlans = Get-AzSecurityPricing | Where-Object {
            $_.PricingTier -eq 'Standard'
        }

        return [PSCustomObject]@{
            Result  = ($defenderPlans.Count -gt 0)
            Details = $defenderPlans
        }
    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Details = "Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-DefenderEnabled