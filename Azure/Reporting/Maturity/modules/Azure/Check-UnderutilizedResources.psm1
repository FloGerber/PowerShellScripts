# Check for idle or underutilized resources flagged by Advisor
function Check-UnderutilizedResources {
    try {
        $recs = Get-AzAdvisorRecommendation | Where-Object {
            $_.Category -eq "Cost" -and $_.Impact -eq "High"
        }

        $details = $recs | Select-Object `
            RecommendationType, `
            ResourceId, `
            ShortDescription, `
            ExtendedProperties

        return [PSCustomObject]@{
            Result  = ($recs.Count -eq 0)
            Summary = if ($recs.Count -eq 0) {
                "✅ No high-impact cost recommendations currently active."
            } else {
                "⚠️ $($recs.Count) high-impact cost-saving recommendations detected."
            }
            Details = $details
        }

    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Details = "🚨 Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-UnderutilizedResources