# DRB Framework MySQL to Oracle Converter

## Overview

The DRB Framework is an automated solution for converting MySQL databases to Oracle 23ai using SQLines SQL Converter. This framework handles the complete migration process, from initial cleanup to final conversion, while maintaining a comprehensive history of all migrations.

## Features

- **Automated MySQL dump cleanup** for Oracle compatibility
- **Batch processing** with individual database selection
- **Automatic SQLines download and setup**
- **Migration history archiving** with timestamps
- **Detailed conversion reports** for each database
- **Script versioning** for traceability

## Requirements

- Windows PowerShell 5.1 or higher
- SQLines SQL Converter (automatically downloaded)
- Oracle 23ai as target database
- MySQL dump files (.sql format)

## Components

### 1. PipelineMySQLtoOracleConversion.ps1
Main orchestration script that manages the entire conversion workflow.

**Key Features:**
- Interactive folder selection for MySQL dumps
- Automatic SQLines download and configuration
- Multi-database support with individual selection
- Automatic archiving of previous conversions
- Report generation and automatic opening

**Parameters:**
- `DumpFolder`: Path to MySQL dump files (optional)
- `SQLlinesUrl`: SQLines download URL (default provided)
- `SkipDownload`: Skip SQLines download if already present
- `SkipCleanup`: Skip environment cleanup

### 2. clear_dump_mysql.ps1
Prepares MySQL dumps for Oracle conversion by removing incompatible elements.

**Transformations:**
- Removes DEFINER statements
- Removes ENGINE and CHARSET specifications
- Removes COLLATE clauses
- Removes ON UPDATE CASCADE
- Converts @ variables to simple variables
- Removes deallocate prepare statements
- Converts data types (DATETIME→TIMESTAMP, LONGTEXT→CLOB, etc.)
- Preserves AUTO_INCREMENT for SQLines conversion

### 3. clear_ambiente.ps1
Archives previous conversion artifacts before starting a new migration.

**Features:**
- Creates timestamped archives in StoricoMigrazioni folder
- Preserves all conversion artifacts (folders, reports, logs)
- Copies current PS1 scripts for version tracking
- Commented exit line for quick disable

## Directory Structure

```
ProjectFolder/
├── PipelineMySQLtoOracleConversion.ps1
├── clear_dump_mysql.ps1
├── clear_ambiente.ps1
├── DumpFolder/
│   ├── database1.sql
│   ├── database2.sql
│   ├── bck/                    # Original file backups
│   ├── inputOracle/            # Cleaned files for SQLines
│   ├── outputOracle/           # Converted Oracle files
│   └── SQLlines/               # SQLines executable
├── out_[database]/             # SQLines output snippets
├── scripts_[database]/         # SQLines generated scripts
├── sqlines_report_[database].html
├── sqlines_[database].log
└── StoricoMigrazioni/          # Migration history
    └── [database]_[timestamp]/
        ├── out_[database]/
        ├── scripts_[database]/
        ├── sqlines_report_[database].html
        ├── sqlines_[database].log
        └── *.ps1 (snapshot of scripts used)
```

## Usage

### Basic Usage
```powershell
.\PipelineMySQLtoOracleConversion.ps1
```

### With Parameters
```powershell
.\PipelineMySQLtoOracleConversion.ps1 -DumpFolder "C:\MySQL\dumps" -SkipDownload
```

### Disable Cleanup
Edit `clear_ambiente.ps1` and uncomment the `exit` line at the beginning.

## Workflow

1. **Environment Cleanup**: Archives previous conversion artifacts
2. **Database Selection**: Choose which database to convert
3. **SQLines Setup**: Download and extract SQLines (if needed)
4. **Directory Creation**: Create working directories
5. **MySQL Cleanup**: Run clear_dump_mysql.ps1 on selected files
6. **Conversion**: Execute SQLines with proper parameters
7. **Artifact Renaming**: Rename outputs with database name
8. **Report Opening**: Automatically open conversion report

## Known Limitations

### SQLines Trial Version
- Maximum ~40 objects per conversion in trial version
- Solution: Split large databases into multiple files
- Alternative: Purchase SQLines license for unlimited conversions

### Multiple Database Processing
- Process one database at a time for best results
- SQLines creates shared output folders that can conflict

## Troubleshooting

### Incomplete Conversions
- Check if database has more than 40 objects
- Review sqlines_[database].log for errors
- Consider splitting large databases

### Missing Tables/Procedures
- Verify objects exist in cleaned inputOracle files
- Check SQLines report for conversion issues
- Ensure no syntax errors in original dump

### Character Encoding Issues
- Scripts save as UTF-8 without BOM
- Original dumps should be UTF-8 encoded

## Version History

Scripts maintain original names for compatibility. Modified versions are saved with version suffix:
- `clear_dump_mysql.ps1` (current version)
- `clear_dump_mysql_v01.ps1` (version 1)
- `clear_dump_mysql_v02.ps1` (version 2)

## Best Practices

1. **One Database at a Time**: Avoid processing multiple databases simultaneously
2. **Review Reports**: Always check SQLines HTML reports for issues
3. **Test Conversions**: Validate converted files before production use
4. **Keep Archives**: StoricoMigrazioni provides rollback capability

## Technical Notes

- All scripts use UTF-8 encoding without BOM
- Compatible with PowerShell 5.1+
- SQLines version: 3.3.177
- Target: Oracle 23ai
- Source: MySQL 5.x/8.x

## Support

For SQLines-specific issues:
- Check SQLines documentation at https://www.sqlines.com
- Review generated reports in sqlines_report_[database].html

For framework issues:
- Check script execution logs
- Verify PowerShell execution policy
- Ensure all three PS1 files are in the same directory

## License

This framework is provided as-is for database migration purposes. SQLines is a third-party tool with its own licensing terms.

## Contributing

When modifying scripts:
1. Keep original script names unchanged
2. Save modifications with incremented version numbers
3. Update this documentation accordingly
4. Test thoroughly before production use