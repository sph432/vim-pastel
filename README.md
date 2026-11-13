# DESCRIPTION
pastel.vim is a Vim plugin that previews the color under the cursor. When the
cursor is on a `#RRGGBB` color code, a small popup shows that color.

The idea is taken from the command-line tool
[sharkdp/pastel](https://github.com/sharkdp/pastel).

# USAGE
Move the cursor onto a color code such as `#FF8800`. A popup with the color
appears next to the cursor and disappears when the cursor leaves the code.

The popup is also hidden in insert mode and when leaving the buffer, and
shown again on leaving insert mode.

# INSTALL
With [vim-plug](https://github.com/junegunn/vim-plug), add this to your
`.vimrc` and run `:PlugInstall`:
```vim
Plug 'https://tools.sphnet.in/git/sph/vim-pastel'
```

Any other plugin manager, or Vim's native package directory
(`~/.vim/pack/*/start/`), works as well.

The plugin does nothing, without raising errors, if Vim lacks the required
features (SEE DEPENDENCIES) or if neither a GUI nor `termguicolors` is in use.

# DEPENDENCIES
- Vim 8.1.1553 or newer, built with `+popupwin`, `+textprop` and `+eval`
- A GUI, or a terminal with `termguicolors` enabled
- Neovim is not supported, as it has no popup windows

# DETAILS
## Detected colors
Only 6-digit hexadecimal codes (`#RRGGBB`) are recognized. A code directly
followed by more hexadecimal digits is not treated as a color.

## Configuration
All options are global variables, set before the plugin loads. The defaults
are shown in parentheses.

- `g:pastel_color_size` (`6`) - size of the color block, vertically in
    half-characters and horizontally in characters; MUST be even
- `g:pastel_bg_size` (`2`) - size of the margin around the color block, in the
    same units; MUST be even
- `g:pastel_offset_x` (`2`) - horizontal placement of the popup relative to the
    color code, in characters:
  - positive: right of the code, its left edge that many columns after the
        code's last column
  - negative: left of the code, its right edge that many columns before the
        code's first column
  - `0`: centered on the code
- `g:pastel_offset_y` (`0`) - vertical placement relative to the cursor line:
  - positive: below, its top edge that many rows below the line
  - negative: above, its bottom edge that many rows above the line
  - `0`: centered on the line
- `g:pastel_black_bg` (`'#000000'`) - background color of the black preview
- `g:pastel_white_bg` (`'#FFFFFF'`) - background color of the white preview
- `g:pastel_trans_fg` (`'#BFBFBF'`) and `g:pastel_trans_bg` (`'#404040'`) -
    the two colors of the checkered "transparent" background

If the popup does not fit on the screen at the requested offset, the offset is
inverted along that axis (eg. `2` becomes `-2`). If it fits neither way, it is
moved onto the screen.

Odd sizes are not implemented yet; the plugin prints a warning and does not
load if one is set.

## Not yet in effect
The following options exist, but nothing reads them yet:
`g:pastel_color_mode`, `g:pastel_color_timer`, `g:pastel_detail_mode`, and the
white and transparent backgrounds. At the moment, the color is always shown on
a black background. SEE [CHANGELOG.md](CHANGELOG.md) for what is planned.

# TECHNICAL INFORMATION
On every `CursorMoved`, the plugin matches `#RRGGBB` against the current line
at the cursor column. If the cursor is on a code, a highlight group is updated
with the color, and a single reused popup window is moved next to the cursor.
The popup content is built from text properties, using the color on a
configurable background.

# META
## LICENSE
SEE [LICENSE.md](LICENSE.md)

## DISCLAIMER
> [!WARNING]
> This repository contains the following code or assets which are LLM-generated
>     or heavily edited using generative LLM tools:
>     - `plugin/pastel.vim`
> These MAY NOT have been manually reviewed, thus MAY contain errors, insecure
>     constructs or licensing artifacts not evident to the authors.

## RULES
This repository follows the conventions defined in
[`meta/conventions`](https://tools.sphnet.in/git/meta/conventions), including
its [CoCo](https://tools.sphnet.in/git/meta/conventions/src/branch/master/CoCo.md)
commit message scheme.

## ATTRIBUTION
- [David Peter](https://github.com/sharkdp) - the original idea of previewing
    a color as a block on black, white and "transparent" backgrounds, as seen in
    his command-line tool [sharkdp/pastel](https://github.com/sharkdp/pastel)
