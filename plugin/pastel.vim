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
" sharkdp/pastel's look would be "t",
" other suggested combinations are "2t", "t|kw" and "3"
let g:pastel_color_mode=get(g:, 'pastel_color_mode', 'k')

"alternate between backgrounds every n seconds in "2" and "3" blocks, 0.1 or
"more; less than that turns alternating off, showing the first background
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
  let s:hex={'k': g:pastel_black_bg, 'w': g:pastel_white_bg,
\            'd': g:pastel_trans_bg, 'l': g:pastel_trans_fg, 'n': 'NONE'}
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
  return join([g:pastel_black_bg, g:pastel_white_bg, g:pastel_trans_bg,
\              g:pastel_trans_fg])
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

"size of a block in pixels, both ways
function s:BlockSize()
  return 2*g:pastel_bg_size+g:pastel_color_size
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
  let bg=g:pastel_bg_size
  let size=g:pastel_color_size
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
  let [width, lines]=s:Size()
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

"the color of a #rgb, #rgba, #rrggbb or #rrggbbaa code, as [red, green, blue,
"alpha]
function s:ParseHex(code)
  let digits=a:code[1:]
  if len(digits) <= 4
    let digits=join(map(split(digits, '\zs'), 'v:val.v:val'), '')
  endif
  let color=map(range(3), 'str2nr(digits[2*v:val:2*v:val+1], 16)')
  let alpha=len(digits) == 8 ? str2nr(digits[6:7], 16)/255.0 : 1.0
  return color+[alpha]
endfunction

"the notations of colors: the pattern finding them in a line, and the parser
"getting a found text's color, [red, green, blue, alpha], or [] if it is not
"one after all
let s:formats=[
\ {'pattern': '\v(\w)@<!#(\x{8}|\x{6}|\x{4}|\x{3})\w@!',
\  'parse': function('s:ParseHex')},
\]

"[color, start, end] of the color code under the cursor, the start and end
"being the byte range of the code in the line, or []; if several overlap,
"the first one, and of those the longest
function s:ColorAtCursor()
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
"the offset is inverted if the popup would not fit in 1..a:limit; if it fits
"neither way, it is moved into 1..a:limit as far as possible and fits is 0
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
      return [start, 1]
    endif
  endfor
  return [max([1, min([starts[0], a:limit-a:size+1])]), 0]
endfunction

"popup position for the code at byte range [mbeg, mend); if there is no room
"on either side of the code, the popup goes above or below its line instead
function s:Position(mbeg, mend)
  let [w, h]=s:Size()
  let maxline=&lines-&cmdheight
  if (w > &columns || h > maxline) && !s:warned
    let s:warned=1
    echohl WarningMsg
    echom 'pastel: the popup ('.w.'x'.h.') is larger than the screen'
    echohl None
  endif
  let cur=col('.')-1
  let [wrow, wcol]=win_screenpos(0)
  let scrcol=wcol+wincol()-1
  let scrrow=wrow+winline()-1
  let first=scrcol-(cur-a:mbeg)
  let [left, fits]=s:Axis(first, scrcol+(a:mend-1-cur), w,
\                         g:pastel_offset_x, &columns)
  if fits
    let [top, fits]=s:Axis(scrrow, scrrow, h, g:pastel_offset_y, maxline)
  else
    let left=max([1, min([first, &columns-w+1])])
    let [top, fits]=s:Axis(scrrow, scrrow, h,
\                          g:pastel_offset_y ? g:pastel_offset_y : 1, maxline)
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
  let ms=float2nr(str2float(string(g:pastel_color_timer))*1000)
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

function s:OnCursorMove() abort
  call s:CheckPopup()
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
