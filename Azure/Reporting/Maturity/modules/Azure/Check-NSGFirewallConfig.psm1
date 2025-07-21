# Check whether any NSGs and Firewall are deployed
function Check-NSGFirewallConfig {
    try {
        $unprotectedSubnets = @()

        $nsgs = Get-AzNetworkSecurityGroup
        $firewalls = Get-AzFirewall
        $vnets = Get-AzVirtualNetwork

        foreach ($vnet in $vnets) {
            foreach ($subnet in $vnet.Subnets) {
                $hasNSG = ($subnet.NetworkSecurityGroup -ne $null)
                if (-not $hasNSG) {
                    $unprotectedSubnets += $subnet
                }
            }
        }

        $firewallPresent = ($firewalls.Count -gt 0)

        return [PSCustomObject]@{
            Result  = ($unprotectedSubnets.Count -eq 0 -and $firewallPresent)
            Details = @{
                MissingNSGs = $unprotectedSubnets
                AzureFirewallConfigured = $firewalls
            }
        }
    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Details = "Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-NSGFirewallConfig