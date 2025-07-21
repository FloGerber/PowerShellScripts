# Check if App Services use auto-heal for self-recovery
function Check-WorkloadAutoRecovery {
    try {
        $resilientWorkloads = @()
        $unprotectedWorkloads = @()

        # --- App Services ---
        $apps = Get-AzWebApp
        foreach ($app in $apps) {
            $config = $app.SiteConfig
            if ($config.AutoHealEnabled -and $config.AutoHealRules -ne $null -and $config.AutoHealRules.Triggers.Count -gt 0) {
                $resilientWorkloads += [PSCustomObject]@{
                    ResourceType   = "AppService"
                    ResourceName   = $app.Name
                    FallbackAction = "Auto-Heal (Triggers: Restart, Slow Response, etc.)"
                }
            } else {
                $unprotectedWorkloads += [PSCustomObject]@{
                    ResourceType   = "AppService"
                    ResourceName   = $app.Name
                    FallbackStatus = if ($config.AutoHealEnabled) { "Enabled but no triggers" } else { "Disabled" }
                }
            }
        }

        # --- Virtual Machines ---
        $vms = Get-AzVM
        foreach ($vm in $vms) {
            $hasRecovery = ($vm.AvailabilitySet -ne $null -or $vm.VirtualMachineScaleSetId -ne $null)

            if ($hasRecovery) {
                $resilientWorkloads += [PSCustomObject]@{
                    ResourceType   = "VirtualMachine"
                    ResourceName   = $vm.Name
                    FallbackAction = "Automatic Repair via Availability Set / Scale Set"
                }
            } else {
                $unprotectedWorkloads += [PSCustomObject]@{
                    ResourceType   = "VirtualMachine"
                    ResourceName   = $vm.Name
                    FallbackStatus = "Standalone VM (no auto-recovery)"
                }
            }
        }

        # --- Final Output ---
        return [PSCustomObject]@{
            Result = ($resilientWorkloads.Count -gt 0)
            Summary = @{
                TotalAppServices        = $apps.Count
                TotalVMs                = $vms.Count
                WorkloadsWithFallback   = $resilientWorkloads.Count
                WorkloadsWithoutRecovery = $unprotectedWorkloads.Count
            }
            Details = @{
                ProtectedWorkloads   = $resilientWorkloads
                UnprotectedWorkloads = $unprotectedWorkloads
            }
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Details = "🚨 Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-WorkloadAutoRecovery