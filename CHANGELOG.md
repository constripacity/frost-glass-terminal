# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions use
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-07-22

First public release. A self-contained, fully reversible Windows Terminal
frosted-glass look: acrylic blur, a cool luminous palette, and a rounded-capsule
Oh My Posh prompt, installed and merged by one PowerShell script.

### Added
- One-shot `install.ps1` that installs dependencies (oh-my-posh, CaskaydiaCove
  Nerd Font, PSReadLine, Terminal-Icons) and **merges** the glass scheme, acrylic
  defaults, and theme into your existing `settings.json` without touching your
  profile GUIDs.
- `uninstall.ps1` that restores the newest `*.bak.<timestamp>` backups.
- Live `customize.ps1` / `Customize.cmd` WinForms panel: opacity, blur, font size,
  padding, backlight sheen, pitch-black, presets, and one-click **Reset to Default**.
  Writes `settings.json` atomically (temp file + swap) so Windows Terminal never
  reads a half-written file.
- "Frost Glass" color scheme (`schemes/frost-glass.json`), an optional bright
  **"Frost Glass Light"** scheme (`schemes/frost-glass-light.json`), and a 2-line
  rounded Oh My Posh theme (`ohmyposh/frost-glass.omp.json`).
- `Ctrl+Shift+Up/Down` live opacity nudge, in WT 1.22+'s split `actions` +
  `keybindings` schema.
- Bundled backlit-glass sheen (`assets/sheen.png`), off by default.
- MIT license, contributing guide.

### Fixed
- Font renders instead of tofu boxes: `font.face` matches the family Nerd Fonts v3
  actually registers (`CaskaydiaCove NF`); the installer derives the real name
  from the downloaded file.
- Font installs *and* registers reliably: dead winget id
  `DEVCOM.NerdFonts.CaskaydiaCove` replaced with a direct Nerd Fonts release
  download; each face registered under a unique key and broadcast via
  `AddFontResource` + `WM_FONTCHANGE`.
- Fresh machines: installer creates/merges `settings.json` even when Windows
  Terminal has never generated one.
- No red errors at shell start: dropped the removed `Enable-PoshTransientPrompt`
  and guarded PSReadLine predictions on non-interactive hosts.
- Mica off by default (it suppresses the acrylic blur and flattens the look).

[1.0.0]: https://github.com/constripacity/frost-glass-terminal/releases/tag/v1.0.0
