if exists('g:loaded_pastel')
  finish
endif
let g:loaded_pastel=1

if !has('popupwin') || !has('textprop')
  finish
endif
if !has('gui_running') && !&termguicolors
  finish
endif

"internal
let s:pastel_win=0
let s:warned=0

"options are read every time they are used, so changes take effect at once; all
"but the layout and the colors can be overridden per buffer by b:pastel_<name>;
"an invalid value is warned about, once per value, and the default is used
"instead, as s:Opt(name) does; the checks return [value] or [] if invalid
let s:defaults={}
let s:checks={}
let s:whats={}
let s:invalid={}

"a:value as a whole number in a:low..a:high, or []; a numeric string is fine
function s:Whole(value, low, high)
  if type(a:value) == v:t_string && a:value =~ '^[+-]\?\d\+$'
    let number=str2nr(a:value)
  elseif type(a:value) == v:t_number
    let number=a:value
  else
    return []
  endif
  return number >= a:low && number <= a:high ? [number] : []
endfunction

"a:value as a whole number of any sensible size, or []
function s:Offset(value)
  return s:Whole(a:value, -1000000, 1000000)
endfunction

"a:value, if it is a number or a numeric string
function s:Seconds(value)
  let numeric=type(a:value) == v:t_number || type(a:value) == v:t_float
  if numeric || type(a:value) == v:t_string && a:value =~ '^\d\+\(\.\d\+\)\?$'
    return [a:value]
  endif
  return []
endfunction

"a:value, if it is a color a highlight group can have, a #RRGGBB one or a name
function s:ColorOption(value)
  if type(a:value) != v:t_string
    return []
  elseif a:value =~ '^#'
    return a:value =~? '^#\x\{6}$' ? [a:value] : []
  elseif a:value !~ '^\a\+$'
    return []
  endif
  try
    execute 'silent highlight pastelpcheck guibg='.a:value
    highlight clear pastelpcheck
  catch
    return []
  endtry
  return [a:value]
endfunction

"a:value, if it is one of a:allowed
function s:OneOf(value, allowed)
  return type(a:value) == v:t_string && index(a:allowed, a:value) >= 0
\        ? [a:value] : []
endfunction

"a:value, if it is a list of strings
function s:Strings(value)
  if type(a:value) == v:t_list
\    && empty(filter(copy(a:value), 'type(v:val) != v:t_string'))
    return [a:value]
  endif
  return []
endfunction

"short, as a longer message in a cursor movement is truncated by the ruler or
"asks for a keypress
function s:Warn(message)
  echohl WarningMsg
  echom strcharpart(a:message, 0, &columns-22)
  echohl None
endfunction

"set g:pastel_<name> to a:default if it is not set, and have it checked by
"a:Check; a:what says what a valid value is, for the warning
function s:Define(name, default, Check, what)
  let s:defaults[a:name]=a:default
  let s:checks[a:name]=a:Check
  let s:whats[a:name]=a:what
  let g:['pastel_'.a:name]=get(g:, 'pastel_'.a:name, a:default)
endfunction

"the value a:value of the variable a:variable, if valid for the option a:name,
"else a:fallback, with a warning unless this value was already warned about;
"it does not say what is used instead, to leave room for what is wrong
function s:Checked(name, variable, value, fallback)
  let checked=s:checks[a:name](a:value)
  if !empty(checked)
    return checked[0]
  endif
  if get(s:invalid, a:variable, '') !=# string(a:value)
    let s:invalid[a:variable]=string(a:value)
    call s:Warn('pastel: '.a:variable.' '.strcharpart(string(a:value), 0, 20)
\               .' is not '.s:whats[a:name])
  endif
  return a:fallback
endfunction

"the options that b:pastel_<name> overrides in a buffer; not the layout and
"the colors, as there is only one popup, shared by all buffers
let s:buffer_local=['alpha_position', 'alpha_first_filetypes',
\                   'ignore_filetypes', 'color_timer', 'color_size',
\                   'bg_size', 'offset_x', 'offset_y']

"the value of the option g:pastel_<name>, or of b:pastel_<name> if the buffer
"has a valid one; an invalid one leaves the global value in effect
function s:Opt(name)
  let value=s:Checked(a:name, 'g:pastel_'.a:name,
\                     get(g:, 'pastel_'.a:name, s:defaults[a:name]),
\                     s:defaults[a:name])
  if exists('b:pastel_'.a:name) && index(s:buffer_local, a:name) >= 0
    return s:Checked(a:name, 'b:pastel_'.a:name, b:['pastel_'.a:name], value)
  endif
  return value
endfunction

"options
"a definition of color blocks to show, from left to right
"  combination of the following as a string:
"  w - color on white background
"  k - color on black background
"  t - color on checkered "transparent" background
"  2 - k and w alternating
"  3 - k, t and w alternating (in that order)
"  | - put the blocks following it in a new row
"
"blocks are of the same size (see below), each with its own margin
" "t" is sharkdp/pastel's look,
" other suggested combinations are "k", "2t", "t|kw" and "3"
let g:pastel_color_mode=get(g:, 'pastel_color_mode', 't')

"alternate between backgrounds every n seconds in "2" and "3" blocks, 0.1 or
"more; less than that turns alternating off, showing the first background
call s:Define('color_timer', 5, function('s:Seconds'), 'a number')

"a definition of color codes to show, from top to bottom
"  combination of the following as a string:
"  x - hexadecimal RGB
"  r - rgb  0-255
"  c - cmyk 0-255
let g:pastel_detail_mode=get(g:, 'pastel_detail_mode', 'x')

"where the alpha is in 8-digit hexadecimal codes:
"  last  - #RRGGBBAA, as in CSS
"  first - #AARRGGBB, as in Android
"  auto  - first in the filetypes listed below, last in the others, with a
"          one-time note per buffer about the guess
"4-digit codes are always #RGBA
call s:Define('alpha_position', 'auto',
\             {value -> s:OneOf(value, ['auto', 'first', 'last'])},
\             'auto, first or last')
call s:Define('alpha_first_filetypes', ['java', 'kotlin'],
\             function('s:Strings'), 'a list of strings')

"filetypes where no colors are looked for, as glob patterns: sql and its
"variants for their very long lines, gitcommit where #123 is an issue and not
"a color; lines longer than 'synmaxcol' are never looked at, if it is not 0
call s:Define('ignore_filetypes', ['gitcommit', '*sql*'],
\             function('s:Strings'), 'a list of strings')

"size is measured vertically in half-chars, horizontally in chars
"6/2 is how sharkdp/pastel looks
call s:Define('color_size', 6, {value -> s:Whole(value, 1, 1000)}, '1..1000')
call s:Define('bg_size', 2, {value -> s:Whole(value, 0, 1000)}, '0..1000')

"popup placement relative to the color code, in characters; positive means
"right/below, negative left/above, 0 centered; if the popup would not fit
"on the screen, the offset is inverted
"  x: 2 puts the popup's left edge 2 columns after the code's last column
"  y: 0 centers the popup on the cursor line
call s:Define('offset_x', 2, function('s:Offset'), 'a whole number')
call s:Define('offset_y', 0, function('s:Offset'), 'a whole number')

"these are better left alone but you may want to change trans colors
call s:Define('white_bg', '#FFFFFF', function('s:ColorOption'), 'a color')
"75% gray
call s:Define('trans_fg', '#BFBFBF', function('s:ColorOption'), 'a color')
"25% gray
call s:Define('trans_bg', '#404040', function('s:ColorOption'), 'a color')
call s:Define('black_bg', '#000000', function('s:ColorOption'), 'a color')

"the blocks of a g:pastel_color_mode value: a list of rows, each a list of w,
"k, t, 2 or 3; empty (and a warning is shown) if the value is not supported
function s:ParseLayout(mode)
  if string(a:mode) !~# '^''[wkt23]\+\(|[wkt23]\+\)*''$'
    echohl WarningMsg
    echom 'pastel: unsupported g:pastel_color_mode '.string(a:mode)
\         .', only w, k, t, 2, 3 and | (not leading, trailing or doubled)'
\         .' are supported'
    if string(a:mode) =~# 'b'
      echom 'pastel: the black block was renamed from b to k'
    endif
    echohl None
    return []
  endif
  return map(split(a:mode, '|'), 'split(v:val, ''\zs'')')
endfunction

let s:layout=s:ParseLayout(g:pastel_color_mode)
if empty(s:layout)
  finish
endif
"the value s:layout was made from
let s:mode=g:pastel_color_mode

"follow changes of g:pastel_color_mode; an unsupported value is warned about
"once and the previous layout stays
function s:UpdateLayout()
  if string(g:pastel_color_mode) !=# string(s:mode)
    let s:mode=g:pastel_color_mode
    let layout=s:ParseLayout(s:mode)
    if !empty(layout)
      let s:layout=layout
    endif
  endif
endfunction

"the popup is drawn as a grid of pixels, a pixel being 1 column wide and half
"a line high; each pixel has one of these colors:
"  k - black, w - white, d - dark and l - light checker,
"  1, 2, 3 and 4 - the color shown, on the background k, w, d or l,
"  n - none, the default color, only used to pad an odd height to full lines
"a character cell is 2 pixels high, drawn as a space if both have the same
"color and as an upper half block (fg: upper, bg: lower) if they differ
let s:colors=['k', 'w', 'd', 'l', '1', '2', '3', '4', 'n']
"the pixel showing the color on a background, by the background's letter
let s:over={'k': '1', 'w': '2', 'd': '3', 'l': '4'}
"you should not see this, ever
let s:color=[255, 0, 255, 1.0]
"the colors of the pixels, by their letters above
let s:hex={}

"a color, [red, green, blue, alpha], with the channels 0 to 255 and the alpha
"0.0 to 1.0, as a #RRGGBB string
function s:ToHex(color)
  return printf('#%02X%02X%02X', a:color[0], a:color[1], a:color[2])
endfunction

"a:color shown over a:background, a #rrggbb color, as a #RRGGBB string; the
"alpha is ignored if the background is not a #rrggbb color
function s:Blend(color, background)
  let alpha=a:color[3]
  if alpha >= 1.0 || a:background !~? '^#\x\{6}$'
    return s:ToHex(a:color)
  endif
  let blended=[]
  for i in range(3)
    let over=a:color[i]
    let under=str2nr(a:background[2*i+1:2*i+2], 16)
    call add(blended, float2nr(round(alpha*over+(1-alpha)*under)))
  endfor
  return s:ToHex(blended)
endfunction

function s:UpdateHex()
  let s:hex={'k': s:Opt('black_bg'), 'w': s:Opt('white_bg'),
\            'd': s:Opt('trans_bg'), 'l': s:Opt('trans_fg'), 'n': 'NONE'}
  for background in ['k', 'w', 'd', 'l']
    let s:hex[s:over[background]]=s:Blend(s:color, s:hex[background])
  endfor
endfunction

function s:DefineHighlight(upper, lower)
  execute 'highlight pastelp'.a:upper.a:lower
\         .' guifg='.s:hex[a:upper].' guibg='.s:hex[a:lower]
endfunction

"the values of the color options the highlight groups were made from
let s:colorkey=''

function s:ColorKey()
  return join([s:Opt('black_bg'), s:Opt('white_bg'), s:Opt('trans_bg'),
\              s:Opt('trans_fg')])
endfunction

function s:DefineHighlights()
  let s:colorkey=s:ColorKey()
  call s:UpdateHex()
  for upper in s:colors
    for lower in s:colors
      call s:DefineHighlight(upper, lower)
    endfor
  endfor
endfunction

function s:SetupPopupHilightStyles()
  call s:DefineHighlights()
  for upper in s:colors
    for lower in s:colors
      let name='pastelp'.upper.lower
      call prop_type_add(name, {'highlight': name})
    endfor
  endfor
endfunction

"make a:color, a [red, green, blue, alpha] list, the color shown
function s:SetColor(color)
  if a:color == s:color
    return
  endif
  let s:color=a:color
  call s:UpdateHex()
  for upper in s:colors
    for lower in s:colors
      if upper =~ '\d' || lower =~ '\d'
        call s:DefineHighlight(upper, lower)
      endif
    endfor
  endfor
endfunction

"the margin and the color's size, g:pastel_bg_size and g:pastel_color_size,
"read once per drawing, as they are needed for every pixel
let s:margin=0
let s:inner=0

function s:ReadSizes()
  let s:margin=s:Opt('bg_size')
  let s:inner=s:Opt('color_size')
endfunction

"size of a block in pixels, both ways
function s:BlockSize()
  return 2*s:margin+s:inner
endfunction

"color of pixel (a:x, a:y), counted from 0 from the popup's top left; pixels
"outside the blocks, and so the padding of an odd height, are default colored
"how many timer ticks the alternating blocks have advanced
let s:phase=0

"the background, w, k or t, of a block of g:pastel_color_mode
function s:Background(block)
  if a:block == '2'
    return ['k', 'w'][s:phase % 2]
  elseif a:block == '3'
    return ['k', 't', 'w'][s:phase % 3]
  endif
  return a:block
endfunction

function s:Pixel(x, y)
  let bg=s:margin
  let size=s:inner
  let block=s:BlockSize()
  let row=a:y / block
  let col=a:x / block
  if row >= len(s:layout) || col >= len(s:layout[row])
    return 'n'
  endif
  let x=a:x % block
  let y=a:y % block
  let background=s:Background(s:layout[row][col])
  if background == 't'
    let pixel=(x+y) % 2 ? 'd' : 'l'
  else
    let pixel=background == 'w' ? 'w' : 'k'
  endif
  if x >= bg && x < bg+size && y >= bg && y < bg+size
    return s:over[pixel]
  endif
  return pixel
endfunction

"[columns, lines] of the popup; an odd height in pixels gets an extra row of
"default colored pixels at the bottom
function s:Size()
  let width=max(map(copy(s:layout), 'len(v:val)'))*s:BlockSize()
  let height=len(s:layout)*s:BlockSize()
  return [width, (height+1)/2]
endfunction

"popup masks, which make the area no block covers transparent, need this;
"without them the text under that area is hidden
let s:has_mask=has('patch-8.1.1580')

"[col, endcol, line, endline] rectangles for the popup's mask, covering the
"character cells without any pixels, so that the text under them is not hidden;
"a run of such cells is added to the rectangle above it if it spans the same
"columns
function s:AddEmptyCells(rects, line, from, to)
  for rect in a:rects
    if rect[0] == a:from && rect[1] == a:to && rect[3] == a:line-1
      let rect[3]=a:line
      return
    endif
  endfor
  call add(a:rects, [a:from, a:to, a:line, a:line])
endfunction

function s:SetPopupContent(popup)
  "what is beyond the screen is never seen, so the work is limited to it, as
  "sizes can be so large that drawing them all would hang Vim
  let [width, lines]=s:Size()
  let width=min([width, &columns])
  let lines=min([lines, &lines])
  let popuptext=[]
  let mask=[]
  for line in range(lines)
    let text=''
    let props=[]
    let runstart=0
    for x in range(width)
      let upper=s:Pixel(x, 2*line)
      let lower=s:Pixel(x, 2*line+1)
      let char=s:hex[upper] ==? s:hex[lower] ? ' ' : '▀'
      let type='pastelp'.upper.lower
      if !empty(props) && props[-1].type == type
        let props[-1].length+=len(char)
      else
        call add(props, {'col': len(text)+1, 'length': len(char),
\                        'type': type})
      endif
      let text.=char
      if upper == 'n' && lower == 'n'
        let runstart=runstart ? runstart : x+1
      elseif runstart
        call s:AddEmptyCells(mask, line+1, runstart, x)
        let runstart=0
      endif
    endfor
    if runstart
      call s:AddEmptyCells(mask, line+1, runstart, width)
    endif
    call add(popuptext, {'text': text, 'props': props})
  endfor
  call popup_settext(a:popup, popuptext)
  if s:has_mask
    call popup_setoptions(a:popup, {'mask': mask})
  endif
endfunction

"whether 8-digit codes in this buffer have the alpha first; if that is
"guessed, say so once per buffer
function s:AlphaFirst()
  let setting=s:Opt('alpha_position')
  if setting ==# 'first'
    return 1
  elseif setting !=# 'auto'
    return 0
  endif
  let filetypes=split(&filetype, '\.')
  let known=s:Opt('alpha_first_filetypes')
  let first=!empty(filter(filetypes,
\                        {_, filetype -> index(known, filetype) >= 0}))
  if !exists('b:pastel_alpha_noted')
    let b:pastel_alpha_noted=1
    let message='pastel: assuming '.(first ? '#AARRGGBB' : '#RRGGBBAA')
\               .', see README'
    call s:Warn(message)
  endif
  return first
endfunction

"the color of a #rgb, #rgba, #rrggbb or #rrggbbaa code, as [red, green, blue,
"alpha]
function s:ParseHex(code)
  let digits=a:code[1:]
  let alphafirst=0
  if len(digits) == 4 || len(digits) == 8
    let alphafirst=len(digits) == 8 && s:AlphaFirst()
  endif
  if len(digits) <= 4
    let digits=join(map(split(digits, '\zs'), 'v:val.v:val'), '')
  elseif alphafirst
    let digits=digits[2:].digits[:1]
  endif
  let color=map(range(3), 'str2nr(digits[2*v:val:2*v:val+1], 16)')
  let alpha=len(digits) == 8 ? str2nr(digits[6:7], 16)/255.0 : 1.0
  return color+[alpha]
endfunction

"a:value, a number or a float, limited to a:low to a:high
function s:Clamp(value, low, high)
  return a:value < a:low ? a:low : a:value > a:high ? a:high : a:value
endfunction

"[value, unit] of a:token, a CSS number with an optional unit (%, deg, grad,
"rad or turn), with the unit in lower case, or [0.0, 'none'] for the keyword
"none, or [] if it is neither
function s:CssToken(token)
  let number='[+-]\=\%(\d\+\%(\.\d\+\)\=\|\.\d\+\)\%(e[+-]\=\d\+\)\='
  let found=matchlist(a:token,
\                     '\c^\('.number.'\)\(%\|deg\|grad\|rad\|turn\)\=$')
  if !empty(found)
    return [str2float(found[1]), tolower(found[2])]
  endif
  return a:token ==? 'none' ? [0.0, 'none'] : []
endfunction

"a red, green or blue channel, 0 to 255, of a CSS token, or -1 if it is no
"channel
function s:CssChannel(token)
  let [value, unit]=a:token
  if unit == '%'
    let value=value*255/100.0
  elseif unit != '' && unit != 'none'
    return -1
  endif
  return float2nr(round(s:Clamp(value, 0.0, 255.0)))
endfunction

"a hue, 0.0 up to 360.0, of a CSS token, or -1.0 if it is no hue
function s:CssHue(token)
  let [value, unit]=a:token
  if unit == 'grad'
    let value=value*0.9
  elseif unit == 'rad'
    let value=value*180/(4*atan(1.0))
  elseif unit == 'turn'
    let value=value*360
  elseif unit != '' && unit != 'deg' && unit != 'none'
    return -1.0
  endif
  let hue=fmod(value, 360.0)
  return hue < 0 ? hue+360 : hue
endfunction

"a saturation, lightness, whiteness, blackness or value, 0.0 to 1.0, of a CSS
"token, or -1.0 if it is no such thing; a plain number is a percentage if
"a:plain is 100.0, and a fraction if it is 1.0
function s:CssFraction(token, plain)
  let [value, unit]=a:token
  if unit == '%'
    return s:Clamp(value/100, 0.0, 1.0)
  elseif unit != '' && unit != 'none'
    return -1.0
  endif
  return s:Clamp(value/a:plain, 0.0, 1.0)
endfunction

"the 0 to 255 channels of a:fractions, [red, green, blue] from 0.0 to 1.0
function s:Channels(fractions)
  return map(copy(a:fractions), 'float2nr(round(v:val*255))')
endfunction

"the color of the hue a:hue (0.0 up to 360.0), saturation a:saturation and
"lightness a:lightness (both 0.0 to 1.0), as [red, green, blue] from 0.0 to 1.0
function s:HslToFractions(hue, saturation, lightness)
  let range=a:saturation*(a:lightness < 0.5 ? a:lightness : 1-a:lightness)
  let color=[]
  for offset in [0, 8, 4]
    let k=fmod(offset+a:hue/30, 12.0)
    let ramp=k-3
    if 9-k < ramp
      let ramp=9-k
    endif
    let ramp=s:Clamp(ramp, -1.0, 1.0)
    call add(color, a:lightness-range*ramp)
  endfor
  return color
endfunction

"the color of the hue a:hue (0.0 up to 360.0), whiteness a:whiteness and
"blackness a:blackness (both 0.0 to 1.0), as [red, green, blue]; if they
"add up to 1.0 or more, it is a gray
function s:HwbToRgb(hue, whiteness, blackness)
  let total=a:whiteness+a:blackness
  if total >= 1
    return s:Channels(repeat([a:whiteness/total], 3))
  endif
  let color=[]
  for fraction in s:HslToFractions(a:hue, 1.0, 0.5)
    call add(color, fraction*(1-total)+a:whiteness)
  endfor
  return s:Channels(color)
endfunction

"the color of the hue a:hue (0.0 up to 360.0), saturation a:saturation and
"value a:value (both 0.0 to 1.0), as [red, green, blue]
function s:HsvToRgb(hue, saturation, value)
  let color=[]
  for offset in [5, 3, 1]
    let k=fmod(offset+a:hue/60, 6.0)
    let ramp=k
    if 4-k < ramp
      let ramp=4-k
    endif
    let ramp=s:Clamp(ramp, 0.0, 1.0)
    call add(color, a:value-a:value*a:saturation*ramp)
  endfor
  return s:Channels(color)
endfunction

"the color of a CSS rgb(), rgba(), hsl(), hsla(), hwb() or hwba() function, or
"a Less hsv() or hsva() one, in the comma notation or the space and slash one,
"as [red, green, blue, alpha], or [] if it is not valid; hwb() has no comma
"notation, as in CSS
function s:ParseCss(text)
  let found=matchlist(a:text,
\                     '\c^\(rgba\=\|hsla\=\|hwba\=\|hsva\=\)(\(.*\))$')
  if empty(found)
    return []
  endif
  let kind=substitute(tolower(found[1]), 'a$', '', '')
  let args=trim(found[2])
  let alpha=''
  if args =~ ','
    if kind == 'hwb' || args =~ '/' || args =~? 'none'
      return []
    endif
    let parts=map(split(args, ',', 1), 'trim(v:val)')
    if len(parts) < 3 || len(parts) > 4
      return []
    endif
    let channels=parts[:2]
    let alpha=get(parts, 3, '')
  else
    let sides=split(args, '/', 1)
    if len(sides) > 2
      return []
    endif
    let channels=split(sides[0])
    let alpha=len(sides) == 2 ? trim(sides[1]) : ''
    if len(sides) == 2 && alpha == ''
      return []
    endif
  endif
  if len(channels) != 3
    return []
  endif
  let tokens=map(copy(channels), 's:CssToken(v:val)')
  if index(tokens, []) >= 0
    return []
  endif
  let opacity=1.0
  if alpha != ''
    let token=s:CssToken(alpha)
    if empty(token) || token[1] != '' && token[1] != '%' && token[1] != 'none'
      return []
    endif
    let opacity=s:Clamp(token[1] == '%' ? token[0]/100 : token[0], 0.0, 1.0)
  endif
  if kind == 'rgb'
    let color=map(copy(tokens), 's:CssChannel(v:val)')
    return index(color, -1) >= 0 ? [] : color+[opacity]
  endif
  let hue=s:CssHue(tokens[0])
  let plain=kind == 'hsv' ? 1.0 : 100.0
  let second=s:CssFraction(tokens[1], plain)
  let third=s:CssFraction(tokens[2], plain)
  if hue < 0 || second < 0 || third < 0
    return []
  elseif kind == 'hsl'
    return s:Channels(s:HslToFractions(hue, second, third))+[opacity]
  elseif kind == 'hwb'
    return s:HwbToRgb(hue, second, third)+[opacity]
  endif
  return s:HsvToRgb(hue, second, third)+[opacity]
endfunction

"the notations of colors: the pattern finding them in a line, and the parser
"getting a found text's color, [red, green, blue, alpha], or [] if it is not
"one after all
let s:formats=[
\ {'pattern': '\v(\w)@<!#(\x{8}|\x{6}|\x{4}|\x{3})\w@!',
\  'parse': function('s:ParseHex')},
\ {'pattern': '\c\v(\w)@<!(rgba?|hsla?|hwba?|hsva?)\([^()]*\)',
\  'parse': function('s:ParseCss')},
\]

"whether not to look for colors on the current line: in a closed fold, in the
"filetypes matching g:pastel_ignore_filetypes, and on lines longer than
"'synmaxcol', as looking through a very long line at every cursor movement
"would be slow; checked before reading the line, which would copy it
function s:Ignored()
  "the code is not displayed in a closed fold
  if foldclosed('.') >= 0
    return 1
  endif
  for filetype in split(&filetype, '\.')
    for pattern in s:Opt('ignore_filetypes')
      if filetype =~# glob2regpat(pattern)
        return 1
      endif
    endfor
  endfor
  return &synmaxcol > 0 && col('$') > &synmaxcol+1
endfunction

"[color, start, end] of the color code under the cursor, the start and end
"being the byte range of the code in the line, or []; if several overlap,
"the first one, and of those the longest
function s:ColorAtCursor()
  if s:Ignored()
    return []
  endif
  let line=getline('.')
  let col=col('.')-1
  let found=[]
  for format in s:formats
    let start=0
    while 1
      let [text, mbeg, mend]=matchstrpos(line, format.pattern, start)
      if mbeg < 0 || mbeg > col
        break
      elseif col < mend
        let color=call(format.parse, [text])
        if !empty(color) && (empty(found) || mbeg < found[1]
\                            || mbeg == found[1] && mend > found[2])
          let found=[color, mbeg, mend]
        endif
        break
      endif
      let start=mend
    endwhile
  endfor
  return found
endfunction

"[start, fits] of a popup of a:size on one axis, placed relative to the anchor
"positions [a:first, a:last] by offset a:off (SEE g:pastel_offset_x/y);
"the offset is inverted if the popup would not fit in a:low..a:limit; if it
"fits neither way, it is moved into a:low..a:limit as far as possible and fits
"is 0
function s:Axis(first, last, size, off, low, limit)
  let starts=[]
  for off in [a:off, -a:off]
    if off > 0
      call add(starts, a:last+off)
    elseif off < 0
      call add(starts, a:first+off-a:size+1)
    else
      call add(starts, a:first+(a:last-a:first+1)/2-a:size/2)
    endif
  endfor
  for start in starts
    if start >= a:low && start+a:size-1 <= a:limit
      return [start, 1]
    endif
  endfor
  return [max([a:low, min([starts[0], a:limit-a:size+1])]), 0]
endfunction

"[first, last] screen lines the popup may cover: not the tabline, if there is
"one, nor the status line of the last window, nor the command line
function s:Rows()
  let tabline=&showtabline == 2 || &showtabline == 1 && tabpagenr('$') > 1
  if has('gui_running') && &guioptions =~# 'e'
    let tabline=0
  endif
  let status=&laststatus >= 2 || &laststatus == 1 && winnr('$') > 1
  return [1+tabline, &lines-&cmdheight-status]
endfunction

"[first, last] screen columns of a code a:length cells long, of which the
"character a:before cells from its start is at screen column a:scrcol; its
"characters are one cell wide; it is mirrored in right-to-left windows, where
"it starts at its right end
function s:CodeColumns(scrcol, before, length, rightleft)
  if a:rightleft
    let last=a:scrcol+a:before
    return [last-(a:length-1), last]
  endif
  let first=a:scrcol-a:before
  return [first, first+a:length-1]
endfunction

"popup position for the code at byte range [mbeg, mend); if there is no room
"on either side of the code, the popup goes above or below its line instead
function s:Position(mbeg, mend)
  let [w, h]=s:Size()
  let [minline, maxline]=s:Rows()
  if (w > &columns || h > maxline-minline+1) && !s:warned
    let s:warned=1
    echohl WarningMsg
    echom 'pastel: the popup ('.w.'x'.h.') is larger than the screen'
    echohl None
  endif
  let cur=col('.')-1
  let offset_y=s:Opt('offset_y')
  let [wrow, wcol]=win_screenpos(0)
  let scrcol=wcol+wincol()-1
  let scrrow=wrow+winline()-1
  let [first, last]=s:CodeColumns(scrcol, cur-a:mbeg, a:mend-a:mbeg, &rightleft)
  let [left, fits]=s:Axis(first, last, w, s:Opt('offset_x'), 1, &columns)
  if fits
    let [top, fits]=s:Axis(scrrow, scrrow, h, offset_y, minline, maxline)
  else
    let left=max([1, min([first, &columns-w+1])])
    let [top, fits]=s:Axis(scrrow, scrrow, h, offset_y ? offset_y : 1,
\                          minline, maxline)
  endif
  return {'line': top, 'col': left, 'pos': 'topleft'}
endfunction

"forget the popup if something else closed it
function s:CheckPopup()
  if s:pastel_win && empty(popup_getpos(s:pastel_win))
    let s:pastel_win=0
  endif
endfunction

"the timer advancing alternating blocks, only running while it is needed
let s:timer=0
let s:timer_ms=0

function s:StopTimer()
  if s:timer
    call timer_stop(s:timer)
    let s:timer=0
    let s:timer_ms=0
  endif
endfunction

function s:OnTimer(id)
  call s:CheckPopup()
  call s:ReadSizes()
  if !s:pastel_win || !popup_getpos(s:pastel_win).visible
    call s:StopTimer()
    return
  endif
  let s:phase+=1
  call s:SetPopupContent(s:pastel_win)
endfunction

"run the timer if the layout has alternating blocks and the interval is valid
"(it is read every time, so changes take effect), else stop it
function s:UpdateTimer()
  let ms=float2nr(str2float(string(s:Opt('color_timer')))*1000)
  if ms < 100 || string(s:layout) !~ '[23]'
    call s:StopTimer()
    let s:phase=0
  elseif !s:timer || ms != s:timer_ms
    call s:StopTimer()
    let s:timer=timer_start(ms, function('s:OnTimer'), {'repeat': -1})
    let s:timer_ms=ms
  endif
endfunction

function s:Hide()
  call s:StopTimer()
  call s:CheckPopup()
  if s:pastel_win
    call popup_hide(s:pastel_win)
  endif
endfunction

"the screen column of the cursor is not up to date during CursorMoved if there
"is concealed text on the line, so the popup is placed again after the redraw
let s:replace=0

function s:OnReplace(id) abort
  let s:replace=0
  call s:Update(0)
endfunction

function s:OnCursorMove() abort
  call s:Update(1)
endfunction

"show, move or hide the popup as the cursor requires; a:again says whether it
"may be placed again later
function s:Update(again) abort
  call s:CheckPopup()
  call s:ReadSizes()
  call s:UpdateLayout()
  if s:ColorKey() !=# s:colorkey
    call s:DefineHighlights()
  endif
  let hit=s:ColorAtCursor()
  if empty(hit)
    call s:Hide()
  else
    call s:SetColor(hit[0])
    let pos=s:Position(hit[1], hit[2])
    if s:pastel_win
      call popup_show(s:pastel_win)
      call popup_move(s:pastel_win, pos)
    else
      let s:pastel_win=popup_create([], extend(pos,
\                                 {'highlight': 'Normal', 'wrap': 0}))
    endif
    call s:UpdateTimer()
    call s:SetPopupContent(s:pastel_win)
    if a:again && &conceallevel > 0 && !s:replace
      let s:replace=timer_start(0, function('s:OnReplace'))
    endif
  endif
endfunction

"folds are closed and opened without the cursor moving, which no event tells
"about, so whether the cursor line is in a closed fold is checked whenever Vim
"is idle, if it has the event
let s:folded=0

function s:OnSafeState() abort
  let folded=foldclosed('.') >= 0
  if folded != s:folded
    let s:folded=folded
    call s:OnCursorMove()
  endif
endfunction

call s:SetupPopupHilightStyles()

augroup pastel
  autocmd!
  autocmd CursorMoved * call s:OnCursorMove()
  autocmd InsertEnter,BufLeave,WinLeave * call s:Hide()
  autocmd InsertLeave,WinEnter * call s:OnCursorMove()
  autocmd ColorScheme * call s:DefineHighlights()
  "the events are not available in older Vims
  if exists('##WinScrolled')
    autocmd WinScrolled * call s:OnCursorMove()
  endif
  if exists('##SafeState')
    autocmd SafeState * call s:OnSafeState()
  endif
augroup end

"vim: sw=2 ts=2 et fdm=syntax
