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

# TODO
- Color modes: show the color on white, black and "transparent" backgrounds
    (`g:pastel_color_mode`: `w`, `b`, `t`, `2`, `3`, `|`)
- Alternating multichar "transparent" background (`▀`)
- Alternate backgrounds on a timer in the `2` and `3` modes
    (`g:pastel_color_timer`)
- Shown color formats adjustable: hexadecimal, `rgb`, `cmyk`
    (`g:pastel_detail_mode`)
- Support odd `g:pastel_color_size` and `g:pastel_bg_size` values
- Detect more color notations: `#RGB`, `#RRGGBBAA`, `rgb()`, `hsl()`
- Make it work with other color-code detectors (eg. RRethy/vim-hexokinase)
- Keep a test script in the repository
