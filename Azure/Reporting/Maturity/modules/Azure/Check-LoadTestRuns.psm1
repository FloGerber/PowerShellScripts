# Check for recent or configured load tests
function Check-LoadTestRuns {
    try {
        $loadTests = $null
        $methodUsed = ""
        $accessToken = ""
        $headers = @{}

        # --- Always Retrieve Token in Advance ---
        try {

            $accessToken = Get-AzAccessToken -ResourceUrl "https://management.azure.com/"
            $plainToken = ConvertFrom-SecureString -SecureString $accessToken.Token -AsPlainText
            $headers = @{ Authorization = "Bearer $plainToken" }
        } catch {
            throw "🔐 Failed to retrieve access token"
        }

        # --- Try Azure Resource Graph ---
        try {
            $loadTests = Search-AzGraph -Query "Resources | where type =~ 'Microsoft.LoadTestService/loadTests' | project name, id, location, resourceGroup"
            $methodUsed = "Resource Graph"
        } catch {}

        # --- Fallback to REST API if Graph fails or returns nothing ---
        if (-not $loadTests -or $loadTests.Count -eq 0) {
            $subId = (Get-AzContext).Subscription.Id
            $uri = "https://management.azure.com/subscriptions/$subId/providers/Microsoft.LoadTestService/loadTests?api-version=2022-12-01"

            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
            $loadTests = $response.value
            $methodUsed = "REST API"
        }

        $configuredTests = @()
        $testsWithRuns = @()

        foreach ($test in $loadTests) {
            $testId = if ($test.id) { $test.id } else { $test.Id }
            $testName = if ($test.name) { $test.name } else { $test.Name }
            $location = if ($test.location) { $test.location } else { $test.Location }
            $group = if ($test.resourceGroup) { $test.resourceGroup } else { ($testId -split "/")[4] }

            # --- Retrieve test run history ---
            $runUri = "https://management.azure.com$testId/testRuns?api-version=2022-12-01"
            try {
                $runResponse = Invoke-RestMethod -Method Get -Uri $runUri -Headers $headers
                $runCount = if ($runResponse.value) { $runResponse.value.Count } else { 0 }
            } catch {
                $runCount = 0
            }

            $configuredTests += [PSCustomObject]@{
                TestName       = $testName
                ResourceGroup  = $group
                Location       = $location
                ResourceId     = $testId
                RunCount       = $runCount
            }

            if ($runCount -gt 0) {
                $testsWithRuns += $testName
            }
        }

        return [PSCustomObject]@{
            Result = ($testsWithRuns.Count -gt 0)
            MethodUsed = $methodUsed
            Summary = @{
                LoadTestsFound     = $configuredTests.Count
                TestsWithRunHistory= $testsWithRuns.Count
            }
            Details = $configuredTests
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Failed to retrieve Azure Load Test configurations and runs"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-LoadTestRuns 