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

# 0.6 - more color formats (planned)
## 0.6.0 (planned)
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

## 0.6.1 (planned)
#### Added
- CSS `rgb()`, `rgba()`, `hsl()` and `hsla()`, in the comma and the space
    and `/` notations

## 0.6.2 (planned)
#### Added
- `hwb()` and `hsv()`

## 0.6.3 (planned)
#### Added
- `lab()`, `lch()`, `oklab()` and `oklch()`; colors outside sRGB are clamped
    to it, SEE the TODO

## 0.6.4 (planned)
#### Added
- Colors in Sass and Less functions with a color argument, eg.
    `rgba(#fff, 0.5)`

# TODO
- Shown color formats adjustable: hexadecimal, `rgb`, `cmyk`
    (`g:pastel_detail_mode`)
- Color notations from outside the web: no source of truth was surveyed yet
    (eg. languages' color literals, X11 `rgb:RR/GG/BB`, LaTeX)
- CMY, CMYK and CMYKA notations: there is no agreed-upon syntax, not even in
    CSS
- Make it work with other color-code detectors (eg. RRethy/vim-hexokinase)
- Color spaces: colors outside sRGB (eg. from `lab()` or `oklch()`) are
    clamped to it, instead of mapped into it as CSS Color 4 specifies
