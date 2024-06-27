# Software Asset Management (SAM)

Dies ist eine einfache Software Asset Management (SAM) Anwendung, die Programme überwacht und deren Nutzung verfolgt. Die Anwendung besteht aus einem Flask-Server und einem PowerShell-Skript, das die Nutzung überwacht und Daten an den Server sendet.

## Inhaltsverzeichnis

- [Software Asset Management (SAM)](#software-asset-management-sam)
  - [Inhaltsverzeichnis](#inhaltsverzeichnis)
  - [Voraussetzungen](#voraussetzungen)
  - [Installation](#installation)
  - [Verwendung](#verwendung)
  - [API-Endpunkte](#api-endpunkte)
  - [Frontend](#frontend)
  - [PowerShell-Skript](#powershell-skript)
  - [Problemlösung](#problemlösung)
  - [Autoren](#autoren)

## Voraussetzungen

- Python 3.7 oder höher
- PowerShell 5.1 oder höher

## Installation

1. Klone das Repository:

    ```bash
    git clone https://github.com/TobiX586/sam.git
    cd sam
    ```

2. Erstelle und aktiviere eine virtuelle Umgebung:

    ```bash
    python -m venv venv
    source venv/bin/activate  # Auf Windows: venv\Scripts\activate
    ```

3. Installiere die Abhängigkeiten:

    ```bash
    pip install -r requirements.txt
    ```

4. Erstelle die SQLite-Datenbank und starte den Server:

    ```bash
    python server.py
    ```

## Verwendung

1. Starte den Flask-Server:

    ```bash
    python server.py
    ```

2. Führe das PowerShell-Skript aus, um die Programme zu überwachen:

    ```powershell
    .\UsageTracker.ps1
    ```

## API-Endpunkte

- **GET /api/programs**: Gibt die Liste der zu überwachenden Programme zurück.
- **POST /api/programs**: Fügt ein neues Programm zur Überwachung hinzu.
  - Body (JSON): `{ "name": "program_name", "description": "program_description" }`
- **DELETE /api/programs**: Entfernt ein Programm aus der Überwachung.
  - Body (JSON): `{ "name": "program_name" }`
- **POST /api/usage**: Sendet Nutzungsdaten an den Server.
  - Body (JSON): `{ "user_id": "user_id", "software_id": "software_id", "start_time": "start_time", "end_time": "end_time", "duration": "duration" }`
- **GET /api/usage**: Gibt die Liste der Nutzungsdaten zurück.

## Frontend

Das Frontend besteht aus einer einfachen HTML-Seite, die die zu überwachenden Programme und die Nutzungsdaten anzeigt. Es verwendet JavaScript, um Daten von den API-Endpunkten abzurufen und anzuzeigen.

## PowerShell-Skript

Das PowerShell-Skript überwacht die Programme und sendet die Nutzungsdaten an den Server. Es führt eine Endlosschleife aus, in der die laufenden Prozesse überwacht werden.

### Beispiel für das PowerShell-Skript (`UsageTracker.ps1`):

```powershell
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
        $processName = $programName.Split('.')[0]

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
