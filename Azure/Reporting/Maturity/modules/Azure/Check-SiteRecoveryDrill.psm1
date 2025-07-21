# Check for successful failover test drills
function Check-SiteRecoveryDrill {
    try {
        $vaults = Get-AzRecoveryServicesVault
        $recentTestJobs = @()

        foreach ($vault in $vaults) {
            Set-AzRecoveryServicesVaultContext -Vault $vault

            $jobs = Get-AzRecoveryServicesJob | Where-Object {
                $_.ActivityName -like '*TestFailover*' -and
                $_.Status -eq 'Completed' -and
                $_.StartTime -gt (Get-Date).AddMonths(-6)
            }

            if ($jobs.Count -gt 0) {
                $recentTestJobs += $jobs | ForEach-Object {
                    [PSCustomObject]@{
                        VaultName   = $vault.Name
                        JobName     = $_.Name
                        Activity    = $_.ActivityName
                        CompletedOn = $_.EndTime
                    }
                }
            }
        }

        return [PSCustomObject]@{
            Result  = ($recentTestJobs.Count -gt 0)
            Details = $recentTestJobs
        }

    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Details = "❌ Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-SiteRecoveryDrill