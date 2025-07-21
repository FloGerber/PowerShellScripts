# Check for Azure Policy assignments
function Check-AzurePolicyAssignment {
    try {
        # Grab all assignments
        $assignments = Get-AzPolicyAssignment

        # Filter by well-known initiatives or tags
        $securityPolicies = $assignments | Where-Object {
            $_.Properties.DisplayName -match 'Security' -or
            $_.Properties.DisplayName -match 'Benchmark' -or
            $_.Properties.Description -match 'CIS|NIST|ISO|SOC'
        }

        return [PSCustomObject]@{
            Result  = ($securityPolicies.Count -gt 0)
            Details = $securityPolicies
        }
    } catch {
        return [PSCustomObject]@{
            Result = $false
            Details = "Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-AzurePolicyAssignment