param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$SqlFile
)
if (-not (Test-Path $SqlFile)) {
    Write-Host "ERROR: File '$SqlFile' not found!" -ForegroundColor Red
    exit 1
}
$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($SqlFile)
$Directory = [System.IO.Path]::GetDirectoryName($SqlFile)
if ($Directory -eq "") { $Directory = "." }
$BackupFile = Join-Path $Directory "bck\$BaseName`_backup.sql"
$CleanFile = Join-Path $Directory "inputoracle\$BaseName`_mysql.sql"
Write-Host "MySQL to Oracle Schema Optimizer" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Input:  $SqlFile" -ForegroundColor White
Write-Host "Backup: $BackupFile" -ForegroundColor Yellow
Write-Host "Output: $CleanFile" -ForegroundColor Green
Write-Host ""
New-Item -ItemType Directory -Path (Join-Path $Directory "bck") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Directory "inputoracle") -Force | Out-Null
try {
    Copy-Item $SqlFile $BackupFile -Force
    Write-Host "Backup created successfully" -ForegroundColor Green
    Write-Host "Reading and optimizing..." -ForegroundColor Green
    $content = Get-Content $SqlFile -Raw -Encoding UTF8
    if ($content.StartsWith([char]0xFEFF)) {
        Write-Host "  Removing UTF-8 BOM..." -ForegroundColor Yellow
        $content = $content.Substring(1)
    }
    Write-Host "  Cleaning MySQL specifics..." -ForegroundColor Blue
    $content = $content -replace 'DEFINER=`[^`]*`@`[^`]*`\s*', ''
    $content = $content -replace 'ENGINE=(InnoDB|MyISAM|MEMORY)\s*', ''
    $content = $content -replace 'DEFAULT CHARSET=\w+\s*', ''
    $content = $content -replace 'DROP\s+TABLE\s+IF\s+EXISTS\s+`([^`]+)`', 'DROP TABLE IF EXISTS $1'
    Write-Host "  Cleaning MySQL comments..." -ForegroundColor Blue
    $content = $content -replace '/\*!\d+[^*/]*\*/', ''
    $content = $content -replace '/\*!\d+[^*/]*', ''
    Write-Host "  Removing COLLATE clauses..." -ForegroundColor Blue
    $content = $content -replace '\s+COLLATE=\w+', ''
    Write-Host "  Removing ON UPDATE CASCADE..." -ForegroundColor Blue
    $content = $content -replace '\s+ON\s+UPDATE\s+CASCADE', ''
    Write-Host "  Optimizing data types..." -ForegroundColor Blue
    $content = $content -replace '\bDATETIME\b', 'TIMESTAMP'
    $content = $content -replace '\bLONGTEXT\b', 'CLOB'
    $content = $content -replace '\bLONGBLOB\b', 'BLOB'
    $content = $content -replace '\bMEDIUMTEXT\b', 'CLOB'
    $content = $content -replace '\bMEDIUMBLOB\b', 'BLOB'
    $content = $content -replace '\bTINYINT\b', 'NUMBER(3)'
    Write-Host "  Fixing dynamic SQL variables..." -ForegroundColor Blue
    $content = $content -replace '@(\w+)', '$1'
    Write-Host "  Removing deallocate prepare..." -ForegroundColor Blue
    $content = $content -replace '\s*deallocate\s+prepare\s+stmt\s*;', ''
    Write-Host "  Final cleanup..." -ForegroundColor Blue
    $content = $content -replace '\s+\)', ')'
    $content = $content -replace '\)\s+;', ');'
    $content = $content -replace '\s+,', ','
    $content = $content -replace ',\s+', ', '
    $content = $content -replace '\r\n', "`n"
    Write-Host "Saving optimized file..." -ForegroundColor Green
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($CleanFile, $content, $utf8NoBom)
    Write-Host ""
    Write-Host "SUCCESS! File optimized for SQLines conversion!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next step:" -ForegroundColor Cyan
    Write-Host "  sqlines.exe -s=mysql -t=oracle `"$CleanFile`" `"outputoracle\$BaseName`_oracle.sql`"" -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}