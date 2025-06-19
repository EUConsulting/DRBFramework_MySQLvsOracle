# Guida Tecnica DRB Framework MySQL to Oracle Converter

## Architettura del Sistema

### Flusso di Conversione
```
MySQL Dump → clear_dump_mysql → SQLines → Oracle SQL
     ↓              ↓               ↓           ↓
    bck/      inputOracle/    outputOracle/  Report
```

### Gestione Storico
```
Conversione N → clear_ambiente → StoricoMigrazioni/DB_timestamp/
                      ↓
              Archivia tutto prima di Conversione N+1
```

## Dettaglio Script

### PipelineMySQLtoOracleConversion.ps1

#### Funzioni Helper
- `Write-Status`: Output formattato per fasi principali
- `Write-Step`: Output per passi secondari
- `Write-Success`: Conferma operazioni completate
- `Write-Error`: Segnalazione errori
- `Write-Warning`: Avvisi importanti
- `Test-ZipFile`: Verifica integrità ZIP

#### Workflow Dettagliato

1. **Selezione Cartella**
   - GUI folder browser se non specificata
   - Validazione esistenza path

2. **Pulizia Ambiente**
   - Chiama clear_ambiente.ps1
   - Archivia conversioni precedenti
   - Parametro SkipCleanup per bypass

3. **Gestione Multi-Database**
   ```powershell
   if ($sqlFiles.Count -gt 1) {
       # Menu selezione interattivo
       # Opzione [A] per processare tutti (sconsigliato)
   }
   ```

4. **Download SQLines**
   - Retry logic (3 tentativi)
   - Verifica integrità ZIP
   - Estrazione con fallback method

5. **Conversione**
   ```powershell
   foreach ($sqlFile in $cleanedFiles) {
       # Pulisce con clear_dump_mysql
       # Converte con SQLines
       # Rinomina output con nome database
   }
   ```

6. **Rinomina Artifacts**
   - `out` → `out_DATABASENAME`
   - `scripts` → `scripts_DATABASENAME`
   - `sqlines_report.html` → `sqlines_report_DATABASENAME.html`
   - `sqlines.log` → `sqlines_DATABASENAME.log`

### clear_dump_mysql.ps1

#### Pattern di Pulizia

```powershell
# DEFINER removal
$content = $content -replace 'DEFINER=`[^`]*`@`[^`]*`\s*', ''

# ENGINE/CHARSET removal
$content = $content -replace 'ENGINE=(InnoDB|MyISAM|MEMORY)\s*', ''
$content = $content -replace 'DEFAULT CHARSET=\w+\s*', ''

# MySQL comments cleanup
$content = $content -replace '/\*!\d+[^*/]*\*/', ''

# Data type conversions
$content = $content -replace '\bDATETIME\b', 'TIMESTAMP'
$content = $content -replace '\bLONGTEXT\b', 'CLOB'

# Variable conversion
$content = $content -replace '@(\w+)', '$1'
```

#### File Management
- Input: `DumpFolder/database.sql`
- Backup: `DumpFolder/bck/database_backup.sql`
- Output: `DumpFolder/inputoracle/database_mysql.sql`

### clear_ambiente.ps1

#### Logica di Archiviazione

```powershell
# Identifica items da archiviare
$itemsToArchive = @()
$foldersToCheck = @("out", "scripts")
$filesToCheck = @("sqlines_report.html", "sqlines.log")

# Raggruppa per database
$databases = @{}
foreach ($item in $itemsToArchive) {
    if ($item.Name -match '_([^_]+)$') {
        $dbName = $matches[1]
        # Rimuove estensioni da dbName
    }
}

# Crea archivi con timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$archivePath = "StoricoMigrazioni/$dbName_$timestamp"
```

#### Preservazione Script
```powershell
$ps1Files = @(
    "clear_dump_mysql.ps1",
    "PipelineMySQLtoOracleConversion.ps1", 
    "clear_ambiente.ps1"
)
# Copia in ogni archivio per tracciabilità
```

## Gestione Errori e Retry

### Download SQLines
```powershell
$maxRetries = 3
while ($retryCount -lt $maxRetries -and -not $downloadSuccess) {
    try {
        Invoke-WebRequest -Uri $SQLlinesUrl -OutFile $zipFile
        if (Test-ZipFile $zipFile) {
            $downloadSuccess = $true
        }
    } catch {
        Start-Sleep -Seconds 5
    }
}
```

### Conversione File
```powershell
try {
    Push-Location $scriptDir
    # SQLines execution
    Pop-Location
} catch {
    Write-Error "Error converting $baseName"
    Pop-Location
}
```

## Parametri SQLines

### Comando Base
```
sqlines.exe -s=mysql -t=oracle -in="input.sql" -out="outputdir"
```

### File Generati
- `out/`: Snippet di conversione per ogni oggetto
- `scripts/`: Script DDL Oracle generati
- `sqlines_report.html`: Report dettagliato conversione
- `sqlines.log`: Log di esecuzione

## Limitazioni e Workaround

### Limite 40 Oggetti (Trial)
**Problema**: SQLines trial converte max ~40 oggetti
**Soluzioni**:
1. Dividere dump grandi in parti
2. Processare un database alla volta
3. Acquistare licenza SQLines

### Conflitti Multi-Database
**Problema**: SQLines sovrascrive cartelle output
**Soluzione**: Rinomina immediata dopo ogni conversione

### Encoding
**Problema**: BOM UTF-8 può causare errori
**Soluzione**: Rimozione automatica in clear_dump_mysql

## Performance e Ottimizzazioni

### Tempi Tipici
- Pulizia MySQL: ~1-5 secondi per MB
- Conversione SQLines: ~2-10 secondi per oggetto
- Totale per database medio (50 tabelle): ~5-10 minuti

### Memory Usage
- Clear_dump: Carica intero file in memoria
- SQLines: ~100-500MB per conversioni grandi
- Raccomandato: 4GB RAM minimo

## Debugging

### Log Analysis
1. Check `sqlines_DATABASENAME.log` per errori SQLines
2. Review `sqlines_report_DATABASENAME.html` per statistiche
3. PowerShell transcript per debug script

### Common Issues

**"Failed to convert X tables"**
- Verifica limite 40 oggetti
- Controlla sintassi SQL nel file pulito

**"Cannot find sqlines.exe"**
- Verifica download completato
- Check antivirus non blocchi exe

**"Access denied"**
- Esegui PowerShell come Administrator
- Check permessi cartelle

## Estensioni Future

### Possibili Miglioramenti
1. Split automatico dump grandi
2. Conversione parallela multi-thread
3. Validazione automatica output
4. Integrazione con Oracle Data Pump

### Script Aggiuntivi Proposti
- `split_large_dump.ps1`: Divide dump > 40 oggetti
- `validate_conversion.ps1`: Verifica output Oracle
- `merge_converted_files.ps1`: Unisce file divisi

## Best Practices Sviluppo

### Modifica Script
1. Mai modificare script originali
2. Salvare come `scriptname_vNN.ps1`
3. Testare su dump piccolo prima
4. Documentare ogni cambiamento

### Testing
```powershell
# Test con dump minimo
.\PipelineMySQLtoOracleConversion.ps1 -DumpFolder ".\test" -SkipDownload

# Verifica pulizia
.\clear_dump_mysql.ps1 ".\test\small.sql"
```

### Git Workflow
```bash
git add *.ps1 *.md
git commit -m "Version X.Y - Description"
git tag -a v2.0 -m "Stable version with archiving"
```