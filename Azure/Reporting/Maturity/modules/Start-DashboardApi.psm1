# Dashboard.Api.psm1

function Start-DashboardApi {
    param (
        [int]$Port = 5000,
        [string]$OverridePath = "./manual_override_log.json"
    )

    Add-Type -AssemblyName System.Net.HttpListener
    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()
    Write-Host "🚀 API listening on http://localhost:$Port/"

    while ($listener.IsListening) {
        $context  = $listener.GetContext()
        $request  = $context.Request
        $response = $context.Response

        try {
            $reader = New-Object System.IO.StreamReader($request.InputStream)
            $body = $reader.ReadToEnd()

            switch ($request.Url.AbsolutePath.ToLower()) {
                "/save-overrides" {
                    $incoming = $body | ConvertFrom-Json
                    $entry = @{
                        Date      = (Get-Date).ToString("yyyy-MM-dd HH:mm")
                        Reviewer  = $env:USERNAME
                        Overrides = $incoming
                    }

                    $log = @()
                    if (Test-Path $OverridePath) {
                        $log = Get-Content $OverridePath | ConvertFrom-Json
                    }
                    $log += $entry
                    $log | ConvertTo-Json -Depth 5 | Set-Content $OverridePath -Encoding UTF8
                    Write-Host "✅ Overrides saved at $OverridePath"
                    $response.StatusCode = 200
                }
                default {
                    $response.StatusCode = 404
                }
            }
        } catch {
            Write-Host "❌ API error: $($_.Exception.Message)"
            $response.StatusCode = 500
        }

        $response.Close()
    }
}

Export-ModuleMember -Function Start-DashboardApi