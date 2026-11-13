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
" default is "btw", sharkdp/pastel's look would be "t",
" other suggested combinations are "2t" "2|t" and "3"
let g:pastel_color_mode=get(g:, 'pastel_color_mode', 't')

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

if g:pastel_color_size % 2 || g:pastel_bg_size % 2
  echohl WarningMsg
  echom 'pastel: odd sizes are not yet implemented'
  echohl None
  finish
endif

function s:SetPopupContent(popup, bg)
  let bgh=g:pastel_bg_size / 2
  let bgw=g:pastel_bg_size
  let colh=g:pastel_color_size / 2
  let colw=g:pastel_color_size
  let totw=bgw*2+colw
  let blank=repeat(' ', totw)
  let bgline={'text': blank,
\             'props': [{'col': 1, 'length': totw, 'type': a:bg}]}
  let colline={'text': blank,
\              'props': [{'col': 1, 'length': bgw, 'type': a:bg},
\                        {'col': bgw+1, 'length': colw, 'type': 'pastel_C'},
\                        {'col': bgw+colw+1, 'length': bgw, 'type': a:bg}]}
  let popuptext=repeat([bgline], bgh) + repeat([colline], colh)
\              + repeat([bgline], bgh)
  call popup_settext(a:popup, popuptext)
endfunction

function s:DefineHighlights()
  execute 'highlight pastelBlack guibg='.g:pastel_black_bg
  execute 'highlight pastelWhite guibg='.g:pastel_white_bg
  execute 'highlight pastelTrans    guifg='.g:pastel_trans_fg
\         .' guibg='.g:pastel_trans_bg
  execute 'highlight pastelTransInv guifg='.g:pastel_trans_bg
\         .' guibg='.g:pastel_trans_fg
  "you should not see this, ever
  highlight pastelColor guifg=#FF00FF
endfunction

function s:SetupPopupHilightStyles()
  call s:DefineHighlights()
  call prop_type_add('pastel_b', {'highlight': 'pastelBlack'})
  call prop_type_add('pastel_w', {'highlight': 'pastelWhite'})
  call prop_type_add('pastel_t', {'highlight': 'pastelTrans'})
  call prop_type_add('pastel_T', {'highlight': 'pastelTransInv'})
  call prop_type_add('pastel_C', {'highlight': 'pastelColor'})
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
  let h=g:pastel_bg_size+g:pastel_color_size/2
  let w=2*g:pastel_bg_size+g:pastel_color_size
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
    execute 'highlight pastelColor guibg='.hit[0]
    let pos=s:Position(hit[1], hit[2])
    if s:pastel_win
      call popup_show(s:pastel_win)
      call popup_move(s:pastel_win, pos)
    else
      let s:pastel_win=popup_create([], pos)
    endif
    call s:SetPopupContent(s:pastel_win, 'pastel_b')
  endif
endfunction

call s:SetupPopupHilightStyles()

augroup pastel
  autocmd!
  autocmd CursorMoved * call s:OnCursorMove()
  autocmd InsertEnter,BufLeave,WinLeave * call s:Hide()
  autocmd InsertLeave,WinEnter * call s:OnCursorMove()
  autocmd ColorScheme * call s:DefineHighlights()
augroup end

"vim: sw=2 ts=2 et fdm=syntax
