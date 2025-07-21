# Check if any VMs use Availability Zones
function Check-FallbackCapability {
    try {
        $resilientResources = @()

        # --- Virtual Machines ---
        $vms = Get-AzVM
        $totalVMs = $vms.Count
        foreach ($vm in $vms) {
            $hasHA = ($vm.Zones.Count -gt 0 -or
                      $vm.AvailabilitySet -ne $null -or
                      $vm.VirtualMachineScaleSetId -ne $null)

            if ($hasHA) {
                $resilientResources += [PSCustomObject]@{
                    ResourceType = "VirtualMachine"
                    ResourceName = $vm.Name
                    Fallback     = "Zone or Scale/Set deployment"
                }
            }
        }

        # --- Application Gateways ---
        $appGWs = Get-AzApplicationGateway
        $totalAppGWs = $appGWs.Count
        foreach ($gw in $appGWs) {
            if ($gw.Zones.Count -gt 0) {
                $resilientResources += [PSCustomObject]@{
                    ResourceType = "AppGateway"
                    ResourceName = $gw.Name
                    Fallback     = "Multi-zone deployment"
                }
            }
        }

        # --- AKS Clusters ---
        $aksClusters = Get-AzAksCluster
        $totalAks = $aksClusters.Count
        foreach ($aks in $aksClusters) {
            $multiZonePool = $aks.AgentPoolProfiles | Where-Object {
                $_.AvailabilityZones.Count -gt 1
            }
            if ($multiZonePool.Count -gt 0) {
                $resilientResources += [PSCustomObject]@{
                    ResourceType = "AKS"
                    ResourceName = $aks.Name
                    Fallback     = "Multi-zone node pool"
                }
            }
        }

        # --- SQL Servers ---
        $sqlServers = Get-AzSqlServer
        $totalSql = $sqlServers.Count
        foreach ($sql in $sqlServers) {
            $fallbackEnabled = $sql.Identity.Type -ne $null # Placeholder logic
            if ($fallbackEnabled) {
                $resilientResources += [PSCustomObject]@{
                    ResourceType = "SQLServer"
                    ResourceName = $sql.ServerName
                    Fallback     = "Geo-redundant or zone-aware"
                }
            }
        }

        # --- Storage Accounts ---
        $storageAccounts = Get-AzStorageAccount
        $totalStorage = $storageAccounts.Count
        $resilientStorage = $storageAccounts | Where-Object {
            $_.Sku.Name -match 'GRS|ZRS|GZRS'
        }
        foreach ($sa in $resilientStorage) {
            $resilientResources += [PSCustomObject]@{
                ResourceType = "StorageAccount"
                ResourceName = $sa.StorageAccountName
                Fallback     = "Redundant storage SKU ($($sa.Sku.Name))"
            }
        }

        # --- Summary Output ---
        $totalResources = $totalVMs + $totalAppGWs + $totalAks + $totalSql + $totalStorage

        return [PSCustomObject]@{
            Result  = ($resilientResources.Count -gt 0)
            Summary = @{
                TotalResourcesScanned = $totalResources
                ResourcesWithFallback = $resilientResources.Count
                Breakdown = @{
                    VMs            = $totalVMs
                    AppGateways     = $totalAppGWs
                    AKSClusters     = $totalAks
                    SQLServers      = $totalSql
                    StorageAccounts = $totalStorage
                }
            }
            Details = $resilientResources
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Details = "🚨 Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-FallbackCapability