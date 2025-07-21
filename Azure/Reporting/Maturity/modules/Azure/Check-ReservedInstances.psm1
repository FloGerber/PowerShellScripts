# FIXME: Needs review, Permision issue pretty sure!
# Check for active Azure Reservations for predictable workloads
function Check-ReservedInstances {
    try {
        $reservations = Get-AzReservation
        $active = $reservations | Where-Object { $_.Status -eq 'Succeeded' }

        return [PSCustomObject]@{
            Result  = ($active.Count -gt 0)
            Details = $active
        }
    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Details = "Error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Check-ReservedInstances