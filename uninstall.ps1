#Requires -Version 7.0
<#
.SYNOPSIS
    Reverts the Frost Glass look by restoring the most recent .bak backups.
.NOTES
    This restores settings.json and your PowerShell profile from the newest
    backup install.ps1 created. It does not uninstall oh-my-posh / fonts /
    modules — remove those with winget/Uninstall-Module if you want.
#>
$ErrorActionPreference = 'Stop'

function Restore-Latest($path) {
    $dir  = Split-Path $path
    $name = Split-Path $path -Leaf
    $bak  = Get-ChildItem $dir -Filter "$name.bak.*" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($bak) {
        Copy-Item $bak.FullName $path -Force
        Write-Host "restored $path  <-  $($bak.Name)" -ForegroundColor Green
    } else {
        Write-Host "no backup found for $path" -ForegroundColor Yellow
    }
}

$wtPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$wt = $wtPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($wt) { Restore-Latest $wt }

Restore-Latest $PROFILE.CurrentUserAllHosts

Remove-Item (Join-Path $env:USERPROFILE '.frost-glass') -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "`nReverted. Restart Windows Terminal." -ForegroundColor Magenta
