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

## Scrolling
In Vims that have the `WinScrolled` event (9.0 and newer), the popup follows
the code when the window is scrolled. Older versions only update the popup on
cursor movement, so scrolling without moving the cursor leaves it in place.

## Configuration
All options are global variables, set in your `.vimrc` or at any time later
with `:let`; a change takes effect the next time the popup is shown. The
defaults are shown in parentheses.

- `g:pastel_color_mode` (`'b'`) - the previews to show and their layout, a
    string of block letters, left to right:
  - `b`: the color on black
  - `w`: the color on white
  - `t`: the color on a checkered "transparent" background, as in
        sharkdp/pastel
  - `|`: the blocks after it go in a new row below

  For example, `'t'` is a single block, `'bw'` shows black and white side by
  side, and `'t|bw'` shows a checkered block with black and white below it.
  Each block has its own margin, and all blocks are the same size. Rows with
  fewer blocks are padded with the default color. Blocks may split a line
  between them: with odd sizes, the line where two rows meet shows the bottom
  of the upper block over the top of the lower one.

  Any other value, for now (including a leading, trailing or doubled `|`),
  prints a warning and the plugin does not load.
- `g:pastel_color_size` (`6`) - size of the color block, vertically in
    half-characters and horizontally in characters
- `g:pastel_bg_size` (`2`) - size of the margin around the color block, in the
    same units
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
inverted along that axis (eg. `2` becomes `-2`). If there is no room on either
side of the code, the popup is placed below the code's line instead, or above
it if the vertical offset is negative or there is no room below; the vertical
offset is used for the distance, or `1` if it is `0`. If it fits nowhere, it is
moved onto the screen as far as possible.

A popup larger than the screen is clipped, not wrapped, and a warning is shown
once.

Sizes may be odd, in which case the color block starts or ends in the middle
of a line. If the total height is odd, the lower half of the last line is left
in the default color (`Normal`), as a line is always two half-characters high.

## Not yet in effect
The following options exist, but nothing reads them yet:
`g:pastel_color_timer`, `g:pastel_detail_mode`, and the `2` and `3` block
letters of `g:pastel_color_mode`. SEE [CHANGELOG.md](CHANGELOG.md) for what is
planned.

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
