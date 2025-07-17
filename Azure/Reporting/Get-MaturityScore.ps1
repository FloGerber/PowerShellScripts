# Connect to Azure

# Connect-MgGraph -Scopes "Directory.Read.All", "User.Read.All", "SecurityEvents.Read.All", "SecurityEvents.ReadWrite.All" -UseDeviceAuthentication
$creds = Get-Credential -Credential "e6175913-9a26-4949-bb87-728bc7dd98b0"

Connect-AzAccount -ServicePrincipal -TenantId 6553bcda-3a70-485b-8bd9-a3283b89cf5c -Credential $creds

Connect-MgGraph -TenantId 6553bcda-3a70-485b-8bd9-a3283b89cf5c -Credential $creds

. ./Check-AzureWAFAllignment.ps1

# Load question bank
$questions = Get-Content "./questions.json" | ConvertFrom-Json
$results = @()
$logDetails = [System.Collections.Generic.List[string]]::new()
$checkOutputs = @{}

# ========== Azure Checks ========== #

# function Run-AzureCheck($checkName) {
#     if (Get-Command $checkName -ErrorAction SilentlyContinue) {
#         try {
#           write-host $checkName
#             $result = & $checkName
#             $logDetails.Add("$checkName → ✅ Passed")
#             return $result
#         } catch {
#             $logDetails.Add("$checkName → ⚠️ Error: $($_.Exception.Message)")
#             return $false
#         }
#      } else {
#          $logDetails.Add("$checkName → ❌ Not Implemented")
#          return $false
#      }
# }

function Run-AzureCheck($checkName) {
    if (Get-Command $checkName -ErrorAction SilentlyContinue) {
        try {
            Write-Host $checkName
            $result = & $checkName
            $checkOutputs[$checkName] = $result  # store full output for markdown
            $logDetails.Add("$checkName → ✅ Passed")
            return $result.Result  # return boolean pass/fail for scoring
        } catch {
            $logDetails.Add("$checkName → ⚠️ Error: $($_.Exception.Message)")
            $checkOutputs[$checkName] = $_
            return $false
        }
    } else {
        $logDetails.Add("$checkName → ❌ Not Implemented")
        $checkOutputs[$checkName] = "Not implemented"
        return $false
    }
}

# function Run-AzureCheck($checkName) {
#         try {
#           write-host $checkName
#             $result = Invoke-Expression $checkName
#             $logDetails.Add("$checkName → ✅ Passed")
#             return $result
#         } catch {
#             $logDetails.Add("$checkName → ⚠️ Error: $($_.Exception.Message)")
#             return $false
#         }
# }



# ========== Assessment Loop ========== #
foreach ($q in $questions) {
    $response = $null
    if ($q.AutoAnswer -eq $true -and $q.AzureCheck) {
        $response = Run-AzureCheck $q.AzureCheck
    }
    if ($null -eq $response) {
        $response = Read-Host "$($q.Pillar): $($q.Text) (Yes/No)"
    }
    $score = if ($response -eq "Yes" -or $response -eq $true) { $q.Weight } else { 0 }
    $results += [PSCustomObject]@{
        Pillar    = $q.Pillar
        Question  = $q.Text
        Response  = $response
        Score     = $score
    }
}

# ========== Markdown Report ========== #
# $reportPath = "./AssessmentReport.md"
# Set-Content $reportPath "# Azure Well-Architected Assessment Report`n"
# $totalScore = 0
# $grouped = $results | Group-Object Pillar
# foreach ($group in $grouped) {
#     Add-Content $reportPath "`n## $($group.Name)"
#     foreach ($item in $group.Group) {
#         Add-Content $reportPath "- **$($item.Text)** → Response: $($item.Response) → Score: $($item.Score)"
#     }
#     $pillarScore = ($group.Group | Measure-Object Score -Sum).Sum
#     Add-Content $reportPath "`n**Total for $($group.Name): $pillarScore**`n"
#     $totalScore += $pillarScore
# }
# Add-Content $reportPath "`n---`n**Total Score:** $totalScore / 625"


#-------------- With details 

$reportPath = "./AssessmentReport.md"
Set-Content $reportPath "# Azure Well-Architected Assessment Report`n"

$totalScore = 0
$grouped = $results | Group-Object Pillar

foreach ($group in $grouped) {
    $pillarName = $group.Name
    Add-Content $reportPath "`n## $($pillarName)"

    # Individual questions and scores
    foreach ($item in $group.Group) {
        Add-Content $reportPath "- **$($item.Question)** → Response: $($item.Response) → Score: $($item.Score)"
    }

    # Pillar score summary
    $pillarScore = ($group.Group | Measure-Object Score -Sum).Sum
    Add-Content $reportPath "`n**Total for $($pillarName): $($pillarScore)**`n"
    $totalScore += $pillarScore

    # Inject Azure Check Details (grouped by pillar)
    $pillarChecks = ($questions | Where-Object { $_.Pillar -eq $pillarName -and $_.AzureCheck }) | Select-Object -ExpandProperty AzureCheck

    foreach ($check in $pillarChecks) {
        if ($checkOutputs.ContainsKey($check)) {
            $checkData = $checkOutputs[$check]

            Add-Content $reportPath "`n<details><summary><strong>Azure Check: $($check)</strong></summary>`n"

            # Summary block
            if ($checkData.PSObject.Properties.Match("Summary").Count -gt 0) {
                Add-Content $reportPath "`n**Summary:**"
                foreach ($key in $checkData.Summary.Keys) {
                    $value = $checkData.Summary[$key]
                    Add-Content $reportPath "- $($key): $($value)"
                }
            }

            # Details block
            if ($checkData.PSObject.Properties.Match("Details").Count -gt 0) {
                Add-Content $reportPath "`n**Details:**"
                $details = $checkData.Details

                if ($details -is [System.Collections.IDictionary]) {
                    foreach ($key in $details.Keys) {
                        $value = $details[$key]
                        Add-Content $reportPath "- $($key):"
                        if ($value -is [System.Collections.IEnumerable]) {
                            foreach ($item in $value) {
                                $json = $item | ConvertTo-Json -Depth 5 -Compress
                                Add-Content $reportPath "  - `$($json)"
                            }
                        } else {
                            Add-Content $reportPath "  - $($value)"
                        }
                    }
                } elseif ($details -is [System.Collections.IEnumerable]) {
                    foreach ($item in $details) {
                        $json = $item | ConvertTo-Json -Depth 5 -Compress
                        Add-Content $reportPath "- `$($json)"
                    }
                } else {
                    Add-Content $reportPath "- $($details)"
                }
            }

            Add-Content $reportPath "`n</details>`n"
        }
    }
}

# Final Score Summary
Add-Content $reportPath "`n---`n**Total Score:** $($totalScore) / 625"
Add-Content $reportPath "`n_Report generated on: $(Get-Date)_"



# ========== Milestone Logging ========== #
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$summary = @{}
foreach ($group in $grouped) {
    $summary[$group.Name] = ($group.Group | Measure-Object Score -Sum).Sum
}
# Reformat detailed check metadata
$checkResults = $questions | ForEach-Object {
    $qid = $_.Id
    $pill = $_.Pillar
    $cmd = $_.AzureCheck
    $responseObj = $results | Where-Object { $_.Question -eq $_.Text }

    $rawResponse = $responseObj.Response
    $score = $responseObj.Score

    $result =
        if ($rawResponse -eq $true -or $rawResponse -eq "Yes") { "Passed" }
        elseif ($rawResponse -eq $false -or $rawResponse -eq "No") { "Failed" }
        else { "Manual" }

    [PSCustomObject]@{
        Id          = $qid
        Pillar      = $pill
        Text        = $_.Text
        OriginalQuestion = $_.OriginalQuestion
        Response    = $rawResponse
        Result      = $result
        Score       = $score
        LastChecked = $timestamp
        Details     = $cmd
    }
}


# Now include it in your assessment entry
$entry = [PSCustomObject]@{
    Date = $timestamp
    Scores = $summary
    Total = $totalScore
    Notes = "Ad hoc assessment"
    Checks = $checkResults
}

$logPath = "./assessment_log.json"
if (Test-Path $logPath) {
    $jsonContent = Get-Content $logPath -Raw | ConvertFrom-Json
    $history = @()
    if ($jsonContent -is [System.Collections.IEnumerable]) {
        $history = $jsonContent
    } else {
        $history += $jsonContent
    }
} else {
    $history = @()
}
$history += $entry
$history | ConvertTo-Json -Depth 5 | Set-Content $logPath


#----------- Including the new structure

# ========== Milestone Logging (Patched) ========== #
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
$logPath = "./assessment_log.json"
if (Test-Path $logPath) {
    $existing = Get-Content $logPath -Raw | ConvertFrom-Json
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
$history | ConvertTo-Json -Depth 5 | Set-Content $logPath

# ========== Azure Check Log ========== #
Set-Content "./azure_checks_log.txt" $logDetails
Write-Host "`n✅ Assessment complete. Markdown saved to: $($reportPath)"
Write-Host "📊 Milestone log updated: $($logPath)"
Write-Host "📋 Azure check results logged to: ./azure_checks_log.txt"




# ========== Azure Check Log ========== #
Set-Content "./azure_checks_log.txt" $logDetails
Write-Host "`n✅ Assessment complete. Markdown saved to: $reportPath"
Write-Host "📊 Milestone log updated: $logPath"
Write-Host "📋 Azure check results logged to: ./azure_checks_log.txt"



# ==== Dashboard HTML Generator ====



# === Load Question Bank & Calculate Max Per Pillar ===
$questions = Get-Content "./questions.json" | ConvertFrom-Json
# Get max possible score per pillar
$pillarMax = $questions | Where-Object { $_.AutoAnswer } | Group-Object Pillar | ForEach-Object {
    [PSCustomObject]@{
        Pillar = $_.Name
        MaxWeight = ($_.Group | Measure-Object -Property Weight -Sum).Sum
    }
}
$pillarMap = @{}
$pillarMax | ForEach-Object { $pillarMap[$_.Pillar] = $_.MaxWeight }


# === Load Assessment Log ===
# Get most recent actual scores
$log = Get-Content "./assessment_log.json" | ConvertFrom-Json
$last = $log[-1]
$latest = $last.Scores
$dates = $log | ForEach-Object { $_.Date }
$pillars = $latest.PSObject.Properties.Name

$checkHTML = "<h3>Azure Checks by Pillar</h3>"
$groupedChecks = $last.Checks | Group-Object Pillar

foreach ($group in $groupedChecks) {
    $checkHTML += "<details><summary><strong>$($group.Name)</strong></summary><ul>"
    foreach ($item in $group.Group) {
        $emoji = switch ($item.Result) {
            "Passed" { "✅" }
            "Failed" { "❌" }
            default  { "🟡" }
        }
        $checkHTML += "<li>$emoji <strong>$($item.Text)</strong><br/>Result: $($item.Result)<br/>Score: $($item.Score)</li>"
    }
    $checkHTML += "</ul></details><br/>"
}


# === Radar Chart Data (Normalized) ===
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

# === Line Chart Data (Trends) ===
$lineSets = @()
$colorMap = @{
    "Security" = "rgba(255,99,132,0.7)"
    "Reliability" = "rgba(54,162,235,0.7)"
    "Cost Optimization" = "rgba(255,206,86,0.7)"
    "Operational Excellence" = "rgba(75,192,192,0.7)"
    "Performance Efficiency" = "rgba(153,102,255,0.7)"
}
$maxScoreY = 0
foreach ($pillar in $pillars) {
    $scores = $log | ForEach-Object { [int]($_.Scores.$pillar) }
    if (($scores | Select-Object -Unique).Count -le 1) { continue }
    $pillarMax = ($scores | Measure-Object -Maximum).Maximum
    if ($pillarMax -gt $maxScoreY) { $maxScoreY = $pillarMax }
    $color = $colorMap[$pillar]
    $lineSets += @{ label = $pillar; data = $scores; borderColor = $color; tension = 0.3; fill = $false }
}
$lineData = @{ labels = $dates; datasets = $lineSets } | ConvertTo-Json -Depth 5 -Compress

# === Change Chart Data (Deltas) ===
$changeLabels = @()
$changeSets = @{}
foreach ($pillar in $pillars) { $changeSets[$pillar] = @() }
for ($i = 1; $i -lt $log.Count; $i++) {
    $changeLabels += "$($log[$i - 1].Date) -> $($log[$i].Date)"
    $prev = $log[$i - 1].Scores
    $curr = $log[$i].Scores
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

# === Suggestions ===

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

# $actionHTML = "<h3>Suggested Actions for Improvement</h3><ul>"
# foreach ($pillar in $pillarActions.Keys) {
#     foreach ($suggestion in $pillarActions[$pillar]) {
#         $actionHTML += "<li><strong>${pillar}:</strong> $suggestion</li>"

#     }
# }
# $actionHTML += "</ul>"

$actionHTML = "<h3>Suggested Actions for Improvement</h3>"

foreach ($pillar in $pillarActions.Keys) {
    $actionHTML += "<details><summary><strong>$($pillar)</strong></summary><ul>"

    # Get recommendation objects, not just strings
    $suggestionObjects = $questions | Where-Object {
        $_.Pillar -eq $pillar -and $_.Recommendation -ne $null -and $_.Severity -ne $null -and $_.Link -ne $null
    }

    foreach ($rec in $suggestionObjects) {
        $severityColor = switch ($rec.Severity) {
            "High"   { "🔥" }
            "Medium" { "⚠️" }
            "Low"    { "ℹ️" }
            default  { "❓" }
        }

        $actionHTML += "<li>$severityColor <strong>$($rec.Recommendation)</strong><br/>"
        $actionHTML += "<em>Severity:</em> $($rec.Severity)<br/>"
        $actionHTML += "<a href='$($rec.Link)' target='_blank'>Learn more</a></li><br/>"
    }

    $actionHTML += "</ul></details><br/>"
}



# === Generate Dashboard HTML ===
$html = @"
<!DOCTYPE html>
<html>
<head>
  <title>Azure WAF Dashboard</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <style>
    body {
      font-family: 'Segoe UI', sans-serif;
      margin: 0;
      padding: 30px;
      background: #f0f2f5;
      color: #333;
      transition: all 0.3s ease;
    }
    .dark-mode { background: #121212; color: #eee; }
    canvas { background: #fff; border-radius: 8px; margin-bottom: 40px; }
    .dark-mode canvas { background: #1e1e1e; }
    .container { max-width: 960px; margin: auto; }
    h2, h3 { text-align: center; }
    .controls { text-align: center; margin-bottom: 20px; }
    button { margin: 5px; padding: 8px 14px; font-size: 0.9em; cursor: pointer; }
  </style>
</head>
<body>
  <div class="container">
    <h2>Azure Well-Architected Assessment Dashboard</h2>
    <div class="controls">
      <button onclick="toggleMode()">Toggle Dark Mode</button>
    </div>

    <h3>Architectural Maturity (Radar)</h3>
    <canvas id="radarChart" width="400" height="400"></canvas>

    <h3>Pillar Score Trends (Line)</h3>
    <canvas id="lineChart" width="900" height="400"></canvas>

    <h3>Pillar Score Changes Between Runs (Bar)</h3>
    <canvas id="changeChart" width="900" height="400"></canvas>

    <!-- AzureChecksPlaceholder -->
    <!-- ActionItemsPlaceholder -->


  </div>

  <script>
    const radarConfig = {
      type: 'radar',
      data: {
        labels: $radarLabels,
        datasets: [{
          label: 'Normalized Maturity (%)',
          data: $radarValues,
          backgroundColor: 'rgba(60,179,113,0.2)',
          borderColor: 'mediumseagreen',
          borderWidth: 2,
          pointBackgroundColor: 'mediumseagreen'
        }]
      },
      options: {
        scales: {
          r: {
            beginAtZero: true,
            max: $actualMaxRadar,
            suggestedMax: $actualMaxRadar
          }
        }
      }
    };

    const lineConfig = {
      type: 'line',
      data: $lineData,
      options: {
        responsive: true,
        plugins: {
          title: {
            display: true,
            text: 'WAF Pillar Score Trends Over Time',
            font: { size: 18 }
          },
          tooltip: {
  callbacks: {
    label: function(ctx) {
      const label = ctx.dataset.label || '';
      const value = ctx.parsed.y !== null ? ctx.parsed.y : '';
      return ```${label}: ${value}```;
    }
  }
},
          legend: { position: 'bottom' }
        },
        scales: {
          y: {
            beginAtZero: true,
            suggestedMax: $maxScoreY,
            title: { display: true, text: 'Score' }
          },
          x: { title: { display: true, text: 'Assessment Date' } }
        }
      }
    };

    const changeConfig = {
      type: 'bar',
      data: $changeChart,
      options: {
        responsive: true,
        plugins: {
          title: {
            display: true,
            text: 'Score Deltas Between Assessments'
          },
          legend: { position: 'bottom' }
        },
        scales: {
          y: {
            beginAtZero: true,
            suggestedMin: -50,
            suggestedMax: 50,
            title: { display: true, text: 'Change in Score' }
          },
          x: { title: { display: true, text: 'Comparison Run' } }
        }
      }
    };

    new Chart(document.getElementById('radarChart'), radarConfig);
    new Chart(document.getElementById('lineChart'), lineConfig);
    new Chart(document.getElementById('changeChart'), changeConfig);

    function toggleMode() {
      document.body.classList.toggle('dark-mode');
    }
  </script>
</body>
</html>
"@

$html = $html.Replace("<!-- AzureChecksPlaceholder -->", $checkHTML)
$html = $html.Replace("<!-- ActionItemsPlaceholder -->", $actionHTML)
Set-Content "./WAF_Dashboard.html" -Value $html
Write-Host "`n✅ Dashboard generated successfully: WAF_Dashboard.html"
