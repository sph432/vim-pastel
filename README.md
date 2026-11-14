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

The documentation is also available inside Vim as `:help pastel`. Plugin
managers generate its tags; with a native package directory, run
`:helptags ALL` once.

# DEPENDENCIES
- Vim 8.1.1553 or newer, built with `+popupwin`, `+textprop` and `+eval`
- A GUI, or a terminal with `termguicolors` enabled
- Neovim is not supported, as it has no popup windows

# DETAILS
## Detected colors
These hexadecimal codes are recognized:
- `#RGB` and `#RRGGBB`
- `#RGBA` and `#RRGGBBAA`, or `#AARRGGBB`, see `g:pastel_alpha_position`

`#ARGB` is not recognized: the 4-digit form is always `#RGBA`. The code must
not be preceded or followed by a letter, digit or underscore, so that eg.
`#define` or `#abcdefg1` are not taken for colors.

These functions are recognized, in upper or lower case, with the comma notation
(`rgb(255, 0, 0, 0.5)`) and the space and slash one (`rgb(255 0 0 / 50%)`),
except where noted:
- `rgb()` and `rgba()`, which are the same: the channels are numbers from 0 to
    255 or percentages, and may be mixed
- `hsl()` and `hsla()`, which are the same: the hue is a number of degrees or
    an angle (`deg`, `grad`, `rad`, `turn`), the saturation and the lightness
    are percentages, or plain numbers of percents
- `hwb()` and `hwba()`: the hue as in `hsl()`, the whiteness and the
    blackness as percentages, or plain numbers of percents; as in CSS, only
    with the space and slash notation. If they add up to 100% or more, the
    color is a gray
- `hsv()` and `hsva()`, as in Less.js: the hue as in `hsl()`, the saturation
    and the value as percentages, or, as in Less, plain numbers from 0 to 1

The alpha is a number from 0 to 1 or a percentage. Values out of range are
limited to it, and a hue wraps around. The keyword `none` counts as 0, in the
space and slash notation. A function with any other mistake, eg. a missing
component, is ignored.

A code with an alpha channel is shown blended over each background: on black
it looks darker, on white lighter, and on the checkered background the
checkers show through. Fully opaque (`FF`) codes look like their 6-digit
form, and `00` shows the background alone. The blending is done directly on
the sRGB values. If you set a background color option to something other than
a `#RRGGBB` color, the alpha is ignored for that background.

Lines longer than `'synmaxcol'` (3000 by default, 0 meaning no limit) are not
searched, as that would slow down moving the cursor in eg. minified or
machine-generated files: it takes seconds on a line of millions of characters.

No color is previewed for a code in a closed fold, as it is not displayed
there.

## Scrolling
In Vims that have the `WinScrolled` event (8.2.4713 and newer), the popup
follows the code when the window is scrolled. SEE Known issues for older
versions.

## Known issues
- In Vims older than 8.2.4713, which lack the `WinScrolled` event, the popup
    is only updated on cursor movement; scrolling the window without moving
    the cursor leaves the popup at its old position on the screen.
- In Vims older than 8.2.0325, which lack the `SafeState` event, closing or
    opening a fold without moving the cursor leaves the popup as it was until
    the cursor moves.
- In Vims older than 8.1.1580, which lack popup masks, the area of a layout
    that no block covers (eg. right of the shorter row of `'wk|t'`) hides the
    text under it, instead of being transparent. A single row of blocks is not
    affected.

## Configuration
All options are global variables, set in your `.vimrc` or at any time later
with `:let`; a change takes effect the next time the popup is shown. The
defaults are shown in parentheses.

A value that is not valid for its option (eg. a float or a list for a size, or
`'FIRST'` for `g:pastel_alpha_position`) raises no error: a short warning is
shown, once per value, and the default is used instead. Numbers may also be
given as strings, eg. `'6'`.

- `g:pastel_color_mode` (`'k'`) - the previews to show and their layout, a
    string of block letters, left to right:
  - `k`: the color on black
  - `w`: the color on white
  - `t`: the color on a checkered "transparent" background, as in
        sharkdp/pastel
  - `2`: the color on black and white, alternating
  - `3`: the color on black, checkered and white, alternating, in that order
  - `|`: the blocks after it go in a new row below

  For example, `'t'` is a single block, `'kw'` shows black and white side by
  side, and `'t|kw'` shows a checkered block with black and white below it.
  Each block has its own margin, and all blocks are the same size. The area
  not covered by a block, eg. right of a shorter row, is transparent: the text
  under it stays visible. Blocks may split a line between them: with odd
  sizes, the line where two rows meet shows the bottom of the upper block over
  the top of the lower one. A half line that has a block on one side and
  nothing on the other has the default color on the empty side.

  Any other value (including a leading, trailing or doubled `|`) prints a
  warning. At startup the plugin does not load; when set later, the previous
  layout stays.
- `g:pastel_color_timer` (`5`) - seconds between the backgrounds of `2` and `3`
    blocks changing, `0.1` or more, fractions allowed; less than that turns
    alternating off, showing the first background. The timer only runs while
    the popup is shown.
- `g:pastel_color_size` (`6`) - size of the color block, vertically in
    half-characters and horizontally in characters, from 1 to 1000
- `g:pastel_bg_size` (`2`) - size of the margin around the color block, in the
    same units, from 0 to 1000
- `g:pastel_alpha_position` (`'auto'`) - where the alpha is in 8-digit
    hexadecimal codes:
  - `'last'`: `#RRGGBBAA`, as in CSS
  - `'first'`: `#AARRGGBB`, as in Android
  - `'auto'`: `'first'` in the filetypes of `g:pastel_alpha_first_filetypes`,
        `'last'` in the others, and a short note (`pastel: assuming ...`) the
        first time an 8-digit code is found in a buffer, as it is a guess

  The variable `b:pastel_alpha_position`, if set, takes precedence in its
  buffer; eg. `autocmd FileType cs let b:pastel_alpha_position='first'`. The
  4-digit form is not affected, as it is always `#RGBA`.
- `g:pastel_alpha_first_filetypes` (`['java', 'kotlin']`) - the filetypes
    where `'auto'` means `'first'`
- `g:pastel_ignore_filetypes` (`['gitcommit', '*sql*']`) - the filetypes where
    no colors are looked for, as a list of glob patterns (`*`, `?`, `[abc]`,
    `{a,b}`), each matched against the whole filetype or any part of a
    compound one: here `gitcommit`, where `#123` is an issue and not a `#RGB`
    color, and `sql` and its variants (`mysql`, `plsql`, ...), for their very
    long lines
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

The colors are `#RRGGBB` ones or color names Vim knows, eg. `'red'` or
`'NONE'`.

The popup does not cover the tabline, the status line of the last window or the
command line. If the popup does not fit on the screen at the requested offset,
the offset is inverted along that axis (eg. `2` becomes `-2`). If there is no
room on either side of the code, the popup is placed below the code's line
instead, or above it if the vertical offset is negative or there is no room
below; the vertical offset is used for the distance, or `1` if it is `0`. If it
fits nowhere, it is moved onto the screen as far as possible.

A popup larger than the screen is clipped, not wrapped, and a warning is shown
once; only the part on the screen is drawn.

Sizes may be odd, in which case the color block starts or ends in the middle
of a line. If the total height is odd, the lower half of the last line is left
in the default color (`Normal`), as a line is always two half-characters high.

## Not yet in effect
The option `g:pastel_detail_mode` exists, but nothing reads it yet. SEE
[CHANGELOG.md](CHANGELOG.md) for what is planned.

# TECHNICAL INFORMATION
On every `CursorMoved`, the plugin matches the notations of colors (the
hexadecimal codes and the functions) against the current line at the cursor
column. Each notation is a pattern finding candidates and a parser turning one
into a color, `[red, green, blue, alpha]`. If the cursor is on a color, it is
blended over each of the four background colors (black, white and the two
checker colors), the highlight groups for the popup are updated, and a single
reused popup window is moved next to the cursor.

The popup is drawn as a grid of pixels, each one column wide and half a line
high. A character cell holds two pixels: a space if they have the same color,
or an upper half block with the upper pixel as its foreground and the lower
one as its background if they differ. The content is built from text
properties.

## Tests
The tests are run from the repository's directory, or any other, with:
```sh
vim -Nu NONE -i NONE -es -S test/run.vim
```
They print the failures, if any, and exit with an error status if there are
any.

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
