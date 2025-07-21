# Check if Azure Tags are used for cost attribution
function Check-AzureTagUsage {
    try {
        $allResources = Get-AzResource
        $taggedResources = @()

        foreach ($res in $allResources) {
            if ($res.Tags.Count -gt 0) {
                $tagInfo = @{
                    ResourceName = $res.Name
                    ResourceType = $res.Type
                    ResourceGroup = $res.ResourceGroupName
                    CostCenterTag = $res.Tags.ContainsKey("costcenter")
                    OwnerTag      = $res.Tags.ContainsKey("owner")
                    EnvironmentTag= $res.Tags.ContainsKey("environment")
                }
                $taggedResources += [PSCustomObject]$tagInfo
            }
        }

        return [PSCustomObject]@{
            Result = ($taggedResources.Count -gt 0)
            Summary = @{
                TotalResourcesScanned = $allResources.Count
                ResourcesWithTags     = $taggedResources.Count
            }
            Details = $taggedResources
        }

    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Summary = "🚨 Failed to check resource tags"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-AzureTagUsage