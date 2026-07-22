# Fonts

The prompt uses **Nerd Font glyphs** (the git branch icon, folder icon, OS icon,
rounded `\ue0b6 / \ue0b4` capsule caps, etc.). Without a Nerd Font you'll see
tofu boxes (□) instead of icons.

`install.ps1` downloads and registers **CaskaydiaCove Nerd Font** straight from
the [Nerd Fonts release](https://github.com/ryanoasis/nerd-fonts/releases/latest)
(no admin, no winget). If that fails (e.g. no network at install time):

1. Download **CaskaydiaCove Nerd Font** (or any Nerd Font you like) from
   <https://www.nerdfonts.com/font-downloads>
2. Select all `.ttf` files → right-click → **Install for all users**
3. Set it in `settings.json` → `profiles.defaults.font.face`
   (must match the installed family exactly. Nerd Fonts v3 registers the short
   name — for CascadiaCode that's `CaskaydiaCove NF`, not `CaskaydiaCove Nerd Font`.
   Check with `[System.Drawing.Text.PrivateFontCollection]` or the Fonts control panel).

Good alternatives with strong ligatures for a glassy feel:
`FiraCode Nerd Font`, `JetBrainsMono Nerd Font`, `Maple Mono NF`.
