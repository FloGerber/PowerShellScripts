# Check if DDoS Protection Plans are configured
function Check-DDoSProtectionPlan {
    try {
        $plans = Get-AzDdosProtectionPlan
        $vnets = Get-AzVirtualNetwork | Where-Object {
            $_.DdosProtectionPlan -ne $null
        }

        return [PSCustomObject]@{
            Result  = ($vnets.Count -gt 0)
            Details = @{
                ProtectionPlans = $plans
                ProtectedVNets  = $vnets
            }
        }
    } catch {
        return [PSCustomObject]@{
            Result = $false
            Details = "Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-DDoSProtectionPlan