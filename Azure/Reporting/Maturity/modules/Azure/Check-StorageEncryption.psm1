# Check if all storage accounts enforce HTTPS traffic only and encryption is enabled for storage accounts and Disks
function Check-StorageEncryption {
    try {
        $unencryptedResources = @()

        # Check Storage Accounts
        $storageAccounts = Get-AzStorageAccount
        foreach ($sa in $storageAccounts) {
            if (-not $sa.EnableHttpsTrafficOnly -or -not $sa.Encryption.Services.Blob.Enabled) {
                $unencryptedResources += $sa
            }
        }

        # Check Managed Disks
        $disks = Get-AzDisk | Where-Object { $_.Encryption.Type -eq 'None' }
        if ($disks) { $unencryptedResources += $disks }

        return [PSCustomObject]@{
            Result  = ($unencryptedResources.Count -eq 0)
            Details = $unencryptedResources
        }
    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Details = "Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-StorageEncryption