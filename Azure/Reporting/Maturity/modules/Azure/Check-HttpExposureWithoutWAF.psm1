# Check for Public exposed HTTP workloads
function Check-HttpExposureWithoutWAF {
    try {
        $httpRisks = @()

        # App Services without HTTPS-only enforcement
        $apps = Get-AzWebApp
        foreach ($app in $apps) {
            if (-not $app.SiteConfig.HttpsOnly) {
                $httpRisks += @{
                    Type     = "AppService"
                    Name     = $app.Name
                    Location = $app.Location
                    Note     = "HTTPS not enforced"
                }
            }
        }

        # NSG Rules exposing port 80
        $nsgs = Get-AzNetworkSecurityGroup
        foreach ($nsg in $nsgs) {
            foreach ($rule in $nsg.SecurityRules) {
                if ($rule.Access -eq "Allow" -and $rule.Direction -eq "Inbound" -and
                    $rule.DestinationPortRange -eq "80" -and $rule.SourceAddressPrefix -eq "0.0.0.0/0") {

                    $httpRisks += @{
                        Type     = "NSG"
                        Name     = $nsg.Name
                        Location = $nsg.Location
                        Note     = "Port 80 open to public"
                    }
                }
            }
        }

        # App Gateways routing HTTP without WAF
        $gateways = Get-AzApplicationGateway
        foreach ($gw in $gateways) {
            if (-not $gw.WebApplicationFirewallConfiguration.Enabled) {
                $httpRisks += @{
                    Type     = "AppGateway"
                    Name     = $gw.Name
                    Location = $gw.Location
                    Note     = "No WAF protection"
                }
            }
        }

        return [PSCustomObject]@{
            Result  = ($httpRisks.Count -eq 0)
            Details = $httpRisks
        }
    } catch {
        return [PSCustomObject]@{
            Result = $false
            Details = "Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-HttpExposureWithoutWAF