#Requires -Version 7.0
<#
.SYNOPSIS
    Installs the Frost Glass terminal look.

.DESCRIPTION
    - Installs oh-my-posh, a Nerd Font, PSReadLine and Terminal-Icons (winget).
    - MERGES the glass scheme + acrylic defaults + theme into your existing
      Windows Terminal settings.json (your profile GUIDs are preserved).
    - Drops the Oh My Posh theme at  ~/.frost-glass/frost-glass.omp.json
    - Backs up and installs the PowerShell profile.

    Everything is backed up with a .bak.<timestamp> suffix before it is touched.
    Re-running is safe (idempotent).

.NOTES
    Run from the repo root:   pwsh -File .\install.ps1
    Requires PowerShell 7+ (the JSON merge uses -AsHashtable). Install with:
        winget install --id Microsoft.PowerShell -e
#>

[CmdletBinding()]
param(
    [int]$Opacity = 50,
    [string]$Font  = "CaskaydiaCove",  # must match the installed Nerd Font family name
    [switch]$SkipInstalls
)

$ErrorActionPreference = 'Stop'
$Root  = $PSScriptRoot
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Info($m)  { Write-Host "  $m" -ForegroundColor Cyan }
function Ok($m)    { Write-Host "  $m" -ForegroundColor Green }
function Warn($m)  { Write-Host "  $m" -ForegroundColor Yellow }

function Backup($path) {
    if (Test-Path $path) {
        $bak = "$path.bak.$Stamp"
        Copy-Item $path $bak -Force
        Info "backed up -> $bak"
    }
}

# Per-user Nerd Font install straight from the Nerd Fonts release (no admin, and
# winget has no reliable CaskaydiaCove package). Registers the real face name so
# it matches profiles.defaults.font.face exactly.
function Install-NerdFont {
    param([string]$Asset = 'CascadiaCode')
    $url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$Asset.zip"
    $zip = Join-Path $env:TEMP "$Asset.nf.zip"
    $tmp = Join-Path $env:TEMP "$Asset.nf"
    try {
        Info "Downloading $Asset Nerd Font..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -ErrorAction Stop
    } catch {
        Warn "Font download failed: $($_.Exception.Message)"
        return $false
    }
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Expand-Archive $zip $tmp -Force
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
    Add-Type -AssemblyName System.Drawing

    # P/Invoke so newly installed fonts go live for apps started afterwards
    # (registry alone doesn't notify the running font subsystem, so Windows
    # Terminal would report "Unable to find the following fonts" until re-login).
    if (-not ('GlassFontApi' -as [type])) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
public class GlassFontApi {
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResourceW(string p);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint f, uint t, out IntPtr r);
    public static void Broadcast() { IntPtr r; SendMessageTimeout((IntPtr)0xffff, 0x001D, IntPtr.Zero, IntPtr.Zero, 0, 3000, out r); }
}
"@
    }

    $regKey = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    # Install the standard variable-width faces; skip Mono/Propo variants to keep it tidy.
    $files = Get-ChildItem $tmp -Recurse -Filter *.ttf | Where-Object { $_.Name -notmatch 'Mono|Propo' }
    if (-not $files) { $files = Get-ChildItem $tmp -Recurse -Filter *.ttf }
    $n = 0
    $regularFace = $null
    foreach ($f in $files) {
        $dest = Join-Path $fontDir $f.Name
        Copy-Item $f.FullName $dest -Force
        # Registry key must be UNIQUE PER FILE. Several style files (Regular/Italic/
        # Bold/...) share one family name, so keying by family name would overwrite
        # entries and leave most files unregistered. Use the filename stem instead.
        $stem = [IO.Path]::GetFileNameWithoutExtension($f.Name)
        New-ItemProperty -Path $regKey -Name "$stem (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
        [GlassFontApi]::AddFontResourceW($dest) | Out-Null
        # Capture the base (Regular-weight) family name; that's what font.face must match.
        if ($f.Name -match '-Regular\.ttf$' -and -not $regularFace) {
            $pfc = New-Object System.Drawing.Text.PrivateFontCollection
            $pfc.AddFontFile($dest)
            $regularFace = $pfc.Families[0].Name
            $pfc.Dispose()
        }
        $n++
    }
    [GlassFontApi]::Broadcast()
    if (-not $regularFace) {
        $pfc = New-Object System.Drawing.Text.PrivateFontCollection
        $pfc.AddFontFile((Join-Path $fontDir ($files | Select-Object -First 1).Name))
        $regularFace = $pfc.Families[0].Name; $pfc.Dispose()
    }
    Ok "installed $n font file(s) -> $fontDir  (family: $regularFace)"
    return $regularFace
}

Write-Host "`nFrost Glass installer`n----------------------" -ForegroundColor Magenta

# The exact family name Windows Terminal must reference. Nerd Fonts v3 uses the
# short " NF" family (e.g. "CaskaydiaCove NF"); the font install below overrides
# this with whatever the downloaded font actually reports.
$FontFace = "$Font NF"

# --- 1. Dependencies ---------------------------------------------------------
if (-not $SkipInstalls) {
    # Modern TLS for all downloads (older Windows defaults can break PSGallery/GitHub).
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

    # Oh My Posh via winget when available; otherwise point the user at the docs.
    # (winget ships with App Installer on Windows 11, but not every machine has it.)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Info "Installing Oh My Posh via winget..."
        winget install --id JanDeDobbeleer.OhMyPosh -e --source winget `
            --accept-source-agreements --accept-package-agreements 2>$null
        Ok "Oh My Posh ready"
    } elseif (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        Ok "Oh My Posh already installed"
    } else {
        Warn "winget not found. Install Oh My Posh from https://ohmyposh.dev/docs/installation/windows"
    }

    # Nerd Font (CaskaydiaCove) straight from the Nerd Fonts release.
    $face = Install-NerdFont -Asset 'CascadiaCode'
    if ($face) { $FontFace = $face }
    else { Warn "Install 'CaskaydiaCove Nerd Font' from https://www.nerdfonts.com manually." }

    # PowerShell modules. On a fresh machine PSGallery needs the NuGet provider and
    # trust set, or Install-Module blocks on an interactive prompt; set both up front.
    Info "Installing PowerShell modules..."
    try {
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
        }
        if ((Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue).InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        }
    } catch { Warn "Could not pre-configure PSGallery: $($_.Exception.Message)" }

    foreach ($m in 'PSReadLine','Terminal-Icons') {
        if (-not (Get-Module -ListAvailable -Name $m)) {
            try {
                Install-Module $m -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                Ok "$m installed"
            } catch { Warn "$m install skipped: $($_.Exception.Message)" }
        } else { Ok "$m already installed" }
    }
}

# --- 2. Oh My Posh theme -----------------------------------------------------
$glassDir = Join-Path $env:USERPROFILE '.frost-glass'
New-Item -ItemType Directory -Force -Path $glassDir | Out-Null
Copy-Item (Join-Path $Root 'ohmyposh/frost-glass.omp.json') (Join-Path $glassDir 'frost-glass.omp.json') -Force
Ok "theme -> $glassDir\frost-glass.omp.json"
$sheenSrc = Join-Path $Root 'assets/sheen.png'
if (Test-Path $sheenSrc) {
    Copy-Item $sheenSrc (Join-Path $glassDir 'sheen.png') -Force
    Ok "sheen -> $glassDir\sheen.png"
}

# --- 3. PowerShell profile ---------------------------------------------------
$profileTarget = $PROFILE.CurrentUserAllHosts
New-Item -ItemType Directory -Force -Path (Split-Path $profileTarget) | Out-Null
Backup $profileTarget
Copy-Item (Join-Path $Root 'powershell/Microsoft.PowerShell_profile.ps1') $profileTarget -Force
Ok "profile -> $profileTarget"

# --- 4. Windows Terminal settings.json (MERGE, don't clobber) ----------------
$wtPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$wt = $wtPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
$freshSettings = $false

if (-not $wt) {
    # No settings.json yet (Windows Terminal installed but never launched, or
    # running on defaults only). Create one at the canonical location so a fresh
    # machine still gets the look. Windows Terminal auto-generates its dynamic
    # profiles (PowerShell, cmd, WSL) on next launch and merges them alongside
    # these values.
    $wt = $wtPaths[0]
    New-Item -ItemType Directory -Force -Path (Split-Path $wt) | Out-Null
    $freshSettings = $true
    Info "No existing settings.json found - creating a fresh one at:"
    Info "  $wt"
}

Backup $wt
if ($freshSettings) {
    $cfg = [ordered]@{ '$schema' = 'https://aka.ms/terminal-profiles-schema' }
} else {
    $cfg = Get-Content $wt -Raw | ConvertFrom-Json -AsHashtable
}

# embedded schemes from the repo (dark default + optional light variant)
$scheme      = Get-Content (Join-Path $Root 'schemes/frost-glass.json')       -Raw | ConvertFrom-Json -AsHashtable
$schemeLight = Get-Content (Join-Path $Root 'schemes/frost-glass-light.json')  -Raw | ConvertFrom-Json -AsHashtable

# 4a. schemes (replace existing entries if present). Both are made available; the
#     dark "Frost Glass" is set as the default below. Switch to the light one by
#     setting profiles.defaults.colorScheme = "Frost Glass Light".
if (-not $cfg.schemes) { $cfg.schemes = @() }
$cfg.schemes = @($cfg.schemes | Where-Object { $_.name -ne 'Frost Glass' -and $_.name -ne 'Frost Glass Light' })
$cfg.schemes += $scheme
$cfg.schemes += $schemeLight

# 4b. glass defaults for every profile
if (-not $cfg.profiles)          { $cfg.profiles = @{} }
if (-not $cfg.profiles.defaults) { $cfg.profiles.defaults = @{} }
$d = $cfg.profiles.defaults
$d.useAcrylic  = $true
$d.opacity     = $Opacity
$d.colorScheme = 'Frost Glass'
$d.padding     = '10, 10, 10, 10'
$d.font        = @{ face = $FontFace; size = 11 }
$d.scrollbarState = 'hidden'
$d.cursorShape    = 'filledBox'
$d.unfocusedAppearance = @{ opacity = [math]::Max(0, $Opacity - 12) }

# The backlit-glass sheen ships bundled (~/.frost-glass/sheen.png) but is OFF in the
# default look — toggle it live in customize.ps1. Clear any prior sheen keys so a
# re-run reflects the default.
foreach ($k in 'backgroundImage','backgroundImageOpacity','backgroundImageStretchMode','backgroundImageAlignment') {
    if ($d.ContainsKey($k)) { $d.Remove($k) }
}

# 4c. theme. Mica is deliberately OFF: WT's Mica backdrop paints a near-solid
#     desktop tint that suppresses the acrylic desktop-blur (the actual frosted
#     glass), leaving the window looking flat. Acrylic alone gives the real look.
if (-not $cfg.themes) { $cfg.themes = @() }
$cfg.themes = @($cfg.themes | Where-Object { $_.name -ne 'frostGlass' })
$cfg.themes += @{
    name   = 'frostGlass'
    window = @{ applicationTheme = 'dark'; useMica = $false }
    # Layered depth: darker/more-opaque title strip + raised lighter active tab,
    # over the see-through body. Different materials read as real depth.
    tab    = @{ background = '#222C3CE6'; unfocusedBackground = '#161C27CC'; showCloseButton = 'hover' }
    tabRow = @{ background = '#080B11E6'; unfocusedBackground = '#080B11B3' }
}
$cfg.theme = 'frostGlass'

# 4d. opacity keybindings (idempotent) - the Ctrl+Shift+Up/Down the README promises.
#     Written in Windows Terminal's modern actions + keybindings schema with
#     distinct ids, so WT keeps the +5 / -5 deltas apart instead of collapsing
#     them into one deltaless action on its next save.
$glassIds  = @('Glass.opacityUp','Glass.opacityDown')
$glassKeys = @('ctrl+shift+up','ctrl+shift+down')

if (-not $cfg.actions) { $cfg.actions = @() }
$cfg.actions = @($cfg.actions | Where-Object { $_.id -notin $glassIds -and $_.command.action -ne 'adjustOpacity' })
$cfg.actions += @{ id = 'Glass.opacityUp';   command = @{ action = 'adjustOpacity'; delta = 5 } }
$cfg.actions += @{ id = 'Glass.opacityDown'; command = @{ action = 'adjustOpacity'; delta = -5 } }

if (-not $cfg.keybindings) { $cfg.keybindings = @() }
$cfg.keybindings = @($cfg.keybindings | Where-Object { $_.id -notin $glassIds -and $_.keys -notin $glassKeys })
$cfg.keybindings += @{ id = 'Glass.opacityUp';   keys = 'ctrl+shift+up' }
$cfg.keybindings += @{ id = 'Glass.opacityDown'; keys = 'ctrl+shift+down' }

# 4e. on a brand-new file, default to PowerShell 7 so the profile + theme load
if ($freshSettings) {
    $cfg.defaultProfile = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
}

$cfg | ConvertTo-Json -Depth 32 | Set-Content $wt -Encoding utf8
if ($freshSettings) { Ok "settings.json created" } else { Ok "settings.json merged (GUIDs preserved)" }

Write-Host "`nDone." -ForegroundColor Green
Info "Restart Windows Terminal. Make sure Settings > Personalisation > Colors >"
Info "'Transparency effects' is ON, and you're not in battery-saver mode."
Info "Nudge opacity live with Ctrl+Shift+Up / Ctrl+Shift+Down."
