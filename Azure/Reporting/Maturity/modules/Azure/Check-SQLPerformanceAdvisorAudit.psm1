# Check for SQL Performance tuning recommendations
function Check-SQLPerformanceAdvisorAudit {
    try {
        $sqlServers = Get-AzSqlServer
        $recommendations = @()

        foreach ($server in $sqlServers) {
            $databases = Get-AzSqlDatabase `
                -ResourceGroupName $server.ResourceGroupName `
                -ServerName $server.ServerName

            foreach ($db in $databases) {
                $recs = Get-AzSqlDatabaseRecommendedAction `
                    -ResourceGroupName $server.ResourceGroupName `
                    -ServerName $server.ServerName `
                    -DatabaseName $db.DatabaseName

                foreach ($rec in $recs) {
                    if ($rec.State -eq "Active" -and $rec.IsExecutable) {
                        $recommendations += [PSCustomObject]@{
                            Server       = $server.ServerName
                            Database     = $db.DatabaseName
                            Recommendation = $rec.Name
                            Description  = $rec.ImplementationDetails.Description
                            EstimatedGain= $rec.EstimatedImpact.AbsoluteValue
                        }
                    }
                }
            }
        }

        return [PSCustomObject]@{
            Result = ($recommendations.Count -gt 0)
            Summary = @{
                SqlServersScanned     = $sqlServers.Count
                DatabasesWithAdvice   = $recommendations.Count
            }
            Details = $recommendations
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Failed to retrieve SQL performance recommendations"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-SQLPerformanceAdvisorAudit