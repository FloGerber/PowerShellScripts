# TODO: To fully check we would need to also evaluate the tags of resources.
# Check for IaC deployments
function Check-InfrastructureAsCodeAudit {
    try {
        $deployments = Get-AzDeployment
        $iacDeployments = @()

        foreach ($dep in $deployments) {
            if ($dep.Template -ne $null -or $dep.TemplateLink -ne $null) {
                $iacDeployments += [PSCustomObject]@{
                    DeploymentName    = $dep.DeploymentName
                    Location          = $dep.Location
                    Timestamp         = $dep.Timestamp
                    Mode              = $dep.Mode
                    TemplateSource    = if ($dep.TemplateLink) { "Linked" } else { "Inline" }
                    ProvisioningState = $dep.ProvisioningState
                }
            }
        }

        return [PSCustomObject]@{
            Result = ($iacDeployments.Count -gt 0)
            Summary = @{
                TotalDeployments       = $deployments.Count
                IaCDeploymentsDetected = $iacDeployments.Count
            }
            Details = $iacDeployments
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Failed to audit infrastructure-as-code deployments"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-InfrastructureAsCodeAudit