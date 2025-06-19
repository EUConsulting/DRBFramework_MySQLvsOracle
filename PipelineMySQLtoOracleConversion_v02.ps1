param(
    [string]$DumpFolder = "",
    [string]$SQLlinesUrl = "https://www.sqlines.com/downloads/sqlines-3.3.177.zip",
    [string]$FrameworkPath = "DRBFrameworkConvertMySQLvsOracle23ai",
    [switch]$SkipDownload = $false,
    [switch]$SkipCleanup = $false
)
function Write-Status {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor $Color
}
function Write-Step {
    param([string]$Message, [string]$Color = "Yellow")
    Write-Host "  $Message" -ForegroundColor $Color
}
function Write-Success {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Green
}
function Write-Error {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Red
}
function Write-Warning {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Magenta
}
function Test-ZipFile {
    param([string]$ZipPath)
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
        $zip.Dispose()
        return $true
    } catch {
        return $false
    }
}
Write-Host "Complete MySQL to Oracle Conversion Pipeline" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""
try {
    Write-Status "Step 1: Selecting Dump Folder"
    if ([string]::IsNullOrEmpty($DumpFolder)) {
        Add-Type -AssemblyName System.Windows.Forms
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select folder containing MySQL dump files"
        $folderBrowser.ShowNewFolderButton = $true
        if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $DumpFolder = $folderBrowser.SelectedPath
        } else {
            Write-Error "No folder selected. Exiting."
            exit 1
        }
    }
    if (-not (Test-Path $DumpFolder)) {
        Write-Error "Dump folder does not exist: $DumpFolder"
        exit 1
    }
    Write-Success "Dump folder selected: $DumpFolder"
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if (-not $SkipCleanup) {
        Write-Status "Step 1.5: Environment Cleanup"
        $clearEnvScript = Join-Path $scriptDir "clear_ambiente_v01.ps1"
        if (Test-Path $clearEnvScript) {
            Write-Step "Running environment cleanup..."
            & powershell -ExecutionPolicy Bypass -File $clearEnvScript $scriptDir
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Environment cleaned successfully"
            } else {
                Write-Warning "Environment cleanup completed with warnings"
            }
        } else {
            Write-Warning "clear_ambiente_v01.ps1 not found, skipping cleanup"
        }
    }
    $sqlFiles = Get-ChildItem -Path $DumpFolder -Filter "*.sql" | Select-Object -ExpandProperty Name
    if ($sqlFiles.Count -eq 0) {
        Write-Error "No SQL files found in $DumpFolder"
        exit 1
    }
    Write-Success "Found $($sqlFiles.Count) SQL files: $($sqlFiles -join ', ')"
    if ($sqlFiles.Count -gt 1) {
        Write-Warning "Multiple databases detected. Select which file to process:"
        Write-Host ""
        for ($i = 0; $i -lt $sqlFiles.Count; $i++) {
            Write-Host "  [$($i+1)] $($sqlFiles[$i])" -ForegroundColor White
        }
        Write-Host "  [A] Process all (may cause issues with object limits)" -ForegroundColor Yellow
        Write-Host ""
        $selection = Read-Host "Enter your choice (1-$($sqlFiles.Count) or A)"
        if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $sqlFiles.Count) {
            $selectedFile = $sqlFiles[[int]$selection - 1]
            $sqlFiles = @($selectedFile)
            Write-Success "Selected: $selectedFile"
        } elseif ($selection -eq 'A' -or $selection -eq 'a') {
            Write-Warning "Processing all files. May encounter object limitations."
        } else {
            Write-Error "Invalid selection"
            exit 1
        }
    }
    $sqlinesFolder = Join-Path $DumpFolder "SQLlines"
    Write-Status "Step 2: Setting up SQLines"
    if (-not $SkipDownload) {
        Write-Step "Downloading SQLlines from $SQLlinesUrl"
        $zipFile = Join-Path $DumpFolder "sqlines.zip"
        if (Test-Path $zipFile) {
            Remove-Item $zipFile -Force
        }
        $maxRetries = 3
        $retryCount = 0
        $downloadSuccess = $false
        while ($retryCount -lt $maxRetries -and -not $downloadSuccess) {
            try {
                $retryCount++
                Write-Step "Download attempt $retryCount of $maxRetries"
                Invoke-WebRequest -Uri $SQLlinesUrl -OutFile $zipFile -UseBasicParsing
                if (Test-Path $zipFile) {
                    $fileSize = (Get-Item $zipFile).Length
                    Write-Step "Downloaded file size: $([math]::Round($fileSize/1MB, 2)) MB"
                    if (Test-ZipFile $zipFile) {
                        Write-Success "SQLlines downloaded and verified successfully"
                        $downloadSuccess = $true
                    } else {
                        Write-Error "Downloaded ZIP file is corrupted"
                        Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
                    }
                } else {
                    Write-Error "Download failed - file not created"
                }
            } catch {
                Write-Error "Download attempt $retryCount failed: $($_.Exception.Message)"
                if (Test-Path $zipFile) {
                    Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
                }
                if ($retryCount -lt $maxRetries) {
                    Write-Step "Waiting 5 seconds before retry..."
                    Start-Sleep -Seconds 5
                }
            }
        }
        if (-not $downloadSuccess) {
            Write-Error "Failed to download SQLlines after $maxRetries attempts"
            Write-Error "Please download manually from: $SQLlinesUrl"
            Write-Error "And place the zip file at: $zipFile"
            exit 1
        }
        Write-Status "Step 3: Extracting SQLlines"
        if (Test-Path $sqlinesFolder) {
            Remove-Item $sqlinesFolder -Recurse -Force
        }
        New-Item -ItemType Directory -Path $sqlinesFolder -Force | Out-Null
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            Write-Step "Extracting ZIP archive..."
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $sqlinesFolder)
            Remove-Item $zipFile -Force
            Write-Success "SQLlines extracted to $sqlinesFolder"
        } catch {
            Write-Error "Failed to extract SQLlines: $($_.Exception.Message)"
            try {
                Write-Step "Trying alternative extraction method..."
                Expand-Archive -Path $zipFile -DestinationPath $sqlinesFolder -Force
                Remove-Item $zipFile -Force
                Write-Success "SQLlines extracted using alternative method"
            } catch {
                Write-Error "Alternative extraction also failed: $($_.Exception.Message)"
                Write-Error "Please extract manually: $zipFile to $sqlinesFolder"
                exit 1
            }
        }
    } else {
        Write-Step "Skipping SQLlines download (using existing)"
    }
    $sqlinesExe = Get-ChildItem -Path $sqlinesFolder -Filter "sqlines.exe" -Recurse | Select-Object -First 1
    if (-not $sqlinesExe) {
        Write-Error "sqlines.exe not found in $sqlinesFolder"
        Write-Error "Please verify the extraction was successful"
        exit 1
    }
    Write-Success "SQLlines executable found: $($sqlinesExe.FullName)"
    Write-Status "Step 4-6: Creating Working Directories"
    $bckFolder = Join-Path $DumpFolder "bck"
    $inputOracleFolder = Join-Path $DumpFolder "inputOracle"
    $outputOracleFolder = Join-Path $DumpFolder "outputOracle"
    @($bckFolder, $inputOracleFolder, $outputOracleFolder) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
            Write-Success "Created: $_"
        } else {
            Write-Success "Already exists: $_"
        }
    }
    Write-Status "Step 7: Copying Cleanup Script"
    $sourceScript = Join-Path $scriptDir "clear_dump_mysql_v02.ps1"
    $targetScript = Join-Path $DumpFolder "clear_dump_mysql_v02.ps1"
    if (Test-Path $sourceScript) {    
        Copy-Item $sourceScript $targetScript -Force
        Write-Success "Cleanup script copied to $targetScript"
    } else {
        Write-Error "Source script not found: $sourceScript"
        exit 1
    }
    Write-Status "Step 8: Running MySQL Cleanup Script"
    $cleanedFiles = @()
    foreach ($sqlFile in $sqlFiles) {
        $sqlFilePath = Join-Path $DumpFolder $sqlFile
        Write-Step "Cleaning $sqlFile"
        try {
            $result = & powershell -ExecutionPolicy Bypass -File $targetScript $sqlFilePath
            if ($LASTEXITCODE -eq 0) {
                Write-Success "$sqlFile cleaned successfully"
                $cleanedFiles += $sqlFile
            } else {
                Write-Error "Failed to clean $sqlFile"
            }
        } catch {
            Write-Error "Error cleaning $sqlFile : $($_.Exception.Message)"
        }
    }
    if ($cleanedFiles.Count -eq 0) {
        Write-Error "No files were cleaned successfully"
        exit 1
    }
    Write-Status "Step 9: Preparing SQLines Environment"
    $env:PATH = "$($sqlinesExe.Directory.FullName);$env:PATH"
    Write-Success "SQLlines path added to environment: $($sqlinesExe.Directory.FullName)"
    Write-Status "Step 10: Running SQLines Conversion"
    $convertedFiles = @()
    $startTime = Get-Date
    foreach ($sqlFile in $cleanedFiles) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($sqlFile)
        $inputFile = Join-Path $inputOracleFolder "$baseName`_mysql.sql"
        if (-not (Test-Path $inputFile)) {
            Write-Error "Cleaned file not found: $inputFile"
            continue
        }
        Write-Step "Converting $baseName..."
        try {
            Push-Location $scriptDir
            $sqlinesArgs = @("-s=mysql", "-t=oracle", "-in=`"$inputFile`"", "-out=`"$outputOracleFolder`"")
            Write-Step "Executing: sqlines.exe $($sqlinesArgs -join ' ')"
            $process = Start-Process -FilePath $sqlinesExe.FullName -ArgumentList $sqlinesArgs -Wait -PassThru -NoNewWindow
            $outputFile = Join-Path $outputOracleFolder "$baseName`_mysql.sql"
            if ($process.ExitCode -eq 0 -and (Test-Path $outputFile)) {
                $inputSize = (Get-Item $inputFile).Length
                $outputSize = (Get-Item $outputFile).Length
                $inputKB = [math]::Round($inputSize/1KB, 1)
                $outputKB = [math]::Round($outputSize/1KB, 1)
                Write-Success "$baseName converted ($inputKB KB to $outputKB KB)"
                $convertedFiles += $baseName
                $outFolder = Join-Path $scriptDir "outr"
                $scriptsFolder = Join-Path $scriptDir "scripts"
                $reportFile = Join-Path $scriptDir "sqlines_report.html"
                $logFile = Join-Path $scriptDir "sqlines.log"
                if (Test-Path $outFolder) {
                    $newName = "outr_$baseName"
                    Move-Item $outFolder (Join-Path $scriptDir $newName) -Force
                    Write-Success "Renamed: out to $newName"
                }
                if (Test-Path $scriptsFolder) {
                    $newName = "scripts_$baseName"
                    Move-Item $scriptsFolder (Join-Path $scriptDir $newName) -Force
                    Write-Success "Renamed: scripts to $newName"
                }
 #               if (Test-Path $reportFile) {
 #                   $newName = "sqlines_report_$baseName.html"
 #                   Move-Item $reportFile (Join-Path $scriptDir $newName) -Force
 #                   Write-Success "Saved report as: $newName"
 #               }
				
				
				# Dopo la rinomina delle cartelle (circa riga 200)
				if (Test-Path $reportFile) {
					$newName = "sqlines_report_$baseName.html"
					Move-Item $reportFile (Join-Path $scriptDir $newName) -Force
					Write-Success "Saved report as: $newName"
					
					# FIX: Aggiorna i riferimenti nel report HTML
					$reportPath = Join-Path $scriptDir $newName
					Write-Step "Updating references in HTML report..."
					
					# Leggi il contenuto del report
					$reportContent = Get-Content $reportPath -Raw -Encoding UTF8
					
					# Sostituisci i riferimenti alla cartella out
					# Pattern tipici nel report SQLines:
					# href="out/..." → href="out_nomedatabase/..."
					# src="out/..." → src="out_nomedatabase/..."
					$reportContent = $reportContent -replace '(href|src)="outr/', "`$1=`"outr_$baseName/"
					$reportContent = $reportContent -replace "'outr/", "'outr_$baseName/"
					
					# Sostituisci anche riferimenti a scripts se necessario
					$reportContent = $reportContent -replace '(href|src)="scripts/', "`$1=`"scripts_$baseName/"
					$reportContent = $reportContent -replace "'scripts/", "'scripts_$baseName/"
					
					# Salva il report aggiornato
					$utf8NoBom = New-Object System.Text.UTF8Encoding $false
					[System.IO.File]::WriteAllText($reportPath, $reportContent, $utf8NoBom)
					
					Write-Success "Updated HTML report references"
				}				
			
                if (Test-Path $logFile) {
                    $newName = "sqlines_$baseName.log"
                    Move-Item $logFile (Join-Path $scriptDir $newName) -Force
                    Write-Success "Saved log as: $newName"
                }
            } else {
                Write-Error "Failed to convert $baseName (Exit code: $($process.ExitCode))"
                $logFile = Join-Path $scriptDir "sqlines.log"
                if (Test-Path $logFile) {
                    Write-Error "Check log file for details: $logFile"
                }
            }
            Pop-Location
        } catch {
            Write-Error "Error converting $baseName : $($_.Exception.Message)"
            Pop-Location
        }
        if ($cleanedFiles.Count -gt 1) {
            Write-Step "Waiting before next conversion..."
            Start-Sleep -Seconds 2
        }
    }
    $endTime = Get-Date
    $duration = $endTime - $startTime
    Write-Status "Step 11: Opening SQLines Reports"
    $reportFiles = Get-ChildItem -Path $scriptDir -Filter "sqlines_report_*.html" | Select-Object -Last 1
    if ($reportFiles) {
        try {
            Start-Process $reportFiles.FullName
            Write-Success "SQLines report opened: $($reportFiles.Name)"
        } catch {
            Write-Error "Failed to open report: $($_.Exception.Message)"
            Write-Step "Manual path: $($reportFiles.FullName)"
        }
    } else {
        Write-Warning "No SQLines reports found"
    }
    Write-Status "Pipeline Completed Successfully" "Green"
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Yellow
    Write-Host "SQL Files Found: $($sqlFiles.Count)" -ForegroundColor Gray
    Write-Host "Files Cleaned: $($cleanedFiles.Count)" -ForegroundColor Gray
    Write-Host "Files Converted: $($convertedFiles.Count)" -ForegroundColor Gray
    $durationText = "{0:mm}:{0:ss}" -f $duration
    Write-Host "Duration: $durationText" -ForegroundColor Gray    
    Write-Host ""
    Write-Host "Output Locations:" -ForegroundColor Cyan
    Write-Host "  Backups: $bckFolder" -ForegroundColor White
    Write-Host "  Cleaned: $inputOracleFolder" -ForegroundColor White
    Write-Host "  Converted: $outputOracleFolder" -ForegroundColor White
    Write-Host "  SQLlines: $sqlinesFolder" -ForegroundColor White
    Write-Host "  Reports: $scriptDir\sqlines_report_*.html" -ForegroundColor White
    Write-Host "  Logs: $scriptDir\sqlines_*.log" -ForegroundColor White
    Write-Host "  Archive: $scriptDir\StoricoMigrazioni" -ForegroundColor White
    Write-Host ""
    if ($convertedFiles.Count -eq $sqlFiles.Count) {
        Write-Host "All files converted successfully!" -ForegroundColor Green
    } elseif ($convertedFiles.Count -gt 0) {
        Write-Host "Partial success: $($convertedFiles.Count)/$($sqlFiles.Count) files converted" -ForegroundColor Yellow
    } else {
        Write-Host "No files converted successfully" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Error "Pipeline failed: $($_.Exception.Message)"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host "Pipeline completed! Check the SQLines reports for detailed conversion statistics." -ForegroundColor Green