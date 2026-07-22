# Contributing to Frost Glass

Thanks for your interest! This is a small, self-contained Windows Terminal
theme + installer, so contributions are easy to test and review.

## Ground rules

- **Keep it native.** The goal is the frosted-glass read using what Windows
  Terminal exposes (acrylic, Mica, transparency) — no external compositors or
  binaries. See the "Scope, honestly" note in the README.
- **The installer must stay idempotent and reversible.** Anything `install.ps1`
  overwrites has to be backed up to `*.bak.<timestamp>` first, and
  `uninstall.ps1` has to restore it. Re-running `install.ps1` twice should be a
  no-op, not a mess.
- **Never merge machine-specific values into tracked files.** `terminal/settings.json`
  is a *reference* file: well-known GUIDs, `%USERPROFILE%`, no local paths or
  usernames. The installer merges into the user's real `settings.json`; it never
  clobbers their profile GUIDs.

## Testing a change

Do the full round-trip on a real Windows 11 + Windows Terminal machine
(a throwaway user profile is ideal):

```powershell
pwsh -ExecutionPolicy Bypass -File .\install.ps1
# restart Windows Terminal, confirm the look
pwsh -File .\uninstall.ps1
# confirm it reverts to your prior settings.json + profile
```

Verify: font renders (no tofu boxes), `Ctrl+Shift+Up/Down` nudges opacity, and
the `customize.ps1` panel writes changes live.

## Palette / prompt changes

- Colors live in `schemes/frost-glass.json` (16 ANSI + bg/fg/cursor/selection)
  and the `palette` block of `ohmyposh/frost-glass.omp.json`. Keep the two in
  sync and update the palette table in the README if you change a named hue.
- PSReadLine syntax colors are in `powershell/Microsoft.PowerShell_profile.ps1`.

## Pull requests

- One focused change per PR; describe what you tested and on which Windows build.
- Screenshots/GIFs are hugely appreciated for any visual change.
- By contributing you agree your work is licensed under the [MIT License](LICENSE).

## Roadmap / good first issues

Open ideas are tracked as GitHub Issues — a light "bright glass" variant, a
faint background sheen preset, VS Code / WezTerm / Alacritty palette ports, and
a comment-preserving `settings.json` merge. Grab one, or open an issue to
propose your own.
