# Connect to Azure

# Connect-MgGraph -Scopes "Directory.Read.All", "User.Read.All", "SecurityEvents.Read.All", "SecurityEvents.ReadWrite.All" -UseDeviceAuthentication
$creds = Get-Credential -Credential "e6175913-9a26-4949-bb87-728bc7dd98b0"

Connect-AzAccount -ServicePrincipal -TenantId 6553bcda-3a70-485b-8bd9-a3283b89cf5c -Credential $creds

Connect-MgGraph -TenantId 6553bcda-3a70-485b-8bd9-a3283b89cf5c -Credential $creds

#. ./Check-AzureWAFAllignment.ps1

$questionsPath = ".\questions.json"
$assessmentLogPath = ".\logs\assessment_log.json"
$azureCheckLogPath = ".\logs\azure_checks_log.txt"
$manuelOverrideLogPath = ".\logs\manual_override_log.json"
$modulesPath =  ".\modules"

$modules = Get-Childitem -include '*.psm1','*.ps1' -Recurse $modulesPath

Import-Module $modules

# Load question bank
$questions = Get-Content $questionsPath | ConvertFrom-Json
$results = @()
$assessmentlogDetails = [System.Collections.Generic.List[string]]::new()
$checkOutputs = @{}

#====================================#
#                                    #
#            Azure Checks            #
#                                    #
#====================================#

function Run-AzureCheck($checkName) {
    if (Get-Command $checkName -ErrorAction SilentlyContinue) {
        try {
            Write-Host $checkName
            $result = & $checkName
            $checkOutputs[$checkName] = $result  # store full output for markdown
            $assessmentlogDetails.Add("$checkName → ✅ Passed")
            return $result.Result  # return boolean pass/fail for scoring
        } catch {
            $assessmentlogDetails.Add("$checkName → ⚠️ Error: $($_.Exception.Message)")
            $checkOutputs[$checkName] = $_
            return $false
        }
    } else {
        $assessmentlogDetails.Add("$checkName → ❌ Not Implemented")
        $checkOutputs[$checkName] = "Not implemented"
        return $false
    }
}

#====================================#
#                                    #
#          Assessment Loop           #
#                                    #
#====================================#

foreach ($q in $questions) {
    $response = $null

    $maxScore += $q.Weight

    if ($q.AutoAnswer -eq $true -and $q.AzureCheck) {
        $response = Run-AzureCheck $q.AzureCheck
    }

    if ($null -eq $response) {
        do {
            $raw = Read-Host "$($q.Pillar): $($q.Text) (Y/Yes/N/No or press [Enter] for N/A)"
            $input = $raw.Trim().ToLower()

            switch ($input) {
                "yes" { $response = "Yes" }
                "y"   { $response = "Yes" }
                "no"  { $response = "No" }
                "n"   { $response = "No" }
                ""    { $response = "N/A" }
                default {
                    Write-Host "❌ Invalid input. Please enter Y, Yes, N, No or just press Enter for N/A." -ForegroundColor Yellow
                    $response = $null
                }
            }
        } until ($response)
    }

    $score = switch ($response) {
        "Yes" { $q.Weight }
        "No"  { 0 }
        "N/A" { 0 }
    }

    $results += [PSCustomObject]@{
        Pillar    = $q.Pillar
        Question  = $q.Text
        Response  = $response
        Score     = $score
    }
}

#====================================#
#                                    #
#         Milestone Logging          #
#                                    #
#====================================#

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$summary = @{}
foreach ($group in $grouped) {
    $summary[$group.Name] = ($group.Group | Measure-Object Score -Sum).Sum
}

# Reformat detailed check metadata
$checkResults = $questions | ForEach-Object {
    $qid   = $_.Id
    $pill  = $_.Pillar
    $check = $_.AzureCheck
    $questionText = $_.Text
    $responseObj = $results | Where-Object { $_.Question -eq $questionText }

    $rawResponse = $responseObj.Response
    $score = $responseObj.Score

    $result =
        if ($rawResponse -eq $true -or $rawResponse -eq "Yes") { "Passed" }
        elseif ($rawResponse -eq $false -or $rawResponse -eq "No") { "Failed" }
        else { "Manual" }

    # Include summary & details from checkOutputs if available
    $checkSummary = $null
    $checkDetails = $null
    if ($checkOutputs.ContainsKey($check)) {
        $fullCheck = $checkOutputs[$check]
        if ($fullCheck.PSObject.Properties.Match("Summary").Count -gt 0) {
            $checkSummary = $fullCheck.Summary
        }
        if ($fullCheck.PSObject.Properties.Match("Details").Count -gt 0) {
            $checkDetails = $fullCheck.Details
        }
    }

    [PSCustomObject]@{
        Id               = $qid
        Pillar           = $pill
        Text             = $questionText
        OriginalQuestion = $_.OriginalQuestion
        Response         = $rawResponse
        Result           = $result
        Score            = $score
        LastChecked      = $timestamp
        AzureCheck       = $check
        Summary          = $checkSummary
        Details          = $checkDetails
    }
}

# Build milestone entry
$entry = [PSCustomObject]@{
    Date   = $timestamp
    Scores = $summary
    Total  = $totalScore
    Notes  = "Ad hoc assessment"
    Checks = $checkResults
}

# Append to log file
if (Test-Path $assessmentlogPath) {
    $existing = Get-Content $assessmentlogPath -Raw | ConvertFrom-Json
    $history = @()
    if ($existing -is [System.Collections.IEnumerable]) {
        $history = $existing
    } else {
        $history += $existing
    }
} else {
    $history = @()
}
$history += $entry
$history | ConvertTo-Json -Depth 5 | Set-Content $assessmentlogPath

#====================================#
#                                    #
#          Azure Check Log           #
#                                    #
#====================================#

Set-Content -Path "$($azureCheckLogPath)" $assessmentlogDetails
Write-Host "📊 Milestone log updated: $($assessmentlogPath)"
Write-Host "📋 Azure check results logged to: $($azureCheckLog)"

#====================================#
#                                    #
#      Dashboard HTML Generator      #
#                                    #
#====================================#

# Get max possible score per pillar
$pillarMax = $questions | Where-Object { $_.AutoAnswer } | Group-Object Pillar | ForEach-Object {
    [PSCustomObject]@{
        Pillar = $_.Name
        MaxWeight = ($_.Group | Measure-Object -Property Weight -Sum).Sum
    }
}
$pillarMap = @{}
$pillarMax | ForEach-Object { $pillarMap[$_.Pillar] = $_.MaxWeight }

# Load Assessment Log
# Get most recent actual scores
$assessmentlog = Get-Content $assessmentLogPath | ConvertFrom-Json
$last = $assessmentlog[-1]

$overrideLog = Get-Content $manuelOverrideLogPath| ConvertFrom-Json
$overrideData = $overrideLog[-1].Overrides
$latestOverrides = @{}
foreach ($key in $overrideData.PSObject.Properties.Name) {
    $latestOverrides[$key] = $overrideData.$key
}

foreach ($item in $last.Checks) {
    $key = "override-$($item.Id)"
    if ($latestOverrides.ContainsKey($key)) {
        $override = $latestOverrides[$key]
        if ($override.Validated -eq $true) {
            $item.Result = "Passed (Override)"
            $item.Score = 5
            $item.OverrideText = $override.Text
        }
    }
}

$latest = $last.Scores
$dates = $assessmentlog | ForEach-Object { $_.Date }
$pillars = $latest.PSObject.Properties.Name

#====================================#
#                                    #
#     Assessment Answer Details      #
#                                    #
#====================================#

$checkHTML = "<h3>Azure Checks by Pillar</h3>"
$groupedChecks = $last.Checks | Group-Object Pillar

foreach ($group in $groupedChecks) {
    $checkHTML += "<details><summary><strong>$($group.Name)</strong></summary><ul>"

    foreach ($item in $group.Group) {
        $isAutomatic = ($item.AzureCheck -ne $null)
        $defaultResult = $item.Result
        $defaultScore = $item.Score
        $id = $item.Id

        # Emoji and color based on initial result
        $emoji = switch ($defaultResult) {
            "Passed"            { "✅" }
            "Failed"            { "❌" }
            "Passed (Override)" { "🔄" }
            default             { "🟡" }
        }

        $color = switch ($defaultResult) {
            "Passed"            { "green" }
            "Failed"            { "red" }
            "Passed (Override)" { "blue" }
            default             { "orange" }
        }

        $checkHTML += "<li><strong>$emoji $($item.Text)</strong><br/>"
        $checkHTML += "Result: <span id='result-$id' style='color:$color;'><strong>$defaultResult</strong></span><br/>"
        $checkHTML += "Score: <span id='score-$id'>$defaultScore</span><br/>"
        $checkHTML += "<em>Check Type:</em> " + ($isAutomatic ? "Automatic" : "Manual") + "<br/>"

        if ($isAutomatic) {
            if ($item.Details -and $item.Details.Count -gt 0) {
                $checkHTML += "<em>Details:</em><pre style='background:#f6f6f6; padding:8px; border-radius:4px;'>"
                $checkHTML += ($item.Details | ConvertTo-Json -Depth 3)
                $checkHTML += "</pre>"
            }

            $checkHTML += "<label for='override-$id'><strong>Override Justification:</strong></label><br/>"
            $overrideText = if ($item.OverrideText) { $item.OverrideText } else { "" }
            $checkHTML += "<textarea id='override-$id' rows='2' cols='80'>$overrideText</textarea><br/>"

            $checkHTML += "<button onclick=""promptRevalidation('override-$id')"">Re-evaluate</button><br/>"
            }
          else {
            if ($item.OriginalQuestion) {
                $checkHTML += "<em>Question:</em> $($item.OriginalQuestion)<br/>"
            }
            if ($item.Response -ne $null) {
                $checkHTML += "<em>Answer:</em> <code>$($item.Response)</code><br/>"
            }
        }

        $checkHTML += "</li><br/>"
    }

    $checkHTML += "</ul></details><br/>"
}

#====================================#
#                                    #
#   Radar Chart Data (Normalized)    #
#                                    #
#====================================#

# Build normalized percentages
$radarData = @()
foreach ($pillar in $pillars) {
    $score = $latest.$pillar
    $max = if ($pillarMap.ContainsKey($pillar)) { $pillarMap[$pillar] } else { 0 }
    $percent = if ($max -eq 0) { 0 } else { [math]::Round(($score / $max) * 100) }
    $radarData += $percent
}
# Format as JSON arrays
$radarLabels = '["' + ($pillars -join '","') + '"]'
$radarValues = '[' + ($radarData -join ',') + ']'
$actualMaxRadar = [math]::Ceiling(($radarData | Measure-Object -Maximum).Maximum / 10) * 10

# $radarLabels = ($pillars | ConvertTo-Json -Compress)
# $radarValues = ($radarData | ConvertTo-Json -Compress)
# $actualMaxRadar = [math]::Ceiling(($radarData | Measure-Object -Maximum).Maximum / 10) * 10

#====================================#
#                                    #
#      Line Chart Data (Trends)      #
#                                    #
#====================================#

$lineSets = @()
$colorMap = @{
    "Security"             = "rgba(255,99,132,0.7)"
    "Reliability"          = "rgba(54,162,235,0.7)"
    "Cost Optimization"    = "rgba(255,206,86,0.7)"
    "Operational Excellence" = "rgba(75,192,192,0.7)"
    "Performance Efficiency" = "rgba(153,102,255,0.7)"
}
$maxScoreY = 0

foreach ($pillar in $pillars) {
    $scores = $assessmentlog | ForEach-Object { [int]($_.Scores.$pillar) }
    $pillarMax = ($scores | Measure-Object -Maximum).Maximum
    if ($pillarMax -gt $maxScoreY) { $maxScoreY = $pillarMax }

    $color = $colorMap[$pillar]
    $lineSets += @{
        label = $pillar
        data = $scores
        borderColor = $color
        backgroundColor = $color
        tension = 0.3
        fill = $false
        pointStyle = "circle"
        pointRadius = 4
        pointHoverRadius = 6
    }
}

$lineData = @{
    labels = $dates
    datasets = $lineSets
} | ConvertTo-Json -Depth 5 -Compress

#====================================#
#                                    #
#     Change Chart Data (Deltas)     #
#                                    #
#====================================#

$changeLabels = @()
$changeSets = @{}
foreach ($pillar in $pillars) { $changeSets[$pillar] = @() }
for ($i = 1; $i -lt $assessmentlog.Count; $i++) {
    $changeLabels += "$($assessmentlog[$i - 1].Date) -> $($assessmentlog[$i].Date)"
    $prev = $assessmentlog[$i - 1].Scores
    $curr = $assessmentlog[$i].Scores
    foreach ($pillar in $pillars) {
        $delta = [int]$curr.$pillar - [int]$prev.$pillar
        $changeSets[$pillar] += $delta
    }
}
$changeDataSets = @()
foreach ($pillar in $pillars) {
    $color = $colorMap[$pillar]
    $changeDataSets += @{ label = $pillar; data = $changeSets[$pillar]; backgroundColor = $color }
}
$changeChart = @{ labels = $changeLabels; datasets = $changeDataSets } | ConvertTo-Json -Depth 5 -Compress

#====================================#
#                                    #
#     Serverity Per Pillar Chart     #
#                                    #
#====================================#

# Initialize chart data
$severityChartLabels = @("High", "Medium", "Low")
$pillarSeverityCounts = @{}

foreach ($pillar in $pillars) {
    $failed = $last.Checks | Where-Object {
        $_.Pillar -eq $pillar -and $_.Result -eq "Failed"
    }

    $counts = @{
        High   = ($questions | Where-Object { $_.Pillar -eq $pillar -and ($failed.Id -contains $_.Id) -and $_.Severity -eq "High" }).Count
        Medium = ($questions | Where-Object { $_.Pillar -eq $pillar -and ($failed.Id -contains $_.Id) -and $_.Severity -eq "Medium" }).Count
        Low    = ($questions | Where-Object { $_.Pillar -eq $pillar -and ($failed.Id -contains $_.Id) -and $_.Severity -eq "Low" }).Count
    }

    $pillarSeverityCounts[$pillar] = $counts
}

$severityColors = @{
    High   = "rgba(255, 99, 132, 0.7)"    # red
    Medium = "rgba(255, 206, 86, 0.7)"    # yellow
    Low    = "rgba(75, 192, 192, 0.7)"    # teal
}

$severityDatasets = @()
foreach ($level in $severityChartLabels) {
    $data = @()
    foreach ($pillar in $pillars) {
        $count = $pillarSeverityCounts[$pillar][$level]
        $data += $count
    }

    $severityDatasets += @{
        label = $level
        data = $data
        backgroundColor = $severityColors[$level]
    }
}

$severityChartData = @{
    labels = $pillars
    datasets = $severityDatasets
} | ConvertTo-Json -Depth 5 -Compress

#====================================#
#                                    #
#            Suggestions             #
#                                    #
#====================================#

$actionThreshold = 70
$pillarActions = @{}

foreach ($pillar in $pillars) {
    $score = $last.Scores.$pillar
    if ($score -ge $actionThreshold) { continue }

    $suggestions = ($questions | Where-Object {
        $_.Pillar -eq $pillar -and $_.Recommendation -ne $null
    }) | Select-Object -ExpandProperty Recommendation

    if ($suggestions.Count -gt 0) {
        $pillarActions[$pillar] = $suggestions
    }
}

$actionHTML = "<h3>Prioritized Recommendations</h3>"
$actionHTML += "<details><summary><strong>Expand to view recommended actions</strong></summary>"
$actionHTML += "<table style='width:100%; border-collapse:collapse; margin-top:10px;'>"
$actionHTML += "<tr><th style='text-align:left;'>Pillar</th><th style='text-align:left;'>Recommendation</th><th>Severity</th><th>Link</th></tr>"

$severityRank = @{
    "High"   = 3
    "Medium" = 2
    "Low"    = 1
    default  = 0
}

$impactSuggestions = @()
foreach ($pillar in $pillars) {
    $failedQuestions = $last.Checks | Where-Object {
        $_.Pillar -eq $pillar -and $_.Result -eq "Failed"
    }

    $recs = $questions | Where-Object {
        $_.Pillar -eq $pillar -and
        $_.Recommendation -ne $null -and
        $_.Severity -ne $null -and
        $_.Link -ne $null -and
        ($failedQuestions.Id -contains $_.Id)
    }

    foreach ($rec in $recs) {
        $impactSuggestions += [PSCustomObject]@{
            Pillar        = $pillar
            Recommendation = $rec.Recommendation
            Severity      = $rec.Severity
            Rank          = $severityRank[$rec.Severity]
            Link          = $rec.Link
        }
    }
}

$impactSuggestions = $impactSuggestions | Sort-Object Rank -Descending

foreach ($s in $impactSuggestions) {
    $bgColor = switch ($s.Severity) {
        "High"   { "#ff4d4d" }
        "Medium" { "#ffcc00" }
        "Low"    { "#ccffcc" }
        default  { "#e0e0e0" }
    }

    #$actionHTML += "<tr style='background-color:$bgColor;'>"
    $actionHTML += "<tr>"
    $actionHTML += "<td><strong>$($s.Pillar)</strong></td>"
    $actionHTML += "<td>$($s.Recommendation)</td>"
    $actionHTML += "<td>$($s.Severity)</td>"
    $actionHTML += "<td><a href='$($s.Link)' target='_blank'>Learn more</a></td>"
    $actionHTML += "</tr>"
}

$actionHTML += "</table></details>"

$tooltipJs = 'return `${label}: ${value}`;'

#====================================#
#                                    #
#      Generate Dashboard HTML       #
#                                    #
#====================================#
$html = Get-Content "./base.html" | Out-String
$html = $html.Replace('$radarLabels', $radarLabels)
$html = $html.Replace('$radarValues', $radarValues)
$html = $html.Replace('$actualMaxRadar', $actualMaxRadar)
$html = $html.Replace('$actualMaxRadar', $actualMaxRadar)
$html = $html.Replace('$lineData', $lineData)
$html = $html.Replace('$tooltipJs', $tooltipJs)
$html = $html.Replace('$maxScoreY', $maxScoreY)
$html = $html.Replace('$changeChart', $changeChart)
$html = $html.Replace('$severityChartData', $severityChartData)


$html = $html.Replace("<!-- AzureChecksPlaceholder -->", $checkHTML)
$html = $html.Replace("<!-- ActionItemsPlaceholder -->", $actionHTML)
# Set-Content "./WAF_Dashboard.html" -Value $html -Encoding UTF8
$html | Set-Content -Path "./WAF_Dashboard.html" -Encoding UTF8
Write-Host "`n✅ Dashboard generated successfully: WAF_Dashboard.html"






#====================================#
#                                    #
#            API Backend             #
#                                    #
#====================================#

Start-DashboardApi -Port 5000 -OverridePath $manuelOverrideLogPath