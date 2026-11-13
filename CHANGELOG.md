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
    without moving the cursor (Vim 9.0 and newer, which have `WinScrolled`;
    older versions are unaffected otherwise)

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

## 0.4.1 (planned)
#### Added
- Alternating backgrounds, switched every `g:pastel_color_timer` seconds, in
    the `2` (black and white) and `3` (black, transparent and white) modes

# TODO
- Shown color formats adjustable: hexadecimal, `rgb`, `cmyk`
    (`g:pastel_detail_mode`)
- Detect more color notations: `#RGB`, `#RRGGBBAA`, `rgb()`, `hsl()`
- Make it work with other color-code detectors (eg. RRethy/vim-hexokinase)
- Keep a test script in the repository
