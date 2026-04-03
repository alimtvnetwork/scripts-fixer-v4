<#
.SYNOPSIS
    Shared JSON and file utilities used by multiple scripts.
#>

function Backup-File {
    param([string]$FilePath, [string]$BackupSuffix)

    Write-Log "Checking backup target: $FilePath"
    if (Test-Path $FilePath) {
        $dir       = Split-Path $FilePath -Parent
        $name      = Split-Path $FilePath -Leaf
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupName = "$name.$timestamp$BackupSuffix"
        $backupPath = Join-Path $dir $backupName
        Write-Log "Backup destination: $backupPath"
        try {
            Copy-Item -Path $FilePath -Destination $backupPath -Force
            Write-Log "Backup created: $backupName" "ok"
            return $true
        } catch {
            Write-Log "Backup failed for $name -- $_" "fail"
            return $false
        }
    } else {
        Write-Log "No existing $(Split-Path $FilePath -Leaf) to back up" "skip"
        return $true
    }
}

function ConvertTo-OrderedHashtable {
    param([Parameter(Mandatory)][PSCustomObject]$InputObject)

    $ht = [ordered]@{}
    foreach ($prop in $InputObject.PSObject.Properties) {
        if ($prop.Value -is [PSCustomObject]) {
            $ht[$prop.Name] = ConvertTo-OrderedHashtable -InputObject $prop.Value
        } else {
            $ht[$prop.Name] = $prop.Value
        }
    }
    return $ht
}

function Merge-JsonDeep {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Base,
        [Parameter(Mandatory)]
        [hashtable]$Override
    )

    $result = $Base.Clone()
    foreach ($key in $Override.Keys) {
        if ($result.ContainsKey($key) -and
            $result[$key] -is [hashtable] -and
            $Override[$key] -is [hashtable]) {
            $result[$key] = Merge-JsonDeep -Base $result[$key] -Override $Override[$key]
        } else {
            $result[$key] = $Override[$key]
        }
    }
    return $result
}
