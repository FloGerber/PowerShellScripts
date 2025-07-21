# Check if Spot VMs are deployed for interruptible workloads
function Check-SpotVMsUsage {
    try {
        $spotVMs = Get-AzVM | Where-Object {
            $_.Priority -eq "Spot" -and $_.ProvisioningState -eq "Succeeded"
        }

        $devIndicators = @("dev", "test", "qa", "lab", "sandbox", "staging")

        $nonCriticalVMs = @()
        foreach ($vm in $spotVMs) {
            $tags = $vm.Tags
            $name = $vm.Name.ToLower()

            $isTaggedNonCritical = $tags.Values -contains "Dev" -or
                                   $tags.Values -contains "Test" -or
                                   $tags.Values -contains "Low"

            $isNamedNonCritical = $devIndicators | Where-Object { $name -like "*$_*" }

            if ($isTaggedNonCritical -or $isNamedNonCritical.Count -gt 0) {
                $nonCriticalVMs += $vm
            }
        }

        return [PSCustomObject]@{
            Result = ($nonCriticalVMs.Count -gt 0)
            Summary = @{
                SpotVMsTotal         = $spotVMs.Count
                SpotNonCriticalVMs   = $nonCriticalVMs.Count
            }
            Details = $nonCriticalVMs | Select-Object Name, ResourceGroupName, Location, Tags
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Could not complete Spot VM check."
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-SpotVMsUsage