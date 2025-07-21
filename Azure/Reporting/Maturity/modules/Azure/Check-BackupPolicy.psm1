# Check if backup policies are assigned in Recovery Vaults
function Check-BackupPolicy {
    try {
        $vaults = Get-AzRecoveryServicesVault
        $policies = @()

        foreach ($vault in $vaults) {
            $policy = Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $vault.Id
            $protectedItems = Get-AzRecoveryServicesBackupItem -VaultId $vault.Id

            if ($policy.Count -gt 0 -and $protectedItems.Count -gt 0) {
                $policies += $policy
            }
        }

        return [PSCustomObject]@{
            Result  = ($policies.Count -gt 0)
            Details = $policies
        }
    } catch {
        return [PSCustomObject]@{
            Result = $false
            Details = "Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-BackupPolicy