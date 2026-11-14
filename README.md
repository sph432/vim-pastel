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
With [vim-plug](https://github.com/junegunn/vim-plug) (or your favourite plugin
manager), add the plugin to your
`.vimrc` and run `:PlugInstall`:
```vim
Plug 'https://tools.sphnet.in/git/sph/vim-pastel'
```

Vim's native package directory (`~/.vim/pack/*/start/`) will work as well.

The plugin does nothing, without raising errors, if Vim lacks the required
features (SEE DEPENDENCIES) or if neither a GUI nor `termguicolors` is in use.

The documentation is also available inside Vim as `:help pastel`. Plugin
managers generate its tags; with a native package directory, run `:helptags ALL` once.

# DEPENDENCIES
- Vim 8.1.1553 or newer, built with `+popupwin`, `+textprop` and `+eval`
- A terminal with `termguicolors` enabled (or a GUI)
- Note that Neovim, lacking +popupwin, is not planned to be supported any time soon

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

## Detail text
The `d` cells of `g:pastel_color_mode` show text about the color, as given by
`g:pastel_detail_format`. A `d` is as large as a block, 10 columns by 5 lines
by default, so `'d'` is just the text, `'t|d'` has it below a checkered block
and `'td'` beside it. Details in a row or column are one region (it has to be a
rectangle): `'dd'` is one region of two cells. A `.` between cells keeps them
apart, so `'d.d'` is two regions, and a row of only `.` between rows does the
same for the rows above and below it; `.` takes no room. The regions are
numbered in reading order, by their first cell: in `'td|d.d'` the `d` right of
`t` and the one below it are region 1, the other `d` is region 2. A region
has to be a rectangle: `'td|dd'` is not valid, write `'td|.|dd'` (a region
above one of two cells) or `'td|d.d'` instead.

A region has as much room as its cells, in whole lines. If its text needs more,
it takes it, to the right first, then down, if there is nothing there: not a
block, nor another region, nor a `.` or a row of only `.` on the way. If it can
not grow, a line that is too long is cut and ends in `…`, and so does the last
line if there are too many. Regions grow in reading order, but all to the right
before any down, so in `'td|d'` the second region, if it needs the width, gets
the cell under the first before it. Where a line may be broken (`%N`) it is, if
it does not fit, instead of growing.

The format is a string, for the first region, or a list of strings, one for
each region. A region with none shows its number and the color: `Region 2`, and
`#ff8800` below it. The format is text with these `%` items:

| item | |
|---|---|
| `%r` `%g` `%b` | the red, green and blue, 0 to 255 |
| `%a` | the alpha, 0 to 1 |
| `%x` `%X` | `#rrggbb` and, if the alpha is not 1, `aa`; lower, upper case |
| `%t` | the color code as written in the buffer |
| `%{id}` | the number of the region |
| `%{rgb}` `%{hsl}` `%{hwb}` `%{hsv}` `%{cmyk}` | the color as a whole |
| `%{hsl.s}` | one value of it, eg. the saturation |
| `%#Group#` `%*` | highlight the text after it with `Group`, until `%*` |
| `%(` `%)` | text that is left out if an item in it is empty |
| `%n` | a line break |
| `%N` | where a line may be broken if too long; a space never is |
| `%%` | a `%` |

For instance `rgb(%r %g %b)`, or `'%x%n%{hsl}%nin the buffer: %t'`.

Numbers take modifiers after a colon, which can be combined: `p` is a percent
(`%r:p` is `50%`), `P` is that without the `%`, `f` a fraction (`0.5`), `x` and
`X` two hex digits, and `.N` is the number of decimals of the percent or the
fraction (`%r:p:.1` is `49.8%`); `o` leaves out an alpha of 1, `a` makes `%x`
and the models always have it. A colon and a letter after an item are always a
modifier; to have them as text, put the item in braces, `%{r}:x`.

The models are shown in the CSS notation, `hsl(32 100% 50%)`, with ` / 0.8`
after the values if the alpha is not 1, or with commas if asked for with `c`,
`hsla(32, 100%, 50%, 0.8)`. The values of the models are `r`, `g`, `b` of `rgb`,
`h`, `s`, `l` of `hsl`, `h`, `s`, `v` of `hsv`, `h`, `w`, `b` of `hwb` and `c`,
`m`, `y`, `k` of `cmyk`, so `%{hsl.s}` and `%{hsv.s}` are not the same number;
the hue is in degrees, the others percents (`p`, `P` and `f` change that), and
the red, green and blue are as `%r`. Models are rounded to whole degrees and
percents unless `.N` says otherwise, `%{hsl:.3}`; as every notation but `cmyk`,
which has none in CSS and is not recognized as a color, is read by the plugin
too, with enough decimals it is the same color. `hwb` has no comma notation.

For `%#Group#` any highlight group can be used, one that does not exist is
warned about once. These are defined as the color changes, if a format uses
them: `PastelRed`, `PastelGreen` and `PastelBlue` have the color's red, green
or blue alone as their background, `PastelCyan`, `PastelMagenta` and
`PastelYellow` their inverses (255 minus it, in cyan, magenta or yellow), and
`PastelAlpha` is a gray the lighter the less transparent the color is; the text
is black or white, whichever is easier to read on it. Text without a
highlight uses `PastelDetail`, which is linked to `Normal`, and can be changed.
For instance `'%#PastelRed#%r%*  %#PastelGreen#%g%*  %#PastelBlue#%b'`.

Everything not listed is reserved, as are the names of the other color spaces
and notations (`%{lab.l}`, `%{hsla}`, `%{hex}` and so on), to be used later. An
item that is not valid, or is not supported yet, is not text: a warning says so
and the default format is used.

## Known issues
- There is only one popup, shared by all windows and buffers, so its layout
    and colors (`g:pastel_color_mode` and the color options) are the same
    everywhere; and a popup is only shown for the cursor of the current
    window.
- In Vim versions before 8.2.4713, lacking the `WinScrolled` event, the popup
    is only updated on cursor movement; scrolling the window without moving
    the cursor leaves the popup at its old position on the screen.
- In Vim versions before 8.2.0325, without the `SafeState` event, closing or
    opening a fold without moving the cursor leaves the popup as it was until
    the cursor moves.
- In Vim versions before 8.1.1580, which lack popup masks, the area of a layout
    that no block covers (eg. right of the shorter row of `'wk|t'`) hides the
    text under it, instead of being transparent.

## Configuration
All options are global variables, set in your `.vimrc` or at any time later
with `:let`; a change takes effect the next time the popup is shown. The
defaults are shown in parentheses.

A value that is not valid for its option (eg. a float or a list for a size, or
`'FIRST'` for `g:pastel_alpha_position`) raises no error: a short warning is
shown, once per value, and the default is used instead. Numbers may also be
given as strings, eg. `'6'`.

Except for `g:pastel_color_mode` and the four color options, which belong to
the one shared popup, every option can be overridden for a buffer by the
variable with the same name, `b:pastel_<name>`, eg.
`autocmd FileType markdown let b:pastel_color_size=3`. It takes precedence over
the global one in its buffer, is validated the same way, and an invalid value
leaves the global one in effect (with a warning).

- `g:pastel_color_mode` (`'t'`) - the previews to show and their layout, a
    string of block letters, left to right:
  - `k`: the color on black
  - `w`: the color on white
  - `t`: the color on a checkered "transparent" background
  - `2`: the color on black and white, alternating
  - `3`: the color on black, checkered and white, alternating, in that order
  - `d`: details, text about the color, SEE Detail text
  - `.`: separates what is on its two sides, SEE Detail text; it takes no room
  - `|`: the blocks after it go in a new row below

  For example, `'t'` is a single block, `'kw'` shows black and white side by
  side, and `'t|kw'` shows a checkered block with black and white below it.
  Each block has its own margin, and all blocks are the same size.
  The area not covered by a block, eg. right of a shorter row, is transparent:
  the text under it stays visible.

  Any other value (including a leading, trailing or doubled `|`, or a layout
  in which the details are not valid, SEE Detail text) prints a warning. At
  startup the plugin does not load; when set later, the previous layout stays.
- `g:pastel_detail_format` (`'%x'`) - what the detail regions show: a template,
    or a list of them, SEE Detail text
- `g:pastel_color_timer` (5) - seconds between the backgrounds of `2` and `3`
    blocks changing, `0.1` or more, fractions allowed; less than that turns
    alternating off, showing the first background. The timer only runs while
    the popup is shown.
- `g:pastel_color_size` (6) - size of the color block, vertically in
    half-characters and horizontally in characters, from 1 to 1000
- `g:pastel_bg_size` (2) - size of the margin around the color block, in the
    same units, from 0 to 1000
- `g:pastel_alpha_position` ('auto') - where the alpha is in 8-digit
    hexadecimal codes:
  - `'last'`: `#RRGGBBAA`, as in CSS
  - `'first'`: `#AARRGGBB`, as in Android
  - `'auto'`: `'first'` in the filetypes of `g:pastel_alpha_first_filetypes`,
        `'last'` in the others, and a short note (`pastel: assuming ...`) the
        first time an 8-digit code is found in a buffer, as it is a guess
  - eg. to force MSB-alpha in your Android project, you could use
        `autocmd BufRead /path/to/my/android/project/*.xml let b:pastel_alpha_position='first'`
  - Note that the 4-digit form is not affected, it is always parsed as `#RGBA`.
- `g:pastel_alpha_first_filetypes` (`['java', 'kotlin']`) - the filetypes where
    `'auto'` should mean `'first'`. XML is omitted as it is indeterminate.
- `g:pastel_ignore_filetypes` (`['gitcommit', '*sql*']`) - the filetypes where
    no colors are looked for, as a list of glob patterns (`*`, `?`, `[abc]`,
    `{a,b}`), each matched against the whole filetype or any part of a
    compound one; default values are:
   - `gitcommit`, where `#123` is more likely an issue id rather than a `#RGB` color
   - `sql` and its variants (`mysql`, `plsql`, ...), for their very long lines
- `g:pastel_offset_x` (2) - horizontal placement of the popup relative to the
    color code, in characters:
  - positive: right of the code, its left edge that many columns after the
        code's last column
  - negative: left of the code, its right edge that many columns before the
        code's first column
  - `0`: centered on the code
- `g:pastel_offset_y` (0) - vertical placement relative to the cursor line:
  - positive: below, its top edge that many rows below the line
  - negative: above, its bottom edge that many rows above the line
  - `0`: centered on the line
- `g:pastel_black_bg` ('#000000') - background color of the black preview
- `g:pastel_white_bg` ('#FFFFFF') - background color of the white preview
- `g:pastel_trans_fg` ('#BFBFBF') and
- `g:pastel_trans_bg` ('#404040') - the two background colors of the checkered "transparent" preview

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
The border always adds up to an even number, but if the color size is odd,
the preview ends up with an odd height:
A pair of vertically consecutive previews will share a line between them - 
the line where two rows meet shows the bottom of the upper block over the top
of the lower one. A vertically single preview will have, in its last line the
default color on bottom.

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
