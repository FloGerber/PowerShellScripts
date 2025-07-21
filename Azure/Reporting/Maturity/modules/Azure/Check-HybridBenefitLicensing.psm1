# Check if Hybrid Benefit is applied for eligible workloads
function Check-HybridBenefitLicensing {
    try {
        $vms = Get-AzVM
        $licensedVMs   = @()
        $unlicensedVMs = @()

        foreach ($vm in $vms) {
            $license = $vm.LicenseType
            $osDisk  = $vm.StorageProfile.OSDisk.OsType
            $sku     = $vm.HardwareProfile.VmSize
            $tags    = $vm.Tags

            $isWindowsOrSQL = $osDisk -eq "Windows" -or $sku -match "SQL"
            $hasAHB         = $license -match "Windows_Server|Sql_Server"

            $record = [PSCustomObject]@{
                Name         = $vm.Name
                OS           = $osDisk
                Size         = $sku
                LicenseType  = $license
                ResourceGroup= $vm.ResourceGroupName
                Location     = $vm.Location
                HybridBenefit= $hasAHB
                HasAHBTag    = $tags.ContainsKey("hybridbenefit")
            }

            if ($hasAHB) {
                $licensedVMs += $record
            } elseif ($isWindowsOrSQL) {
                $unlicensedVMs += $record
            }
        }

        return [PSCustomObject]@{
            Result  = $licensedVMs.Count -gt 0
            Summary = @{
                TotalVMsChecked       = $vms.Count
                VMsWithAHB            = $licensedVMs.Count
                PotentiallyUnlicensed = $unlicensedVMs.Count
            }
            Details = @{
                LicensedVMs     = $licensedVMs
                UnlicensedVMs   = $unlicensedVMs
            }
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Failed to check Hybrid Benefit licensing"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-HybridBenefitLicensing