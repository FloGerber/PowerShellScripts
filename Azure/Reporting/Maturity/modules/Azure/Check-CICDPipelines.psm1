# Check if Deployments are done via AzureDevops, overwrite if using for example github or gitlab
function Check-CICDPipelines {
    try {
        # Requires Az.DevOps module
        $projects = Get-AzDevOpsProject
        $pipelines = @()

        foreach ($proj in $projects) {
            $pl = Get-AzDevOpsPipeline -ProjectName $proj.Name
            $pipelines += $pl
        }

        return [PSCustomObject]@{
            Result  = ($pipelines.Count -gt 0)
            Details = $pipelines
        }
    } catch {
        return [PSCustomObject]@{
            Result = $false
            Details = "Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-CICDPipelines