# Check if resource SKU sizes match workload demands
function Check-SKUAlignmentAudit {
    try {
        $vms = Get-AzVM
        $lowTierSkuFamilyPattern = "^B1s$|^B1ms$|^A[0-2]$|^D1$|^D2$"
        $misalignedVms = @()
        $acceptableBurstables = @()
        $tagNamingIssues = @()

        foreach ($vm in $vms) {
            $vmSizeRaw = $vm.HardwareProfile.VmSize  # e.g. Standard_B1s
            $vmSizeParts = $vmSizeRaw -split "_"
            $skuFamily = if ($vmSizeParts.Count -gt 1) { $vmSizeParts[1] } else { $vmSizeRaw }

            $tags = $vm.Tags

            # --- Retrieve tag values robustly ---
            $envValue = ($tags.GetEnumerator() | Where-Object { $_.Key -match "^(env|environment)$" }).Value
            if (-not $envValue) { $envValue = "unknown" }

            $criticality = ($tags.GetEnumerator() | Where-Object { $_.Key -match "^criticality$" }).Value
            if (-not $criticality) { $criticality = "unknown" }

            # --- Detect tag naming issues ---
            $envKeyActual = ($tags.Keys | Where-Object { $_ -match "^(env|environment)$" })
            if ($envKeyActual.Count -eq 0) {
                $tagNamingIssues += [PSCustomObject]@{
                    VMName = $vm.Name
                    Issue  = "Missing environment tag (env/environment)"
                }
            } elseif ($envKeyActual[0] -ne "env") {
                $tagNamingIssues += [PSCustomObject]@{
                    VMName = $vm.Name
                    Issue  = "Environment tag uses '$($envKeyActual[0])' instead of 'env'"
                }
            }

            # --- Evaluate alignment ---
            $isBurstable = ($skuFamily -match "^B.*")
            $matchesLowTier = ($skuFamily -match $lowTierSkuFamilyPattern)

            if ($matchesLowTier -or $isBurstable) {
                $contextOk = (
                    $isBurstable -and
                    ($envValue -match "dev|test|staging") -and
                    ($criticality -match "low|medium")
                )

                $record = [PSCustomObject]@{
                    VMName        = $vm.Name
                    Location      = $vm.Location
                    VmSize        = $vmSizeRaw
                    SkuFamily     = $skuFamily
                    ResourceGroup = $vm.ResourceGroupName
                    OS            = $vm.StorageProfile.OsDisk.OsType
                    Environment   = $envValue
                    Criticality   = $criticality
                    Justified     = $contextOk
                }

                if ($contextOk) {
                    $acceptableBurstables += $record
                } else {
                    $misalignedVms += $record
                }
            }
        }

        return [PSCustomObject]@{
            Result = ($misalignedVms.Count -eq 0)
            Summary = @{
                TotalVMsScanned        = $vms.Count
                MisalignedSKUs         = $misalignedVms.Count
                AcceptableBurstables   = $acceptableBurstables.Count
                TagNamingIssuesFound   = $tagNamingIssues.Count
            }
            Details = @{
                Misaligned       = $misalignedVms
                Acceptable       = $acceptableBurstables
                TagIssues        = $tagNamingIssues
            }
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Failed to assess VM SKU alignment"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-SKUAlignmentAudit