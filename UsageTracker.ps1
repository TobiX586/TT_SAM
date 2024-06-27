# Define the API endpoints
$programsEndpoint = "http://localhost:5000/api/programs"
$usageEndpoint = "http://localhost:5000/api/usage"

# Function to get the list of programs to monitor from the server
function GetProgramsToMonitor {
    try {
        Write-Host "Fetching programs to monitor..."
        $response = Invoke-RestMethod -Uri $programsEndpoint -Method Get
        Write-Host "Programs fetched: $($response.programs | ConvertTo-Json)"
        return $response.programs
    } catch {
        Write-Host "Failed to retrieve programs: $_"
        return @()
    }
}

# Function to check if the process is running
function IsProcessRunning {
    param (
        [string]$processName
    )
    try {
        $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($process -ne $null) {
            Write-Host "Process $processName is running."
            return $true
        } else {
            Write-Host "Process $processName is not running."
            return $false
        }
    } catch {
        Write-Host "Error checking process $processName"
        return $false
    }
}

# Function to send usage data to the server
function SendUsageData {
    param (
        [hashtable]$usageData
    )
    $jsonData = $usageData | ConvertTo-Json -Depth 3
    try {
        Write-Host "Sending usage data: $jsonData"
        $response = Invoke-RestMethod -Uri $usageEndpoint -Method Post -Body $jsonData -ContentType "application/json"
        Write-Host "Response from server: $($response | ConvertTo-Json)"
        Write-Host "Usage data sent successfully"
    } catch {
        Write-Host "Failed to send usage data: $_"
    }
}

# Main loop to monitor software usage
$startTimes = @{}
$endTimes = @{}

while ($true) {
    $programsToMonitor = GetProgramsToMonitor
    if ($programsToMonitor.Count -eq 0) {
        Write-Host "No programs to monitor."
        Start-Sleep -Seconds 60
        continue
    }

    foreach ($program in $programsToMonitor) {
        $programName = $program.name
        $processName = $programName.Split('.')[0]  # Entfernt die Erweiterung .exe

        Write-Host "Checking process: $processName"
        Write-Host "Current startTimes: $($startTimes.Keys -join ', ')"

        if (IsProcessRunning -processName $processName) {
            if (-not $startTimes.ContainsKey($programName)) {
                $startTimes[$programName] = Get-Date
                Write-Host "Process $programName started at $($startTimes[$programName])"
            } else {
                Write-Host "Process $programName is already being monitored."
            }
        } else {
            if ($startTimes.ContainsKey($programName)) {
                $endTimes[$programName] = Get-Date
                $duration = ($endTimes[$programName] - $startTimes[$programName]).TotalSeconds
                Write-Host "Process $programName ended at $($endTimes[$programName]) after $duration seconds"

                $usageData = @{
                    user_id    = $env:USERNAME
                    software_id = $programName
                    start_time  = $startTimes[$programName].ToString("o")
                    end_time    = $endTimes[$programName].ToString("o")
                    duration    = $duration 
                }

                Write-Host "Data: $($usageData | ConvertTo-Json -Depth 3)"
                SendUsageData -usageData $usageData
                $startTimes.Remove($programName)
            } else {
                Write-Host "Process $programName was not started yet."
            }
        }
    }
    
    Start-Sleep -Seconds 10
}
