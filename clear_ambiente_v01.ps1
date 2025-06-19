param(
    [Parameter(Position=0)]
    [string]$WorkingDir = "."
)
# exit  # Decommentare per disabilitare la pulizia
Write-Host "SQLines Environment Cleanup Script" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
if (-not (Test-Path $WorkingDir)) {
    Write-Host "ERROR: Working directory not found: $WorkingDir" -ForegroundColor Red
    exit 1
}
$WorkingDir = Resolve-Path $WorkingDir
Write-Host "Working directory: $WorkingDir" -ForegroundColor White
$storicoDir = Join-Path $WorkingDir "StoricoMigrazioni"
if (-not (Test-Path $storicoDir)) {
    New-Item -ItemType Directory -Path $storicoDir -Force | Out-Null
    Write-Host "Created archive directory: StoricoMigrazioni" -ForegroundColor Green
}
$itemsToArchive = @()
$foldersToCheck = @("out", "scripts")
foreach ($folder in $foldersToCheck) {
    $basePath = Join-Path $WorkingDir $folder
    if (Test-Path $basePath) {
        $itemsToArchive += @{Type="Folder"; Path=$basePath; Name=$folder}
    }
    $renamedFolders = Get-ChildItem -Path $WorkingDir -Directory -Filter "$folder`_*" -ErrorAction SilentlyContinue
    foreach ($renamedFolder in $renamedFolders) {
        $itemsToArchive += @{Type="Folder"; Path=$renamedFolder.FullName; Name=$renamedFolder.Name}
    }
}
$filesToCheck = @("sqlines_report.html", "sqlines.log")
foreach ($file in $filesToCheck) {
    $basePath = Join-Path $WorkingDir $file
    if (Test-Path $basePath) {
        $itemsToArchive += @{Type="File"; Path=$basePath; Name=$file}
    }
    $pattern = $file -replace '\.', '_*.'
    $renamedFiles = Get-ChildItem -Path $WorkingDir -File -Filter $pattern -ErrorAction SilentlyContinue
    foreach ($renamedFile in $renamedFiles) {
        if ($renamedFile.Name -ne $file) {
            $itemsToArchive += @{Type="File"; Path=$renamedFile.FullName; Name=$renamedFile.Name}
        }
    }
}
if ($itemsToArchive.Count -eq 0) {
    Write-Host "No SQLines artifacts found to archive" -ForegroundColor Yellow
    exit 0
}
Write-Host ""
Write-Host "Found $($itemsToArchive.Count) items to archive:" -ForegroundColor Yellow
foreach ($item in $itemsToArchive) {
    Write-Host "  - $($item.Name) [$($item.Type)]" -ForegroundColor Gray
}
$databases = @{}
foreach ($item in $itemsToArchive) {
    if ($item.Name -match '_([^_]+)$') {
        $dbName = $matches[1] -replace '\.html$', '' -replace '\.log$', ''
        if (-not $databases.ContainsKey($dbName)) {
            $databases[$dbName] = @()
        }
        $databases[$dbName] += $item
    } else {
        if (-not $databases.ContainsKey("_current")) {
            $databases["_current"] = @()
        }
        $databases["_current"] += $item
    }
}
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ps1Files = @("clear_dump_mysql.ps1", "PipelineMySQLtoOracleConversion.ps1", "clear_ambiente.ps1")
$availablePS1 = @()
foreach ($ps1 in $ps1Files) {
    $ps1Path = Join-Path $WorkingDir $ps1
    if (Test-Path $ps1Path) {
        $availablePS1 += $ps1Path
    }
}
Write-Host ""
Write-Host "Archiving process started..." -ForegroundColor Cyan
$archivedCount = 0
foreach ($db in $databases.Keys) {
    $archiveName = if ($db -eq "_current") { "Current_$timestamp" } else { "$db`_$timestamp" }
    $archivePath = Join-Path $storicoDir $archiveName
    Write-Host ""
    Write-Host "Creating archive: $archiveName" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
    foreach ($item in $databases[$db]) {
        try {
            if ($item.Type -eq "Folder") {
                $destPath = Join-Path $archivePath $item.Name
                Write-Host "  Moving folder: $($item.Name)" -ForegroundColor Gray
                Move-Item -Path $item.Path -Destination $destPath -Force
            } else {
                Write-Host "  Moving file: $($item.Name)" -ForegroundColor Gray
                Move-Item -Path $item.Path -Destination $archivePath -Force
            }
            $archivedCount++
        } catch {
            Write-Host "  ERROR moving $($item.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    foreach ($ps1Path in $availablePS1) {
        $ps1Name = Split-Path -Leaf $ps1Path
        Write-Host "  Copying script: $ps1Name" -ForegroundColor Gray
        Copy-Item -Path $ps1Path -Destination $archivePath -Force
    }
}
Write-Host ""
Write-Host "Archive completed successfully!" -ForegroundColor Green
Write-Host "  Items archived: $archivedCount" -ForegroundColor White
Write-Host "  Archive location: $storicoDir" -ForegroundColor White
Write-Host ""