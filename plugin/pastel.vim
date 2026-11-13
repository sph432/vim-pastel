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

"options
"a definition of color blocks to show, from left to right
"  combination of the following as a string:
"  w - color on white background
"  b - color on black background
"  t - color on checkered "transparent" background
"  2 - b and w alternating
"  3 - b, t and w alternating (in that order)
"  | - put blocks right of it in a new line
"
"blocks are of the same size (see below)
" sharkdp/pastel's look would be "t",
" other suggested combinations are "2t" "2|t" and "3"
"
"only a single w, b or t is supported for now
let g:pastel_color_mode=get(g:, 'pastel_color_mode', 'b')

"alternate between backgrounds every n seconds in "2" and "3" blocks
let g:pastel_color_timer=get(g:, 'pastel_color_timer', 5)

"a definition of color codes to show, from top to bottom
"  combination of the following as a string:
"  x - hexadecimal RGB
"  r - rgb  0-255
"  c - cmyk 0-255
let g:pastel_detail_mode=get(g:, 'pastel_detail_mode', 'x')

"size is measured vertically in half-chars, horizontally in chars
"6/2 is how sharkdp/pastel looks
let g:pastel_color_size=get(g:, 'pastel_color_size', 6)
let g:pastel_bg_size=get(g:, 'pastel_bg_size', 2)

"popup placement relative to the color code, in characters; positive means
"right/below, negative left/above, 0 centered; if the popup would not fit
"on the screen, the offset is inverted
"  x: 2 puts the popup's left edge 2 columns after the code's last column
"  y: 0 centers the popup on the cursor line
let g:pastel_offset_x=get(g:, 'pastel_offset_x', 2)
let g:pastel_offset_y=get(g:, 'pastel_offset_y', 0)

"these are better left alone but you may want to change trans colors
let g:pastel_white_bg=get(g:, 'pastel_white_bg', '#FFFFFF')
let g:pastel_trans_fg=get(g:, 'pastel_trans_fg', '#BFBFBF') "75% gray
let g:pastel_trans_bg=get(g:, 'pastel_trans_bg', '#404040') "25% gray
let g:pastel_black_bg=get(g:, 'pastel_black_bg', '#000000')

if index(['w', 'b', 't'], g:pastel_color_mode) < 0
  echohl WarningMsg
  echom 'pastel: unsupported g:pastel_color_mode "'.g:pastel_color_mode
\       .'", only a single w, b or t is supported for now'
  echohl None
  finish
endif

"the popup is drawn as a grid of pixels, a pixel being 1 column wide and half
"a line high; each pixel has one of these colors:
"  k - black, w - white, d - dark and l - light checker, c - the color shown
"a character cell is 2 pixels high, drawn as a space if both have the same
"color and as an upper half block (fg: upper, bg: lower) if they differ
let s:colors=['k', 'w', 'd', 'l', 'c']
"you should not see this, ever
let s:color='#FF00FF'

function s:Hex()
  return {'k': g:pastel_black_bg, 'w': g:pastel_white_bg,
\         'd': g:pastel_trans_bg, 'l': g:pastel_trans_fg, 'c': s:color}
endfunction

function s:DefineHighlight(upper, lower)
  let hex=s:Hex()
  execute 'highlight pastelp'.a:upper.a:lower
\         .' guifg='.hex[a:upper].' guibg='.hex[a:lower]
endfunction

function s:DefineHighlights()
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

function s:SetColor(hex)
  let s:color=a:hex
  for other in s:colors
    call s:DefineHighlight('c', other)
    call s:DefineHighlight(other, 'c')
  endfor
endfunction

"color of pixel (a:x, a:y), counted from 0 from the popup's top left
function s:Pixel(x, y)
  let bg=g:pastel_bg_size
  let size=g:pastel_color_size
  if a:x >= bg && a:x < bg+size && a:y >= bg && a:y < bg+size
    return 'c'
  elseif g:pastel_color_mode == 't'
    return (a:x+a:y) % 2 ? 'd' : 'l'
  endif
  return g:pastel_color_mode == 'w' ? 'w' : 'k'
endfunction

"[columns, lines] of the popup; an odd height in pixels gets an extra row of
"background pixels at the bottom
function s:Size()
  let size=2*g:pastel_bg_size+g:pastel_color_size
  return [size, (size+1)/2]
endfunction

function s:SetPopupContent(popup)
  let [width, lines]=s:Size()
  let popuptext=[]
  for line in range(lines)
    let text=''
    let props=[]
    for x in range(width)
      let upper=s:Pixel(x, 2*line)
      let lower=s:Pixel(x, 2*line+1)
      let char=upper == lower ? ' ' : '▀'
      let type='pastelp'.upper.lower
      if !empty(props) && props[-1].type == type
        let props[-1].length+=len(char)
      else
        call add(props, {'col': len(text)+1, 'length': len(char),
\                        'type': type})
      endif
      let text.=char
    endfor
    call add(popuptext, {'text': text, 'props': props})
  endfor
  call popup_settext(a:popup, popuptext)
endfunction

"[code, start, end] of the #rrggbb code under the cursor, or []
function s:ColorAtCursor()
  let line=getline('.')
  let col=col('.')-1
  let start=0
  while 1
    let [color, mbeg, mend]=matchstrpos(line, '\v#\x{6}\x@!', start)
    if mbeg < 0
      return []
    endif
    if col < mbeg
      return []
    elseif col < mend
      return [color, mbeg, mend]
    endif
    let start=mend
  endwhile
endfunction

"start of a popup of a:size on one axis, placed relative to the anchor
"positions [a:first, a:last] by offset a:off (SEE g:pastel_offset_x/y);
"the offset is inverted if the popup would not fit in 1..a:limit
function s:Axis(first, last, size, off, limit)
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
    if start >= 1 && start+a:size-1 <= a:limit
      return start
    endif
  endfor
  return max([1, min([starts[0], a:limit-a:size+1])])
endfunction

"popup position for the code at byte range [mbeg, mend)
function s:Position(mbeg, mend)
  let [w, h]=s:Size()
  let cur=col('.')-1
  let [wrow, wcol]=win_screenpos(0)
  let scrcol=wcol+wincol()-1
  let scrrow=wrow+winline()-1
  let left=s:Axis(scrcol-(cur-a:mbeg), scrcol+(a:mend-1-cur), w,
\                 g:pastel_offset_x, &columns)
  let top=s:Axis(scrrow, scrrow, h, g:pastel_offset_y, &lines-&cmdheight)
  return {'line': top, 'col': left, 'pos': 'topleft'}
endfunction

"forget the popup if something else closed it
function s:CheckPopup()
  if s:pastel_win && empty(popup_getpos(s:pastel_win))
    let s:pastel_win=0
  endif
endfunction

function s:Hide()
  call s:CheckPopup()
  if s:pastel_win
    call popup_hide(s:pastel_win)
  endif
endfunction

function s:OnCursorMove() abort
  call s:CheckPopup()
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
      let s:pastel_win=popup_create([], pos)
    endif
    call s:SetPopupContent(s:pastel_win)
  endif
endfunction

call s:SetupPopupHilightStyles()

augroup pastel
  autocmd!
  autocmd CursorMoved * call s:OnCursorMove()
  autocmd InsertEnter,BufLeave,WinLeave * call s:Hide()
  autocmd InsertLeave,WinEnter * call s:OnCursorMove()
  autocmd ColorScheme * call s:DefineHighlights()
  "the event is not available in older Vims
  if exists('##WinScrolled')
    autocmd WinScrolled * call s:OnCursorMove()
  endif
augroup end

"vim: sw=2 ts=2 et fdm=syntax
