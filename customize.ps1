#Requires -Version 7.0
<#
.SYNOPSIS
    Frost Glass — live customizer.

.DESCRIPTION
    A small dark-themed control panel (WinForms) that edits your real Windows
    Terminal settings.json in real time. Windows Terminal hot-reloads the file on
    save, so opacity / blur / sheen / font / padding / colour changes appear
    instantly in any open terminal window.

    Controls:
      - Transparency  (opacity 10-100 %)
      - Font size     (8-24 pt)
      - Padding       (0-30 px, applied uniformly)
      - Frosted blur  (useAcrylic on/off)
      - Backlight     (background image: none / glass sheen + strength)
      - Pitch-black background (scheme bg #000000 vs the glass navy #0C0F16)
      - Mica tint     (off by default; it flattens the blur)
      - Presets       : Frosted · Clear glass · Solid black

    Requires PowerShell 7+ (the JSON merge uses -AsHashtable). Launch it via
    Customize.cmd (or: pwsh -NoProfile -File .\customize.ps1).
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- locate settings.json ----------------------------------------------------
$wtPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$script:WT = $wtPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $script:WT) {
    [void][System.Windows.Forms.MessageBox]::Show(
        "Windows Terminal settings.json not found.`nRun install.ps1 first.",
        "Frost Glass Customizer", 'OK', 'Warning')
    return
}

$glassDir  = Join-Path $env:USERPROFILE '.frost-glass'
$sheenPath = Join-Path $glassDir 'sheen.png'

function Read-Cfg { Get-Content $script:WT -Raw | ConvertFrom-Json -AsHashtable }

# One-time safety backup of settings.json when the customizer opens.
try {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item $script:WT "$($script:WT).bak.$stamp" -Force -ErrorAction Stop
} catch { }

# ATOMIC, VALIDATED save. Set-Content truncates-then-writes in place, so Windows
# Terminal's file watcher can read a half-written settings.json and get unstable
# (this could close/disrupt open terminals). Instead: serialize, prove it parses,
# write to a temp file, then atomically swap it in so WT only ever sees a whole,
# valid file.
function Save-Cfg($cfg) {
    $json = $cfg | ConvertTo-Json -Depth 32
    $null = $json | ConvertFrom-Json -AsHashtable      # throws if the JSON is bad -> we never write it
    $tmp  = "$($script:WT).tmp"
    Set-Content -LiteralPath $tmp -Value $json -Encoding utf8
    Move-Item -LiteralPath $tmp -Destination $script:WT -Force   # atomic replace on the same volume
}

# --- palette -----------------------------------------------------------------
$bgDark   = [System.Drawing.Color]::FromArgb(14, 17, 24)
$bgPanel  = [System.Drawing.Color]::FromArgb(22, 27, 37)
$fg       = [System.Drawing.Color]::FromArgb(232, 239, 245)
$accent   = [System.Drawing.Color]::FromArgb(102, 180, 255)
$muted    = [System.Drawing.Color]::FromArgb(120, 134, 154)

# --- form --------------------------------------------------------------------
$form               = New-Object System.Windows.Forms.Form
$form.Text          = "Frost Glass Customizer"
$form.Size          = New-Object System.Drawing.Size(440, 700)
$form.StartPosition = 'CenterScreen'
$form.BackColor     = $bgDark
$form.ForeColor     = $fg
$form.Font          = New-Object System.Drawing.Font("Segoe UI", 9.5)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox   = $false

function New-Label($text, $x, $y, $w, $color) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, 20); $l.ForeColor = $color
    $form.Controls.Add($l); return $l
}
function New-Slider($x, $y, $min, $max, $freq) {
    $t = New-Object System.Windows.Forms.TrackBar
    $t.Location = New-Object System.Drawing.Point($x, $y)
    $t.Size = New-Object System.Drawing.Size(400, 40)
    $t.Minimum = $min; $t.Maximum = $max; $t.TickFrequency = $freq
    $t.SmallChange = 1; $t.LargeChange = [Math]::Max(1, [int](($max - $min) / 10))
    $form.Controls.Add($t); return $t
}
function New-Check($text, $x, $y, $w, $color) {
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $text; $c.Location = New-Object System.Drawing.Point($x, $y)
    $c.Size = New-Object System.Drawing.Size($w, 24); $c.ForeColor = $color
    $form.Controls.Add($c); return $c
}

$title = New-Label "Frost Glass" 20 12 400 $accent
$title.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 15)
$title.Size = New-Object System.Drawing.Size(400, 30)
New-Label "Live control panel — changes apply to Windows Terminal instantly" 20 44 400 $muted | Out-Null

# --- Transparency ------------------------------------------------------------
New-Label "Transparency" 20 78 200 $fg | Out-Null
$opVal = New-Label "" 320 78 100 $accent; $opVal.TextAlign = 'TopRight'
$opBar = New-Slider 18 100 10 100 10

# --- Font size ---------------------------------------------------------------
New-Label "Font size" 20 146 200 $fg | Out-Null
$fontVal = New-Label "" 320 146 100 $accent; $fontVal.TextAlign = 'TopRight'
$fontBar = New-Slider 18 168 8 24 2

# --- Padding -----------------------------------------------------------------
New-Label "Padding" 20 214 200 $fg | Out-Null
$padVal = New-Label "" 320 214 100 $accent; $padVal.TextAlign = 'TopRight'
$padBar = New-Slider 18 236 0 30 5

# --- Frosted blur ------------------------------------------------------------
$acrylicChk = New-Check "Frosted blur (acrylic)  —  off = clear glass" 20 286 400 $fg

# --- Backlight (background image: none / glass sheen) -------------------------
New-Label "Backlight" 20 318 100 $fg | Out-Null
$shVal = New-Label "" 320 318 100 $accent; $shVal.TextAlign = 'TopRight'
$backCombo = New-Object System.Windows.Forms.ComboBox
$backCombo.DropDownStyle = 'DropDownList'
$backCombo.Location = New-Object System.Drawing.Point(120, 316)
$backCombo.Size = New-Object System.Drawing.Size(190, 24)
$backCombo.FlatStyle = 'Flat'; $backCombo.BackColor = $bgPanel; $backCombo.ForeColor = $fg
[void]$backCombo.Items.AddRange(@('None', 'Glass sheen'))
$form.Controls.Add($backCombo)
$sheenBar = New-Slider 18 340 0 100 10

# --- Toggles -----------------------------------------------------------------
$pitchChk = New-Check "Pitch-black background (#000000 instead of glass navy)" 20 388 400 $fg
$micaChk  = New-Check "Mica tint (flattens the blur — usually leave off)" 20 418 400 $muted

# --- Presets -----------------------------------------------------------------
New-Label "Presets" 20 456 200 $muted | Out-Null

function New-Preset($text, $x, $y, $onClick) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size(128, 34)
    $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderColor = $muted
    $b.BackColor = $bgPanel; $b.ForeColor = $fg
    $b.Add_Click($onClick)
    $form.Controls.Add($b); return $b
}

# --- Status ------------------------------------------------------------------
$statusLbl = New-Label "" 20 610 400 $muted
$statusLbl.Size = New-Object System.Drawing.Size(400, 40)

# --- apply logic (debounced) -------------------------------------------------
$script:applying = $false

$applyBlock = {
    try {
        $cfg = Read-Cfg
        if (-not $cfg.profiles)          { $cfg.profiles = @{} }
        if (-not $cfg.profiles.defaults) { $cfg.profiles.defaults = @{} }
        $d = $cfg.profiles.defaults

        $op = [int]$opBar.Value
        $d.useAcrylic  = [bool]$acrylicChk.Checked
        $d.opacity     = $op
        $d.unfocusedAppearance = @{ opacity = [Math]::Max(0, $op - 12) }

        # font size (preserve the existing face)
        if (-not $d.font) { $d.font = @{ face = 'CaskaydiaCove NF' } }
        $d.font.size = [int]$fontBar.Value

        # uniform padding
        $pad = [int]$padBar.Value
        $d.padding = ("{0}, {0}, {0}, {0}" -f $pad)

        # Backlight image: 0 none, 1 glass sheen.
        $backImg = switch ($backCombo.SelectedIndex) {
            1 { if (Test-Path $sheenPath) { $sheenPath } else { $null } }
            default { $null }
        }
        if ($backImg) {
            $d.backgroundImage            = $backImg
            $d.backgroundImageOpacity     = [Math]::Round(($sheenBar.Value / 100.0), 2)
            $d.backgroundImageStretchMode = 'fill'
            $d.backgroundImageAlignment   = 'center'
        } else {
            foreach ($k in 'backgroundImage','backgroundImageOpacity','backgroundImageStretchMode','backgroundImageAlignment') {
                if ($d.ContainsKey($k)) { $d.Remove($k) }
            }
        }

        if ($cfg.themes) {
            foreach ($t in $cfg.themes) {
                if ($t.name -eq 'frostGlass') {
                    if (-not $t.window) { $t.window = @{} }
                    $t.window.useMica = [bool]$micaChk.Checked
                }
            }
        }

        $bg = if ($pitchChk.Checked) { '#000000' } else { '#0C0F16' }
        if ($cfg.schemes) {
            foreach ($s in $cfg.schemes) { if ($s.name -eq 'Frost Glass') { $s.background = $bg } }
        }

        Save-Cfg $cfg

        $backOn = ($backCombo.SelectedIndex -gt 0)
        $opVal.Text   = "$op%"
        $fontVal.Text = "$([int]$fontBar.Value) pt"
        $padVal.Text  = "$([int]$padBar.Value) px"
        $shVal.Text   = if ($backOn) { "$($sheenBar.Value)%" } else { "off" }
        $sheenBar.Enabled = $backOn
        $statusLbl.Text = "Applied  •  $op%  •  blur $([bool]$acrylicChk.Checked)  •  $([int]$fontBar.Value)pt  •  pad $([int]$padBar.Value)  •  backlight $($backCombo.Text)"
        $statusLbl.ForeColor = $accent
    } catch {
        $statusLbl.Text = "Error: $($_.Exception.Message)"
        $statusLbl.ForeColor = [System.Drawing.Color]::FromArgb(255, 143, 166)
    }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 120
$timer.Add_Tick({ $timer.Stop(); if (-not $script:applying) { & $applyBlock } })
$queue = { $timer.Stop(); $timer.Start() }

# wire live controls
$opBar.Add_ValueChanged({ $opVal.Text = "$([int]$opBar.Value)%"; & $queue })
$fontBar.Add_ValueChanged({ $fontVal.Text = "$([int]$fontBar.Value) pt"; & $queue })
$padBar.Add_ValueChanged({ $padVal.Text = "$([int]$padBar.Value) px"; & $queue })
$sheenBar.Add_ValueChanged({ $shVal.Text = "$([int]$sheenBar.Value)%"; & $queue })
$acrylicChk.Add_CheckedChanged($queue)
$backCombo.Add_SelectedIndexChanged($queue)
$pitchChk.Add_CheckedChanged($queue)
$micaChk.Add_CheckedChanged($queue)

# $backlight: 0 none, 1 glass sheen.
function Set-State($op, $acrylic, $backlight, $sheenPct, $pitch, $mica, $fontSize, $pad) {
    $script:applying = $true
    $opBar.Value    = [Math]::Min(100, [Math]::Max(10, [int]$op))
    $acrylicChk.Checked = [bool]$acrylic
    $backCombo.SelectedIndex = [Math]::Min(1, [Math]::Max(0, [int]$backlight))
    $sheenBar.Value = [Math]::Min(100, [Math]::Max(0, [int]$sheenPct))
    $pitchChk.Checked   = [bool]$pitch
    $micaChk.Checked    = [bool]$mica
    $fontBar.Value  = [Math]::Min(24, [Math]::Max(8, [int]$fontSize))
    $padBar.Value   = [Math]::Min(30, [Math]::Max(0, [int]$pad))
    $script:applying = $false
    & $applyBlock
}

# The shipped default look (matches a fresh install.ps1). Backlight off (0).
$script:DefaultLook = { Set-State 50 $true 0 0 $false $false 11 10 }

# Presets keep the current font size + padding (they only touch the glass look).
# Backlight: 0 none, 1 glass sheen.
New-Preset "Frosted"     20  478 { Set-State 55  $true  1 50 $false $false $fontBar.Value $padBar.Value } | Out-Null
New-Preset "Clear glass" 156 478 { Set-State 65  $false 1 30 $false $false $fontBar.Value $padBar.Value } | Out-Null
New-Preset "Solid black" 292 478 { Set-State 100 $false 0 0  $true  $false $fontBar.Value $padBar.Value } | Out-Null

# --- Default (accent) + Close row --------------------------------------------
$defaultBtn = New-Object System.Windows.Forms.Button
$defaultBtn.Text = "Reset to Default"; $defaultBtn.Location = New-Object System.Drawing.Point(20, 520)
$defaultBtn.Size = New-Object System.Drawing.Size(264, 34)
$defaultBtn.FlatStyle = 'Flat'; $defaultBtn.FlatAppearance.BorderColor = $accent
$defaultBtn.BackColor = $bgPanel; $defaultBtn.ForeColor = $accent
$defaultBtn.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5)
$defaultBtn.Add_Click($script:DefaultLook)
$form.Controls.Add($defaultBtn)

$closeBtn = New-Object System.Windows.Forms.Button
$closeBtn.Text = "Close"; $closeBtn.Location = New-Object System.Drawing.Point(292, 522)
$closeBtn.Size = New-Object System.Drawing.Size(128, 30)
$closeBtn.FlatStyle = 'Flat'; $closeBtn.FlatAppearance.BorderColor = $muted
$closeBtn.BackColor = $bgPanel; $closeBtn.ForeColor = $fg
$closeBtn.Add_Click({ $form.Close() })
$form.Controls.Add($closeBtn)
$tip = New-Label "Tip: keep a terminal window open to watch changes live." 20 564 400 $muted

# --- initialise from current settings ----------------------------------------
try {
    $c0 = Read-Cfg
    $d0 = $c0.profiles.defaults
    $curOp    = if ($d0 -and $d0.opacity)    { [int]$d0.opacity } else { 55 }
    $curAcr   = if ($d0 -and $d0.ContainsKey('useAcrylic')) { [bool]$d0.useAcrylic } else { $true }
    $curBack = 0
    if ($d0 -and $d0.ContainsKey('backgroundImage') -and $d0.backgroundImage) { $curBack = 1 }
    $curShPct = if ($d0 -and $d0.backgroundImageOpacity) { [int]([double]$d0.backgroundImageOpacity * 100) } else { 50 }
    $curFont  = if ($d0 -and $d0.font -and $d0.font.size) { [int]$d0.font.size } else { 11 }
    $curPad   = 14
    if ($d0 -and $d0.padding) {
        $pv = $d0.padding
        if ($pv -is [string]) { $curPad = [int](($pv -split '[,\s]+' | Where-Object { $_ -ne '' })[0]) }
        elseif ($pv -is [int] -or $pv -is [double]) { $curPad = [int]$pv }
    }
    $curMica  = $false
    if ($c0.themes) { foreach ($t in $c0.themes) { if ($t.name -eq 'frostGlass' -and $t.window) { $curMica = [bool]$t.window.useMica } } }
    $curPitch = $false
    if ($c0.schemes) { foreach ($s in $c0.schemes) { if ($s.name -eq 'Frost Glass' -and $s.background -eq '#000000') { $curPitch = $true } } }
    Set-State $curOp $curAcr $curBack $curShPct $curPitch $curMica $curFont $curPad
} catch {
    Set-State 55 $true 1 50 $false $false 11 14
}

[void]$form.ShowDialog()
$timer.Dispose()
$form.Dispose()
