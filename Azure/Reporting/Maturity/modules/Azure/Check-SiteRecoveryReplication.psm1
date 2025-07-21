# Check if Site Recovery Vaults exist for RPO (Recovery Point Objective)/RTO (Recovery Time Objective) definition
function Check-SiteRecoveryReplication {
    try {
        $vaults = Get-AzRecoveryServicesVault
        $replicatedItems = @()

        foreach ($vault in $vaults) {
            $items = Get-AzRecoveryServicesReplicationProtectedItem -VaultId $vault.Id
            if ($items.Count -gt 0) {
                $replicatedItems += $items
            }
        }

        return [PSCustomObject]@{
            Result  = ($replicatedItems.Count -gt 0)
            Details = $replicatedItems
        }
    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Details = "Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-SiteRecoveryReplication