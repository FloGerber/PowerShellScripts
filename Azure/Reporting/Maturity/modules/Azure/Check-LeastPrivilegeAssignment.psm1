# Check if high privilede roles are assigned on root, subscription and Management Group level
function Check-LeastPrivilegeAssignment {
    try {
        $roles = Get-AzRoleAssignment
        $broadScopes = $roles | Where-Object {
            $_.RoleDefinitionName -in @('Owner', 'Contributor') -and (
                $_.Scope -eq '/' -or
                $_.Scope -like '/subscriptions/*' -or
                $_.Scope -like '/providers/Microsoft.Management/managementGroups/*'
            )
        }

        return [PSCustomObject]@{
            Result  = ($broadScopes.Count -eq 0)
            Details = $broadScopes
        }
    } catch {
        return [PSCustomObject]@{
            Result = $false
            Details = "Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-LeastPrivilegeAssignment