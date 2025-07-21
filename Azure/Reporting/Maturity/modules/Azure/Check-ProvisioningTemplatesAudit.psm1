# TODO: To fully check also for terraform deployements we would also have to evaluate Tags and they need to be in place like managedBy = terraform
# Check if template-based resource provisioning exists
function Check-ProvisioningTemplatesAudit {
    try {
        $resourceGroups = Get-AzResourceGroup
        $templateDeployments = @()

        foreach ($rg in $resourceGroups) {
            $deployments = Get-AzResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue

            foreach ($dep in $deployments) {
                if ($dep.TemplateLink -ne $null -or $dep.Template -ne $null) {
                    $templateDeployments += [PSCustomObject]@{
                        ResourceGroup     = $rg.ResourceGroupName
                        DeploymentName    = $dep.DeploymentName
                        Timestamp         = $dep.Timestamp
                        Mode              = $dep.Mode
                        TemplateSource    = if ($dep.TemplateLink) { "Linked" } else { "Inline" }
                        ProvisioningState = $dep.ProvisioningState
                    }
                }
            }
        }

        return [PSCustomObject]@{
            Result = ($templateDeployments.Count -gt 0)
            Summary = @{
                ResourceGroupsScanned     = $resourceGroups.Count
                TemplateBasedDeployments  = $templateDeployments.Count
            }
            Details = $templateDeployments
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Failed to audit template-based provisioning"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-ProvisioningTemplatesAudit