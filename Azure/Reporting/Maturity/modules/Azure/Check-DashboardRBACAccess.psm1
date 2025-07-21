# Check if portal dashboards exist and can be RBAC-controlled
function Check-DashboardRBACAccess {
    try {
        $dashboards = $null
        $methodUsed = ""

        # --- Attempt Resource Graph ---
        try {
            $dashboards = Search-AzGraph -Query "Resources | where type == 'microsoft.portal/dashboards' | project name, id, resourceGroup, tags"
            $methodUsed = "Resource Graph"
        } catch {
            # ignore and attempt REST fallback
        }

        # --- Fallback to REST API if Graph fails or returns nothing ---
        if (-not $dashboards -or $dashboards.Count -eq 0) {
            $subId = (Get-AzContext).Subscription.Id
            $token = ConvertFrom-SecureString -SecureString (Get-AzAccessToken -ResourceUrl "https://management.azure.com/").Token -AsPlainText
            $uri = "https://management.azure.com/subscriptions/$subId/resources?api-version=2021-04-01&`$filter=resourceType eq 'Microsoft.Portal/dashboards'"
            $headers = @{ Authorization = "Bearer $token" }

            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
            $dashboards = $response.value
            $methodUsed = "REST API"
        }

        $restrictedDashboards = @()
        $defaultDashboards = @()

        foreach ($db in $dashboards) {
            $id = if ($db.id) { $db.id } else { $db.Id }
            $name = if ($db.name) { $db.name } else { $db.Name }
            $group = if ($db.resourceGroup) { $db.resourceGroup } else { ($id -split "/")[4] }

            try {
                $acl = Get-AzRoleAssignment -Scope $id
                if ($acl.Count -gt 0) {
                    $accessDetails = $acl | Select-Object RoleDefinitionName, PrincipalType, PrincipalName
                    $restrictedDashboards += [PSCustomObject]@{
                        DashboardName = $name
                        ResourceGroup = $group
                        DashboardId   = $id
                        AccessRoles   = $accessDetails
                    }
                } else {
                    $defaultDashboards += [PSCustomObject]@{
                        DashboardName = $name
                        ResourceGroup = $group
                        DashboardId   = $id
                        AccessRoles   = @("No explicit assignments found")
                    }
                }
            } catch {
                $defaultDashboards += [PSCustomObject]@{
                    DashboardName = $name
                    ResourceGroup = $group
                    DashboardId   = $id
                    AccessRoles   = @("Error retrieving role assignments")
                }
            }
        }

        return [PSCustomObject]@{
            Result = ($restrictedDashboards.Count -gt 0)
            MethodUsed = $methodUsed
            Summary = @{
                DashboardsScanned       = $dashboards.Count
                WithCustomRBAC          = $restrictedDashboards.Count
                UsingDefaultPermissions = $defaultDashboards.Count
            }
            Details = @{
                RestrictedDashboards   = $restrictedDashboards
                DefaultScopeDashboards = $defaultDashboards
            }
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Failed to complete dashboard RBAC audit"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-DashboardRBACAccess