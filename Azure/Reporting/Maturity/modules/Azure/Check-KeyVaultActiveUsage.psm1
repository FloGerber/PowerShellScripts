# Check if any Azure Key Vaults are deployed
function Check-KeyVaultActiveUsage {
    try {
        $vaults = Get-AzKeyVault
        $activeVaults = @()

        foreach ($vault in $vaults) {
            $secrets = Get-AzKeyVaultSecret -VaultName $vault.VaultName
            $certs   = Get-AzKeyVaultCertificate -VaultName $vault.VaultName
            $keys    = Get-AzKeyVaultKey -VaultName $vault.VaultName

            if (($secrets.Count + $certs.Count + $keys.Count) -gt 0) {
                $activeVaults += $vault
            }
        }

        return [PSCustomObject]@{
            Result  = ($activeVaults.Count -gt 0)
            Details = @{
                UsedVaults  = $activeVaults
                AllVaults   = $vaults
            }
        }
    } catch {
        return [PSCustomObject]@{
            Result = $false
            Details = "Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-KeyVaultActiveUsage