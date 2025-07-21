# Check if diagnostic settings are configured
function Check-DiagnosticLogging {
    try {
        # 1. Get all Azure resources
        $resources = Get-AzResource

        # 2. Initialize a list for logging gaps
        $missingDiagnostics = @()

        # 3. Scan each resource for diagnostic settings
        foreach ($resource in $resources) {
            $diagSetting = Get-AzDiagnosticSetting -ResourceId $resource.Id -ErrorAction SilentlyContinue

            # 3a. Case: No diagnostic setting exists
            if (-not $diagSetting) {
                $missingDiagnostics += [PSCustomObject]@{
                    ResourceName = $resource.Name
                    ResourceType = $resource.Type
                    ResourceId   = $resource.Id
                    Status       = "❌ Missing"
                    Reason       = "No diagnostic setting found"
                }
                continue
            }

            # 3b. Case: Setting exists but no destination configured
            if (-not $diagSetting.WorkspaceId -and -not $diagSetting.StorageAccountId -and -not $diagSetting.EventHubAuthorizationRuleId) {
                $missingDiagnostics += [PSCustomObject]@{
                    ResourceName = $resource.Name
                    ResourceType = $resource.Type
                    ResourceId   = $resource.Id
                    Status       = "⚠️ Incomplete"
                    Reason       = "Diagnostics configured, but no destination set"
                }
            }
        }

        # 4. Return structured result
        return [PSCustomObject]@{
            Result  = ($missingDiagnostics.Count -eq 0)
            Summary = @{
                TotalResourcesScanned       = $resources.Count
                ResourcesWithIncompleteLogs = $missingDiagnostics.Count
                CompliantResources          = $resources.Count - $missingDiagnostics.Count
            }
            Details = $missingDiagnostics
        }

    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Details = "⚠️ Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-DiagnosticLogging