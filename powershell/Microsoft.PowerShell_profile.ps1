# ==============================================================================
#  Frost Glass — PowerShell profile
#  Applies to pwsh 7+ (recommended) and Windows PowerShell 5.1.
#  install.ps1 copies this to your $PROFILE and drops the theme at
#  $env:USERPROFILE\.frost-glass\frost-glass.omp.json
# ==============================================================================

# --- Encoding: required for Nerd Font glyphs in the prompt -------------------
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- Oh My Posh --------------------------------------------------------------
$GlassTheme = Join-Path $env:USERPROFILE '.frost-glass\frost-glass.omp.json'
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    if (Test-Path $GlassTheme) {
        oh-my-posh init pwsh --config $GlassTheme | Invoke-Expression
    } else {
        # Fall back to a bundled theme if the custom one isn't in place yet.
        oh-my-posh init pwsh | Invoke-Expression
    }
    # Transient prompt (collapses old prompts to a clean ❯) ships in the theme's
    # `transient_prompt` block on modern oh-my-posh. Older builds needed a cmdlet:
    if (Get-Command Enable-PoshTransientPrompt -ErrorAction SilentlyContinue) {
        Enable-PoshTransientPrompt
    }
}

# --- Terminal-Icons (glyphs for ls / dir) ------------------------------------
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}

# --- PSReadLine: predictions + Frost Glass syntax colors --------------------
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine

    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -BellStyle None

    # Inline predictions need an interactive VT host; skip when output is redirected
    # (e.g. running a script) so we don't spew errors.
    if (-not [Console]::IsOutputRedirected) {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -PredictionViewStyle ListView
    }

    # Frosted palette mapped onto shell tokens
    Set-PSReadLineOption -Colors @{
        Command            = "#66B4FF"  # glass blue
        Parameter          = "#B49BFF"  # lavender
        Operator           = "#5FE6DF"  # aqua
        Variable           = "#5FE39A"  # mint
        String             = "#FFD36B"  # amber
        Number             = "#FFA7BA"  # rose
        Type               = "#86F0EB"  # bright aqua
        Comment            = "#5A6678"  # lifted slate (readable on glass)
        Keyword            = "#CBB9FF"  # bright lavender
        Member             = "#E8EFF5"  # frost
        InlinePrediction   = "#5A6678"  # dim ghost text
        Selection          = "#34465E"
        Default            = "#E8EFF5"
    }

    # History search with the up/down arrows
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
}

# --- Quality-of-life ---------------------------------------------------------
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function gs { git status @args }
function gl { git log --oneline --graph --decorate -20 @args }
Set-Alias ll Get-ChildItem

# Live-tweak transparency from the shell (Windows Terminal only)
function Set-GlassOpacity([int]$Percent = 70) {
    Write-Host "Use Ctrl+Shift+Up / Ctrl+Shift+Down in Windows Terminal to nudge opacity." -ForegroundColor Cyan
    Write-Host "Target opacity: $Percent% — set it in settings.json > profiles.defaults.opacity" -ForegroundColor Cyan
}
