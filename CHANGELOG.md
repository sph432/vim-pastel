# 0.1 - first usable release
## 0.1.0
#### Added
- Popup previewing the color under the cursor when it is a `#RRGGBB` code,
    shown on a black background
- Configuration through `g:pastel_*` variables; user values are not overridden
- Popup is hidden in insert mode and when leaving the buffer, and shown again
    on leaving insert mode
- Plugin skips loading, instead of erroring, without `+popupwin`, `+textprop`
    or truecolor support

## 0.1.1
#### Fixed
- Stale popup handle when the popup is closed by something other than the
    plugin (eg. `popup_clear()`): the popup is now recreated instead of
    erroring

# 0.2 - cursor behavior
## 0.2.0
#### Fixed
- Popup covering the color code it previews; it is now placed right of the
    code, or left of it if there is no room
- Popup placement near the top line and the bottom and right screen edges
- Popup not following window switches: it is hidden on leaving a window and
    shown again on returning to a color code

## 0.2.1
#### Added
- Popup placement preferences `g:pastel_offset_x` and `g:pastel_offset_y`; the
    offset is inverted along an axis where the popup would not fit

#### Fixed
- Popup staying at its old screen position when the window is scrolled
    without moving the cursor (Vim 8.2.4713 and newer, which have
    `WinScrolled`; older versions still leave it in place)

# 0.3 - preview backgrounds
## 0.3.0
#### Added
- Background of the preview selectable with `g:pastel_color_mode`: `b`
    (black), `w` (white) or `t` (checkered "transparent")

## 0.3.1
#### Added
- Support for odd `g:pastel_color_size` and `g:pastel_bg_size` values

#### Fixed
- Checkered "transparent" background not alternating properly

# 0.4 - layouts
## 0.4.0
#### Added
- Layout of previews in `g:pastel_color_mode`: several blocks side by side,
    and `|` to start a new row; every block has its own margin
- Options changed at runtime with `:let` take effect on the next popup,
    including the color options
- Popup placed below or above the code's line when there is no room on either
    side of it, instead of covering the code
- One-time warning when the popup is larger than the screen; such a popup is
    clipped, not wrapped

## 0.4.1
#### Added
- Alternating backgrounds, switched every `g:pastel_color_timer` seconds, in
    the `2` (black and white) and `3` (black, transparent and white) modes

#### Fixed
- Layouts with rows of different length (eg. `wb|t`) blanking the text under
    the area no block covers; it is now transparent (in Vim 8.1.1580 and
    newer, older versions still blank it)

# 0.5 - transparency
## 0.5.0
#### Added
- Colors with an alpha channel (`#RRGGBBAA`), shown blended over each
    background; on the checkered background the checkers show through

#### Changed
- The black block of `g:pastel_color_mode` is now `k`, as it was `b`; the
    default is now `'k'`. BREAKING: `b` is no longer accepted, so a
    `g:pastel_color_mode` containing it must be updated; the warning on an
    unsupported value mentions the rename

# 0.6 - more color formats
## 0.6.0
#### Added
- Colors in the `#RGB` and `#RGBA` notations
- Option for the position of the alpha digits in 8-digit codes,
    `g:pastel_alpha_position`: `#RRGGBBAA` (`last`), `#AARRGGBB` (`first`) or
    `auto`, which picks by filetype (`g:pastel_alpha_first_filetypes`) and says
    so once per buffer; `b:pastel_alpha_position` overrides it per buffer

#### Changed
- Hexadecimal codes must not be preceded or followed by a letter, digit or
    underscore: `#abcdefg1` is no longer taken for `#abcdef`, and `#define` is
    not taken for a color

## 0.6.1
#### Added
- CSS `rgb()`, `rgba()`, `hsl()` and `hsla()`, in the comma and the space
    and `/` notations, with numbers, percentages, angle units and `none`

# 0.7 - robustness
## 0.7.0
#### Added
- `hwb()` and `hwba()` (in the space and slash notation, as in CSS), and the
    Less `hsv()` and `hsva()`
- `g:pastel_ignore_filetypes`, the filetypes where no colors are looked for,
    as glob patterns

#### Changed
- No colors are looked for in the `gitcommit` and `*sql*` filetypes by
    default, where `#123` is an issue and not a color, and where lines can be
    very long. BREAKING: previews no longer appear there; set
    `g:pastel_ignore_filetypes` to `[]` to get them back
- Invalid option values (eg. a float or a list for a size, a color Vim does
    not know, `'FIRST'` for `g:pastel_alpha_position`) are warned about, once
    per value, and the option's default is used instead; `g:pastel_color_size`
    must now be from 1 to 1000, and `g:pastel_bg_size` from 0 to 1000

#### Fixed
- Cursor movement lagging on very long lines (seconds, on lines of millions
    of characters): lines longer than `'synmaxcol'` are not searched
- An error on every cursor movement with a float, a list or an unknown color
    as an option's value
- Vim hanging with very large sizes: only the part of the popup on the screen
    is drawn
- Popup covering the tabline, or the status line of the last window
- Popup overlapping the code in right-to-left windows (`'rightleft'`)
- Popup shown for a code in a closed fold, where it is not displayed; it now
    follows the fold being closed and opened (Vim 8.2.0325 and newer, which
    have `SafeState`; older versions update it on the next cursor movement)
- Popup far from the code when text on the line is concealed

# 0.8 - per-buffer options
## 0.8.0
#### Added
- Per-buffer overrides of the options, `b:pastel_<name>`, validated like the
    global ones: for all but `g:pastel_color_mode` and the color options, which
    belong to the single shared popup; `b:pastel_alpha_position` was the only
    one before

#### Changed
- The default of `g:pastel_color_mode` is now `'t'` (the checkered
    background, as in sharkdp/pastel), as it was `'k'`; set it to `'k'` to
    keep the black one

# 0.9 - details
## 0.9.0
#### Added
- Detail regions: `d` cells in `g:pastel_color_mode` show text about the color
    as given by the new `g:pastel_detail_format` (a template for the first
    region or a list of them, `'%x'` by default; a region without one shows its
    number and the color). Cells next to each other are one region, which has
    to be a rectangle; a `.` between cells, or a row of only `.` between rows,
    keeps regions apart and takes no room. Regions grow to the right, then
    down, into free space as far as their text needs, and are cut with `…`
    where they can not
- Templates with the items `%r %g %b %a %x %X %t %{id} %n %N %%` and the
    modifiers `p P f x X .N o a` (eg. `%r:p:.1`); the other items, `%#`, `%*`,
    `%(`, `%)` and the color space names are reserved, and an invalid item is
    warned about, not taken for text

#### Changed
- `g:pastel_detail_mode`, which never did anything, is replaced by
    `g:pastel_detail_format`

## 0.9.1
#### Added
- The color as a whole in templates, `%{rgb}`, `%{hsl}`, `%{hwb}`, `%{hsv}` and
    `%{cmyk}`, in the CSS notation (`hsl(32 100% 50% / 0.8)`), with `:c` for the
    comma notation and `:a` to always have the alpha, and by value, eg.
    `%{hsl.s}`; whole degrees and percents unless `.N` is given, with which
    the notations read by the plugin give the same color back
- Groups of items in templates, `%(`...`%)`, which are left out if an item in
    them is empty, eg. `%( / %a:o%)`
- Highlights in templates, `%#Group#` to `%*`, and groups for the red, green
    and blue of the color (`PastelRed`, `PastelGreen`, `PastelBlue`), their
    inverses (`PastelCyan`, `PastelMagenta`, `PastelYellow`) and its alpha
    (`PastelAlpha`), defined as the color changes, if a template uses them

# 0.10 - ANSI colors (planned)
## 0.10.0 (planned)
#### Added
- Colors in ANSI SGR sequences: `38`, `48` and `58` (foreground, background
    and underline) with `2` (RGB), `3` (CMY) or `4` (CMYK), in the semicolon
    form (`38;2;255;136;0`) and the colon form (`38:2::255:136:0`); the
    sequence may be written with a real escape character, `\e`, `\033`,
    `\x1b`, `^[`, or without any (`38;2;255;136;0`). The color space tag of
    T.416 (the empty element after `2`, `3` or `4` in the colon form) is
    accepted and ignored for now. The indexed form (`38:5:n`, `38;5;n`) is
    not a color by itself, as OSC 4 can set what the indexes are, so it is
    not shown; the default palette may be added later, as a named palette
- This is the first notation with CMY and CMYK, which also gives `%{cmyk}`
    and a `cmy` model for templates a notation to be read back as

# 0.11 - color operations (planned)
Pastel's commands that change a color, working on the color under the cursor
and rewriting it in place, in its own notation, or in another one. They need
the models of the templates to give the same color back (SEE
`g:pastel_detail_format`).

Undecided, for all of them but `pick` most of all: where the result goes (over
the color in the buffer, into a register, or only shown in the popup) and in
which notation (that of the original, or a chosen one). This is to be decided
once, for the whole group, before any of them is built.
#### Added
- `pick`: choose a color and insert it
- `complement`, `rotate` (the hue), `lighten` and `darken`, `saturate` and
    `desaturate` (`to-gray` of pastel is the latter taken to the end)
- `format`: rewrite the color in another notation, eg. from `#ff8800` to
    `hsl(32 100% 50%)`
- Showing an arbitrary color in the popup, not only one in the buffer
    (pastel's `color`)

# 0.12 - more color tools (maybe, planned)
#### Added
- `mix`, `gradient`, `distinct` and `random`
- `colorblind` (simulation of color vision deficiencies) and `textcolor`
    (the readable black or white for a background)
- Where results go and in which notation (SEE 0.11) applies to these as well;
    `gradient` and `distinct` produce several colors, so it matters more

# 0.x - several popups (planned)
#### Added
- A popup for each window or buffer instead of the single shared one, and with
    it per-buffer layout (`b:pastel_color_mode`) and colors; it may be done
    only in 1.0.0

# 1.x - beyond 1.0 (planned)
#### Added
- Colors in Sass and Less functions with a color argument, eg.
    `rgba(#fff, 0.5)`
- `lab()`, `lch()`, `oklab()` and `oklch()`, only in the space and slash
    notation, as in CSS Color 4
- `color()` with the predefined color spaces, eg. `display-p3`
- Colors outside sRGB are mapped into it as CSS Color 4 specifies, instead of
    being clamped to it

# Not planned
Commands of pastel that do not fit a plugin or are already covered: `colorcheck`
(truecolor is required anyway), `gray` (only a special case of `desaturate`),
`paint` (no text formatting, ANSI output is `format`), `help` and `list`
(`:help pastel`).

# TODO
- Color notations from outside the web: no source of truth was surveyed yet
    (eg. languages' color literals, X11 `rgb:RR/GG/BB`, LaTeX)
- CMY, CMYK and CMYKA notations other than ANSI SGR (0.10.0): there is no
    agreed-upon syntax, not even in CSS
- Make it work with other color-code detectors (eg. RRethy/vim-hexokinase)
